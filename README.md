# heads-of-governments-db

Generates an SQLite database of the heads of government of four countries -- the prime ministers of
Japan and the United Kingdom, the presidents of South Korea and the United States -- from
hand-maintained text lists.

```sh
$ ./mvnw test
$ sqlite3 db/heads_of_governments.sqlite3 'SELECT country, number, name, term_start FROM head WHERE term_end IS NULL'
GB|59|Andy Burnham|2026-07-20
JP|105|高市早苗|2026-02-18
KR|21|이재명|2025-06-04
US|47|Donald Trump|2025-01-20
```

That is the whole project. Nothing is published; the database is the deliverable, and the build is
how you get it. It needs a JDK 25 or newer.

## The database

`db/heads_of_governments.sqlite3`, two tables.

| table        | rows | one row is                                                               |
|--------------|-----:|--------------------------------------------------------------------------|
| `government` |    4 | a government in the institutional sense, keyed by ISO 3166-1 alpha-2 code |
| `head`       |  254 | one term of office, keyed by `(country, term_start)`                      |

```sql
CREATE TABLE government
(
    country    TEXT NOT NULL PRIMARY KEY,                                   -- GB, JP, KR, US
    head_kind  TEXT NOT NULL CHECK (head_kind IN ('PRESIDENT', 'PRIME_MINISTER')),
    head_title TEXT NOT NULL,                                               -- 内閣総理大臣, 대통령, ...
    numbering  TEXT NOT NULL                                                -- what head.number counts here
) WITHOUT ROWID;

CREATE TABLE head
(
    country    TEXT    NOT NULL REFERENCES government (country),
    number     INTEGER NOT NULL,
    term_start TEXT    NOT NULL,                                            -- yyyy-MM-dd
    term_end   TEXT,                                                        -- NULL for the incumbent
    name       TEXT    NOT NULL,
    party      TEXT    NOT NULL,                                            -- '/' separates successive parties
    born       INTEGER NOT NULL,
    died       INTEGER,                                                     -- NULL while living
    PRIMARY KEY (country, term_start),
    CHECK (term_end IS NULL OR term_end >= term_start),
    CHECK (died IS NULL OR died >= born)
) WITHOUT ROWID;

CREATE INDEX idx_head_country_number ON head (country, number);
CREATE INDEX idx_head_name ON head (name);
CREATE UNIQUE INDEX uq_head_incumbent ON head (country) WHERE term_end IS NULL;
```

`number` is not the key because it means something different in each country -- Japan counts
appointments, South Korea elections, the United States presidencies, the United Kingdom persons --
and the United Kingdom repeats it across a person's non-consecutive terms. `government.numbering`
spells out each country's rule. The unique partial index enforces one sitting head per government.
Dates are text, SQLite's own convention, so this finds who held office on a day:

```sql
SELECT country, name FROM head
WHERE term_start <= '1990-01-01' AND (term_end IS NULL OR term_end >= '1990-01-01');
```

Column by column: [db/heads_of_governments.sqlite3.md](db/heads_of_governments.sqlite3.md).

## The data

Under `src/main/resources`, one list per table, each in two forms.

The **`.txt`** files are the source, edited by hand. Lines starting with `#` are comments, including
the header row; the rest are TAB-separated records. Every file's header names its sources and explains
its columns. The four country lists share one layout:

```
#number	term_start	term_end	name	party	born	died
47	2025-01-20	-	Donald Trump	Republican	1946	-
```

The **`.asv`** files are the same records as ASCII separated values -- `US` (0x1F) between fields,
`RS` (0x1E) between records, no comments, no newlines -- and are what the generator reads. They are
derived from the `.txt` and the build fails if one is stale. After editing a `.txt`:

```sh
cd src/main/resources
for t in list_of_*.txt; do
  grep -v -E '^(#|$)' "$t" | tr '\t' '\037' | paste -sd $'\036' - | tr -d '\n' > "${t%.txt}.asv"
done
```

Sources are cited at the top of each list: the national archives where they exist (首相官邸,
대통령기록관, the White House) and the corresponding Wikipedia lists.

## How it is built

A JUnit test is the generator. `HeadsOfGovernments_Sqlite_Test` parses the `.asv` files, deletes any
previous database, creates the schema, inserts everything in one transaction with foreign keys on,
runs `ANALYZE`, then reopens the file and checks it: row counts per country, four incumbents, no
orphans, the indexes present. `VACUUM` is the last step, so the file ships compact. `_Asv_Test` checks the inputs first. The only
dependencies are JUnit, AssertJ and [sqlite-jdbc](https://github.com/xerial/sqlite-jdbc), all in
test scope.

## License

[Apache License, Version 2.0](LICENSE).
