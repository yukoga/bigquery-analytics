-- aWQ9R1RNLUs3NDJaQlomZW52PTEmYXV0aD1CNUJnVHlkbURzREtnTC1EU1RqcG5n


SQL="""
WITH config AS (
  SELECT
    {lookback} AS lookback
    , '{start_date}' AS startDate
    , '{end_date}' AS endDate
    , '{start_channel}' AS startChannel
    , '{converted_channel}' AS convertedChannel
    , '{not_converted_channel}' AS notConvertedChannel
)
, base AS (
  SELECT
    fullVisitorId AS visitorId
    , visitStartTime AS interactionId
    , FORMAT_TIMESTAMP(
      "%Y-%m-%d %T"
      , TIMESTAMP_MILLIS(visitStartTime*1000)
      , "Asia/Tokyo"
    ) AS interactionDate
    , IF(trafficSource.isTrueDirect = true
        ,'direct'
        , IF(trafficSource.medium = '(none)'
            , 'direct'
            , trafficSource.medium
        )
    ) AS channel
    , IF(totals.transactions > 0, 1, 0) AS label
  FROM
    `{data_project}.{dataset}.ga_sessions_20*`
  WHERE
    _TABLE_SUFFIX BETWEEN
      (SELECT startDate FROM config)
    AND 
      (SELECT endDate FROM config)
), logs_in_lookback AS (
  SELECT
    *
  FROM (
    SELECT
      visitorId
      , interactionId
      , interactionDate
      , LAST_VALUE(interactionDate)
          OVER (PARTITION BY visitorId ORDER BY interactionId
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
          ) AS lastInteractionDate
      , DATETIME_DIFF(
          CAST(
            LAST_VALUE(interactionDate)
              OVER (PARTITION BY visitorId ORDER BY interactionId
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
          AS DATETIME)
          , CAST(interactionDate AS DATETIME)
          , DAY
      ) AS interactionDaysDiff
      , channel
      , label
    FROM base
  )
  WHERE
    interactionDaysDiff < (SELECT lookback FROM config) + 1
), multi_channels AS (
  SELECT
    visitorId
    , pathId
    , CONCAT(visitorId, CAST(pathId AS STRING)) AS visitorPathId 
    , interactionId
    , channel
    , label
    , SUM(label)
        OVER (
          PARTITION BY visitorId, pathId ORDER BY interactionId
          ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        )
      AS isConverted
  FROM (
    SELECT
      visitorId
      , interactionId
      , channel
      , label
      , SUM(laggedLabel)
          OVER (
            PARTITION BY visitorId ORDER BY interactionId
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
          ) AS pathId
    FROM (
      SELECT
        visitorId
        , interactionId
        , channel
        , label
        , IF(LAG(label)
              OVER (PARTITION BY visitorId ORDER BY interactionId)
            IS NULL
            , 0
            , LAG(label)
                OVER (PARTITION BY visitorId ORDER BY interactionId)
        ) AS laggedLabel
      FROM logs_in_lookback
    )
  )
), mcf_paths AS (
  SELECT
    visitorPathId
    , STRING_AGG(channel, ' > ') AS path
    , isConverted
  FROM multi_channels
  GROUP BY
    visitorPathId, isConverted
)

SELECT
  visitorPathId
  , path
  , IF(isConverted = 1
      , CONCAT('(start) > ', path, ' > (converted)')
      , CONCAT('(start) > ', path, ' > (not converted)')
  ) AS v_path
  , isConverted
  , IF(isConverted = 1, 1, 0) AS conversions
  , IF(isConverted = 0, 1, 0) AS not_conversions
  , ARRAY_LENGTH(SPLIT(path, ' > ')) AS path_length
  , IF(isConverted = 1, 1, 0) / ARRAY_LENGTH(SPLIT(path, ' > ')) AS linear_alloc
FROM mcf_paths
""".format(
    lookback=config['lookback']
    , start_date=config['start_date']
    , end_date=config['end_date']
    , data_project=config['data_project']
    , dataset=config['dataset']
    , start_channel=config['start_channel']
    , converted_channel=config['converted_channel']
    , not_converted_channel=config['not_converted_channel']
)
