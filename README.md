# heads-of-governments-db

Generates an SQLite database of the heads of government of five countries -- the presidents of
France, South Korea and the United States, the prime ministers of Japan and the United Kingdom --
from hand-maintained text lists.

```sh
$ ./mvnw test
$ sqlite3 db/heads_of_governments.sqlite3 'SELECT country, number, name, term_start FROM head WHERE term_end IS NULL'
FR|25|Emmanuel Macron|2022-05-14
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
| `government` |    5 | a government in the institutional sense, keyed by ISO 3166-1 alpha-2 code |
| `head`       |  285 | one term of office, keyed by a surrogate `id`                               |

```sql
CREATE TABLE government
(
    country    TEXT NOT NULL PRIMARY KEY,                                   -- FR, GB, JP, KR, US
    head_kind  TEXT NOT NULL CHECK (head_kind IN ('PRESIDENT', 'PRIME_MINISTER')),
    head_title TEXT NOT NULL,                                               -- 内閣総理大臣, 대통령, ...
    numbering  TEXT NOT NULL                                                -- what head.number counts here
) WITHOUT ROWID;

CREATE TABLE head
(
    id         INTEGER PRIMARY KEY,                                         -- rowid; regenerated each run
    country    TEXT    NOT NULL REFERENCES government (country),
    number     INTEGER NOT NULL,
    term_start TEXT    NOT NULL,                                            -- yyyy-MM-dd
    term_end   TEXT,                                                        -- NULL for the incumbent
    name       TEXT    NOT NULL,
    party      TEXT    NOT NULL,                                            -- '/' separates successive parties
    born       INTEGER NOT NULL,
    died       INTEGER,                                                     -- NULL while living
    CHECK (term_end IS NULL OR term_end >= term_start),
    CHECK (died IS NULL OR died >= born)
);

CREATE INDEX idx_head_country_number ON head (country, number);
CREATE INDEX idx_head_name ON head (name);
```

A term is told apart by `(country, term_start)`; the generator checks that no pair repeats, though
the schema declares no constraint on it. `number` could not serve, because it means something
different in each country -- Japan counts appointments, South Korea elections, the United States
presidencies, France and the United Kingdom persons -- and the last two repeat it across a person's
terms. `government.numbering` spells out each country's rule. `id` is the rowid, numbered by country
and then by date as the generator inserts; the file is rebuilt on every run, so do not store an `id`
anywhere outside the file. The schema declares no uniqueness beyond `id`; the generator checks the
data once, at build time.
Dates are text, SQLite's own convention, so this finds who held office on a day:

```sql
SELECT country, name FROM head
WHERE term_start <= '1990-01-01' AND (term_end IS NULL OR term_end >= '1990-01-01');
```

Column by column: [db/heads_of_governments.sqlite3.md](db/heads_of_governments.sqlite3.md).
Queries to profile each table, and exercises on them, are under [src/test/sql](src/test/sql).

## The data

Under `src/main/resources`, one list per table, each in two forms.

The **`.txt`** files are the source, edited by hand: one record per line, a `|` between fields, no
header row and no comments. The five country lists share one layout, `number`, `term_start`,
`term_end`, `name`, `party`, `born`, `died`, with `-` where there is nothing: the incumbent's
`term_end`, a living person's `died`.

```
47|2025-01-20|-|Donald Trump|Republican|1946|-
```

`list_of_governments.txt` has `country`, `head_kind`, `head_title`, `numbering`. `party` is one
token, `_` for a space and `/` between successive affiliations, in the country's own language where
that is not English.

The **`.asv`** files are the same records as ASCII separated values -- `US` (0x1F) between fields,
`RS` (0x1E) between records, no comments, no newlines -- and are what the generator reads. They are
derived from the `.txt` and the build fails if one is stale. After editing a `.txt`:

```sh
cd src/main/resources
for t in list_of_*.txt; do
  grep -v '^$' "$t" | tr '|' '\037' | paste -sd $'\036' - | tr -d '\n' > "${t%.txt}.asv"
done
```

### Sources and notes

**France** -- [fr.wikipedia: Liste des présidents de la République française](https://fr.wikipedia.org/wiki/Liste_des_pr%C3%A9sidents_de_la_R%C3%A9publique_fran%C3%A7aise),
[en.wikipedia: List of presidents of France](https://en.wikipedia.org/wiki/List_of_presidents_of_France),
[elysee.fr](https://www.elysee.fr/la-presidence/les-presidents-de-la-republique-depuis-1848).
`number` is the ordinal of the person by first election; a person re-elected has one line per term
and keeps the number (Grévy, Lebrun, de Gaulle, Mitterrand, Chirac, Macron), the second term
starting the day the first ends. Thiers is counted from 31 August 1871 (loi Rivet), not from
17 February 1871 when he became chef du pouvoir exécutif. Louis-Napoléon Bonaparte's term ends on
2 December 1852, the day the Second Empire was proclaimed. The office did not exist from 11 July
1940 to 16 January 1947. Interim presidents (Alain Poher, 1969 and 1974) hold no number and are not
listed. Parties are French names, with the usual acronyms for the Fourth and Fifth Republics
(SFIO, CNIP, UNR, UDR, RI, UDF, PS, RPR, UMP, LREM); a party renamed under the president is written
as a succession (UNR/UDR, RPR/UMP, LREM/Renaissance).

**Japan** -- [ja.wikipedia: 内閣総理大臣の一覧](https://ja.wikipedia.org/wiki/%E5%86%85%E9%96%A3%E7%B7%8F%E7%90%86%E5%A4%A7%E8%87%A3%E3%81%AE%E4%B8%80%E8%A6%A7),
[en.wikipedia: List of prime ministers of Japan](https://en.wikipedia.org/wiki/List_of_prime_ministers_of_Japan),
[首相官邸: 歴代内閣](https://www.kantei.go.jp/jp/rekidainaikaku/).
`number` is the 代 as Japanese usage counts it, one per appointment: a cabinet re-formed after a
general election starts a new 代, and a person keeps one line per 代 (吉田茂 is 45 and 48 through
51; 安倍晋三 is 90 and 96 through 98). Interim and acting prime ministers (兼任, 臨時代理: 三条実美,
内田康哉, 伊東正義, 青木幹雄, ...) hold no 代 and are not listed. Names keep the kanji of the source
(若槻禮次郎, 濱口雄幸, 東條英機). `無所属` is independent; `民主党` names both the 1947-1950 and the
1998-2016 party.

**South Korea** -- [ko.wikipedia: 대한민국 대통령 목록](https://ko.wikipedia.org/wiki/%EB%8C%80%ED%95%9C%EB%AF%BC%EA%B5%AD_%EB%8C%80%ED%86%B5%EB%A0%B9_%EB%AA%A9%EB%A1%9D),
[en.wikipedia: List of presidents of South Korea](https://en.wikipedia.org/wiki/List_of_presidents_of_South_Korea),
[대통령기록관](https://www.pa.go.kr/online_contents/president/).
`number` is the 대 as Korean usage counts it, one per election: a person re-elected keeps one line
per term with consecutive numbers (이승만 is 1, 2 and 3; 박정희 is 5 through 9; 전두환 is 11 and
12). Acting presidents (권한대행) hold no 대 and are not listed. A suspension during a term (노무현
2004-03-12 ~ 2004-05-14, 박근혜 2016-12-09 ~ 2017-03-10, 윤석열 2024-12-14 ~ 2025-04-04) does not
split the line; the term ends on the day the office was vacated. `무소속` is independent.

**United Kingdom** -- [en.wikipedia: List of prime ministers of the United Kingdom](https://en.wikipedia.org/wiki/List_of_prime_ministers_of_the_United_Kingdom).
`number` is the ordinal of the person by first appointment (Walpole 1, Starmer 58); a person who
served non-consecutive terms has one line per term and keeps the same number on each.

**United States** -- [en.wikipedia: List of presidents of the United States](https://en.wikipedia.org/wiki/List_of_presidents_of_the_United_States),
[whitehouse.gov archive: chronological list](https://georgewbush-whitehouse.archives.gov/history/presidents/chronological.html).
`number` is the presidency number: Cleveland appears twice, as 22 and 24, and Trump as 45 and 47.

**Governments** -- [ISO 3166 country codes](https://www.iso.org/iso-3166-country-codes.html),
[en.wikipedia: Head of government](https://en.wikipedia.org/wiki/Head_of_government),
[en.wikipedia: Head of state](https://en.wikipedia.org/wiki/Head_of_state).
`country` is the ISO 3166-1 alpha-2 code as `java.util.Locale#getCountry()` returns it; the United
Kingdom is `GB`, not `UK`. `head_title` is in the country's own language. `numbering` repeats, in a
sentence, the rule for `number` given above.

## How it is built

A JUnit test is the generator. `HeadsOfGovernments_Sqlite_Test` parses the `.asv` files, deletes any
previous database, creates the schema, inserts everything in one transaction with foreign keys on,
runs `ANALYZE`, then reopens the file and checks it: row counts per country, five incumbents, no
orphans, the indexes present. `VACUUM` is the last step, so the file ships compact. `_Asv_Test` checks the inputs first. The only
dependencies are JUnit, AssertJ and [sqlite-jdbc](https://github.com/xerial/sqlite-jdbc), all in
test scope.

## License

[Apache License, Version 2.0](LICENSE).
