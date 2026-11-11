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

import java.sql.DriverManager;

import static com.github.jinahya.headsofgovernments.HeadsOfGovernments_Sqlite_Test.count;
import static org.assertj.core.api.Assertions.assertThat;

/**
 * Opens the database the way a consumer does: as a classpath resource, through {@code jdbc:sqlite::resource:}, which
 * makes {@code sqlite-jdbc} extract it to a temporary file first.
 */
class HeadsOfGovernments_Resource_Test {

    @Test
    void the_database_opens_as_a_classpath_resource() throws Exception {
        final var url = "jdbc:sqlite::resource:" + HeadsOfGovernments_Sqlite_Test.RESOURCE_NAME;
        try (var connection = DriverManager.getConnection(url)) {
            assertThat(count(connection, "SELECT COUNT(*) FROM office")).isEqualTo(5);
            assertThat(count(connection, "SELECT COUNT(*) FROM head WHERE term_end IS NULL"))
                    .as("incumbents").isEqualTo(5);
            assertThat(count(connection, "SELECT COUNT(*) FROM incumbent")).as("incumbent rows").isEqualTo(5);
        }
    }
}
