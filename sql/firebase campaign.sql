SELECT
  *
FROM
    `adh-demo-data-review.analytics_213025502.events_*`
WHERE
    _TABLE_SUFFIX BETWEEN '20220501' AND '20220530'
    AND event_name = 'firebase_campaign'
