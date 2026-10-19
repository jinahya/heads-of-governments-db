/*-
 * #%L
 * heads-of-governments-db
 * %%
 * Copyright (C) 2026 Jinahya, Inc.
 * %%
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * #L%
 */
package com.github.jinahya.headsofgovernments;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Types;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Generates {@code db/heads_of_governments.sqlite3} from {@code schema.sql} and the {@code .asv} resources, then
 * reopens it and checks it. The schema is documented in {@code db/heads_of_governments.sqlite3.md}; keep the two in
 * step.
 */
class HeadsOfGovernments_Sqlite_Test {

    /** The file to generate, relative to the project directory, which is where surefire runs. */
    static final Path PATH = Path.of("db", "heads_of_governments.sqlite3");

    static final String TABLE_OFFICE = "office";

    static final String TABLE_HEAD = "head";

    /** The schema, {@code schema.sql} beside the lists, in execution order; one element per statement. */
    static final List<String> DDL = ddl();

    private static List<String> ddl() {
        final String text;
        try (var stream = HeadsOfGovernments_Sqlite_Test.class.getResourceAsStream("/schema.sql")) {
            text = new String(Objects.requireNonNull(stream, "schema.sql").readAllBytes(), StandardCharsets.UTF_8);
        } catch (final IOException ioe) {
            throw new UncheckedIOException(ioe);
        }
        // a statement ends with a ';' that ends a line; a ';' inside a comment does not. The comment lines before a
        // statement (the license, a note) are dropped: SQLite keeps a statement's text from its first keyword, and
        // sqlite-jdbc fails on a statement that opens with a comment
        return Stream.of(Pattern.compile("(?m);[ \\t]*$").split(text))
                .map(v -> v.lines().dropWhile(l -> l.isBlank() || l.stripLeading().startsWith("--"))
                        .collect(Collectors.joining(System.lineSeparator())))
                .map(String::strip)
                .filter(v -> !v.isBlank())
                .toList();
    }

    // -----------------------------------------------------------------------------------------------------------------
    static String url() {
        return "jdbc:sqlite:" + PATH.toAbsolutePath();
    }

    static void execute(final Connection connection, final String sql) throws SQLException {
        try (var statement = connection.createStatement()) {
            statement.execute(sql);
        }
    }

    static int count(final Connection connection, final String sql) throws SQLException {
        try (var statement = connection.createStatement(); var results = statement.executeQuery(sql)) {
            assertThat(results.next()).isTrue();
            return results.getInt(1);
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    static int insertOffices(final Connection connection, final List<Office> offices)
            throws SQLException {
        final var sql = """
                INSERT INTO office (country, head_kind, head_title, numbering)
                VALUES (?, ?, ?, ?)""";
        var inserted = 0;
        try (var statement = connection.prepareStatement(sql)) {
            for (final var office : offices) {
                statement.setString(1, office.country());
                statement.setString(2, office.headKind());
                statement.setString(3, office.headTitle());
                statement.setString(4, office.numbering());
                inserted += statement.executeUpdate();
            }
        }
        return inserted;
    }

    static int insertHeads(final Connection connection, final List<Head> heads) throws SQLException {
        final var sql = """
                INSERT INTO head (country, number, term_start, term_end, name, party, born, died)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)""";
        var inserted = 0;
        try (var statement = connection.prepareStatement(sql)) {
            for (final var head : heads) {
                statement.setString(1, head.country());
                statement.setInt(2, head.number());
                statement.setString(3, head.termStart().toString());
                if (head.termEnd() == null) {
                    statement.setNull(4, Types.VARCHAR);
                } else {
                    statement.setString(4, head.termEnd().toString());
                }
                statement.setString(5, head.name());
                statement.setString(6, head.party());
                statement.setInt(7, head.born());
                if (head.died() == null) {
                    statement.setNull(8, Types.INTEGER);
                } else {
                    statement.setInt(8, head.died());
                }
                inserted += statement.executeUpdate();
            }
        }
        return inserted;
    }

    // -----------------------------------------------------------------------------------------------------------------
    @Test
    void generate() throws Exception {
        // the .asv files are the inputs; refuse to build from stale ones
        for (final var baseName : _Asv_Test.BASE_NAMES) {
            assertThat(_Asv.readText(baseName + ".asv"))
                    .as("%s.asv is not %s.txt flattened; regenerate it first", baseName, baseName)
                    .isEqualTo(_Asv.flattenResource(baseName + ".txt"));
        }
        final var offices = Office.readAll();
        final var heads = offices.stream()
                .map(Office::country)
                .sorted()
                .flatMap(c -> {
                    try {
                        return Head.readAll(c).stream();
                    } catch (final java.io.IOException ioe) {
                        throw new java.io.UncheckedIOException(ioe);
                    }
                })
                // insertion order is id order; make it country, then term_start, so a run is reproducible
                .sorted(Comparator.comparing(Head::country).thenComparing(Head::termStart))
                .toList();
        // start from an empty file, so the result holds nothing but this run
        Files.createDirectories(PATH.getParent());
        Files.deleteIfExists(PATH);
        try (var connection = DriverManager.getConnection(url())) {
            execute(connection, "PRAGMA foreign_keys = ON");
            // a read-only distribution file: no pointer-map pages, smallest file
            execute(connection, "PRAGMA auto_vacuum = NONE");
            for (final var ddl : DDL) {
                execute(connection, ddl);
            }
            connection.setAutoCommit(false);
            assertThat(insertOffices(connection, offices)).isEqualTo(offices.size());
            assertThat(insertHeads(connection, heads)).isEqualTo(heads.size());
            connection.commit();
            connection.setAutoCommit(true);
            // populate sqlite_stat1 so a consumer's query planner has index statistics
            execute(connection, "ANALYZE");
        }
        // reopen and check
        try (var connection = DriverManager.getConnection(url())) {
            assertThat(count(connection, "SELECT COUNT(*) FROM office")).isEqualTo(5);
            assertThat(count(connection, "SELECT COUNT(*) FROM head")).isEqualTo(heads.size()).isEqualTo(285);
            for (final var e : Map.of("FR", 31, "GB", 81, "JP", 105, "KR", 21, "US", 47).entrySet()) {
                assertThat(count(connection, "SELECT COUNT(*) FROM head WHERE country = '" + e.getKey() + "'"))
                        .as(e.getKey()).isEqualTo(e.getValue());
            }
            assertThat(count(connection, "SELECT MIN(id) FROM head")).as("first id").isOne();
            assertThat(count(connection, "SELECT MAX(id) FROM head")).as("last id").isEqualTo(heads.size());
            assertThat(count(connection, "SELECT COUNT(*) FROM (SELECT country, term_start FROM head GROUP BY 1, 2 HAVING COUNT(*) > 1)"))
                    .as("(country, term_start) duplicates").isZero();
            assertThat(count(connection, "SELECT COUNT(*) FROM head WHERE term_end IS NULL"))
                    .as("incumbents").isEqualTo(5);
            assertThat(count(connection, "SELECT COUNT(*) FROM head WHERE country NOT IN (SELECT country FROM office)"))
                    .as("orphans").isZero();
            assertThat(count(connection, "SELECT COUNT(*) FROM pragma_foreign_key_check")).as("foreign_key_check rows").isZero();
            assertThat(count(connection, "SELECT COUNT(*) FROM sqlite_stat1")).as("ANALYZE ran").isPositive();
            assertThat(count(connection, "SELECT COUNT(*) FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_head_%'"))
                    .as("indexes").isEqualTo(2);
        }
        // the last word: compact the file, and leave it with no free page
        try (var connection = DriverManager.getConnection(url())) {
            execute(connection, "VACUUM");
            assertThat(count(connection, "PRAGMA freelist_count")).as("free pages after VACUUM").isZero();
            try (var statement = connection.createStatement();
                 var results = statement.executeQuery("PRAGMA integrity_check")) {
                assertThat(results.next()).isTrue();
                assertThat(results.getString(1)).as("integrity_check").isEqualTo("ok");
            }
        }
        assertThat(PATH).isRegularFile();
        assertThat(Files.size(PATH)).isPositive();
    }
}
