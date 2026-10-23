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
-- Exercises at the basic level on office, a problem per query that reads office alone. Each problem states the request
-- it answers, then the SQL that answers it.
--
-- Parameters are bind variables (:name); the sqlite3 shell binds one with `.parameter set :name 'value'`, and an IDE
-- prompts for them when a statement runs.
--


-- -------------------------------------------------------------------------------- HOG-OFFICE-B-01 An office by country
-- A reader has a country code, typed in whatever case, and wants that office.
SELECT country, head_kind, head_title, numbering
FROM office
WHERE country = UPPER(:country)
;


-- ----------------------------------------------------------------------------------------- HOG-OFFICE-B-02 The offices
-- The front page lists every office with the title of its head, by country code.
SELECT country, head_kind, head_title
FROM office
ORDER BY country ASC
;
