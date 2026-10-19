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

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Draws {@code db/heads_of_governments.sqlite3.erd.svg} from {@link HeadsOfGovernments_Sqlite_Test#DDL}. The DDL is run
 * on an in-memory database and read back through the {@code PRAGMA}s, so the diagram is the schema as SQLite sees it
 * and cannot drift from it; nothing here knows a table by name.
 */
class HeadsOfGovernments_Erd_Test {

    /** The file to draw, relative to the project directory, which is where surefire runs. */
    static final Path PATH = Path.of("db", "heads_of_governments.sqlite3.erd.svg");

    // -----------------------------------------------------------------------------------------------------------------
    record Column(String name, String type, boolean notNull, boolean pk) {
    }

    record ForeignKey(String from, String table, String to) {
    }

    record Index(String name, boolean unique, List<String> columns) {
    }

    record Table(String name, boolean withoutRowid, List<Column> columns, List<ForeignKey> foreignKeys,
                 List<Index> indexes) {

        int indexOf(final String column) {
            for (int i = 0; i < columns.size(); i++) {
                if (columns.get(i).name().equals(column)) {
                    return i;
                }
            }
            throw new IllegalArgumentException(name + " has no column " + column);
        }
    }

    /** Reads every user table of the connection, with its columns, foreign keys and explicit indexes. */
    static List<Table> read(final Connection connection) throws SQLException {
        final var tables = new ArrayList<Table>();
        final var names = new ArrayList<String>();
        final var withoutRowids = new ArrayList<Boolean>();
        try (var statement = connection.createStatement();
             var results = statement.executeQuery(
                     "SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
                     + " ORDER BY name")) {
            while (results.next()) {
                names.add(results.getString(1));
                withoutRowids.add(results.getString(2).toUpperCase(Locale.ROOT).contains("WITHOUT ROWID"));
            }
        }
        for (int t = 0; t < names.size(); t++) {
            final var name = names.get(t);
            final var columns = new ArrayList<Column>();
            try (var statement = connection.createStatement();
                 var results = statement.executeQuery("PRAGMA table_info(" + name + ")")) {
                while (results.next()) {
                    columns.add(new Column(results.getString("name"), results.getString("type"),
                                           results.getInt("notnull") != 0, results.getInt("pk") != 0));
                }
            }
            final var foreignKeys = new ArrayList<ForeignKey>();
            try (var statement = connection.createStatement();
                 var results = statement.executeQuery("PRAGMA foreign_key_list(" + name + ")")) {
                while (results.next()) {
                    foreignKeys.add(new ForeignKey(results.getString("from"), results.getString("table"),
                                                   results.getString("to")));
                }
            }
            final var indexes = new ArrayList<Index>();
            try (var statement = connection.createStatement();
                 var results = statement.executeQuery("PRAGMA index_list(" + name + ")")) {
                while (results.next()) {
                    if (!"c".equals(results.getString("origin"))) { // only CREATE INDEX, not a key's own index
                        continue;
                    }
                    indexes.add(new Index(results.getString("name"), results.getInt("unique") != 0,
                                          new ArrayList<>()));
                }
            }
            for (final var index : indexes) {
                try (var statement = connection.createStatement();
                     var results = statement.executeQuery("PRAGMA index_info(" + index.name() + ")")) {
                    while (results.next()) {
                        index.columns().add(results.getString("name"));
                    }
                }
            }
            indexes.sort(Comparator.comparing(Index::name));
            tables.add(new Table(name, withoutRowids.get(t), columns, foreignKeys, indexes));
        }
        // parents to the left of the tables that reference them
        tables.sort(Comparator.comparingInt((Table table) -> table.foreignKeys().size()).thenComparing(Table::name));
        return tables;
    }

    // -----------------------------------------------------------------------------------------------------------------
    // geometry, in px; the text is 13px monospace, which is 8px per character in the common fonts
    static final int CHAR = 8;

    static final int ROW = 22;

    static final int HEADER = 32;

    static final int FOOTER_ROW = 18;

    static final int PAD = 12;

    static final int MARGIN = 24;

    static final int TITLE = 44;

    static final int GAP = 120;

    static final String MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, 'Liberation Mono', monospace";

    static final String SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif";

    static String escape(final String text) {
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }

    /** One line of a table body: a key marker, the name, the type and the nullability, in aligned columns. */
    static String line(final Column column, final int nameWidth, final int typeWidth) {
        final var key = column.pk() ? "PK" : "  ";
        final var nullability = column.pk() || column.notNull() ? "NOT NULL" : "NULL";
        return String.format(Locale.ROOT, "%s  %-" + nameWidth + "s  %-" + typeWidth + "s  %s",
                             key, column.name(), column.type(), nullability);
    }

    static String line(final Index index) {
        return (index.unique() ? "UNIQUE " : "") + index.name() + " (" + String.join(", ", index.columns()) + ")";
    }

    static String draw(final List<Table> tables) {
        // size each box
        final var widths = new int[tables.size()];
        final var heights = new int[tables.size()];
        final var lines = new ArrayList<List<String>>();
        for (int t = 0; t < tables.size(); t++) {
            final var table = tables.get(t);
            final var nameWidth = table.columns().stream().mapToInt(c -> c.name().length()).max().orElse(0);
            final var typeWidth = table.columns().stream().mapToInt(c -> c.type().length()).max().orElse(0);
            final var body = new ArrayList<String>();
            for (final var column : table.columns()) {
                final var text = line(column, nameWidth, typeWidth);
                body.add(table.foreignKeys().stream().anyMatch(k -> k.from().equals(column.name()))
                         ? "FK" + text.substring(2) : text);
            }
            lines.add(body);
            var chars = body.stream().mapToInt(String::length).max().orElse(0);
            chars = Math.max(chars, table.name().length() + 2 + (table.withoutRowid() ? 13 : 12));
            for (final var index : table.indexes()) {
                chars = Math.max(chars, line(index).length() - 2); // the footer is 11px, roughly 6.5px a char
            }
            widths[t] = PAD * 2 + chars * CHAR;
            heights[t] = HEADER + table.columns().size() * ROW + PAD
                         + (table.indexes().isEmpty() ? 0 : PAD / 2 + table.indexes().size() * FOOTER_ROW);
        }
        // place them left to right
        final var xs = new int[tables.size()];
        var x = MARGIN;
        var bottom = 0;
        for (int t = 0; t < tables.size(); t++) {
            xs[t] = x;
            x += widths[t] + GAP;
            bottom = Math.max(bottom, heights[t]);
        }
        final var top = MARGIN + TITLE;
        final var width = x - GAP + MARGIN;
        final var height = top + bottom + MARGIN;
        final var relationships = tables.stream().mapToInt(t -> t.foreignKeys().size()).sum();
        // draw
        final var svg = new StringBuilder();
        svg.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        svg.append(String.format(Locale.ROOT,
                                 "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\""
                                 + " viewBox=\"0 0 %d %d\">\n", width, height, width, height));
        svg.append(String.format(Locale.ROOT, "  <rect width=\"%d\" height=\"%d\" fill=\"#ffffff\"/>\n",
                                 width, height));
        svg.append(String.format(Locale.ROOT,
                                 "  <text x=\"%d\" y=\"%d\" font-family=\"%s\" font-size=\"16\" font-weight=\"600\""
                                 + " fill=\"#1f2328\">%s</text>\n",
                                 MARGIN, MARGIN + 14, SANS,
                                 escape(HeadsOfGovernments_Sqlite_Test.PATH.getFileName().toString())));
        svg.append(String.format(Locale.ROOT,
                                 "  <text x=\"%d\" y=\"%d\" font-family=\"%s\" font-size=\"11\" fill=\"#57606a\">"
                                 + "%d tables, %d relationship%s; drawn from the DDL by the build</text>\n",
                                 MARGIN, MARGIN + 32, SANS, tables.size(), relationships,
                                 relationships == 1 ? "" : "s"));
        for (int t = 0; t < tables.size(); t++) {
            final var table = tables.get(t);
            final var tx = xs[t];
            final var w = widths[t];
            final var h = heights[t];
            svg.append(String.format(Locale.ROOT, "  <g id=\"%s\">\n", escape(table.name())));
            svg.append(String.format(Locale.ROOT,
                                     "    <rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" rx=\"6\" fill=\"#ffffff\""
                                     + " stroke=\"#d0d7de\"/>\n", tx, top, w, h));
            svg.append(String.format(Locale.ROOT,
                                     "    <path d=\"M%d %dh%dv%da6 6 0 0 0 -6 -6h%da6 6 0 0 0 -6 6z\""
                                     + " fill=\"#f6f8fa\"/>\n",
                                     tx, top + HEADER, w, -(HEADER - 6), -(w - 12)));
            svg.append(String.format(Locale.ROOT,
                                     "    <line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"#d0d7de\"/>\n",
                                     tx, top + HEADER, tx + w, top + HEADER));
            svg.append(String.format(Locale.ROOT,
                                     "    <text x=\"%d\" y=\"%d\" font-family=\"%s\" font-size=\"14\""
                                     + " font-weight=\"600\""
                                     + " fill=\"#1f2328\">%s</text>\n",
                                     tx + PAD, top + 21, MONO, escape(table.name())));
            svg.append(String.format(Locale.ROOT,
                                     "    <text x=\"%d\" y=\"%d\" font-family=\"%s\" font-size=\"11\" fill=\"#57606a\""
                                     + " text-anchor=\"end\">%s</text>\n",
                                     tx + w - PAD, top + 20, SANS,
                                     table.withoutRowid() ? "WITHOUT ROWID" : "rowid table"));
            var y = top + HEADER;
            for (int c = 0; c < table.columns().size(); c++) {
                final var column = table.columns().get(c);
                svg.append(String.format(Locale.ROOT,
                                         "    <text x=\"%d\" y=\"%d\" font-family=\"%s\" font-size=\"13\"%s"
                                         + " fill=\"#1f2328\" xml:space=\"preserve\">%s</text>\n",
                                         tx + PAD, y + 16, MONO, column.pk() ? " font-weight=\"600\"" : "",
                                         escape(lines.get(t).get(c))));
                y += ROW;
            }
            if (!table.indexes().isEmpty()) {
                y += PAD / 2;
                svg.append(String.format(Locale.ROOT,
                                         "    <line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"#d0d7de\"/>\n",
                                         tx, y, tx + w, y));
                for (final var index : table.indexes()) {
                    svg.append(String.format(Locale.ROOT,
                                             "    <text x=\"%d\" y=\"%d\" font-family=\"%s\" font-size=\"11\""
                                             + " fill=\"#57606a\">%s</text>\n",
                                             tx + PAD, y + 13, MONO, escape(line(index))));
                    y += FOOTER_ROW;
                }
            }
            svg.append("  </g>\n");
        }
        // one line per foreign key, from the parent's referenced column to the child's referencing column:
        // a bar at the parent (exactly one), a ring and a crow's foot at the child (zero or more)
        for (int t = 0; t < tables.size(); t++) {
            final var child = tables.get(t);
            for (final var key : child.foreignKeys()) {
                final var p = tables.indexOf(tables.stream().filter(o -> o.name().equals(key.table())).findFirst()
                                                     .orElseThrow());
                final var parent = tables.get(p);
                final var px = xs[p] + widths[p];
                final var py = top + HEADER + parent.indexOf(key.to()) * ROW + ROW / 2;
                final var cx = xs[t];
                final var cy = top + HEADER + child.indexOf(key.from()) * ROW + ROW / 2;
                final var mx = (px + cx) / 2;
                svg.append(String.format(Locale.ROOT,
                                         "  <g id=\"%s_%s\" fill=\"none\" stroke=\"#57606a\" stroke-width=\"1.25\">\n",
                                         escape(child.name()), escape(key.from())));
                svg.append(String.format(Locale.ROOT, "    <path d=\"M%d %dH%dV%dH%d\"/>\n", px, py, mx, cy, cx));
                svg.append(String.format(Locale.ROOT, "    <line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\"/>\n",
                                         px + 10, py - 7, px + 10, py + 7));
                svg.append(String.format(Locale.ROOT, "    <circle cx=\"%d\" cy=\"%d\" r=\"4\" fill=\"#ffffff\"/>\n",
                                         cx - 22, cy));
                svg.append(String.format(Locale.ROOT, "    <path d=\"M%d %dL%d %dM%d %dL%d %d\"/>\n",
                                         cx - 14, cy, cx, cy - 7, cx - 14, cy, cx, cy + 7));
                svg.append("  </g>\n");
            }
        }
        svg.append("</svg>\n");
        return svg.toString();
    }

    // -----------------------------------------------------------------------------------------------------------------
    @Test
    void draw() throws Exception {
        final List<Table> tables;
        try (var connection = DriverManager.getConnection("jdbc:sqlite::memory:")) {
            for (final var ddl : HeadsOfGovernments_Sqlite_Test.DDL) {
                HeadsOfGovernments_Sqlite_Test.execute(connection, ddl);
            }
            tables = read(connection);
        }
        assertThat(tables).extracting(Table::name)
                .containsExactly(HeadsOfGovernments_Sqlite_Test.TABLE_OFFICE,
                                 HeadsOfGovernments_Sqlite_Test.TABLE_HEAD);
        final var svg = draw(tables);
        Files.createDirectories(PATH.getParent());
        Files.writeString(PATH, svg, StandardCharsets.UTF_8);
        assertThat(Files.readString(PATH, StandardCharsets.UTF_8)).isEqualTo(svg).contains("<svg ", "</svg>");
    }
}
