WITH Roster AS (
    SELECT 'Adams' as LastName, 50 as SchoolID UNION ALL
    SELECT 'Buchanan', 52 UNION ALL
    SELECT 'Coolidge', 52 UNION ALL
    SELECT 'Davis', 51 UNION ALL
    SELECT 'Eisenhower', 77
), TeamMascot AS(
    SELECT 50 as SchoolID, 'Jaguars' as Mascot UNION ALL
    SELECT 51, 'Knights' UNION ALL
    SELECT 52, 'Lakers' UNION ALL
    SELECT 53, 'Mustangs'
), PlayerStats AS (
    SELECT 'Adams' as LastName, 51 as OpponentID, 3 as PointsScored UNION ALL
    SELECT 'Buchanan', 77, 0 UNION ALL
    SELECT 'Coolidge', 77, 1 UNION ALL
    SELECT 'Adams', 52, 4 UNION ALL
    SELECT 'Buchanan', 50, 13
)

-- INTERSECT : This query returns the last names 
-- that are present in both Roster and PlayerStats.

SELECT LastName
FROM Roster
INTERSECT DISTINCT
SELECT LastName
FROM PlayerStats;
