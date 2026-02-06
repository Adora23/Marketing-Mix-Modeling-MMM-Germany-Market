-- --------------------------------------------------
-- Staging layer: raw ingestion of e-commerce data
-- No transformations applied
-- --------------------------------------------------

CREATE TABLE stg_online_retail_raw (
    invoiceno      TEXT,
    stockcode      TEXT,
    description    TEXT,
    quantity       INTEGER,
    invoicedate    TIMESTAMP,
    unitprice      NUMERIC(10,2),
    customerid     TEXT,
    country        TEXT
);

-- Normalize country values for Germany only.
-- Other countries are left untouched to preserve source fidelity

CREATE OR REPLACE VIEW vw_retail_germany_normalized AS
SELECT
    invoiceno,
    stockcode,
    description,
    quantity,
    invoicedate,
    unitprice,
    customerid,

    CASE
        WHEN country IN ('GER', 'DE', 'Deutschland', 'Germany ') THEN 'Germany'
        ELSE country
    END AS country_normalized

FROM stg_online_retail_raw;


CREATE OR REPLACE VIEW vw_retail_germany_only AS
SELECT *
FROM vw_retail_germany_normalized
WHERE country_normalized = 'Germany';

-- --------------------------------------------------
-- Germany-only cleaned transaction layer.
-- Removes invalid invoices, zero or negative prices, missing timestamps,
-- and corrupted invoice numbers while preserving returns (negative quantities).
-- Prepares data for reliable revenue calculation and MMM aggregation.
-- --------------------------------------------------

CREATE OR REPLACE VIEW vw_retail_germany_cleaned AS
SELECT
    invoiceno,
    stockcode,
    description,

    quantity,
    unitprice,

    (quantity * unitprice) AS revenue,

    invoicedate,
    customerid

FROM vw_retail_germany_only
WHERE
    invoicedate IS NOT NULL
    AND unitprice > 0
    AND quantity <> 0
    AND invoiceno ~ '^[0-9]+$';

-- Remove exact duplicate transaction rows while preserving valid revenue records.
-- Deduplication is based on invoice, product, quantity, price, and timestamp
-- to avoid double-counting caused by system re-exports or ingestion errors.

CREATE OR REPLACE VIEW vw_retail_germany_deduplicated AS
SELECT DISTINCT ON (
    invoiceno,
    stockcode,
    quantity,
    unitprice,
    invoicedate
)
    *
FROM vw_retail_germany_cleaned
ORDER BY
    invoiceno,
    stockcode,
    invoicedate;
	
-- Aggregate cleaned German transaction data to a weekly grain for Marketing Mix Modeling (MMM).
-- Produces core business metrics (revenue, orders, customers) aligned to marketing spend
-- and campaign cadence, enabling time-series analysis and budget optimization.

CREATE OR REPLACE VIEW vw_mmm_germany_weekly_revenue AS
SELECT
    DATE_TRUNC('week', invoicedate)::DATE AS week_start,
    SUM(revenue) AS weekly_revenue,
    COUNT(DISTINCT invoiceno) AS orders,
    COUNT(DISTINCT customerid) AS customers
FROM vw_retail_germany_deduplicated
GROUP BY 1
ORDER BY 1;

-- --------------------------------------------------
-- Mock Google Ads spend staging table
-- --------------------------------------------------
-- This script creates and populates a simulated Google Ads spend dataset
-- aligned to the invoice date range of the retail transactions.
-- Daily spend values are generated to mimic realistic marketing behavior,
-- including higher spend during peak seasonal months (November–December).
-- The resulting table supports weekly aggregation and Marketing Mix Modeling (MMM)
-- when real platform spend data is unavailable.
-- --------------------------------------------------

CREATE TABLE stg_google_ads (
    date DATE,
    spend NUMERIC(12,2)
);

INSERT INTO stg_google_ads (date, spend)
SELECT
    d::DATE,
    ROUND(
        (
            CASE
                WHEN EXTRACT(MONTH FROM d) IN (11,12)
                    THEN RANDOM() * 8000 + 3000  -- holiday uplift
                ELSE RANDOM() * 4000 + 1000
            END
        )::NUMERIC
    , 2)
FROM generate_series(
    (SELECT MIN(invoicedate)::DATE FROM stg_online_retail_raw),
    (SELECT MAX(invoicedate)::DATE FROM stg_online_retail_raw),
    INTERVAL '1 day'
) d;

CREATE OR REPLACE VIEW vw_google_ads_weekly AS
SELECT
    DATE_TRUNC('week', date)::DATE AS week_start,
    SUM(spend) AS google_ads_spend
FROM stg_google_ads
GROUP BY 1
ORDER BY 1;

-- --------------------------------------------------
-- Mock Meta Ads spend staging table
-- --------------------------------------------------
-- Generates simulated daily Meta (Facebook/Instagram) ad spend aligned
-- to the retail invoice date range, with increased spend during
-- peak seasonal months (November–December).
-- --------------------------------------------------
CREATE TABLE stg_meta_ads (
    date DATE,
    spend NUMERIC(12,2)
);

INSERT INTO stg_meta_ads (date, spend)
SELECT
    d::DATE,
    ROUND(
        (
            CASE
                WHEN EXTRACT(MONTH FROM d) IN (11,12)
                    THEN RANDOM() * 6000 + 2000  -- holiday uplift
                ELSE RANDOM() * 3000 + 800
            END
        )::NUMERIC
    , 2)
FROM generate_series(
    (SELECT MIN(invoicedate)::DATE FROM stg_online_retail_raw),
    (SELECT MAX(invoicedate)::DATE FROM stg_online_retail_raw),
    INTERVAL '1 day'
) d;

CREATE OR REPLACE VIEW vw_meta_ads_weekly AS
SELECT
    DATE_TRUNC('week', date)::DATE AS week_start,
    SUM(spend) AS meta_ads_spend
FROM stg_meta_ads
GROUP BY 1
ORDER BY 1;

-- --------------------------------------------------
-- Mock daily Email volume staging table
-- --------------------------------------------------
-- Generates simulated daily email sends aligned with the
-- retail invoice date range. Higher email volumes are
-- created for peak seasonal months (November–December).
-- --------------------------------------------------
CREATE TABLE stg_email_campaigns (
    send_date DATE,
    emails_sent INTEGER
);

INSERT INTO stg_email_campaigns (send_date, emails_sent)
SELECT
    d::DATE,
    CASE
        WHEN EXTRACT(MONTH FROM d) IN (11,12)
            THEN FLOOR(RANDOM() * 8000 + 2000)::INTEGER  -- holiday uplift
        ELSE FLOOR(RANDOM() * 4000 + 500)::INTEGER
    END
FROM generate_series(
    (SELECT MIN(invoicedate)::DATE FROM stg_online_retail_raw),
    (SELECT MAX(invoicedate)::DATE FROM stg_online_retail_raw),
    INTERVAL '1 day'
) d;

-- Aggregates daily Email volume to a weekly grai
CREATE OR REPLACE VIEW vw_email_weekly AS
SELECT
    DATE_TRUNC('week', send_date)::DATE AS week_start,
    SUM(emails_sent) AS email_volume
FROM stg_email_campaigns
GROUP BY 1
ORDER BY 1;

-- --------------------------------------------------
-- Staging table for mock promotions
-- --------------------------------------------------
CREATE TABLE stg_promotions (
    promo_name TEXT,
    start_date DATE,
    end_date DATE
);
INSERT INTO stg_promotions (promo_name, start_date, end_date)
VALUES
    ('Black Friday', '2009-11-20', '2009-11-26'),
    ('Christmas Sale', '2010-12-18', '2010-12-31'),
    ('Summer Sale', '2010-07-10', '2010-07-16');

-- --------------------------------------------------
-- Expand promotions to daily flags
-- --------------------------------------------------
CREATE OR REPLACE VIEW vw_promotions_daily AS
SELECT DISTINCT
    d::DATE AS promo_date,
    1 AS promo_flag
FROM stg_promotions p
CROSS JOIN LATERAL generate_series(
    p.start_date,
    p.end_date,
    INTERVAL '1 day'
) d;

-- --------------------------------------------------
-- Aggregate daily promo flags to weekly
-- --------------------------------------------------
CREATE OR REPLACE VIEW vw_promotions_weekly AS
SELECT
    DATE_TRUNC('week', promo_date)::DATE AS week_start,
    MAX(promo_flag) AS promo_flag   -- 1 if any day in the week has a promo
FROM vw_promotions_daily
GROUP BY 1
ORDER BY 1;

-- --------------------------------------------------
-- Seasonality feature engineering for MMM
-- --------------------------------------------------
-- This query derives basic calendar-based seasonality variables from the
-- weekly revenue date (`week_start`) to support Marketing Mix Modeling (MMM).
-- These features capture recurring temporal patterns such as month-of-year,
-- holiday periods, and Q4 effects, helping the model distinguish natural
-- seasonal demand from marketing-driven performance.
-- --------------------------------------------------
SELECT
    r.week_start,

    -- Seasonality variables
    EXTRACT(WEEK FROM r.week_start)::SMALLINT  AS week_of_year,
    EXTRACT(MONTH FROM r.week_start)::SMALLINT AS month,
    EXTRACT(YEAR FROM r.week_start)::SMALLINT  AS year,

    CASE
        WHEN EXTRACT(MONTH FROM r.week_start) IN (11,12)
        THEN 1 ELSE 0
    END AS is_holiday_season,

    CASE
        WHEN EXTRACT(MONTH FROM r.week_start) IN (10,11,12)
        THEN 1 ELSE 0
    END AS is_q4
FROM vw_mmm_germany_weekly_revenue r;

-- --------------------------------------------------
-- Final model-ready dataset for Marketing Mix Modeling (MMM)
-- --------------------------------------------------
-- This view consolidates all weekly revenue, marketing spend,
-- email volume, promotions, and seasonality controls into a single
-- dataset ready for Marketing Mix Modeling.
--
-- Missing values in marketing channels or promo flags are filled with 0.
-- Seasonality variables are derived inline from the week_start date.
-- --------------------------------------------------

CREATE OR REPLACE VIEW vw_mmm_germany_model_input AS
SELECT
    r.week_start,

    -- Target variables
    r.weekly_revenue,
    r.orders,
    r.customers,

    -- Marketing channels
    COALESCE(g.weekly_google_spend, 0) AS google_ads_sp,
    COALESCE(m.weekly_meta_spend, 0)   AS meta_spend,
    COALESCE(e.weekly_email_volume, 0) AS email_volume,

    -- Promotions
    COALESCE(p.promo_flag, 0) AS promo_flag,

    -- Seasonality controls (inline derivation)
    EXTRACT(WEEK FROM r.week_start)::SMALLINT  AS week_of_year,
    EXTRACT(MONTH FROM r.week_start)::SMALLINT AS month,
    EXTRACT(YEAR FROM r.week_start)::SMALLINT  AS year,
    CASE WHEN EXTRACT(MONTH FROM r.week_start) IN (11,12) THEN 1 ELSE 0 END AS is_holiday_season,
    CASE WHEN EXTRACT(MONTH FROM r.week_start) IN (10,11,12) THEN 1 ELSE 0 END AS is_q4

FROM vw_mmm_germany_weekly_revenue r

-- Marketing channels
LEFT JOIN vw_google_ads_weekly g
    ON r.week_start = g.week_start

LEFT JOIN vw_meta_ads_weekly m
    ON r.week_start = m.week_start

LEFT JOIN vw_email_weekly e
    ON r.week_start = e.week_start

-- Promotions
LEFT JOIN vw_promotions_weekly p
    ON r.week_start = p.week_start

ORDER BY r.week_start;


