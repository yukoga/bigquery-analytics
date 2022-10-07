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

-- Initialization
-- SET start_date = '2022-01-01';
-- SET end_date = '2022-06-30';
SET start_date = NULL;
SET end_date = NULL;
-- SET end_date = '2022-08-31';


-- Define functions
CREATE OR REPLACE FUNCTION ga4_sandbox.GET_DATE_RANGE(
    start_date STRING, end_date STRING,
    durations INT64, timezone STRING)
RETURNS ARRAY<STRING>
AS (CASE
        WHEN start_date IS NOT NULL AND end_date IS NOT NULL 
            THEN [
                REPLACE(start_date, '-', ''),
                REPLACE(end_date, '-', '')]
        WHEN start_date IS NULL AND end_date IS NOT NULL
            THEN [FORMAT_DATE('%Y%m%d',
                    DATE_SUB(TIMESTAMP(end_date, timezone),
                        INTERVAL durations DAY)),
                        REPLACE(end_date, '-', '')]
        WHEN start_date IS NOT NULL AND end_date IS NULL
            THEN [REPLACE(start_date, '-', ''),
                FORMAT_DATE('%Y%m%d',
                    DATE_ADD(TIMESTAMP(start_date, timezone),
                        INTERVAL durations DAY))]
        ELSE [FORMAT_DATE('%Y%m%d',
            DATE_SUB(CURRENT_DATE(timezone),
                INTERVAL durations DAY)),
                FORMAT_DATE('%Y%m%d', CURRENT_DATE(timezone))]
    END
);

CREATE OR REPLACE FUNCTION ga4_sandbox.COUNT_EVENTS_IN_SESSION(
    source_events ARRAY <STRUCT <
        name STRING, timestamp INT64, datetime DATETIME,
        params ARRAY <STRUCT <
        key STRING, value STRUCT <
            string_value STRING, int_value INT64,
            float_value FLOAT64, double_value FLOAT64>
        >>
    >>, target_events ARRAY <STRING>)
RETURNS INT64
AS (
    (SELECT SUM(CASE WHEN ev.name IN UNNEST(target_events)
            THEN 1 ELSE 0 END) FROM UNNEST(source_events) ev)
);

CREATE OR REPLACE FUNCTION ga4_sandbox.GET_SOURCE_MEDIUM(
    user_source STRING, user_medium STRING,
    event_source STRING, event_medium STRING,
    page_location STRING, default_channel STRING,
    session_number INT64)
RETURNS STRING
AS (
    LOWER(IFNULL(
        CASE 
-- Traffic source priorities:
-- user source --> dclid/gclid --> event source --> utm --> referrer --> direct
            WHEN session_number = 1 
                AND user_source IS NOT NULL 
                    THEN CONCAT(user_source, ' / ', user_medium)
            WHEN session_number = 1  
                AND user_source IS NULL
                    THEN '(direct) / (none)'
            WHEN session_number > 1
                AND REGEXP_CONTAINS(page_location, r'(&|\?)dclid=(.*)') 
                    THEN 'dv360 / cpm'
            WHEN session_number > 1 
                AND REGEXP_CONTAINS(page_location, r'(&|\?)gclid=(.*)')
                    THEN 'google / cpc'
            WHEN session_number > 1 
                AND event_source IS NOT NULL
                    THEN CONCAT(event_source, ' / ', event_medium)
            WHEN session_number > 1
                AND REGEXP_CONTAINS(page_location, r'utm_source=(.*)')
                    THEN CONCAT(
                        REGEXP_EXTRACT(page_location, r'utm_source=(.*)', 1),
                        ' / ',
                        REGEXP_EXTRACT(page_location, r'utm_medium=(.*)', 1))
            ELSE default_channel
            END, default_channel
        )
    )
);

CREATE OR REPLACE TABLE FUNCTION `msc-jp-cloud.ga4_sandbox.get_ga4_table_for_attribution`(
    start_date STRING, end_date STRING,
    timezone STRING, durations INT64,
    default_channel STRING, events ARRAY <STRING>, conversions ARRAY <STRING>
)
AS (
    WITH base AS(
        SELECT
            user_pseudo_id AS visitor_id,
            CAST((
                SELECT evp.value.int_value 
                FROM UNNEST(event_params) evp 
                WHERE evp.key = 'ga_session_id'
                AND evp.value.int_value IS NOT NULL) AS STRING) AS session_id,
            CAST((
                SELECT evp.value.int_value 
                FROM UNNEST(event_params) evp 
                WHERE evp.key = 'ga_session_number'
                AND evp.value.int_value IS NOT NULL) AS STRING) AS session_number,                
            traffic_source.source AS user_source,
            traffic_source.medium AS user_medium,
            (SELECT evp.value.string_value FROM UNNEST(event_params) evp 
                WHERE evp.key = 'event_source') AS event_source,
            (SELECT evp.value.string_value FROM UNNEST(event_params) evp 
                WHERE evp.key = 'event_medium') AS event_medium,
            (SELECT evp.value.string_value FROM UNNEST(event_params) evp 
                WHERE evp.key = 'page_location') AS page_location,
            (SELECT evp.value.string_value FROM UNNEST(event_params) evp 
                WHERE evp.key = 'page_referrer') AS page_referrer,
            event_timestamp AS event_timestamp,
            DATETIME(TIMESTAMP_MICROS(event_timestamp), timezone) AS event_datetime,
            event_name AS event_name,
            event_params AS event_params
        FROM `adh-demo-data-review.analytics_213025502.events_*`
        WHERE _TABLE_SUFFIX 
            BETWEEN ga4_sandbox.GET_DATE_RANGE(
                start_date, end_date, durations, timezone)[ORDINAL(1)]
            AND ga4_sandbox.GET_DATE_RANGE(
                start_date, end_date, durations, timezone)[OFFSET(1)] 
            AND event_name IN UNNEST(events)
    ), logs AS (
        SELECT
            t1.visitor_id, t1.session_id,
            ga4_sandbox.GET_SOURCE_MEDIUM(
                t1.user_source, t1.user_medium,
                t1.event_source, t1.event_medium,
                t1.page_location, default_channel, t1.session_number) AS source_medium,
            ARRAY(
                SELECT STRUCT <
                    name STRING,
                    timestamp INT64,
                    datetime DATETIME,
                    params ARRAY <STRUCT <
                        key STRING,
                        value STRUCT <
                            string_value STRING, 
                            int_value INT64,
                            float_value FLOAT64,
                            double_value FLOAT64>
                        >
                    >
                >(t2.event_name, t2.event_timestamp, t2.event_datetime, t2.event_params)
                FROM base t2
                WHERE t2.visitor_id = t1.visitor_id AND t2.session_id = t1.session_id
            ) AS events
        FROM base t1
    )

    SELECT
        DISTINCT visitor_id, session_id, source_medium,
        (SELECT
            DATETIME(TIMESTAMP_MICROS(MIN(ev.timestamp)), timezone)
                FROM UNNEST(events) ev) AS session_start_datetime,
        (SELECT MAX(CASE WHEN ev.name IN UNNEST(conversions)
            THEN 1 ELSE 0 END) = 1 FROM UNNEST(events) ev) AS is_converted_session,
        CASE WHEN source_medium = '(direct) / (none)'
            THEN true ELSE false END AS is_direct,
        ga4_sandbox.COUNT_EVENTS_IN_SESSION(events, conversions) AS conversions,
        ga4_sandbox.COUNT_EVENTS_IN_SESSION(events, ['page_view']) AS pageviews
        -- events
    FROM logs
);



BEGIN
    SELECT 
        visitor_id,
        session_id,
        session_start_datetime,
        conversions,
        pageviews,
        is_converted_session,
        source_medium,
        is_direct,
    FROM ga4_sandbox.get_ga4_table_for_attribution(
        start_date, end_date,
        timezone,
        data_durations_in_days,
        default_channel,
        required_event_names,
        conversion_event_names
    )
    WHERE visitor_id IN (
        '856962968.1652906170',
        '338107230.1641092154'
    )
    -- AND session_id IN ('1652906169', '1653310323')
    ORDER BY visitor_id, session_id ASC
;

EXCEPTION WHEN ERROR THEN
    # Get error informations
    SELECT
        @@error.message,
        @@error.stack_trace,
        @@error.statement_text,
        @@error.formatted_stack_trace;
END;
