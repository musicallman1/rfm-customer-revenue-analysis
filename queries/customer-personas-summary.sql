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
        MAX(InvoiceDate) AS last_order_date
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
),

RFM_scores AS (
    SELECT
        CONCAT(r_score, f_score, m_score) AS RFM_score,
        COUNT(CustomerID) AS n
    FROM RFM_2
    GROUP BY RFM_score
    ORDER BY n
)

SELECT
    CASE
        WHEN RFM_score = '444' THEN 'Champions'

        WHEN RFM_score LIKE '44_' OR RFM_score LIKE '43_'
          OR RFM_score LIKE '34_' OR RFM_score LIKE '33_'
          AND RFM_score != '331' THEN 'Loyal Customers'

        WHEN RFM_score LIKE '41_' THEN 'New Customers'

        WHEN RFM_score = '322' OR RFM_score = '313'
          OR RFM_score = '314' OR RFM_score = '331'
          OR RFM_score = '311' OR RFM_score = '312'
          OR RFM_score = '224' OR RFM_score = '242'
          OR RFM_score = '233' THEN 'Promising'

        WHEN RFM_score = '244' OR RFM_score LIKE '42_'
          OR RFM_score LIKE '32_' THEN 'Potential Loyalists'

        WHEN RFM_score LIKE '14_' OR RFM_score LIKE '13_'
          AND RFM_score != '131' THEN 'At Risk'

        WHEN RFM_score LIKE '2__'
          AND RFM_score != '244'
          AND RFM_score != '211'
          AND RFM_score != '224'
          AND RFM_score != '242'
          AND RFM_score != '233' THEN 'Needing Attention'

        WHEN RFM_score = '211' THEN 'About to Sleep'
        WHEN RFM_score = '111' THEN 'Lost'

        WHEN RFM_score = '131' OR RFM_score = '113'
          OR RFM_score = '122' OR RFM_score = '114'
          THEN 'Hibernating'

        ELSE 'Hibernating'
    END AS customer_persona,

    COUNT(RFM_score) AS persona_RFM_count,
    SUM(n) AS total_customers

FROM RFM_scores

GROUP BY customer_persona
ORDER BY total_customers DESC
