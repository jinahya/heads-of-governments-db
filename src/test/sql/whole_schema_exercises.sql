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
-- Exercises on the whole schema, a problem per query that reads both tables; Basic, then Intermediate, then Advanced.
-- Each problem states the request it answers, then the SQL that answers it.
--
-- Parameters are bind variables (:name); the sqlite3 shell binds one with `.parameter set :name 'value'`, and an IDE
-- prompts for them when a statement runs.
--


-- =============================================================================================================== BASIC


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


-- ======================================================================================================== INTERMEDIATE


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


-- ============================================================================================================ ADVANCED


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
