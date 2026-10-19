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
import java.util.List;
import java.util.Objects;
import java.util.Set;

/**
 * The office a head of government holds, one per line of {@code list_of_offices.txt}.
 *
 * @param country   the ISO 3166-1 alpha-2 code of the country, as {@link java.util.Locale#getCountry()} returns it.
 * @param headKind  what the head of this office is; one of {@link #HEAD_KINDS}.
 * @param headTitle the head's title in the country's own language.
 * @param numbering what the {@code number} column of the heads list counts for this country.
 */
record Office(String country, String headKind, String headTitle, String numbering) {

    /** The name of the resource holding the offices, in ASCII separated values. */
    static final String RESOURCE_NAME = "list_of_offices.asv";

    /** The number of fields of a record. */
    static final int FIELDS = 4;

    /** The values {@code headKind} may take. */
    static final Set<String> HEAD_KINDS = Set.of("PRESIDENT", "PRIME_MINISTER");

    // -----------------------------------------------------------------------------------------------------------------

    /**
     * Creates a new instance from the fields of a record.
     *
     * @param fields the fields; {@value #FIELDS} of them.
     * @return a new instance.
     */
    static Office from(final String[] fields) {
        Objects.requireNonNull(fields, "fields is null");
        if (fields.length != FIELDS) {
            throw new IllegalArgumentException("expected " + FIELDS + " fields, got " + fields.length);
        }
        return new Office(fields[0], fields[1], fields[2], fields[3]);
    }

    /**
     * Reads every office from {@link #RESOURCE_NAME}.
     *
     * @return a list of governments, in file order.
     * @throws IOException if the resource cannot be read.
     */
    static List<Office> readAll() throws IOException {
        return _Asv.read(RESOURCE_NAME).stream().map(Office::from).toList();
    }

    // -----------------------------------------------------------------------------------------------------------------
    Office {
        Objects.requireNonNull(country, "country is null");
        Objects.requireNonNull(headKind, "headKind is null");
        Objects.requireNonNull(headTitle, "headTitle is null");
        Objects.requireNonNull(numbering, "numbering is null");
        if (!HEAD_KINDS.contains(headKind)) {
            throw new IllegalArgumentException("unknown headKind: " + headKind);
        }
    }
}
