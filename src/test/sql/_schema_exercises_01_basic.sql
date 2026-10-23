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
-- Exercises at the basic level on the whole schema, a problem per query that reads both tables. Each problem states the
-- request it answers, then the SQL that answers it.
--
-- Parameters are bind variables (:name); the sqlite3 shell binds one with `.parameter set :name 'value'`, and an IDE
-- prompts for them when a statement runs.
--


-- ------------------------------------------------------------------- HOG-SCHEMA-B-01 The incumbents, with their titles
-- The front page names each country's head of government today, with the title the country gives the office.
SELECT g.country, g.head_title, h.name, h.term_start
FROM office g
         JOIN head h ON h.country = g.country AND h.term_end IS NULL
ORDER BY g.country ASC
;


-- ----------------------------------------------------- HOG-SCHEMA-B-02 A country's list, with the rule for its numbers
-- A reader asks for one country's list and should see, with it, what number counts there.
SELECT g.head_title, g.numbering, h.number, h.term_start, h.term_end, h.name, h.party
FROM office g
         JOIN head h ON h.country = g.country
WHERE g.country = :country
ORDER BY h.term_start ASC
;


-- ------------------------------------------------------------------------------------ HOG-SCHEMA-B-03 Terms per office
-- Each office with the kind of head it has and how many terms the list holds.
SELECT g.country, g.head_kind, COUNT(h.id) AS terms
FROM office g
         LEFT JOIN head h ON h.country = g.country
GROUP BY g.country, g.head_kind
ORDER BY g.country ASC
;
