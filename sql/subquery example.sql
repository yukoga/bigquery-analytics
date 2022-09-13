-- To learn subquery
-- https://cloud.google.com/bigquery/docs/reference/standard-sql/subqueries#scalar_subquery_concepts

WITH
Players AS (
    SELECT 'gorbie' AS username, 29 AS level, 'red' AS team UNION ALL
    SELECT 'junelyn', 2 , 'blue' UNION ALL
    SELECT 'corba', 43, 'green'),
NPCs AS (
    SELECT 'niles' AS username, 'red' AS team UNION ALL
    SELECT 'jujul', 'red' UNION ALL
    SELECT 'effren', 'blue'),
Mascots AS (
    SELECT 'cardinal' AS mascot , 'red' AS team UNION ALL
    SELECT 'parrot', 'green' UNION ALL
    SELECT 'finch', 'blue' UNION ALL
    SELECT 'sparrow', 'yellow')

-- Scalar subquery
-- SELECT
--     username,
--     (SELECT mascot FROM Mascots WHERE Players.team = Mascots.team) AS player_mascot
-- FROM
--     Players

-- Array subquery
-- SELECT ARRAY(SELECT username FROM NPCs WHERE team = 'red') AS red

-- IN subquery
-- SELECT 'corba' IN (SELECT username FROM Players) AS result

-- EXISTS subquery
-- SELECT EXISTS(SELECT username FROM Players WHERE team = 'yellow') AS result
-- SELECT team,
-- EXISTS(SELECT team FROM Players p WHERE p.team = m.team) AS flag 
-- FROM Mascots m

-- Table subquery
-- SELECT results.username FROM (SELECT * FROM Players) AS results
-- SELECT 
--     username
-- FROM (
--     WITH read_team AS (SELECT * FROM NPCs WHERE team = 'red')
--     SELECT * FROM read_team
-- )
-- Correlated subquery
SELECT mascot FROM Mascots m
WHERE 
    NOT EXISTS(SELECT username FROM Players p WHERE m.team = p.team)
;

