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
-- The schema of db/heads_of_governments.sqlite3, in execution order. The generator runs it statement by statement,
-- split on a ';' that ends a line, with the comment lines before a statement dropped; the ERD test runs the same on
-- an in-memory database. SQLite keeps each statement's text in sqlite_master.sql, comments included, so a '--'
-- comment inside a statement ships in the file and .schema shows it. Keep db/heads_of_governments.sqlite3.md in
-- step.
--
---
CREATE TABLE office (
    -- the office the head of government holds; one row per country
    country    TEXT NOT NULL PRIMARY KEY,                    -- ISO 3166-1 alpha-2: FR, GB, JP, KR, US
    head_kind  TEXT NOT NULL,                                -- PRESIDENT or PRIME_MINISTER
    head_title TEXT NOT NULL,                                -- the head's title, in the country's language
    numbering  TEXT NOT NULL,                                -- what head.number counts for this country
    CHECK (head_kind IN ('PRESIDENT', 'PRIME_MINISTER'))
) WITHOUT ROWID;

-- id is the rowid, so SQLite assigns it; the generator inserts by country then term_start, so it is 1..N in that
-- order. No uniqueness is declared on (country, term_start); the generator checks it instead.
CREATE TABLE head (
    -- one term of a head of government
    id         INTEGER PRIMARY KEY,                          -- the rowid; assigned by the build, not stable
    country    TEXT    NOT NULL REFERENCES office (country), -- the office's country
    number     INTEGER NOT NULL,                             -- the term number, as office.numbering says
    term_start TEXT    NOT NULL,                             -- ISO-8601 date, yyyy-MM-dd
    term_end   TEXT,                                         -- ISO-8601 date; NULL for the incumbent
    name       TEXT    NOT NULL,                             -- the person's name, in the source's script
    party      TEXT    NOT NULL,                             -- one token; / separates successive parties
    born       INTEGER NOT NULL,                             -- the year of birth
    died       INTEGER,                                      -- the year of death; NULL while living
    CHECK (term_end IS NULL OR term_end >= term_start),
    CHECK (died IS NULL OR died >= born)
);

CREATE INDEX idx_head_country_number ON head (country, number);

CREATE INDEX idx_head_name ON head (name);
