# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

A generator, and nothing else. `./mvnw test` reads the lists under `src/main/resources` and writes
`db/heads_of_governments.sqlite3`, an SQLite database of the heads of government of five countries.
The project publishes no artifact: there is no main source, the jar is empty, and `maven.install.skip`
and `maven.deploy.skip` are set. The generated file is committed, so whoever wants the database can
take it without building; a change to a list means rebuilding and committing the file with it.

The sibling `../kftc-financial-institution-info` was the model for this, down to the `ANALYZE` and
`VACUUM` at the end of the run.

## Layout

```
src/main/resources/
  list_of_offices.txt                                  the five offices, hand-edited
  list_of_offices.asv                                  the same, flattened (generated)
  list_of_presidents_of_france.txt / .asv              one country's heads, hand-edited / flattened
  list_of_presidents_of_japan.txt / .asv
  list_of_presidents_of_south_korea.txt / .asv
  list_of_presidents_of_the_united_states.txt / .asv
  list_of_prime_ministers_of_the_united_kingdom.txt / .asv
src/test/java/com/github/jinahya/headsofgovernments/
  _Asv.java                                            reads .asv; flattens a delimited .txt to .asv
  Office.java, Head.java                               records, one per table, each with from(String[])
  _Asv_Test.java                                       the .asv files are current and parse as expected
  HeadsOfGovernments_Sqlite_Test.java                  the generator; holds the DDL
src/test/sql/
  office.sql, head.sql                                 profiling queries, a section per column
  office_exercises.sql, head_exercises.sql             exercises on one table, Basic / Intermediate / Advanced
  whole_schema_exercises.sql                           exercises that read both tables
db/
  heads_of_governments.sqlite3                         the output; committed, rebuilt on every run
  heads_of_governments.sqlite3.md                      the schema and column notes; committed
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
cd src/main/resources
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

Two tables, `office` (`WITHOUT ROWID`) and `head` (a rowid table). The DDL lives in
`HeadsOfGovernments_Sqlite_Test.DDL` and is repeated in `db/heads_of_governments.sqlite3.md`; **a
change to one is a change to both.**

- `office` is the office the head of government holds -- 内閣総理大臣, 대통령, the Prime Minister --
  not an administration or a government. Key `country`, ISO 3166-1 alpha-2 as `Locale.getCountry()`
  returns it: the United Kingdom is `GB`. `head_kind` is `PRESIDENT` or `PRIME_MINISTER`, checked.
- `head` is one term of office. Key `id INTEGER PRIMARY KEY`, the rowid, which SQLite assigns as the
  generator inserts; the generator sorts by `country` then `term_start` first, so ids are 1..N in that
  order, but the file is rebuilt on every run and an `id` is never stable. What tells terms apart is
  `(country, term_start)`, not `(country, number)`: France and the United Kingdom keep a person's
  number across terms, so `number` repeats. The schema declares no unique constraint on
  `(country, term_start)`, by decision; the generator asserts it after the inserts instead. Dates are
  ISO-8601 text, SQLite's convention. `term_end IS NULL` is the incumbent.
- Indexes: `(country, number)` and `(name)`, both plain. There is no unique index on the incumbent,
  by decision: the schema is for consumers, and the generator asserts one incumbent per office
  after the inserts instead.

Names are country codes and snake_case; keep them so. If a country ever contributes a second office
(South Korea has a prime minister too), the key of `office` becomes `(country, head_kind)` and
`head` references both columns; `id` is unaffected.

## The SQL files

`src/test/sql` holds hand-written SQL against the generated database, after the sibling
`../oracle-sample-schemas-persistence`. Nothing runs them in the build; they are for a reader with the
`sqlite3` tool or an IDE, and `sqlite3 db/heads_of_governments.sqlite3 '.read src/test/sql/head.sql'`
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
./mvnw test          # generates db/heads_of_governments.sqlite3; the whole build
./mvnw clean test    # the same from scratch
```

Needs a JDK 25 or newer: `maven.compiler.release` is 17 for main sources, of which there are none,
and 25 for the tests, which are the generator. The enforcer requires Java 25.

The generator deletes any previous database before writing, so the file holds exactly one run. It
sets `PRAGMA auto_vacuum = NONE`, runs `ANALYZE` after the inserts, reopens the file and checks row
counts, incumbents, foreign keys and the indexes, and ends with `VACUUM`, so the file is compact. Inspect the result with the `sqlite3` tool:

```sh
sqlite3 db/heads_of_governments.sqlite3 '.schema' 'SELECT country, name FROM head WHERE term_end IS NULL'
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
- Prose about the data (README.md, the schema notes) is English; data values keep the script of
  their source (`内閣総理大臣`, `대통령`, `Président de la République`).
