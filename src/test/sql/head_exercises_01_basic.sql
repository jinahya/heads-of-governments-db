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
-- Exercises at the basic level on head, a problem per query that reads head alone. Each problem states the request it
-- answers, then the SQL that answers it.
--
-- Parameters are bind variables (:name); the sqlite3 shell binds one with `.parameter set :name 'value'`, and an IDE
-- prompts for them when a statement runs. Dates are ISO-8601 text, so they compare as strings and date() and
-- julianday() read them directly; an incumbent's open term is measured to date('now'). A sort key that can be NULL
-- says NULLS FIRST or NULLS LAST, even where that is SQLite's default; a NOT NULL key does not.
--


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
