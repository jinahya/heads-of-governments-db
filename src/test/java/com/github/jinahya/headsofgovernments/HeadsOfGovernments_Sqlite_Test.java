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

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Types;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Generates {@code db/heads_of_governments.sqlite3} from the {@code .asv} resources, then reopens it and checks it.
 * The schema is documented in {@code db/heads_of_governments.sqlite3.md}; keep the two in step.
 */
class HeadsOfGovernments_Sqlite_Test {

    /** The file to generate, relative to the project directory, which is where surefire runs. */
    static final Path PATH = Path.of("db", "heads_of_governments.sqlite3");

    static final String TABLE_GOVERNMENT = "government";

    static final String TABLE_HEAD = "head";

    /** The schema, in execution order. */
    static final List<String> DDL = List.of(
            """
            CREATE TABLE government (
                country    TEXT NOT NULL PRIMARY KEY,
                head_kind  TEXT NOT NULL CHECK (head_kind IN ('PRESIDENT', 'PRIME_MINISTER')),
                head_title TEXT NOT NULL,
                numbering  TEXT NOT NULL
            ) WITHOUT ROWID""",
            """
            CREATE TABLE head (
                country    TEXT    NOT NULL REFERENCES government (country),
                number     INTEGER NOT NULL,
                term_start TEXT    NOT NULL,
                term_end   TEXT,
                name       TEXT    NOT NULL,
                party      TEXT    NOT NULL,
                born       INTEGER NOT NULL,
                died       INTEGER,
                PRIMARY KEY (country, term_start),
                CHECK (term_end IS NULL OR term_end >= term_start),
                CHECK (died IS NULL OR died >= born)
            ) WITHOUT ROWID""",
            "CREATE INDEX idx_head_country_number ON head (country, number)",
            "CREATE INDEX idx_head_name ON head (name)",
            // a government has at most one sitting head; also makes the incumbents a four-entry lookup
            "CREATE UNIQUE INDEX uq_head_incumbent ON head (country) WHERE term_end IS NULL"
    );

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
    static int insertGovernments(final Connection connection, final List<Government> governments)
            throws SQLException {
        final var sql = """
                INSERT INTO government (country, head_kind, head_title, numbering)
                VALUES (?, ?, ?, ?)""";
        var inserted = 0;
        try (var statement = connection.prepareStatement(sql)) {
            for (final var government : governments) {
                statement.setString(1, government.country());
                statement.setString(2, government.headKind());
                statement.setString(3, government.headTitle());
                statement.setString(4, government.numbering());
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
        final var governments = Government.readAll();
        final var heads = governments.stream()
                .map(Government::country)
                .sorted()
                .flatMap(c -> {
                    try {
                        return Head.readAll(c).stream();
                    } catch (final java.io.IOException ioe) {
                        throw new java.io.UncheckedIOException(ioe);
                    }
                })
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
            assertThat(insertGovernments(connection, governments)).isEqualTo(governments.size());
            assertThat(insertHeads(connection, heads)).isEqualTo(heads.size());
            connection.commit();
            connection.setAutoCommit(true);
            // populate sqlite_stat1 so a consumer's query planner has index statistics
            execute(connection, "ANALYZE");
        }
        // reopen and check
        try (var connection = DriverManager.getConnection(url())) {
            assertThat(count(connection, "SELECT COUNT(*) FROM government")).isEqualTo(4);
            assertThat(count(connection, "SELECT COUNT(*) FROM head")).isEqualTo(heads.size()).isEqualTo(254);
            for (final var e : Map.of("GB", 81, "JP", 105, "KR", 21, "US", 47).entrySet()) {
                assertThat(count(connection, "SELECT COUNT(*) FROM head WHERE country = '" + e.getKey() + "'"))
                        .as(e.getKey()).isEqualTo(e.getValue());
            }
            assertThat(count(connection, "SELECT COUNT(*) FROM head WHERE term_end IS NULL"))
                    .as("incumbents").isEqualTo(4);
            assertThat(count(connection, "SELECT COUNT(*) FROM head WHERE country NOT IN (SELECT country FROM government)"))
                    .as("orphans").isZero();
            assertThat(count(connection, "SELECT COUNT(*) FROM pragma_foreign_key_check")).as("foreign_key_check rows").isZero();
            assertThat(count(connection, "SELECT COUNT(*) FROM sqlite_stat1")).as("ANALYZE ran").isPositive();
            assertThat(count(connection, "SELECT COUNT(*) FROM sqlite_master WHERE type = 'index' AND name = 'uq_head_incumbent'"))
                    .as("uq_head_incumbent exists").isOne();
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
