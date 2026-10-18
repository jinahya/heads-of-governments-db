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
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.Locale;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Checks the {@code .asv} resources: that each is the flattened form of its {@code .txt}, and that they parse into
 * the expected records.
 */
class _Asv_Test {

    /** Every list, by base name; each exists as {@code .txt} (the source) and {@code .asv} (the flattened form). */
    static final String[] BASE_NAMES = {
            "list_of_governments",
            "list_of_presidents_of_japan",
            "list_of_presidents_of_south_korea",
            "list_of_presidents_of_the_united_states",
            "list_of_prime_ministers_of_the_united_kingdom"
    };

    // -----------------------------------------------------------------------------------------------------------------
    @ParameterizedTest
    @ValueSource(strings = {
            "list_of_governments",
            "list_of_presidents_of_japan",
            "list_of_presidents_of_south_korea",
            "list_of_presidents_of_the_united_states",
            "list_of_prime_ministers_of_the_united_kingdom"
    })
    void asv_is_the_flattened_txt(final String baseName) throws Exception {
        final var expected = _Asv.flattenResource(baseName + ".txt");
        final var actual = _Asv.readText(baseName + ".asv");
        assertThat(actual)
                .as("%s.asv should be %s.txt flattened; regenerate it from the .txt", baseName, baseName)
                .isEqualTo(expected);
        assertThat(actual).doesNotStartWith(String.valueOf(_Asv.RS)).doesNotEndWith(String.valueOf(_Asv.RS));
        assertThat(actual).doesNotContain("\n").doesNotContain("\t");
    }

    // -----------------------------------------------------------------------------------------------------------------
    @Test
    void governments_parse() throws Exception {
        final var governments = Government.readAll();
        assertThat(governments).hasSize(4);
        final var isoCountries = Set.of(Locale.getISOCountries());
        assertThat(governments)
                .extracting(Government::country)
                .doesNotHaveDuplicates()
                .allSatisfy(c -> assertThat(c).isIn(isoCountries))
                .containsExactlyInAnyOrderElementsOf(Head.RESOURCE_NAMES.keySet());
        assertThat(governments).extracting(Government::headKind).allSatisfy(k -> assertThat(k).isIn(Government.HEAD_KINDS));
        assertThat(governments).allSatisfy(g -> {
            assertThat(g.headTitle()).isNotBlank();
            assertThat(g.numbering()).isNotBlank();
        });
    }

    @Test
    void heads_parse() throws Exception {
        final var expectedCounts = java.util.Map.of("GB", 81, "JP", 105, "KR", 21, "US", 47);
        for (final var country : Head.RESOURCE_NAMES.keySet()) {
            final var heads = Head.readAll(country);
            assertThat(heads).as(country).hasSize(expectedCounts.get(country));
            assertThat(heads).as("%s: one incumbent", country).filteredOn(Head::isIncumbent).hasSize(1);
            assertThat(heads).as("%s: last line is the incumbent", country).last().matches(Head::isIncumbent);
            assertThat(heads).as("%s: one term per start date", country)
                    .extracting(Head::termStart).doesNotHaveDuplicates();
            assertThat(heads).as("%s: in chronological order", country)
                    .extracting(Head::termStart).isSorted();
            assertThat(heads).allSatisfy(h -> {
                assertThat(h.number()).isPositive();
                assertThat(h.name()).isNotBlank();
                assertThat(h.party()).isNotBlank().doesNotContainAnyWhitespaces();
            });
        }
    }
}
