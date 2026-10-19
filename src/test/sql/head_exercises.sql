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
-- Exercises on head, a problem per query that reads head alone; Basic, then Intermediate, then Advanced. Each problem
-- states the request it answers, then the SQL that answers it.
--
-- Parameters are bind variables (:name); the sqlite3 shell binds one with `.parameter set :name 'value'`, and an IDE
-- prompts for them when a statement runs. Dates are ISO-8601 text, so they compare as strings and date() and
-- julianday() read them directly; an incumbent's open term is measured to date('now'). A sort key that can be NULL
-- says NULLS FIRST or NULLS LAST, even where that is SQLite's default; a NOT NULL key does not.
--


-- =============================================================================================================== BASIC


-- ------------------------------------------------------------------------------ HOG-HEAD-B-01 Who held office on a day
-- A reader gives a date and wants each country's head on that day. A country whose office was vacant is absent.
SELECT country, number, name, party, term_start, term_end
FROM head
WHERE term_start <= :date
  AND (term_end IS NULL OR term_end >= :date)
ORDER BY country ASC
;


-- ------------------------------------------------------------------------------------ HOG-HEAD-B-02 One country's list
-- A reader wants a country's heads, first to latest, as the source lists them.
SELECT *
FROM head
WHERE country = :country
ORDER BY term_start ASC
;


-- ---------------------------------------------------------------------------------------- HOG-HEAD-B-03 The incumbents
-- The dashboard shows who is in office now, per country, and since when.
SELECT country, number, name, party, term_start
FROM head
WHERE term_end IS NULL
ORDER BY country ASC
;


-- ----------------------------------------------------------------------------------------- HOG-HEAD-B-04 Terms by name
-- A reader types part of a name and wants every term of anyone matching it. LIKE folds case for ASCII letters only,
-- so 'churchill' finds Churchill and '吉田' finds 吉田茂; the index on name does not help a leading wildcard.
SELECT country, number, name, term_start, term_end
FROM head
WHERE name LIKE '%' || :name || '%'
ORDER BY country ASC, term_start ASC
;


-- ---------------------------------------------------------------------------- HOG-HEAD-B-05 Terms that began in a year
-- A timeline wants every term that began in a given year, in any country, in date order.
SELECT term_start, country, number, name
FROM head
WHERE term_start BETWEEN :year || '-01-01' AND :year || '-12-31'
ORDER BY term_start ASC, country ASC
;


-- ======================================================================================================== INTERMEDIATE


-- ------------------------------------------------------------------------ HOG-HEAD-I-01 The longest terms of a country
-- For one country, each term with its length in days, longest first; the incumbent's term runs to today.
SELECT number,
       name,
       term_start,
       term_end,
       CAST(julianday(COALESCE(term_end, date ('now'))) - julianday(term_start) AS INTEGER) AS days
FROM head
WHERE country = :country
ORDER BY days DESC, term_start ASC
;


-- ------------------------------------------------------------------------------------ HOG-HEAD-I-02 More than one term
-- Per country, the persons with more than one term, with how many and the numbers they held.
SELECT country, name, COUNT(*) AS terms, GROUP_CONCAT(number, ', ' ORDER BY term_start) AS numbers
FROM head
GROUP BY country, name
HAVING COUNT(*) > 1
ORDER BY country ASC, MIN(term_start) ASC
;


-- ---------------------------------------------------------------------------------- HOG-HEAD-I-03 Age on taking office
-- Per country, the youngest, the oldest and the average age at which a term began, in whole years of the calendar
-- (the year of term_start less the year of birth; born is a year, so that is as fine as the data allows).
SELECT country,
       MIN(CAST(SUBSTR(term_start, 1, 4) AS INTEGER) - born)           AS youngest,
       MAX(CAST(SUBSTR(term_start, 1, 4) AS INTEGER) - born)           AS oldest,
       ROUND(AVG(CAST(SUBSTR(term_start, 1, 4) AS INTEGER) - born), 1) AS average
FROM head
GROUP BY country
ORDER BY country ASC
;


-- --------------------------------------------------------------------------------------- HOG-HEAD-I-04 Terms per party
-- For one country, each party with how many terms it held and how many different persons, most terms first. A party
-- written as a succession ('RPR/UMP') counts as its own value.
SELECT party, COUNT(*) AS terms, COUNT(DISTINCT name) AS persons
FROM head
WHERE country = :country
GROUP BY party
ORDER BY terms DESC, party ASC
;


-- ----------------------------------------------------------------------------------- HOG-HEAD-I-05 Living former heads
-- Per country, the former heads still living, with the day their last term ended, most recent first.
SELECT country, name, born, MAX(term_end) AS last_term_end
FROM head
WHERE died IS NULL
GROUP BY country, name
HAVING MAX(term_end IS NULL) = 0
ORDER BY country ASC, last_term_end DESC NULLS LAST
;


-- -------------------------------------------------------------------------------- HOG-HEAD-I-06 Terms begun per decade
-- Across all countries, how many terms began in each decade, with the countries that had one.
SELECT SUBSTR(term_start, 1, 3) || '0s' AS decade,
       COUNT(*)                         AS terms,
       GROUP_CONCAT(DISTINCT country)   AS countries
FROM head
GROUP BY decade
ORDER BY decade ASC
;


-- ---------------------------------------------------------------------- HOG-HEAD-I-07 The latest terms of each country
-- Per country, the :n most recent terms, oldest of them first. Terms, not persons: a head re-elected appears once per
-- term. term_start is NOT NULL and distinct within a country, so the numbering has no ties.
SELECT country, number, name, term_start, term_end
FROM (SELECT h.*, ROW_NUMBER() OVER (PARTITION BY country ORDER BY term_start DESC) AS latest_rn
      FROM head AS h)
WHERE latest_rn <= :n
ORDER BY country ASC, term_start ASC
;


-- -------------------------------------------------------- HOG-HEAD-I-08 The first and the latest terms of each country
-- Per country, its first :n terms and its most recent :n, each row saying which it is. A row is 'first' when it is
-- among the first :n, so with a country of 2 * :n terms or fewer the two sets overlap and 'first' wins.
SELECT country,
       CASE WHEN first_rn <= :n THEN 'first' ELSE 'latest' END AS which,
       number,
       name,
       term_start,
       term_end
FROM (SELECT h.*,
             ROW_NUMBER() OVER (PARTITION BY country ORDER BY term_start ASC)  AS first_rn, ROW_NUMBER() OVER (PARTITION BY country ORDER BY term_start DESC) AS latest_rn
      FROM head AS h)
WHERE first_rn <= :n
   OR latest_rn <= :n
ORDER BY country ASC, term_start ASC
;


-- ------------------------------------------------------------------- HOG-HEAD-I-09 The first two terms of each country
-- Per country, its first two terms, the earlier first. Terms, not persons: a head whose first two terms were
-- consecutive appears twice. term_start is NOT NULL and distinct within a country, so the numbering has no ties.
SELECT country, name, term_start, term_end
FROM (SELECT h.*, ROW_NUMBER() OVER (PARTITION BY country ORDER BY term_start ASC) AS first_rn
      FROM head AS h)
WHERE first_rn <= 2
ORDER BY country ASC, term_start ASC
;

-- ---------------------------------------------------------- HOG-HEAD-I-10 Two or more terms, the top three per country
-- Per country, up to three heads with two or more terms, most terms first and, at a tie, the earlier first term first;
-- a name is taken as one person.
SELECT country, name, terms
FROM (SELECT country,
             name,
             COUNT(*) AS  terms,
             ROW_NUMBER() OVER (PARTITION BY country ORDER BY COUNT(*) DESC, MIN(term_start) ASC) AS place
      FROM head
      GROUP BY country, name
      HAVING COUNT(*) >= 2)
WHERE place <= 3
ORDER BY country ASC, place ASC
;


-- --------------------------------------------- HOG-HEAD-I-11 Party share of completed terms, the top three per country
-- Per country, over the terms that have ended, each party's share of the days in office as a percentage of that
-- country's total (its tenure share), the top three parties; a succession ('A/B') counts as a party of its own.
SELECT country, party, tenure_share
FROM (SELECT country,
             party,
             ROUND(100.0 * SUM(julianday(term_end) - julianday(term_start))
                       / SUM(SUM(julianday(term_end) - julianday(term_start))) OVER (PARTITION BY country),
                   1) AS  tenure_share,
             ROW_NUMBER() OVER (PARTITION BY country
                 ORDER BY SUM(julianday(term_end) - julianday(term_start)) DESC)             AS place
      FROM head
      WHERE term_end IS NOT NULL
      GROUP BY country, party)
WHERE place <= 3
ORDER BY country ASC, tenure_share DESC
;


-- ============================================================================================================ ADVANCED


-- --------------------------------------------------------------------------------------------- HOG-HEAD-A-01 Vacancies
-- Per country, each gap of more than a day between a term's end and the next term's start, with its length; a day
-- between is only how some sources write a succession, so it does not count.
SELECT country,
       previous_name,
       previous_term_end,
       name,
       term_start,
       CAST(julianday(term_start) - julianday(previous_term_end) AS INTEGER) - 1 AS days_vacant
FROM (SELECT country,
             name,
             term_start,
             LAG(name) OVER (PARTITION BY country ORDER BY term_start)     AS previous_name, LAG(term_end) OVER (PARTITION BY country ORDER BY term_start) AS previous_term_end
      FROM head)
WHERE julianday(term_start) - julianday(previous_term_end) > 1
ORDER BY country ASC, term_start ASC
;


-- ------------------------------------------------------------------------------------- HOG-HEAD-A-02 Longest in office
-- Per country, the person with the most days in office over all their terms, counting an open term to today; ties
-- share the place.
SELECT country, name, terms, days
FROM (SELECT country,
             name,
             COUNT(*)                                                                                  AS terms,
             CAST(SUM(julianday(COALESCE(term_end, date ('now'))) - julianday(term_start)) AS INTEGER) AS days,
             RANK()                                                                                       OVER (PARTITION BY country
                 ORDER BY SUM(julianday(COALESCE(term_end, date('now'))) - julianday(term_start)) DESC) AS place
      FROM head
      GROUP BY country, name)
WHERE place = 1
ORDER BY country ASC
;


-- -------------------------------------------------------------------------- HOG-HEAD-A-03 The longest run of one party
-- Per country, the longest unbroken run of consecutive terms held by the same party, with when it began and ended;
-- a run is counted in terms, not days, and a succession ('UNR/UDR') is a party of its own.
WITH ordered AS (SELECT country,
                        party,
                        term_start,
                        term_end,
                        ROW_NUMBER() OVER (PARTITION BY country ORDER BY term_start)        AS seq, ROW_NUMBER() OVER (PARTITION BY country, party ORDER BY term_start) AS seq_in_party
                 FROM head),
     runs AS (SELECT country,
                     party,
                     COUNT(*)                              AS terms,
                     MIN(term_start)                       AS since,
                     MAX(COALESCE(term_end, date ('now'))) AS until
              FROM ordered
              GROUP BY country, party, seq - seq_in_party),
     placed AS (SELECT *, RANK() OVER (PARTITION BY country ORDER BY terms DESC, since ASC) AS place
                FROM runs)
SELECT country, party, terms, since, until
FROM placed
WHERE place = 1
ORDER BY country ASC
;


-- -------------------------------------------------------------------- HOG-HEAD-A-04 Every party of a head, one per row
-- party may be a succession, 'A/B', when the party was renamed or changed under the head. Give the heads whose party
-- is one, with each party on its own row and its position in the succession.
WITH RECURSIVE parts(id, country, name, term_start, position, party, rest) AS
                   (SELECT id, country, name, term_start, 0, NULL, party || '/'
                    FROM head
                    WHERE party LIKE '%/%'
                    UNION ALL
                    SELECT id,
                           country,
                           name,
                           term_start,
                           position + 1,
                           SUBSTR(rest, 1, INSTR(rest, '/') - 1),
                           SUBSTR(rest, INSTR(rest, '/') + 1)
                    FROM parts
                    WHERE rest <> '')
SELECT country, name, term_start, position, party
FROM parts
WHERE position > 0
ORDER BY country ASC, term_start ASC, position ASC
;


-- ----------------------------------------------------------------------------- HOG-HEAD-A-05 Predecessor and successor
-- For a person named exactly, each of their terms with who held the office immediately before and after it in that
-- country; the incumbent has no successor.
SELECT country, number, term_start, term_end, predecessor, successor
FROM (SELECT country,
             number,
             name,
             term_start,
             term_end,
             LAG(name) OVER (PARTITION BY country ORDER BY term_start)  AS predecessor, LEAD(name) OVER (PARTITION BY country ORDER BY term_start) AS successor
      FROM head)
WHERE name = :name
ORDER BY country ASC, term_start ASC
;
