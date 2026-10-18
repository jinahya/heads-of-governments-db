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

import java.io.IOException;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * One term of a head of government, one per line of a country's list file.
 *
 * @param country   the ISO 3166-1 alpha-2 code of the government's country.
 * @param number    the term number, counted as the government's {@code numbering} says.
 * @param termStart the first day of the term.
 * @param termEnd   the last day of the term, or {@code null} for the incumbent.
 * @param name      the name of the person.
 * @param party     the party, a single token; {@code '/'} separates successive affiliations.
 * @param born      the year of birth.
 * @param died      the year of death, or {@code null} while living.
 */
record Head(String country, int number, LocalDate termStart, LocalDate termEnd, String name, String party, int born,
            Integer died) {

    /** The names of the resources holding each country's heads, in ASCII separated values, by country. */
    static final Map<String, String> RESOURCE_NAMES = Map.of(
            "FR", "list_of_presidents_of_france.asv",
            "GB", "list_of_prime_ministers_of_the_united_kingdom.asv",
            "JP", "list_of_presidents_of_japan.asv",
            "KR", "list_of_presidents_of_south_korea.asv",
            "US", "list_of_presidents_of_the_united_states.asv"
    );

    /** The number of fields of a record. */
    static final int FIELDS = 7;

    /** The field value standing for "none": the incumbent's {@code termEnd}, a living person's {@code died}. */
    static final String NONE = "-";

    // -----------------------------------------------------------------------------------------------------------------

    /**
     * Creates a new instance from the fields of a record.
     *
     * @param country the country the record belongs to; the files do not carry it.
     * @param fields  the fields; {@value #FIELDS} of them, in the order {@code number}, {@code term_start},
     *                {@code term_end}, {@code name}, {@code party}, {@code born}, {@code died}.
     * @return a new instance.
     */
    static Head from(final String country, final String[] fields) {
        Objects.requireNonNull(country, "country is null");
        Objects.requireNonNull(fields, "fields is null");
        if (fields.length != FIELDS) {
            throw new IllegalArgumentException("expected " + FIELDS + " fields, got " + fields.length);
        }
        return new Head(
                country,
                Integer.parseInt(fields[0]),
                LocalDate.parse(fields[1]),
                NONE.equals(fields[2]) ? null : LocalDate.parse(fields[2]),
                fields[3],
                fields[4],
                Integer.parseInt(fields[5]),
                NONE.equals(fields[6]) ? null : Integer.valueOf(fields[6])
        );
    }

    /**
     * Reads every head of the specified country from its resource.
     *
     * @param country the country.
     * @return a list of heads, in file order.
     * @throws IOException if the resource cannot be read.
     */
    static List<Head> readAll(final String country) throws IOException {
        final var resourceName = RESOURCE_NAMES.get(country);
        if (resourceName == null) {
            throw new IllegalArgumentException("no resource for country " + country);
        }
        return _Asv.read(resourceName).stream().map(f -> from(country, f)).toList();
    }

    // -----------------------------------------------------------------------------------------------------------------
    Head {
        Objects.requireNonNull(country, "country is null");
        Objects.requireNonNull(termStart, "termStart is null");
        Objects.requireNonNull(name, "name is null");
        Objects.requireNonNull(party, "party is null");
        if (termEnd != null && termEnd.isBefore(termStart)) {
            throw new IllegalArgumentException("termEnd(" + termEnd + ") is before termStart(" + termStart + ")");
        }
        if (died != null && died < born) {
            throw new IllegalArgumentException("died(" + died + ") is before born(" + born + ")");
        }
    }

    /**
     * Tells whether this head is the incumbent, that is, has no {@code termEnd}.
     *
     * @return {@code true} if this head is the incumbent; {@code false} otherwise.
     */
    boolean isIncumbent() {
        return termEnd == null;
    }
}
