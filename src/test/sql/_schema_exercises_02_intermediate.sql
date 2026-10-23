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
-- Exercises at the intermediate level on the whole schema, a problem per query that reads both tables. Each problem
-- states the request it answers, then the SQL that answers it.
--
-- Parameters are bind variables (:name); the sqlite3 shell binds one with `.parameter set :name 'value'`, and an IDE
-- prompts for them when a statement runs.
--


-- ------------------------------------------------------------------ HOG-SCHEMA-I-01 Presidents against prime ministers
-- By the kind of head: how many terms, how many different persons, and the average length of a term in days, an open
-- term counted to today.
SELECT g.head_kind,
       COUNT(*)                                                                                       AS terms,
       COUNT(DISTINCT g.country || ' ' || h.name)                                                     AS persons,
       CAST(AVG(julianday(COALESCE(h.term_end, date('now'))) - julianday(h.term_start)) AS INTEGER)   AS average_days
FROM office g
         JOIN head h ON h.country = g.country
GROUP BY g.head_kind
ORDER BY g.head_kind ASC
;


-- ------------------------------------------------------------------------------- HOG-SCHEMA-I-02 Numbering in practice
-- Per office: how many terms, how many distinct numbers, the highest number, and the rule; where terms exceed
-- numbers, number is the person's and repeats.
SELECT g.country,
       COUNT(*)                 AS terms,
       COUNT(DISTINCT h.number) AS numbers,
       MAX(h.number)            AS highest,
       g.numbering
FROM office g
         JOIN head h ON h.country = g.country
GROUP BY g.country, g.numbering
ORDER BY g.country ASC
;


-- ------------------------------------------------------------------------------- HOG-SCHEMA-I-03 The span of each list
-- Per office, the first term's start, the latest term's start and the years between them, with the head's title.
SELECT g.country,
       g.head_title,
       MIN(h.term_start)                                         AS first_term_start,
       MAX(h.term_start)                                         AS latest_term_start,
       CAST(SUBSTR(MAX(h.term_start), 1, 4) AS INTEGER)
           - CAST(SUBSTR(MIN(h.term_start), 1, 4) AS INTEGER)    AS years
FROM office g
         JOIN head h ON h.country = g.country
GROUP BY g.country, g.head_title
ORDER BY g.country ASC
;
