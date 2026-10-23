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
-- Exercises at the advanced level on the whole schema, a problem per query that reads both tables. Each problem states
-- the request it answers, then the SQL that answers it.
--
-- Parameters are bind variables (:name); the sqlite3 shell binds one with `.parameter set :name 'value'`, and an IDE
-- prompts for them when a statement runs.
--


-- ------------------------------------------------------------------ HOG-SCHEMA-A-01 Each office's longest-serving head
-- Per office, the person with the most days in office over all their terms, with the title they held; ties
-- share the place.
SELECT country, head_title, name, terms, days
FROM (SELECT g.country,
             g.head_title,
             h.name,
             COUNT(*)                                                                                   AS terms,
             CAST(SUM(julianday(COALESCE(h.term_end, date('now'))) - julianday(h.term_start)) AS INTEGER) AS days,
             RANK() OVER (PARTITION BY g.country
                 ORDER BY SUM(julianday(COALESCE(h.term_end, date('now'))) - julianday(h.term_start)) DESC) AS place
      FROM office g
               JOIN head h ON h.country = g.country
      GROUP BY g.country, g.head_title, h.name)
WHERE place = 1
ORDER BY country ASC
;


-- ---------------------------------------------------------------- HOG-SCHEMA-A-02 Every office on a day, vacant or not
-- A reader gives a date and wants every office with its head on that day, or 'vacant' where the office was empty
-- or the list had not yet begun.
SELECT g.country, g.head_title, COALESCE(h.name, '(vacant)') AS name, h.term_start, h.term_end
FROM office g
         LEFT JOIN head h ON h.country = g.country
    AND h.term_start <= :date
    AND (h.term_end IS NULL OR h.term_end >= :date)
ORDER BY g.country ASC
;


-- ---------------------------------------------------------------------- HOG-SCHEMA-A-03 The incumbents' contemporaries
-- On the day each incumbent took office, who headed the other offices? One row per pair, the incumbent first.
SELECT i.country     AS country,
       i.name        AS incumbent,
       i.term_start  AS since,
       o.country     AS other,
       g.head_title,
       o.name        AS head
FROM head i
         JOIN head o ON o.country <> i.country
    AND o.term_start <= i.term_start
    AND (o.term_end IS NULL OR o.term_end >= i.term_start)
         JOIN office g ON g.country = o.country
WHERE i.term_end IS NULL
ORDER BY i.country ASC, o.country ASC
;
