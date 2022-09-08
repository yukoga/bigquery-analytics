DECLARE attribution_table STRING DEFAULT 'traffic_sources';
DECLARE timezone STRING;
DECLARE data_durations_in_days INT64;
DECLARE data_end_date DATE;
DECLARE data_start_date DATE;
DECLARE end_date STRING;
DECLARE start_date STRING;

-- Configurations
SET timezone = 'Asia/Tokyo';
SET data_durations_in_days = 180;
SET data_end_date = CURRENT_DATE(timezone);
SET data_start_date = DATE_SUB(data_end_date, INTERVAL data_durations_in_days DAY);

-- Initialization
SET start_date = FORMAT_DATE('%y%m%d', data_start_date);
SET end_date = FORMAT_DATE('%y%m%d', data_end_date);

BEGIN
  WITH config AS (
      SELECT
          90 AS lookback  -- Lookback in days
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
              BETWEEN start_date 
              AND end_date
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

  SELECT * FROM attribution_table
  ORDER BY
    event_timestamp ASC
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
