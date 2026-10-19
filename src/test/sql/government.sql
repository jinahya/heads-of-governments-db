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
-- Profiling queries on government, a section per column. Each says what it looks for and what the result should be;
-- 'no rows' marks a check that passes when nothing comes back.
--
-- CREATE TABLE government (
--     country    TEXT NOT NULL PRIMARY KEY,
--     head_kind  TEXT NOT NULL CHECK (head_kind IN ('PRESIDENT', 'PRIME_MINISTER')),
--     head_title TEXT NOT NULL,
--     numbering  TEXT NOT NULL
-- ) WITHOUT ROWID
--
-- Run the file as a whole: sqlite3 db/heads_of_governments.sqlite3 '.read src/test/sql/government.sql'
--


-- ------------------------------------------------------------------------------------------------------------- country
SELECT country, head_kind, head_title, numbering
FROM government
ORDER BY country ASC
;

-- country is an ISO 3166-1 alpha-2 code: two upper-case ASCII letters, as Locale.getCountry() returns it.
-- no rows: every country is two upper-case letters.
SELECT country
FROM government
WHERE country NOT GLOB '[A-Z][A-Z]'
;


-- ----------------------------------------------------------------------------------------------------------- head_kind
-- the CHECK admits two values; how many governments of each.
SELECT head_kind, COUNT(*) AS governments
FROM government
GROUP BY head_kind
ORDER BY head_kind ASC
;


-- ---------------------------------------------------------------------------------------------------------- head_title
SELECT MIN(LENGTH(head_title)), MAX(LENGTH(head_title))
FROM government
;

-- a head_title which is blank, or carries leading or trailing spaces.
-- no rows: every head_title is trimmed and not blank.
SELECT country, '[' || head_title || ']' AS head_title
FROM government
WHERE TRIM(head_title) = ''
   OR head_title <> TRIM(head_title)
;

-- head_title is in the country's own language, so it need not be ASCII; which are and which are not.
SELECT country, head_title, head_title GLOB '*[^ -~]*' AS non_ascii
FROM government
ORDER BY country ASC
;


-- ----------------------------------------------------------------------------------------------------------- numbering
SELECT MIN(LENGTH(numbering)), MAX(LENGTH(numbering))
FROM government
;

-- numbering is an English sentence that says what head.number counts; free text, so only check it is not blank or
-- padded.
-- no rows: every numbering is trimmed and not blank.
SELECT country, '[' || numbering || ']' AS numbering
FROM government
WHERE TRIM(numbering) = ''
   OR numbering <> TRIM(numbering)
;


-- ---------------------------------------------------------------------------------------------------------------------
-- a government with no head at all; the generator inserts a list for every government, so none is bare.
-- no rows: every government has at least one head.
SELECT g.country
FROM government g
WHERE NOT EXISTS (SELECT 1
                  FROM head h
                  WHERE h.country = g.country)
;
