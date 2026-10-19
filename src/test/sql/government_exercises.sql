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
-- Exercises on government, a problem per query that reads government alone; Basic, then Intermediate, then Advanced.
-- Each problem states the request it answers, then the SQL that answers it.
--
-- Parameters are bind variables (:name); the sqlite3 shell binds one with `.parameter set :name 'value'`, and an IDE
-- prompts for them when a statement runs.
--


-- =============================================================================================================== BASIC


-- ------------------------------------------------------------------------- HOG-GOVERNMENT-B-01 A government by country
-- A reader has a country code, typed in whatever case, and wants that government.
SELECT country, head_kind, head_title, numbering
FROM government
WHERE country = UPPER(:country)
;


-- --------------------------------------------------------------------------------- HOG-GOVERNMENT-B-02 The governments
-- The front page lists every government with the title of its head, by country code.
SELECT country, head_kind, head_title
FROM government
ORDER BY country ASC
;


-- ======================================================================================================== INTERMEDIATE


-- ----------------------------------------------------------------- HOG-GOVERNMENT-I-01 Governments by the kind of head
-- How many governments have a president and how many a prime minister, naming the countries of each.
SELECT head_kind, COUNT(*) AS governments, GROUP_CONCAT(country, ', ' ORDER BY country) AS countries
FROM government
GROUP BY head_kind
ORDER BY head_kind ASC
;


-- ---------------------------------------------------------------------------- HOG-GOVERNMENT-I-02 Titles outside ASCII
-- head_title is in the country's own language. Which titles use a character outside ASCII, and which do not?
SELECT country,
       head_title,
       CASE WHEN head_title GLOB '*[^ -~]*' THEN 'non-ASCII' ELSE 'ASCII' END AS script
FROM government
ORDER BY script ASC, country ASC
;


-- ============================================================================================================ ADVANCED


-- ----------------------------------------------------------------- HOG-GOVERNMENT-A-01 What number counts, in a phrase
-- numbering is a sentence, but each opens by naming what is counted -- 'ordinal of the person by first election',
-- '代', '대', 'presidency number' -- before its first comma or semicolon. Show each government with that phrase alone.
SELECT country,
       CASE
           WHEN comma > 0 AND (semicolon = 0 OR comma < semicolon) THEN SUBSTR(numbering, 1, comma - 1)
           WHEN semicolon > 0 THEN SUBSTR(numbering, 1, semicolon - 1)
           ELSE numbering
           END AS counts
FROM (SELECT country, numbering, INSTR(numbering, ',') AS comma, INSTR(numbering, ';') AS semicolon
      FROM government)
ORDER BY country ASC
;
