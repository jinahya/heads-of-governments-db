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
-- Exercises at the advanced level on office, a problem per query that reads office alone. Each problem states the
-- request it answers, then the SQL that answers it.
--
-- Parameters are bind variables (:name); the sqlite3 shell binds one with `.parameter set :name 'value'`, and an IDE
-- prompts for them when a statement runs.
--


-- --------------------------------------------------------------------- HOG-OFFICE-A-01 What number counts, in a phrase
-- numbering is a sentence, but each opens by naming what is counted -- 'ordinal of the person by first election',
-- '代', '대', 'presidency number' -- before its first comma or semicolon. Show each office with that phrase alone.
SELECT country,
       CASE
           WHEN comma > 0 AND (semicolon = 0 OR comma < semicolon) THEN SUBSTR(numbering, 1, comma - 1)
           WHEN semicolon > 0 THEN SUBSTR(numbering, 1, semicolon - 1)
           ELSE numbering
           END AS counts
FROM (SELECT country, numbering, INSTR(numbering, ',') AS comma, INSTR(numbering, ';') AS semicolon
      FROM office)
ORDER BY country ASC
;
