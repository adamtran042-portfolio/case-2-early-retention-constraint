-- Case 2: Cohort retention by first purchase month
-- Purpose: Measure retention (% of cohort customers returning in later months)
-- Notes: Environment setup / ingestion omitted.

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

WITH cleaned AS (
    SELECT *
    FROM retention
    WHERE CustomerID IS NOT NULL
      -- Optional: uncomment if your dataset includes returns / invalid rows
      -- AND Quantity > 0
      -- AND UnitPrice > 0
),
cohort_table AS (
    -- First purchase month for each customer
    SELECT
        CustomerID,
        MIN(DATE_FORMAT(InvoiceDate, '%Y-%m-01')) AS cohort_month
    FROM cleaned
    GROUP BY CustomerID
),
cohort_indexed AS (
    -- Assign each invoice to a cohort and compute months since first purchase
    SELECT
        r.CustomerID,
        DATE_FORMAT(r.InvoiceDate, '%Y-%m-01') AS invoice_month,
        c.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            c.cohort_month,
            DATE_FORMAT(r.InvoiceDate, '%Y-%m-01')
        ) AS cohort_index
    FROM cleaned r
    JOIN cohort_table c
      ON r.CustomerID = c.CustomerID
),
cohort_counts AS (
    -- Unique customers active in each cohort month and index
    SELECT
        cohort_month,
        cohort_index,
        COUNT(DISTINCT CustomerID) AS users
    FROM cohort_indexed
    GROUP BY cohort_month, cohort_index
)
SELECT
    c1.cohort_month,
    c1.cohort_index,
    c1.users,
    ROUND(c1.users / c0.users * 100, 2) AS retention_percentage
FROM cohort_counts c1
JOIN cohort_counts c0
  ON c1.cohort_month = c0.cohort_month
 AND c0.cohort_index = 0
ORDER BY c1.cohort_month, c1.cohort_index;
