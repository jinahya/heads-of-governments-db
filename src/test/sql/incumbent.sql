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
-- Profiling queries on the view incumbent. Each says what it looks for and what the result should be; 'no rows' marks
-- a check that passes when nothing comes back.
--
-- CREATE VIEW incumbent (country, head_kind, head_title, number, term_start, name, party, born) AS
-- SELECT ... FROM office o JOIN head h ON h.country = o.country AND h.term_end IS NULL
--
-- Run the file as a whole, from the project directory:
--   sqlite3 src/main/resources/heads_of_governments.sqlite3 \
--     '.read src/test/sql/incumbent.sql'
--


-- ------------------------------------------------------------------------------------------------------------- country
SELECT country, head_kind, head_title, number, term_start, name, party, born
FROM incumbent
ORDER BY country ASC
;

-- country identifies a row; the schema cannot declare it, the generator asserts it.
-- no rows: no country appears twice.
SELECT country, COUNT(*) AS heads
FROM incumbent
GROUP BY country
HAVING COUNT(*) > 1
;

-- an office with no incumbent.
-- no rows: every office has one.
SELECT g.country
FROM office g
WHERE g.country NOT IN (SELECT country FROM incumbent)
;


-- ---------------------------------------------------------------------------------------------------------------------
-- the view against head: every incumbent is a term with term_end IS NULL, and the other way round.
-- no rows: the two agree.
SELECT country, term_start
FROM incumbent
EXCEPT
SELECT country, term_start
FROM head
WHERE term_end IS NULL
UNION ALL
SELECT country, term_start
FROM head
WHERE term_end IS NULL
EXCEPT
SELECT country, term_start
FROM incumbent
;
