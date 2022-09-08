DECLARE attribution_table STRING DEFAULT 'traffic_sources';
-- SET attribution_table = 'SELECT * FROM traffic_sources';

WITH config AS (
    SELECT
        90 AS lookback  -- Lookback in days
        , '220801' AS start_date   -- Start date in YYmmdd
        , '220831' AS end_date       -- End date in YYmmdd
        , 'traffic_sources' AS table_name 
        , '{start_channel}' AS startChannel -- Starting channel
        , '{converted_channel}' AS convertedChannel -- Converted channel
        , '{not_converted_channel}' AS notConvertedChannel  -- Not converted channel
), base AS (
    SELECT 
        event_date
        , event_timestamp
        , user_pseudo_id AS visitor_id
        , event_name
        , MAX(CASE WHEN ev_params.key = 'ga_session_number' THEN ev_params.value.int_value    END) AS session_number
        , MAX(CASE WHEN ev_params.key = 'ga_session_id'     THEN ev_params.value.int_value    END) AS session_id
        , MAX(CASE WHEN ev_params.key = 'page_location'     THEN ev_params.value.string_value END) AS page_location
        , MAX(CASE WHEN ev_params.key = 'event_source'      THEN ev_params.value.string_value END) AS event_source
        , MAX(CASE WHEN ev_params.key = 'event_medium'      THEN ev_params.value.string_value END) AS event_medium
        , traffic_source.source AS user_source
        , traffic_source.medium AS user_medium
    FROM
        `adh-demo-data-review.analytics_213025502.events_20*`
        , UNNEST(event_params) AS ev_params
    WHERE
        _TABLE_SUFFIX 
            BETWEEN (SELECT start_date FROM config) 
            AND (SELECT end_date FROM config)
    GROUP BY 
        event_date, event_timestamp, user_pseudo_id, user_id, event_name, traffic_source.source, traffic_source.medium
), traffic_sources AS (
    SELECT
        LOWER(IFNULL(source_medium, '(direct) / (none)')) AS source_medium,
        *
    FROM (
        SELECT 
            visitor_id,
            session_id,
            event_timestamp,
            event_date,
            event_name,
            CASE 
                WHEN REGEXP_CONTAINS(page_location, r'(&|\?)dclid=(.*)') THEN 'dv360 / cpm'
                WHEN REGEXP_CONTAINS(page_location, r'(&|\?)gclid=(.*)') THEN 'google / cpc'
                WHEN REGEXP_CONTAINS(page_location, r'utm_source=([0-1a-zA-Z_\-]+)') THEN 
                    CONCAT(REGEXP_EXTRACT(page_location, r'utm_source=([0-1a-zA-Z_\-]+)', 1), ' / ',
                            REGEXP_EXTRACT(page_location, r'utm_medium=([0-1a-zA-Z_\-]+)', 1))
                WHEN event_source IS NOT NULL THEN CONCAT(event_source, ' / ', event_medium)
                WHEN user_source IS NOT NULL THEN CONCAT(user_source, ' / ', user_medium)
                ELSE '(direct) / (none)'
            END AS source_medium
        FROM base
    )
), metrics AS (
    SELECT
        visitor_id,
        session_id,
    FROM base
)


EXECUTE IMMEDIATE
    "SELECT * FROM @attribution_table"
    USING attribution_table AS attribution_table

-- SELECT
--     source_medium,
--     -- COUNT(DISTINCT session_id) AS sessions
-- -- REGEXP_EXTRACT(page_location, r'utm_source=([0-1a-zA-Z_\-]+)') AS ext,
-- -- -- REGEXP_EXTRACT(page_location, r'(&|\?)utm_source=(.*)') AS ext,
-- *
-- FROM (
-- SELECT 
-- base.session_id,
--     CONCAT(visitor_id, '-',
--         CAST(
--             FIRST_VALUE(event_timestamp) 
--                 OVER (PARTITION BY visitor_id ORDER BY event_timestamp ASC)
--                 AS STRING)) AS hoge_id,
--     CASE 
--         WHEN REGEXP_CONTAINS(page_location, r'(&|\?)dclid=(.*)') THEN 'dv360 / cpm'
--         WHEN REGEXP_CONTAINS(page_location, r'(&|\?)gclid=(.*)') THEN 'google / cpc'
--         WHEN REGEXP_CONTAINS(page_location, r'utm_source=([0-1a-zA-Z_\-]+)') THEN 
--             CONCAT(REGEXP_EXTRACT(page_location, r'utm_source=([0-1a-zA-Z_\-]+)', 1), ' / ',
--                     REGEXP_EXTRACT(page_location, r'utm_medium=([0-1a-zA-Z_\-]+)', 1))
--         WHEN event_source IS NOT NULL THEN CONCAT('session: ', event_source, ' / ', event_medium)
--         WHEN user_source IS NOT NULL THEN CONCAT('user: ', user_source, ' / ', user_medium)
--         ELSE 'direct / none'
--     END AS source_medium
-- FROM base
-- )
-- WHERE source_medium IS NOT NULL
-- GROUP BY source_medium
-- ORDER BY sessions DESC

-- WHERE visitor_id = '1812133135.1616800146'

-- SELECT * FROM (
-- SELECT 
--     visitor_id,
--     event_timestamp,
--     page_location,
--     event_source,
--     user_source,
--     CASE 
--         WHEN REGEXP_CONTAINS(page_location, r'(&|\?)dclid=(.*)') THEN 'dv360 / cpm'
--         WHEN REGEXP_CONTAINS(page_location, r'(&|\?)gclid=(.*)') THEN 'google / cpc'
--         -- WHEN REGEXP_CONTAINS(page_location, r'(&|\?)utm_source=(.*)') THEN 
--         --     CONCAT(REGEXP_EXTRACT(page_location, r"(&|\?)utm_source=(.*)", 1), ' / ',
--         --             REGEXP_EXTRACT(page_location, r"(&|\?|&amp;)utm_medium=(.*)", 1))
--         WHEN event_source IS NOT NULL THEN CONCAT('session: ', event_source, ' / ', event_medium)
--         WHEN user_source IS NOT NULL THEN CONCAT('user: ', user_source, ' / ', user_medium)
--         ELSE 'direct / none'
--     END AS source_medium
-- FROM base
-- )
-- WHERE source_medium IS NULL
-- WHERE visitor_id = '1812133135.1616800146'
;
