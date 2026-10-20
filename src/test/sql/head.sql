-- #%L
-- heads-of-governments-db
-- %%
-- Copyright (C) 2026 Jinahya, Inc.
-- %%
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #L%
---
--
-- Profiling queries on head, a section per column. Each says what it looks for and what the result should be;
-- 'no rows' marks a check that passes when nothing comes back.
--
-- CREATE TABLE head (
--     id         INTEGER PRIMARY KEY,
--     country    TEXT    NOT NULL REFERENCES office (country),
--     number     INTEGER NOT NULL,
--     term_start TEXT    NOT NULL,
--     term_end   TEXT,
--     name       TEXT    NOT NULL,
--     party      TEXT    NOT NULL,
--     born       INTEGER NOT NULL,
--     died       INTEGER,
--     CHECK (term_end IS NULL OR term_end >= term_start),
--     CHECK (died IS NULL OR died >= born)
-- )
-- CREATE UNIQUE INDEX idx_head_country_term_start ON head (country, term_start)
-- CREATE INDEX idx_head_country_number ON head (country, number)
-- CREATE INDEX idx_head_name ON head (name)
--
-- Run the file as a whole: sqlite3 db/heads_of_governments.sqlite3 '.read src/test/sql/head.sql'
--


-- ------------------------------------------------------------------------------------------------------------------ id
-- id is the rowid; the generator inserts by country, then term_start, so ids run 1..N in that order in this run.
SELECT MIN(id), MAX(id), COUNT(*)
FROM head
;

-- a row whose id disagrees with its position by (country, term_start).
-- no rows: ids are 1..N by country, then term_start.
SELECT id, country, term_start, position
FROM (SELECT id, country, term_start, ROW_NUMBER() OVER (ORDER BY country, term_start) AS position
      FROM head)
WHERE id <> position
ORDER BY id ASC
;


-- ------------------------------------------------------------------------------------------------------------- country
SELECT country, COUNT(*) AS terms
FROM head
GROUP BY country
ORDER BY country ASC
;

-- a head whose country is not an office; the foreign key forbids it while enforced, which the generator does.
-- no rows: no orphan.
SELECT id, country, name
FROM head
WHERE country NOT IN (SELECT country FROM office)
;


-- -------------------------------------------------------------------------------------------------------------- number
SELECT country, MIN(number), MAX(number), COUNT(*) AS terms, COUNT(DISTINCT number) AS numbers
FROM head
GROUP BY country
ORDER BY country ASC
;

-- a number that repeats within a country. France and the United Kingdom number persons, and a person re-elected or
-- returning keeps the number, so both repeat; Japan, South Korea and the United States number terms, so none repeats.
-- rows for FR and GB only.
SELECT country, number, COUNT(*) AS terms, GROUP_CONCAT(name, ' / ' ORDER BY term_start) AS names
FROM head
GROUP BY country, number
HAVING COUNT(*) > 1
ORDER BY country ASC, number ASC
;

-- a number that is not the previous term's plus one, going by term_start. A person keeping the number (FR, GB) steps
-- by 0; a person returning after others (GB) steps back; a 代, a 대 or a presidency never skips, so JP, KR and US are
-- absent.
SELECT country, number, name, term_start, number - previous_number AS step
FROM (SELECT country,
             number,
             name,
             term_start,
             LAG(number) OVER (PARTITION BY country ORDER BY term_start) AS previous_number
      FROM head)
WHERE previous_number IS NOT NULL
  AND number - previous_number <> 1
ORDER BY country ASC, term_start ASC
;

-- a number missing from 1..MAX within a country.
-- no rows: every country's numbers are dense.
WITH RECURSIVE n(country, number, max_number) AS (SELECT country, 1, MAX(number)
                                                  FROM head
                                                  GROUP BY country
                                                  UNION ALL
                                                  SELECT country, number + 1, max_number
                                                  FROM n
                                                  WHERE number < max_number)
SELECT n.country, n.number
FROM n
WHERE NOT EXISTS (SELECT 1
                  FROM head h
                  WHERE h.country = n.country
                    AND h.number = n.number)
ORDER BY n.country ASC, n.number ASC
;


-- ---------------------------------------------------------------------------------------------------------- term_start
SELECT country, MIN(term_start), MAX(term_start)
FROM head
GROUP BY country
ORDER BY country ASC
;

-- a term_start that is not a yyyy-MM-dd date; date() returns NULL for a malformed value and rewrites a lax one.
-- no rows: every term_start is a well-formed date.
SELECT id, country, term_start
FROM head
WHERE term_start NOT GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
   OR date(term_start) IS NOT term_start
;

-- two terms of one country starting on the same day; the unique index idx_head_country_term_start refuses it.
-- no rows: (country, term_start) is distinct.
SELECT country, term_start, COUNT(*) AS terms
FROM head
GROUP BY country, term_start
HAVING COUNT(*) > 1
;


-- ------------------------------------------------------------------------------------------------------------ term_end
-- the incumbent is the row with no term_end.
SELECT country, id, number, name, term_start
FROM head
WHERE term_end IS NULL
ORDER BY country ASC
;

-- a country with other than one incumbent; nothing in the schema prevents it, the generator checks it.
-- no rows: exactly one incumbent per country.
SELECT country, COUNT(*) AS incumbents
FROM head
WHERE term_end IS NULL
GROUP BY country
HAVING COUNT(*) <> 1
;

-- the same format check as term_start.
-- no rows: every term_end is a well-formed date.
SELECT id, country, term_end
FROM head
WHERE term_end IS NOT NULL
  AND (term_end NOT GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
    OR date(term_end) IS NOT term_end)
;

-- a term that starts before the previous term of the same country ends: two heads at once. The CHECK keeps
-- term_end >= term_start within a row; nothing keeps rows apart.
-- no rows: no country's terms overlap.
SELECT country, previous_name, previous_term_end, name, term_start
FROM (SELECT country,
             name,
             term_start,
             LAG(name) OVER (PARTITION BY country ORDER BY term_start)     AS previous_name,
             LAG(term_end) OVER (PARTITION BY country ORDER BY term_start) AS previous_term_end
      FROM head)
WHERE previous_term_end > term_start
ORDER BY country ASC, term_start ASC
;

-- an incumbent who is not the last term of the country by term_start; the overlap check above misses this, since
-- NULL compares with nothing.
-- no rows: every incumbent is the latest term.
SELECT country, name, term_start, next_term_start
FROM (SELECT country,
             name,
             term_start,
             term_end,
             LEAD(term_start) OVER (PARTITION BY country ORDER BY term_start) AS next_term_start
      FROM head)
WHERE term_end IS NULL
  AND next_term_start IS NOT NULL
;

-- how a succession is written differs by source: the day a term ends is the day the next begins, or the day before,
-- and anything longer is a vacancy. Counts each kind per country.
SELECT country,
       SUM(gap = 0) AS same_day,
       SUM(gap = 1) AS next_day,
       SUM(gap > 1) AS vacancy
FROM (SELECT country,
             julianday(term_start) - julianday(LAG(term_end) OVER (PARTITION BY country ORDER BY term_start)) AS gap
      FROM head)
WHERE gap IS NOT NULL
GROUP BY country
ORDER BY country ASC
;


-- ---------------------------------------------------------------------------------------------------------------- name
SELECT MIN(LENGTH(name)), MAX(LENGTH(name))
FROM head
;

-- a name which is blank, or carries leading or trailing spaces.
-- no rows: every name is trimmed and not blank.
SELECT id, '[' || name || ']' AS name
FROM head
WHERE TRIM(name) = ''
   OR name <> TRIM(name)
;

-- name keeps the script of the source, so a Japanese or Korean name has no space in it and the others have one.
SELECT country, SUM(name LIKE '% %') AS with_space, SUM(name NOT LIKE '% %') AS without_space
FROM head
GROUP BY country
ORDER BY country ASC
;

-- a name with more than one term in a country: re-elected (FR, KR), a new 代 (JP), or returned after an absence
-- (GB, US).
SELECT country, name, COUNT(*) AS terms, MIN(term_start) AS first_term_start, MAX(term_start) AS last_term_start
FROM head
GROUP BY country, name
HAVING COUNT(*) > 1
ORDER BY country ASC, first_term_start ASC
;

-- a name shared by two persons, which shows as one name with two years of birth; the sources tell such persons
-- apart (John Adams and John Quincy Adams, 鳩山一郎 and 鳩山由紀夫).
-- no rows: a name is one person within a country.
SELECT country, name, GROUP_CONCAT(DISTINCT born) AS born
FROM head
GROUP BY country, name
HAVING COUNT(DISTINCT born) > 1
;


-- --------------------------------------------------------------------------------------------------------------- party
SELECT MIN(LENGTH(party)), MAX(LENGTH(party))
FROM head
;

-- party is one token: '_' inside a multi-word name, '/' between successive parties, never a space.
-- no rows: no party is blank or has a space.
SELECT id, country, party
FROM head
WHERE TRIM(party) = ''
   OR party LIKE '% %'
;

-- the parties written as a succession, a party renamed or changed under the head.
SELECT country, name, term_start, party
FROM head
WHERE party LIKE '%/%'
ORDER BY country ASC, term_start ASC
;

-- distinct parties per country, a succession counting as its own value.
SELECT country, COUNT(DISTINCT party) AS parties
FROM head
GROUP BY country
ORDER BY country ASC
;


-- ---------------------------------------------------------------------------------------------------------------- born
SELECT MIN(born), MAX(born)
FROM head
;

-- a head under 18 when the term started, by year: a typo in born or in term_start.
-- no rows: every head was an adult on taking office.
SELECT id, country, name, born, term_start
FROM head
WHERE born + 18 > CAST(SUBSTR(term_start, 1, 4) AS INTEGER)
;

-- a living head born more than a hundred years ago: more likely a missing died than a centenarian.
-- no rows: no living head is over a hundred.
SELECT id, country, name, born
FROM head
WHERE died IS NULL
  AND born < CAST(STRFTIME('%Y', 'now') AS INTEGER) - 100
;


-- ---------------------------------------------------------------------------------------------------------------- died
SELECT MIN(died), MAX(died), SUM(died IS NULL) AS living
FROM head
;

-- an incumbent recorded as dead.
-- no rows: every incumbent is alive.
SELECT id, country, name, died
FROM head
WHERE term_end IS NULL
  AND died IS NOT NULL
;

-- a year of death before the year the term ended; a head who died in office died in the year the term ended.
-- no rows: nobody's term outlasts them.
SELECT id, country, name, term_end, died
FROM head
WHERE died < CAST(SUBSTR(term_end, 1, 4) AS INTEGER)
;

-- a person's died differing between terms: NULL on one line and a year on another, or two years.
-- no rows: a person's died is the same on every line.
SELECT country, name, GROUP_CONCAT(DISTINCT COALESCE(died, 'NULL')) AS died
FROM head
GROUP BY country, name
HAVING COUNT(DISTINCT COALESCE(died, 0)) > 1
;


-- ---------------------------------------------------------------------------------------------------------------------
-- the statistics ANALYZE wrote, which the generator leaves for a consumer's query planner. idx is NULL on a row that
-- describes a table rather than an index; such a row, if any, goes first.
SELECT tbl, idx, stat
FROM sqlite_stat1
ORDER BY tbl ASC, idx ASC NULLS FIRST
;

-- the foreign keys hold.
-- no rows: no head references a missing office.
SELECT *
FROM pragma_foreign_key_check
;

-- the file is sound.
-- ok
PRAGMA integrity_check
;
