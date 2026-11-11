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
-- Profiling queries on the view contemporary. Each says what it looks for and what the result should be; 'no rows'
-- marks a check that passes when nothing comes back.
--
-- CREATE VIEW contemporary (country_left, name_left, country_right, name_right, overlap_start, overlap_end) AS
-- SELECT ... FROM head a JOIN head b ON b.country > a.country AND the two terms overlap
--
-- Run the file as a whole, from the project directory:
--   sqlite3 src/main/resources/heads_of_governments.sqlite3 \
--     '.read src/test/sql/contemporary.sql'
--


-- ----------------------------------------------------------------------------------------- country_left, country_right
-- how many pairs each two countries contribute; ten pairs of countries, all with some.
SELECT country_left, country_right, COUNT(*) AS pairs
FROM contemporary
GROUP BY country_left, country_right
ORDER BY country_left ASC, country_right ASC
;

-- each pair is written once, country_left before country_right.
-- no rows: no pair is written the other way round, or within one country.
SELECT country_left, country_right
FROM contemporary
WHERE country_left >= country_right
;


-- ------------------------------------------------------------------------------------------ overlap_start, overlap_end
-- an overlap that ends before it starts.
-- no rows: every overlap is at least a day.
SELECT *
FROM contemporary
WHERE overlap_end < overlap_start
;

-- overlap_end is NULL only while both heads are in office: one row per two incumbents, ten in all.
SELECT country_left, name_left, country_right, name_right, overlap_start
FROM contemporary
WHERE overlap_end IS NULL
ORDER BY country_left ASC, country_right ASC
;

-- the longest overlaps.
SELECT country_left, name_left, country_right, name_right, overlap_start, overlap_end,
       julianday(overlap_end) - julianday(overlap_start) + 1 AS days
FROM contemporary
WHERE overlap_end IS NOT NULL
ORDER BY days DESC, overlap_start ASC
LIMIT 10
;


-- ---------------------------------------------------------------------------------------------------------------------
-- nothing identifies a row, but no row should repeat either.
-- no rows: every row is distinct.
SELECT country_left, name_left, country_right, name_right, overlap_start, overlap_end, COUNT(*)
FROM contemporary
GROUP BY country_left, name_left, country_right, name_right, overlap_start, overlap_end
HAVING COUNT(*) > 1
;
