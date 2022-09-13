DECLARE timezone STRING;
DECLARE data_durations_in_days INT64;
DECLARE data_end_date DATE;
DECLARE data_start_date DATE;
DECLARE end_date STRING;
DECLARE start_date STRING;
DECLARE conversion_event_names ARRAY <STRING>;

-- Configurations
SET timezone = 'Asia/Tokyo';
SET data_durations_in_days = 180;
SET data_end_date = CURRENT_DATE(timezone);
SET data_start_date = DATE_SUB(data_end_date, INTERVAL data_durations_in_days DAY);
SET conversion_event_names = ['purchase', 'in_app_purchase'];

-- Initialization
SET start_date = FORMAT_DATE('%y%m%d', data_start_date);
SET end_date = FORMAT_DATE('%y%m%d', data_end_date);

BEGIN
    WITH base AS (
        SELECT 
            FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP_MICROS(event_timestamp), timezone) AS event_date,
            event_timestamp,
            user_pseudo_id AS visitor_id,
            event_name,
            MAX(CASE WHEN ev_params.key = 'ga_session_number' THEN ev_params.value.int_value    END) AS session_number,
            MAX(CASE WHEN ev_params.key = 'ga_session_id'     THEN ev_params.value.int_value    END) AS session_id,
            MAX(CASE WHEN ev_params.key = 'page_location'     THEN ev_params.value.string_value END) AS page_location,
            MAX(CASE WHEN ev_params.key = 'event_source'      THEN ev_params.value.string_value END) AS event_source,
            MAX(CASE WHEN ev_params.key = 'event_medium'      THEN ev_params.value.string_value END) AS event_medium,
            traffic_source.source AS user_source,
            traffic_source.medium AS user_medium
        FROM
            `adh-demo-data-review.analytics_213025502.events_20*`,
            UNNEST(event_params) AS ev_params
        WHERE
            _TABLE_SUFFIX BETWEEN start_date AND end_date
        GROUP BY 
            event_date,
            event_timestamp,
            user_pseudo_id,
            user_id,
            event_name,
            traffic_source.source,
            traffic_source.medium
    ), traffic_sources AS (
        SELECT
            visitor_id,
            session_id,
            -- event_timestamp,
            event_date,
            -- event_name,
            LOWER(IFNULL(source_medium, '(direct) / (none)')) AS source_medium,
            CASE
                WHEN LOWER(IFNULL(source_medium, '(direct) / (none)')) = '(direct) / (none)' 
                THEN 1 ELSE 0 END AS is_direct,
            SUM(CASE WHEN event_name = 'page_view' THEN 1 ELSE 0 END) AS pageviews,
            SUM(CASE WHEN event_name IN UNNEST(conversion_event_names) THEN 1 ELSE 0 END) AS conversions,
            s_conversion
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
                END AS source_medium,
                SUM(CASE WHEN event_name IN UNNEST(conversion_event_names) THEN 1 ELSE 0 END) 
                    OVER (PARTITION BY session_id ORDER BY event_timestamp ASC
                        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS s_conversion
            FROM base
        )
        WHERE visitor_id IS NOT NULL 
            AND session_id IS NOT NULL
        GROUP BY
            visitor_id, session_id, event_date, source_medium, is_direct, s_conversion
    ), metrics_base AS (
        SELECT
            visitor_id,
            session_id,
            event_date,
            SUM(CASE WHEN event_name = 'page_view' THEN 1 ELSE 0 END) AS pageviews,
            SUM(CASE WHEN event_name IN UNNEST(conversion_event_names) THEN 1 ELSE 0 END) AS conversions
        FROM base
        WHERE session_id IS NOT NULL
        GROUP BY visitor_id, session_id, event_date
    ), in_lookback_windows AS (
        SELECT *
        FROM traffic_sources
    )

    SELECT * FROM traffic_sources
    -- ORDER BY conversions DESC
    -- SELECT event_date, visitor_id, session_id, event_timestamp, event_name FROM base
    WHERE visitor_id IN (
        -- '1176439903.1655492354',
        -- '1060992553.1658351476',
        '856962968.1652906170') --,
        -- '523813833.1642180577')
    -- AND event_name IN ('purchase', 'in_app_purchase')
    AND event_date = '20220623'
    -- ORDER BY visitor_id, event_timestamp ASC
    ORDER BY conversions
;
EXCEPTION WHEN ERROR THEN
    # Get error informations
    SELECT
        @@error.message,
        @@error.stack_trace,
        @@error.statement_text,
        @@error.formatted_stack_trace;
END
;
