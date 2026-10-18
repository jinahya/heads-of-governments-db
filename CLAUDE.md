# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

A generator, and nothing else. `./mvnw test` reads the lists under `src/main/resources` and writes
`db/heads_of_governments.sqlite3`, an SQLite database of the heads of government of four countries.
The project publishes no artifact: there is no main source, the jar is empty, and `maven.install.skip`
and `maven.deploy.skip` are set. Nothing downstream consumes the build; whoever wants the database
runs the build and takes the file.

The sibling `../kftc-financial-institution-info` was the model for this, down to the `ANALYZE` and
`VACUUM` at the end of the run.

## Layout

```
src/main/resources/
  list_of_governments.txt                              the four governments, hand-edited
  list_of_governments.asv                              the same, flattened (generated)
  list_of_presidents_of_japan.txt / .asv               one country's heads, hand-edited / flattened
  list_of_presidents_of_south_korea.txt / .asv
  list_of_presidents_of_the_united_states.txt / .asv
  list_of_prime_ministers_of_the_united_kingdom.txt / .asv
src/test/java/com/github/jinahya/headsofgovernments/
  _Asv.java                                            reads .asv, flattens .txt
  Government.java, Head.java                           records, one per table, each with from(String[])
  _Asv_Test.java                                       the .asv files are current and parse as expected
  HeadsOfGovernments_Sqlite_Test.java                  the generator; holds the DDL
db/
  heads_of_governments.sqlite3                         the output; git-ignored
  heads_of_governments.sqlite3.md                      the schema and column notes; committed
```

## The data files, and which one is the truth

**The `.txt` files are the only thing a human edits.** Each is a commented, TAB-separated list: lines
starting with `#` and blank lines are comments, the header row is itself a comment directly above the
data, and the header's prose explains every column. The four country lists share one layout,
`number, term_start, term_end, name, party, born, died`; `-` means "none" (the incumbent's `term_end`,
a living person's `died`). What `number` counts differs by country and is written in
`list_of_governments.txt`, column `numbering`.

**The `.asv` files are derived** -- ASCII separated values: `US` (0x1F) between fields, `RS` (0x1E)
between records, nothing before the first record and nothing after the last, no newline, no `GS`.
They are what the generator reads, so they are committed, and `_Asv_Test` fails the build when one is
not byte-for-byte its `.txt` flattened. After editing a `.txt`, regenerate its `.asv`:

```sh
cd src/main/resources
for t in list_of_*.txt; do
  grep -v -E '^(#|$)' "$t" | tr '\t' '\037' | paste -sd $'\036' - | tr -d '\n' > "${t%.txt}.asv"
done
```

`.gitattributes` marks `*.asv` as `-diff`; a diff of a one-line file is unreadable anyway.

Do not add a second hand-edited copy of any data. If a new form of the data is wanted, derive it from
the `.txt` in the build, as the `.asv` and the database are.

## The schema

Two tables, `government` and `head`, both `WITHOUT ROWID`. The DDL lives in
`HeadsOfGovernments_Sqlite_Test.DDL` and is repeated in `db/heads_of_governments.sqlite3.md`; **a
change to one is a change to both.**

- `government` is a government in the institutional sense -- the Government of Japan, HM Government
  -- not an administration. Key `country`, ISO 3166-1 alpha-2 as `Locale.getCountry()` returns it:
  the United Kingdom is `GB`. `head_kind` is `PRESIDENT` or `PRIME_MINISTER`, checked.
- `head` is one term of office. Key `(country, term_start)`, not `(country, number)`: the United
  Kingdom keeps a person's number across non-consecutive terms, so `number` repeats. Dates are
  ISO-8601 text, SQLite's convention. `term_end IS NULL` is the incumbent.
- Indexes: `(country, number)`, `(name)`, and `uq_head_incumbent`, a unique partial index on
  `country WHERE term_end IS NULL` that enforces one sitting head per government.

Names are country codes and snake_case; keep them so. If a country ever contributes a second office
(South Korea has a prime minister too), the key of `government` becomes `(country, head_kind)` and
`head` references both columns; until then the simple key stays.

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
  underscore (`_Asv`). Record types are named for what a row is (`Government`, `Head`).
- Every Java file carries the Apache 2.0 header in the `#%L` form the license plugin produces.
- Comments in the data files are English; data values keep the script of their source
  (`内閣総理大臣`, `대통령`).
