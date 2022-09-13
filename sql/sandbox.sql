DECLARE last_date STRING DEFAULT '20220623';
DECLARE start_date STRING DEFAULT '20220624';
DECLARE lookback INT64 DEFAULT 60;

BEGIN
    WITH base AS (
        SELECT 1 AS id, 'taro' AS name, 1 AS converted
        UNION ALL 
        SELECT 2, 'jiro', 0 UNION ALL
        SELECT 3, 'saburo', 0 UNION ALL
        SELECT 4, 'shiro', 1 UNION ALL
        SELECT 5, 'goro', 0
    )

    SELECT id, name,
    EXISTS(SELECT id, name FROM base t WHERE t.id = id AND t.name = name AND converted = 1) AS flag
    FROM base
    WHERE id IN (3, 2) OR name = 'saburo'
    -- SELECT
    --     DATE_SUB(PARSE_DATE("%Y%m%d", last_date), INTERVAL lookback DAY),
    --     DATE_DIFF(PARSE_DATE("%Y%m%d", last_date), PARSE_DATE("%Y%m%d", start_date), DAY)
    ;

EXCEPTION WHEN ERROR THEN
    # Get error informations
    SELECT
        @@error.message,
        @@error.stack_trace,
        @@error.statement_text,
        @@error.formatted_stack_trace;
END;

