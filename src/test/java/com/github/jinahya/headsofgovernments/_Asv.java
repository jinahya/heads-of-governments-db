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

import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Objects;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Reads ASCII separated values: {@code US} ({@code 0x1F}) between fields, {@code RS} ({@code 0x1E}) between records,
 * nothing before the first record and nothing after the last. Every {@code .asv} under {@code src/main/resources} is
 * the flattened form of the {@code .txt} of the same name, produced by {@link #flatten(List)}: blank lines dropped,
 * each {@value #DELIMITER} replaced with {@code US}, and the lines joined with {@code RS}. The lists carry no comments
 * and no header row; what their columns mean is written in {@code README.md}.
 *
 * <p>The conversion is mechanical because the lists keep three promises: the delimiter never occurs inside a field,
 * a record is one line, and every record has the same number of fields. {@link #flatten(List, char, String, int)} is
 * the general form, for any single-character delimiter that keeps the same promises.</p>
 */
final class _Asv {

    /** The record separator. */
    static final char RS = '\u001E';

    /** The unit (field) separator. */
    static final char US = '\u001F';

    /** The field delimiter of the {@code .txt} lists. */
    static final char DELIMITER = '|';

    private static final Pattern RS_PATTERN = Pattern.compile(Pattern.quote(String.valueOf(RS)));

    private static final Pattern US_PATTERN = Pattern.compile(Pattern.quote(String.valueOf(US)));

    // -----------------------------------------------------------------------------------------------------------------

    /**
     * Reads the whole of a classpath resource as UTF-8 text.
     *
     * @param resourceName the name of the resource, relative to the root of the classpath.
     * @return the text of the resource.
     * @throws IOException if the resource is missing or cannot be read.
     */
    static String readText(final String resourceName) throws IOException {
        Objects.requireNonNull(resourceName, "resourceName is null");
        try (var stream = _Asv.class.getResourceAsStream('/' + resourceName)) {
            if (stream == null) {
                throw new FileNotFoundException("no resource named " + resourceName);
            }
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        }
    }

    /**
     * Parses ASCII separated values into records of fields. An empty text has no record; an empty field is kept.
     *
     * @param text the text to parse.
     * @return a list of records, each an array of fields.
     */
    static List<String[]> parse(final String text) {
        Objects.requireNonNull(text, "text is null");
        if (text.isEmpty()) {
            return List.of();
        }
        return RS_PATTERN.splitAsStream(text)
                .map(record -> US_PATTERN.split(record, -1))
                .toList();
    }

    /**
     * Reads and parses a classpath resource of ASCII separated values.
     *
     * @param resourceName the name of the resource, relative to the root of the classpath.
     * @return a list of records, each an array of fields.
     * @throws IOException if the resource is missing or cannot be read.
     */
    static List<String[]> read(final String resourceName) throws IOException {
        return parse(readText(resourceName));
    }

    /**
     * Flattens the lines of a delimited list into ASCII separated values: lines that are empty or start with the
     * comment prefix are dropped, each delimiter becomes {@code US}, and the remaining lines are joined with
     * {@code RS}.
     *
     * @param lines     the lines of the list.
     * @param delimiter the field delimiter; must not occur inside a field, and must not be {@code US} or {@code RS}.
     * @param comment   the prefix of a comment line; {@code null} or empty when the list has no comments.
     * @param fields    the number of fields of every record, or a non-positive value not to check it.
     * @return the flattened text.
     * @throws IllegalArgumentException if a record does not have {@code fields} fields.
     */
    static String flatten(final List<String> lines, final char delimiter, final String comment, final int fields) {
        Objects.requireNonNull(lines, "lines is null");
        if (delimiter == US || delimiter == RS) {
            throw new IllegalArgumentException("delimiter is a separator: 0x" + Integer.toHexString(delimiter));
        }
        final var records = lines.stream()
                .filter(line -> !line.isEmpty() && (comment == null || comment.isEmpty() || !line.startsWith(comment)))
                .toList();
        if (fields > 0) {
            for (final var record : records) {
                final var count = record.chars().filter(c -> c == delimiter).count() + 1;
                if (count != fields) {
                    throw new IllegalArgumentException(
                            "expected " + fields + " fields, got " + count + " in record: " + record);
                }
            }
        }
        return records.stream()
                .map(record -> record.replace(delimiter, US))
                .collect(Collectors.joining(String.valueOf(RS)));
    }

    /**
     * Flattens the lines of a {@code .txt} list of this project: delimited by {@value #DELIMITER}, no comments, the
     * number of fields unchecked.
     *
     * @param lines the lines of the list.
     * @return the flattened text.
     * @see #flatten(List, char, String, int)
     */
    static String flatten(final List<String> lines) {
        return flatten(lines, DELIMITER, null, 0);
    }

    /**
     * Reads a {@code .txt} list from the classpath and flattens it.
     *
     * @param resourceName the name of the resource, relative to the root of the classpath.
     * @return the flattened text.
     * @throws IOException if the resource is missing or cannot be read.
     * @see #flatten(List)
     */
    static String flattenResource(final String resourceName) throws IOException {
        return flatten(readText(resourceName).lines().toList());
    }

    // -----------------------------------------------------------------------------------------------------------------
    private _Asv() {
        throw new AssertionError("instantiation is not allowed");
    }
}
