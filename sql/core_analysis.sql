-- ============================================================
-- Case 2 (MySQL): Cohort Retention + Revenue + ARPU + Country + Weekly
-- Base table: retention (InvoiceDate, Quantity, UnitPrice, CustomerID, Country)
-- Notes:
-- - Keep only valid rows (CustomerID not null; optionally Quantity/UnitPrice > 0)
-- - Revenue = Quantity * UnitPrice
-- - "Revenue retention (%)" is normalized to cohort index 0 revenue (per cohort).
-- - Month-1 retention by country is computed on top 5 countries by cohort size (index 0 users).
-- - Weekly cohort retention uses first purchase week as cohort anchor.
-- ============================================================


CREATE TABLE IF NOT EXISTS retention (
    InvoiceNo INT,
    StockCode VARCHAR(255),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate DATETIME NOT NULL,
    UnitPrice DECIMAL(10,2),
    CustomerID INT,
    Country VARCHAR(255)
)
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

/* ------------------------------------------------------------
0) Common cleaned base
------------------------------------------------------------ */
WITH cleaned AS (
    SELECT
        *,
        (Quantity * UnitPrice) AS amount
    FROM retention
    WHERE CustomerID IS NOT NULL
      AND InvoiceDate IS NOT NULL
      -- Recommended for the Online Retail dataset:
      AND Quantity > 0
      AND UnitPrice > 0
),

/* ------------------------------------------------------------
1) MONTHLY COHORT RETENTION (%)
   - First purchase month per customer
   - Cohort index = months since first purchase month
------------------------------------------------------------ */
cohort_month_table AS (
    SELECT
        CustomerID,
        MIN(DATE_FORMAT(InvoiceDate, '%Y-%m-01')) AS cohort_month
    FROM cleaned
    GROUP BY CustomerID
),
cohort_month_indexed AS (
    SELECT
        r.CustomerID,
        r.Country,
        DATE_FORMAT(r.InvoiceDate, '%Y-%m-01') AS invoice_month,
        c.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            c.cohort_month,
            DATE_FORMAT(r.InvoiceDate, '%Y-%m-01')
        ) AS cohort_index,
        r.amount
    FROM cleaned r
    JOIN cohort_month_table c
      ON r.CustomerID = c.CustomerID
),
cohort_month_users AS (
    SELECT
        cohort_month,
        cohort_index,
        COUNT(DISTINCT CustomerID) AS users
    FROM cohort_month_indexed
    GROUP BY cohort_month, cohort_index
)
SELECT
    u1.cohort_month,
    u1.cohort_index,
    u1.users,
    ROUND(u1.users / u0.users * 100, 2) AS retention_percentage
FROM cohort_month_users u1
JOIN cohort_month_users u0
  ON u1.cohort_month = u0.cohort_month
 AND u0.cohort_index = 0
ORDER BY u1.cohort_month, u1.cohort_index;


-- ============================================================
-- 2) MONTHLY REVENUE RETENTION (%) + AVG REVENUE PER RETAINED USER
--    Output grain: (cohort_month, cohort_index)
-- ============================================================

WITH cleaned AS (
    SELECT
        *,
        (Quantity * UnitPrice) AS amount
    FROM retention
    WHERE CustomerID IS NOT NULL
      AND InvoiceDate IS NOT NULL
      AND Quantity > 0
      AND UnitPrice > 0
),
cohort_month_table AS (
    SELECT
        CustomerID,
        MIN(DATE_FORMAT(InvoiceDate, '%Y-%m-01')) AS cohort_month
    FROM cleaned
    GROUP BY CustomerID
),
cohort_month_indexed AS (
    SELECT
        r.CustomerID,
        DATE_FORMAT(r.InvoiceDate, '%Y-%m-01') AS invoice_month,
        c.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            c.cohort_month,
            DATE_FORMAT(r.InvoiceDate, '%Y-%m-01')
        ) AS cohort_index,
        r.amount
    FROM cleaned r
    JOIN cohort_month_table c
      ON r.CustomerID = c.CustomerID
),
cohort_month_users AS (
    SELECT
        cohort_month,
        cohort_index,
        COUNT(DISTINCT CustomerID) AS users
    FROM cohort_month_indexed
    GROUP BY cohort_month, cohort_index
),
cohort_month_revenue AS (
    SELECT
        cohort_month,
        cohort_index,
        SUM(amount) AS revenue
    FROM cohort_month_indexed
    GROUP BY cohort_month, cohort_index
),
cohort_month_joined AS (
    SELECT
        u.cohort_month,
        u.cohort_index,
        u.users,
        r.revenue
    FROM cohort_month_users u
    JOIN cohort_month_revenue r
      ON u.cohort_month = r.cohort_month
     AND u.cohort_index = r.cohort_index
),
month0 AS (
    SELECT
        cohort_month,
        users   AS users_m0,
        revenue AS revenue_m0
    FROM cohort_month_joined
    WHERE cohort_index = 0
)
SELECT
    j.cohort_month,
    j.cohort_index,
    j.users AS active_users,
    j.revenue,
    ROUND(j.users / m.users_m0 * 100, 2) AS customer_retention_pct,
    ROUND(j.revenue / NULLIF(m.revenue_m0, 0) * 100, 2) AS revenue_retention_pct,
    ROUND(j.revenue / NULLIF(j.users, 0), 2) AS avg_revenue_per_retained_user
FROM cohort_month_joined j
JOIN month0 m
  ON j.cohort_month = m.cohort_month
ORDER BY j.cohort_month, j.cohort_index;


-- ============================================================
-- 3) MONTH-1 RETENTION (%) BY TOP 5 COUNTRIES
--    Definition:
--    - Cohort anchored by first purchase month (same as above)
--    - Month-1 retention for a country = users at cohort_index=1 / users at cohort_index=0
--    - Top 5 countries chosen by total month-0 users (cohort size)
-- ============================================================

WITH cleaned AS (
    SELECT
        *,
        (Quantity * UnitPrice) AS amount
    FROM retention
    WHERE CustomerID IS NOT NULL
      AND InvoiceDate IS NOT NULL
      AND Quantity > 0
      AND UnitPrice > 0
),
cohort_month_table AS (
    SELECT
        CustomerID,
        MIN(DATE_FORMAT(InvoiceDate, '%Y-%m-01')) AS cohort_month
    FROM cleaned
    GROUP BY CustomerID
),
-- Assign each customer a "home country" for segmentation.
-- Approach: use the country from their first purchase record.
first_purchase_country AS (
    SELECT
        x.CustomerID,
        x.Country
    FROM (
        SELECT
            r.CustomerID,
            r.Country,
            r.InvoiceDate,
            ROW_NUMBER() OVER (PARTITION BY r.CustomerID ORDER BY r.InvoiceDate) AS rn
        FROM cleaned r
    ) x
    WHERE x.rn = 1
),
cohort_month_indexed AS (
    SELECT
        r.CustomerID,
        fpc.Country,
        c.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            c.cohort_month,
            DATE_FORMAT(r.InvoiceDate, '%Y-%m-01')
        ) AS cohort_index
    FROM cleaned r
    JOIN cohort_month_table c
      ON r.CustomerID = c.CustomerID
    JOIN first_purchase_country fpc
      ON r.CustomerID = fpc.CustomerID
),
country_cohort_counts AS (
    SELECT
        Country,
        cohort_month,
        cohort_index,
        COUNT(DISTINCT CustomerID) AS users
    FROM cohort_month_indexed
    GROUP BY Country, cohort_month, cohort_index
),
country_month0_size AS (
    SELECT
        Country,
        SUM(users) AS total_month0_users
    FROM country_cohort_counts
    WHERE cohort_index = 0
    GROUP BY Country
),
top5_countries AS (
    SELECT Country
    FROM country_month0_size
    ORDER BY total_month0_users DESC
    LIMIT 5
),
country_m0_m1 AS (
    SELECT
        c.Country,
        SUM(CASE WHEN c.cohort_index = 0 THEN c.users ELSE 0 END) AS users_m0,
        SUM(CASE WHEN c.cohort_index = 1 THEN c.users ELSE 0 END) AS users_m1
    FROM country_cohort_counts c
    JOIN top5_countries t
      ON c.Country = t.Country
    GROUP BY c.Country
)
SELECT
    Country,
    users_m0 AS month0_users,
    users_m1 AS month1_users,
    ROUND(users_m1 / NULLIF(users_m0, 0) * 100, 2) AS month1_retention_pct
FROM country_m0_m1
ORDER BY month1_retention_pct DESC;


-- ============================================================
-- 4) WEEKLY COHORT RETENTION (%)
--    Cohort anchor: first purchase week (week start)
--    Cohort index: weeks since first purchase week
--    Output grain: (cohort_week, cohort_week_index)
-- ============================================================

WITH cleaned AS (
    SELECT
        *,
        (Quantity * UnitPrice) AS amount
    FROM retention
    WHERE CustomerID IS NOT NULL
      AND InvoiceDate IS NOT NULL
      AND Quantity > 0
      AND UnitPrice > 0
),
cohort_week_table AS (
    -- Monday week start. If your business uses Sunday start, adjust accordingly.
    SELECT
        CustomerID,
        MIN(DATE_SUB(DATE(InvoiceDate), INTERVAL WEEKDAY(InvoiceDate) DAY)) AS cohort_week_start
    FROM cleaned
    GROUP BY CustomerID
),
weekly_indexed AS (
    SELECT
        r.CustomerID,
        DATE_SUB(DATE(r.InvoiceDate), INTERVAL WEEKDAY(r.InvoiceDate) DAY) AS invoice_week_start,
        c.cohort_week_start,
        TIMESTAMPDIFF(
            WEEK,
            c.cohort_week_start,
            DATE_SUB(DATE(r.InvoiceDate), INTERVAL WEEKDAY(r.InvoiceDate) DAY)
        ) AS cohort_week_index
    FROM cleaned r
    JOIN cohort_week_table c
      ON r.CustomerID = c.CustomerID
),
weekly_counts AS (
    SELECT
        cohort_week_start,
        cohort_week_index,
        COUNT(DISTINCT CustomerID) AS users
    FROM weekly_indexed
    GROUP BY cohort_week_start, cohort_week_index
)
SELECT
    w1.cohort_week_start,
    w1.cohort_week_index,
    w1.users,
    ROUND(w1.users / w0.users * 100, 2) AS weekly_retention_pct
FROM weekly_counts w1
JOIN weekly_counts w0
  ON w1.cohort_week_start = w0.cohort_week_start
 AND w0.cohort_week_index = 0
ORDER BY w1.cohort_week_start, w1.cohort_week_index;
