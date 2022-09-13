DECLARE timezone STRING;
DECLARE data_durations_in_days INT64;
DECLARE data_end_date DATE;
DECLARE data_start_date DATE;
DECLARE end_date STRING;
DECLARE start_date STRING;
DECLARE conversion_event_names ARRAY <STRING>;
DECLARE required_event_names ARRAY <STRING>;
DECLARE default_channel STRING;

-- Configurations
SET timezone = 'Asia/Tokyo';
SET data_durations_in_days = 180;
SET data_end_date = CURRENT_DATE(timezone);
SET data_start_date = DATE_SUB(data_end_date, INTERVAL data_durations_in_days DAY);
SET conversion_event_names = ['purchase', 'in_app_purchase'];
SET required_event_names = ['page_view', 'purchase', 'in_app_purchase'];
SET default_channel = '(direct) / (none)';

-- Define functions
CREATE OR REPLACE TABLE FUNCTION `msc-jp-cloud.ga4_sandbox.get_ga4_table_for_attribution`(
    start_date STRING, end_date STRING, timezone STRING, events ARRAY <STRING>
)
AS (
    WITH base AS (
        SELECT
            user_pseudo_id AS visitor_id,
            MAX(CASE WHEN event_params.key = 'ga_session_number'
                THEN event_params.value.int_value    END) AS session_number,
            MAX(CASE WHEN event_params.key = 'ga_session_id'
                THEN event_params.value.int_value    END) AS session_id,
            FORMAT_TIMESTAMP('%Y-%m-%dt',
                TIMESTAMP_MICROS(event_timestamp), timezone) event_date,
            event_timestamp,
            event_name,
            event_params,
        FROM `adh-demo-data-review.analytics_213025502.events_*`
        WHERE _TABLE_SUFFIX BETWEEN start_date AND end_date
            AND event_name IN UNNEST(events)
    )

    SELECT 
        *, 
    FROM base t1
);

CREATE TEMP FUNCTION GET_DATE_FROM_MICRO(fmt STRING, time_stamp INT64, timezone STRING)
RETURNS STRING
AS (
    FORMAT_TIMESTAMP(fmt, TIMESTAMP_MICROS(time_stamp), timezone)
);

CREATE TEMP FUNCTION GET_SOURCE_MEDIUM(
    page_location STRING,
    event_source STRING, event_medium STRING,
    user_source STRING, user_medium STRING,
    default_channel STRING)
RETURNS STRING
AS (
    LOWER(IFNULL(
        CASE 
            WHEN user_source IS NOT NULL THEN CONCAT(user_source, ' / ', user_medium)
            WHEN REGEXP_CONTAINS(page_location, r'(&|\?)dclid=(.*)') THEN 'dv360 / cpm'
            WHEN REGEXP_CONTAINS(page_location, r'(&|\?)gclid=(.*)') THEN 'google / cpc'
            WHEN REGEXP_CONTAINS(page_location, r'utm_source=([0-1a-zA-Z_\-]+)') THEN 
                CONCAT(REGEXP_EXTRACT(page_location, r'utm_source=([0-1a-zA-Z_\-]+)', 1), ' / ',
                    REGEXP_EXTRACT(page_location, r'utm_medium=([0-1a-zA-Z_\-]+)', 1))
            WHEN event_source IS NOT NULL THEN CONCAT(event_source, ' / ', event_medium)
            ELSE '(direct) / (none)'
        END, '(direct) / (none)'))
);

-- CREATE TEMP FUNCTION COUNT_EVENTS_IN_SESSION(
--     source_events ARRAY <STRING>, target_events ARRAY <STRING>)
-- RETURNS INT64
-- AS (
--     (
--         SELECT COUNT(*) AS event_name FROM UNNEST(source_events)
--         WHERE event_name IN (
--         SELECT * FROM UNNEST(source_events)
--             INTERSECT DISTINCT (SELECT * FROM UNNEST(target_events))))
-- );

CREATE TEMP FUNCTION GET_SESSION_ID(
    params ARRAY<STRUCT <
        key STRING,
        value STRUCT <
            string_value STRING,
            int_value INT64,
            float_value FLOAT64,
            double_value FLOAT64
    >>>)
RETURNS STRING
AS (
    CAST((
        SELECT p.value.int_value 
        FROM UNNEST(params) p 
        WHERE p.key = 'ga_session_id') AS STRING)
);

-- Initialization
SET start_date = FORMAT_DATE('%Y%m%d', data_start_date);
SET end_date = FORMAT_DATE('%Y%m%d', data_end_date);


BEGIN
    WITH base AS (
        SELECT 
            visitor_id,
            session_id,
            -- GET_SESSION_ID(event_params) AS session_id,
            event_date,
            event_timestamp,
            event_name,
        FROM ga4_sandbox.get_ga4_table_for_attribution(
            start_date, end_date, timezone, required_event_names
        )
    )
    -- SELECT event_name FROM (
    SELECT 
        visitor_id,
        session_id,
        ARRAY(SELECT event_name FROM base t2 WHERE t2.visitor_id = t1.visitor_id AND t2.session_id = t1.session_id) AS event_array,
        event_timestamp,
        event_date,
        event_name,
        -- COUNT_EVENTS_IN_SESSION(
        --     , conversion_event_names) AS counts
    FROM base t1
    WHERE visitor_id IN (
        '856962968.1652906170'
    )
    AND session_id = '1652906169'
    -- ) INTERSECT DISTINCT (
    --     SELECT * FROM UNNEST(['page_view', 'purchase'])
    -- )
    -- ORDER BY visitor_id, event_timestamp ASC
;

EXCEPTION WHEN ERROR THEN
    # Get error informations
    SELECT
        @@error.message,
        @@error.stack_trace,
        @@error.statement_text,
        @@error.formatted_stack_trace;
END;
