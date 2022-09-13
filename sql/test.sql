DECLARE name STRING DEFAULT 'hoge';
DECLARE table_name STRING DEFAULT 'temp';


DECLARE timezone STRING;
DECLARE data_durations_in_days INT64;
DECLARE data_end_date DATE;
DECLARE data_start_date DATE;
DECLARE end_date STRING;
DECLARE start_date STRING;
DECLARE conversion_event_names ARRAY <STRING>;
DECLARE default_channel STRING;

-- Configurations
SET timezone = 'Asia/Tokyo';
SET data_durations_in_days = 180;
SET data_end_date = CURRENT_DATE(timezone);
SET data_start_date = DATE_SUB(data_end_date, INTERVAL data_durations_in_days DAY);
SET conversion_event_names = ['purchase', 'in_app_purchase'];
SET default_channel = '(direct) / (none)';

-- Initialization
SET start_date = FORMAT_DATE('%y%m%d', data_start_date);
SET end_date = FORMAT_DATE('%y%m%d', data_end_date);


BEGIN
CREATE TEMP FUNCTION get_my_tables(dataset STRING, start_date STRING, end_date STRING)
RETURNS ANY
AS (
    SELECT * FROM 
);

END;

    SELECT event_date,
        event_timestamp,
        MAX(CASE WHEN ev_params.key = 'ga_session_id'     THEN ev_params.value.int_value    END) AS session_id,
        event_name,
        MAX(CASE WHEN ev_params.key = 'event_source'      THEN ev_params.value.string_value END) AS event_source,
        MAX(CASE WHEN ev_params.key = 'event_medium'      THEN ev_params.value.string_value END) AS event_medium,
        traffic_source.source AS user_source,
        traffic_source.medium AS user_medium,
    FROM
        `adh-demo-data-review.analytics_213025502.events_20*`,
        UNNEST(event_params) AS ev_params
    WHERE
        _TABLE_SUFFIX BETWEEN start_date AND end_date
        AND
        user_pseudo_id IN (
            '856962968.1652906170'
        )
        AND event_name IN UNNEST(conversion_event_names) OR event_name = 'page_view'
    GROUP BY event_date, event_timestamp, event_name, user_source, user_medium
    ORDER BY event_timestamp;
END;

    SELECT 
    *
    FROM (
        SELECT 
            FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP_MICROS(event_timestamp), timezone) AS event_date,
            FORMAT_TIMESTAMP('%Y%m%d %H:%M:%S', TIMESTAMP_MICROS(event_timestamp), timezone) AS event_time,
            event_timestamp,
            user_pseudo_id AS visitor_id,
            MAX(CASE WHEN ev_params.key = 'ga_session_id'     THEN ev_params.value.int_value    END) AS session_id,
            event_name,
            SUM(CASE WHEN event_name = 'page_view' THEN 1 ELSE 0 END) AS pageviews,
            SUM(CASE WHEN event_name IN UNNEST(conversion_event_names) THEN 1 ELSE 0 END) AS conversions,
            CONCAT(user_pseudo_id,
                '_',
                CAST(MAX(CASE WHEN ev_params.key = 'ga_session_id' THEN ev_params.value.int_value END) AS STRING),
                '_',
                CAST(event_timestamp AS STRING)) AS event_id,
            MAX(CASE WHEN ev_params.key = 'event_source'      THEN ev_params.value.string_value END) AS event_source,
            MAX(CASE WHEN ev_params.key = 'event_medium'      THEN ev_params.value.string_value END) AS event_medium,
            traffic_source.source AS user_source,
            traffic_source.medium AS user_medium,
            MAX(CASE WHEN ev_params.key = 'ga_session_number' THEN ev_params.value.int_value    END) AS session_number,
            MAX(CASE WHEN ev_params.key = 'page_location'     THEN ev_params.value.string_value END) AS page_location,
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
    )
    WHERE 
        -- event_name = 'page_view'
        -- OR 
        event_name IN UNNEST(conversion_event_names)
        AND visitor_id IN (
            '856962968.1652906170'
        )
    ORDER BY visitor_id, event_timestamp ASC
;

EXCEPTION WHEN ERROR THEN
    SELECT
        @@error.message,
        @@error.stack_trace,
        @@error.statement_text,
        @@error.formatted_stack_trace;
END;
