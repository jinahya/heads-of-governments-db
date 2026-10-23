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
-- Exercises at the intermediate level on office, a problem per query that reads office alone. Each problem states the
-- request it answers, then the SQL that answers it.
--
-- Parameters are bind variables (:name); the sqlite3 shell binds one with `.parameter set :name 'value'`, and an IDE
-- prompts for them when a statement runs.
--


-- ------------------------------------------------------------------------- HOG-OFFICE-I-01 Offices by the kind of head
-- How many offices have a president and how many a prime minister, naming the countries of each.
SELECT head_kind, COUNT(*) AS offices, GROUP_CONCAT(country, ', ' ORDER BY country) AS countries
FROM office
GROUP BY head_kind
ORDER BY head_kind ASC
;


-- -------------------------------------------------------------------------------- HOG-OFFICE-I-02 Titles outside ASCII
-- head_title is in the country's own language. Which titles use a character outside ASCII, and which do not?
SELECT country,
       head_title,
       CASE WHEN head_title GLOB '*[^ -~]*' THEN 'non-ASCII' ELSE 'ASCII' END AS script
FROM office
ORDER BY script ASC, country ASC
;
