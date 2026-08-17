WITH Data_Time_Range AS (
    SELECT *
    FROM `tc-da-1.turing_data_analytics.rfm`
    WHERE InvoiceDate BETWEEN '2010-12-01' AND '2011-12-02'
),

Frequency_Monetary AS (
    SELECT
        CustomerID,
        Country,
        COUNT(DISTINCT InvoiceNo) AS frequency,
        SUM(UnitPrice * Quantity) AS monetary,
        MAX(InvoiceDate) AS last_order_date,
        MIN(InvoiceDate) AS cohort_date,
        SUM(Quantity) / COUNT(DISTINCT InvoiceNo) AS Quanity_order
    FROM Data_Time_Range dtr
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID, Country
    ORDER BY COUNT(DISTINCT InvoiceNo)
),

RFM_1 AS (
    SELECT
        *,
        TIMESTAMP_DIFF(
            TIMESTAMP('2011-12-02'),
            last_order_date,
            DAY
        ) AS recency
    FROM Frequency_Monetary
    WHERE monetary >= 0
),

Q_tiles AS (
    SELECT
        a.*,

        -- All percentiles for MONETARY
        b.percentiles[OFFSET(25)]  AS m25,
        b.percentiles[OFFSET(50)]  AS m50,
        b.percentiles[OFFSET(75)]  AS m75,
        b.percentiles[OFFSET(100)] AS m100,

        -- All percentiles for FREQUENCY
        c.percentiles[OFFSET(25)]  AS f25,
        c.percentiles[OFFSET(50)]  AS f50,
        c.percentiles[OFFSET(75)]  AS f75,
        c.percentiles[OFFSET(100)] AS f100,

        -- All percentiles for RECENCY
        d.percentiles[OFFSET(25)]  AS r25,
        d.percentiles[OFFSET(50)]  AS r50,
        d.percentiles[OFFSET(75)]  AS r75,
        d.percentiles[OFFSET(100)] AS r100
    FROM RFM_1 a,
         (SELECT APPROX_QUANTILES(monetary, 100)  AS percentiles FROM RFM_1) b,
         (SELECT APPROX_QUANTILES(frequency, 100) AS percentiles FROM RFM_1) c,
         (SELECT APPROX_QUANTILES(recency, 100)   AS percentiles FROM RFM_1) d
),

RFM_2 AS (
    SELECT
        *,
        CAST(ROUND((f_score + m_score) / 2, 0) AS INT64) AS fm_score
    FROM (
        SELECT
            *,

            CASE
                WHEN monetary <= m25                     THEN 1
                WHEN monetary <= m50 AND monetary > m25 THEN 2
                WHEN monetary <= m75 AND monetary > m50 THEN 3
                WHEN monetary <= m100 AND monetary > m75 THEN 4
            END AS m_score,

            CASE
                WHEN frequency <= f25                     THEN 1
                WHEN frequency <= f50 AND frequency > f25 THEN 2
                WHEN frequency <= f75 AND frequency > f50 THEN 3
                WHEN frequency <= f100 AND frequency > f75 THEN 4
            END AS f_score,

            -- Recency scoring is reversed
            CASE
                WHEN recency <= r25                     THEN 4
                WHEN recency <= r50 AND recency > r25 THEN 3
                WHEN recency <= r75 AND recency > r50 THEN 2
                WHEN recency <= r100 AND recency > r75 THEN 1
            END AS r_score

        FROM Q_tiles
    )
)

-- No self-join needed: RFM_2 already has r_score/f_score/m_score per
-- (CustomerID, Country), so RFM_score and persona are computed directly
-- here instead of joining back to a derived RFM_scores table (the
-- previous join-on-CustomerID-only version fanned out and mismatched
-- scores for customers with multiple country rows).
SELECT
    CustomerID,
    cohort_date,
    CAST(DATE_TRUNC(cohort_date, MONTH) AS DATETIME) AS cohort_month,
    Country,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    fm_score,
    CONCAT(r_score, f_score, m_score) AS RFM_score,
    ROUND(monetary / frequency, 2) AS AOV,
    ROUND(Quanity_order, 2) AS Quantity_per_order,

    CASE
        WHEN CONCAT(r_score, f_score, m_score) = '444' THEN 'Champions'

        WHEN CONCAT(r_score, f_score, m_score) LIKE '44_'
          OR CONCAT(r_score, f_score, m_score) LIKE '43_'
          OR CONCAT(r_score, f_score, m_score) LIKE '34_'
          OR CONCAT(r_score, f_score, m_score) LIKE '33_'
          AND CONCAT(r_score, f_score, m_score) != '331'
          THEN 'Loyal Customers'

        WHEN CONCAT(r_score, f_score, m_score) LIKE '41_' THEN 'New Customers'

        WHEN CONCAT(r_score, f_score, m_score) IN (
            '322', '313', '314', '331', '311', '312', '224', '242', '233'
        ) THEN 'Promising'

        WHEN CONCAT(r_score, f_score, m_score) = '244'
          OR CONCAT(r_score, f_score, m_score) LIKE '42_'
          OR CONCAT(r_score, f_score, m_score) LIKE '32_'
          THEN 'Potential Loyalists'

        WHEN CONCAT(r_score, f_score, m_score) LIKE '14_'
          OR CONCAT(r_score, f_score, m_score) LIKE '13_'
          AND CONCAT(r_score, f_score, m_score) != '131'
          THEN 'At Risk'

        WHEN CONCAT(r_score, f_score, m_score) LIKE '2__'
          AND CONCAT(r_score, f_score, m_score) NOT IN (
              '244', '211', '224', '242', '233'
          ) THEN 'Needing Attention'

        WHEN CONCAT(r_score, f_score, m_score) = '211' THEN 'About to Sleep'
        WHEN CONCAT(r_score, f_score, m_score) = '111' THEN 'Lost'

        WHEN CONCAT(r_score, f_score, m_score) IN ('131', '113', '122', '114')
          THEN 'Hibernating'

        ELSE 'Hibernating'
    END AS customer_persona

FROM RFM_2
