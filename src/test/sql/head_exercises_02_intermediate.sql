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
-- Exercises at the intermediate level on head, a problem per query that reads head alone. Each problem states the
-- request it answers, then the SQL that answers it.
--
-- Parameters are bind variables (:name); the sqlite3 shell binds one with `.parameter set :name 'value'`, and an IDE
-- prompts for them when a statement runs. Dates are ISO-8601 text, so they compare as strings and date() and
-- julianday() read them directly; an incumbent's open term is measured to date('now'). A sort key that can be NULL
-- says NULLS FIRST or NULLS LAST, even where that is SQLite's default; a NOT NULL key does not.
--


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
