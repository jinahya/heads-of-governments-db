# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

A generator of one resource. `./mvnw test` reads the lists under `src/test/resources` and
writes `src/main/resources/heads_of_governments.sqlite3`, an SQLite database of the heads of
government of five countries. The file sits at the root of the classpath, not under a package
directory. The jar carries that file and nothing else: there is no main source and no runtime
dependency. A consumer brings `sqlite-jdbc` and opens it with
`jdbc:sqlite::resource:heads_of_governments.sqlite3`. The schema is the contract; each release
replaces the whole file.

**It is chicken and egg, by design.** `process-resources` copies the committed database into
`target/classes` before the tests regenerate it, so a jar carries the file as the previous build left
it. Generation is reproducible byte for byte, so `HeadsOfGovernments_Sqlite_Test.generate` ends by
comparing the fresh file with the classpath copy and fails when they differ: after a change to a list,
the first build fails, the second passes, and the database is committed with the list. Releases are
cut from a clean checkout, so they ship exactly what was committed.

The sibling `../kftc-financial-institution-info` was the model for this, down to the `ANALYZE` and
`VACUUM` at the end of the run.

## Layout

```
src/main/resources/
  heads_of_governments.sqlite3                         the output, and all the jar holds; committed
src/test/resources/
  list_of_offices.txt                                  the five offices, hand-edited
  list_of_offices.asv                                  the same, flattened (generated)
  list_of_heads_of_FR.txt / .asv                       one country's heads, hand-edited / flattened
  list_of_heads_of_GB.txt / .asv
  list_of_heads_of_JP.txt / .asv
  list_of_heads_of_KR.txt / .asv
  list_of_heads_of_US.txt / .asv
src/test/java/com/github/jinahya/headsofgovernments/
  _Asv.java                                            reads .asv; flattens a delimited .txt to .asv
  Office.java, Head.java                               records, one per table, each with from(String[])
  _Asv_Test.java                                       the .asv files are current and parse as expected
  HeadsOfGovernments_Sqlite_Test.java                  the generator; holds the DDL
  HeadsOfGovernments_Resource_Test.java                opens the database as a consumer does, via :resource:
src/test/sql/
  office.sql, head.sql                                 profiling queries, a section per column
  incumbent.sql, contemporary.sql                      profiling queries on the views
  office_exercises.sql, head_exercises.sql             exercises on one table, Basic / Intermediate / Advanced
  whole_schema_exercises.sql                           exercises that read both tables
README.md                                              also the schema: SQL, a Mermaid ERD and column notes
```

## The data files, and which one is the truth

**The `.txt` files are the only thing a human edits.** Each holds records only: one per line, `|`
between fields, no header row, no comments. The five country lists share one layout,
`number, term_start, term_end, name, party, born, died`; `-` means "none" (the incumbent's `term_end`,
a living person's `died`). What `number` counts differs by country and is written in
`list_of_offices.txt`, column `numbering`. The sources of every list and the editorial notes --
who is left out, how a suspension or a re-election is written -- live in README.md under *Sources
and notes*, and a change to a list's conventions is a change there too.

**The `.asv` files are derived** -- ASCII separated values: `US` (0x1F) between fields, `RS` (0x1E)
between records, nothing before the first record and nothing after the last, no newline, no `GS`.
They are what the generator reads, so they are committed, and `_Asv_Test` fails the build when one is
not byte-for-byte its `.txt` flattened. After editing a `.txt`, regenerate its `.asv`:

```sh
cd src/test/resources
for t in list_of_*.txt; do
  grep -v '^$' "$t" | tr '|' '\037' | paste -sd $'\036' - | tr -d '\n' > "${t%.txt}.asv"
done
```

`.gitattributes` marks `*.asv` as `-diff`; a diff of a one-line file is unreadable anyway.

The conversion is mechanical because the lists keep three promises: `|` never occurs inside a field,
a record is one line, and every record of a list has the same number of fields. `_Asv.flatten(lines,
delimiter, comment, fields)` is the general converter for any single-character delimiter that keeps
the same promises. `_Asv_Test` runs it over every country list with the field count checked, and
fails on a comment or a blank line in any `.txt`.

Do not add a second hand-edited copy of any data. If a new form of the data is wanted, derive it from
the `.txt` in the build, as the `.asv` and the database are.

## The schema

Two tables, `office` and `head`, both `WITHOUT ROWID`, and two views over them. The DDL lives in
`HeadsOfGovernments_Sqlite_Test.DDL` and is repeated in README.md, under *The database*, as SQL and
as a Mermaid ERD; **a change to one is a change to both.**

Every table and column carries a `--` comment in the DDL. SQLite has no `COMMENT ON`, but it stores
the statement's text verbatim in `sqlite_master.sql`, so the comments ship in the file and `.schema`
shows them: a line that is only a comment, first inside the parentheses, is the table's; a comment on
a column's line is the column's. A view names its columns in a list, `CREATE VIEW v (a, b) AS`, so
its comments sit the same way. Keep a comment short
enough that the line stays within 120 in the Java source, and keep the column notes in README.md
saying the same thing.

- `office` is the office the head of government holds -- 内閣総理大臣, 대통령, the Prime Minister --
  not an administration or a government. Key `country`, ISO 3166-1 alpha-2 as `Locale.getCountry()`
  returns it: the United Kingdom is `GB`. `head_kind` is `PRESIDENT` or `PRIME_MINISTER`, checked.
- `head` is one term of office. Key `(country, term_start)`, not `(country, number)`: France and the
  United Kingdom keep a person's number across terms, so `number` repeats. There is no surrogate
  key; the generator inserts in key order, so a run is reproducible. Dates are ISO-8601 text,
  SQLite's convention. `term_end IS NULL` is the incumbent.
- Indexes: `(country, number)`, `(term_start)`, `(term_end)`, `(name)`, `(born)` and `(died)`, all plain.
  There is no unique index on the incumbent, by decision: the schema is for consumers, and the
  generator asserts one incumbent per office after the inserts instead.
- `incumbent` is each office's head today, one row per country. `country` identifies a row, so a
  consumer may map it as a read-only `@Entity`; SQLite cannot declare that, so the generator asserts
  it. Keep it so: a change that could give an office two rows breaks every such mapping.
- `contemporary` is every two terms in different countries that overlapped,
  `country_left < country_right`, with the span they shared. It has no identity, by design: it is read as a projection.
- A view stays deterministic: nothing from `date('now')` or the like, so a query on the file answers
  the same whenever it runs.

Names are country codes and snake_case; keep them so. If a country ever contributes a second office
(South Korea has a prime minister too), the key of `office` becomes `(country, head_kind)`,
`head` references both columns, and its key becomes `(country, head_kind, term_start)`.

## The SQL files

`src/test/sql` holds hand-written SQL against the generated database, after the sibling
`../oracle-sample-schemas-persistence`. Nothing runs them in the build; they are for a reader with the
`sqlite3` tool or an IDE, and `sqlite3 <the database> '.read src/test/sql/head.sql'`
runs one whole.

- `office.sql` and `head.sql` profile a table, a section per column under a ruler, each query
  prefaced by what it looks for and what the result should be; `-- no rows:` marks a check that passes
  when nothing comes back. The last section covers the table as a whole.
- `*_exercises.sql` pose a problem per query, under `BASIC`, `INTERMEDIATE` and `ADVANCED` rulers. Each
  carries an id, `HOG-<TABLE>-<B|I|A>-<nn>` (`HOG-SCHEMA-` for the whole schema), and restates the
  request it answers. Parameters are bind variables (`:name`); the shell binds one with
  `.parameter set :name 'value'`.

Every file starts with the Apache 2.0 header in the `-- #%L` form, rulers are 120 columns, and lines
stay within 120. A sort key that can be NULL (`term_end`, `died`, an aggregate of either, `sqlite_stat1.idx`)
says `NULLS FIRST` or `NULLS LAST`, even where that is SQLite's default; a `NOT NULL` key does not. A change to the schema or to a list's conventions can falsify a `no rows:` claim or
a comment that names a country, so rerun the files after one and read what they return.

## Build

```sh
./mvnw test          # regenerates the database; fails once after a list changes, see above
./mvnw verify        # the same, plus the jar and the licence check
./mvnw clean test    # the same from scratch
```

Needs a JDK 25 or newer: `maven.compiler.release` is 17 for main sources, of which there are none,
and 25 for the tests, which are the generator. The enforcer requires Java 25.

The generator deletes any previous database before writing, so the file holds exactly one run. It
sets `PRAGMA auto_vacuum = NONE`, runs `ANALYZE` after the inserts, reopens the file and checks row
counts, incumbents, foreign keys, the indexes and the views, and ends with `VACUUM`, so the file is compact. Inspect the result with the `sqlite3` tool:

```sh
sqlite3 src/main/resources/heads_of_governments.sqlite3 \
  '.schema' 'SELECT country, name FROM head WHERE term_end IS NULL'
```

## Dependencies

Three, all `test` scope: JUnit Jupiter, AssertJ and `org.xerial:sqlite-jdbc`. Versions live in
`<properties>` and `<dependencyManagement>` of `pom.xml`; the enforcer's `dependencyConvergence`
runs on every build. Do not add a persistence framework, an ORM, a logging binding or a utility
library: the generator is plain JDBC and `java.nio`, and should stay that way. `sqlite-jdbc` is the
only dependency with native code; it loads its own library and needs nothing installed.

## Conventions

- Test classes are package-private and named `Xxx_Test`; internal helpers carry a leading
  underscore (`_Asv`). Record types are named for what a row is (`Office`, `Head`).
- Every Java file carries the Apache 2.0 header in the `#%L` form the license plugin produces.
- Prose about the data (README.md) is English; data values keep the script of
  their source (`内閣総理大臣`, `대통령`, `Président de la République`).
