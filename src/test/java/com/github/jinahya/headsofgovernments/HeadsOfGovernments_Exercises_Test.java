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

import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.sqlite.SQLiteDataSource;

import javax.sql.DataSource;
import java.sql.DriverManager;

/**
 * Runs a few exercises of {@code src/test/sql} through plain JDBC against {@code db/heads_of_governments.sqlite3} and
 * prints the rows they return. A query here is the text of its exercise in the file, which carries the same id, with a
 * bind variable ({@code :country}) written as {@code ?}; a change to one is a change to the other.
 *
 * <p>The code is for the book, so it is kept plain: the driver is loaded once, by {@link Class#forName(String)} in a
 * static initializer; the first exercise connects through {@link DriverManager}, the others through a
 * {@link DataSource}.</p>
 */
@Slf4j
class HeadsOfGovernments_Exercises_Test {

    /**
     * The class name of the SQLite JDBC driver.
     */
    static final String DRIVER = "org.sqlite.JDBC";

    static {
        try {
            Class.forName(DRIVER);
        } catch (final ClassNotFoundException cnfe) {
            throw new ExceptionInInitializerError(cnfe);
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    /**
     * The database, relative to the project directory, which is where surefire runs.
     */
    static final String URL = "jdbc:sqlite:db/heads_of_governments.sqlite3";

    // -----------------------------------------------------------------------------------------------------------------
    @BeforeAll
    static void messageOnly() {
        _LoggingUtils.messageOnly();
    }

    // -----------------------------------------------------------------------------------------------------------------
    @DisplayName("HOG-OFFICE-B-02 The offices")
    @Test
    void offices() throws Exception {
        final var sql = """
                SELECT country, head_kind, head_title
                FROM office
                ORDER BY country ASC""";
        try (var connection = DriverManager.getConnection(URL);
             var statement = connection.createStatement();
             var results = statement.executeQuery(sql)) {
            while (results.next()) {
                final var country = results.getString("country");
                final var headKind = results.getString("head_kind");
                final var headTitle = results.getString("head_title");
                log.debug("{}\t{}\t{}", country, headKind, headTitle);
            }
        }
    }

    @DisplayName("HOG-HEAD-B-02 One country's list")
    @ParameterizedTest(name = "[{index}] {0}")
    @ValueSource(strings = {"FR", "GB", "JP", "KR", "US"})
    void heads(final String country) throws Exception {
        final var sql = """
                SELECT *
                FROM head
                WHERE country = ?
                ORDER BY term_start ASC""";
        final var dataSource = new SQLiteDataSource();
        dataSource.setUrl(URL);
        try (var connection = dataSource.getConnection();
             var statement = connection.prepareStatement(sql)) {
            statement.setString(1, country);
            try (var results = statement.executeQuery()) {
                while (results.next()) {
                    final var id = results.getLong("id");
                    final var number = results.getInt("number");
                    final var termStart = results.getString("term_start");
                    final var termEnd = results.getString("term_end");
                    final var name = results.getString("name");
                    final var party = results.getString("party");
                    final var born = results.getInt("born");
                    var died = (Integer) results.getInt("died");
                    if (results.wasNull()) {
                        died = null;
                    }
                    log.debug("{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}",
                              id, country, number, termStart, termEnd, name, party, born, died);
                }
            }
        }
    }

    @DisplayName("HOG-HEAD-I-11 Party share of completed terms, the top three per country")
    @Test
    void partyShareTopThree() throws Exception {
        final var sql = """
                SELECT country, party, tenure_share
                FROM (SELECT country,
                             party,
                             ROUND(100.0 * SUM(julianday(term_end) - julianday(term_start))
                                       / SUM(SUM(julianday(term_end) - julianday(term_start))) OVER (PARTITION BY country),
                                   1) AS  tenure_share,
                             ROW_NUMBER() OVER (PARTITION BY country
                                 ORDER BY SUM(julianday(term_end) - julianday(term_start)) DESC)             AS place
                      FROM head
                      WHERE term_end IS NOT NULL
                      GROUP BY country, party)
                WHERE place <= 3
                ORDER BY country ASC, tenure_share DESC""";
        final var dataSource = new SQLiteDataSource();
        dataSource.setUrl(URL);
        try (var connection = dataSource.getConnection();
             var statement = connection.createStatement();
             var results = statement.executeQuery(sql)) {
            while (results.next()) {
                final var country = results.getString("country");
                final var party = results.getString("party");
                final var tenureShare = results.getDouble("tenure_share");
                log.debug("{}\t{}\t{}", country, party, tenureShare);
            }
        }
    }
}
