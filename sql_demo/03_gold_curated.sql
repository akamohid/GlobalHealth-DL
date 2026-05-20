-- ============================================================
-- DS 312 Term Project: Healthcare Data Lake
-- Script 03: Gold Zone – Curated Analytics-Ready Outputs
-- ============================================================

USE HealthcareDL;
GO

-- ─────────────────────────────────────────────────────────────
-- GOLD VIEW 1: Country Health Profile (latest year)
-- Grain: one row per country
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('gold.vw_country_health_profile','V') IS NOT NULL DROP VIEW gold.vw_country_health_profile;
GO
CREATE VIEW gold.vw_country_health_profile AS
WITH latest AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY country_name ORDER BY year DESC
    ) AS rn
    FROM silver.who_health_indicators
)
SELECT
    country_name,
    status,
    year                AS latest_year,
    life_expectancy,
    adult_mortality,
    infant_deaths,
    under_five_deaths,
    gdp,
    schooling,
    income_composition,
    total_expenditure,
    hiv_aids,
    hepatitis_b,
    polio,
    diphtheria,
    alcohol,
    bmi
FROM latest WHERE rn = 1;
GO

-- ─────────────────────────────────────────────────────────────
-- GOLD VIEW 2: COVID-19 Country Summary
-- Grain: one row per country – peak figures + case fatality rate
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('gold.vw_covid_country_summary','V') IS NOT NULL DROP VIEW gold.vw_covid_country_summary;
GO
CREATE VIEW gold.vw_covid_country_summary AS
SELECT
    country_region,
    who_region,
    MIN(report_date)            AS first_report_date,
    MAX(report_date)            AS last_report_date,
    MAX(confirmed)              AS peak_confirmed,
    MAX(deaths)                 AS peak_deaths,
    MAX(recovered)              AS peak_recovered,
    CASE
        WHEN MAX(confirmed) > 0
        THEN ROUND(CAST(MAX(deaths) AS FLOAT) / MAX(confirmed) * 100, 3)
        ELSE NULL
    END                         AS case_fatality_rate_pct,
    COUNT(DISTINCT report_date) AS reporting_days
FROM silver.disease_outbreaks
GROUP BY country_region, who_region;
GO

-- ─────────────────────────────────────────────────────────────
-- GOLD VIEW 3: Hospital Beds Trend (2015 onwards)
-- Grain: one row per country + year
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('gold.vw_hospital_beds_trend','V') IS NOT NULL DROP VIEW gold.vw_hospital_beds_trend;
GO
CREATE VIEW gold.vw_hospital_beds_trend AS
SELECT
    hc.country_code,
    hc.country_name,
    hc.year,
    hc.hospital_beds_per1k,
    whi.status              AS development_status,
    whi.gdp                 AS gdp_per_capita
FROM silver.hospital_capacity hc
LEFT JOIN (
    SELECT DISTINCT country_name, status, gdp
    FROM silver.who_health_indicators
    WHERE year = (SELECT MAX(year) FROM silver.who_health_indicators w2
                  WHERE w2.country_name = silver.who_health_indicators.country_name)
) whi ON hc.country_name = whi.country_name;
GO

-- ─────────────────────────────────────────────────────────────
-- GOLD TABLE: Integrated Health Scorecard
-- Grain: one row per country – joins all 3 Silver datasets
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('gold.health_scorecard','U') IS NOT NULL DROP TABLE gold.health_scorecard;
GO
CREATE TABLE gold.health_scorecard (
    country_name              NVARCHAR(200) NOT NULL,
    development_status        NVARCHAR(20),

    -- From DS1: WHO Life Expectancy (latest year available)
    who_latest_year           SMALLINT,
    life_expectancy           FLOAT,        -- years
    adult_mortality           FLOAT,        -- per 1,000 (15-60 yrs)
    infant_deaths             INT,          -- per 1,000
    under_five_deaths         INT,          -- per 1,000
    gdp_per_capita            FLOAT,        -- USD
    schooling_years           FLOAT,
    income_composition        FLOAT,        -- HDI proxy (0-1)
    health_expenditure_pct    FLOAT,        -- % of total govt expenditure
    hiv_aids_deaths           FLOAT,
    hepatitis_b_pct           FLOAT,        -- immunisation %
    polio_pct                 FLOAT,
    diphtheria_pct            FLOAT,

    -- From DS3: World Bank hospital beds (latest year)
    hospital_beds_per1k       FLOAT,
    beds_latest_year          SMALLINT,

    -- From DS2: COVID-19 peak figures
    covid_peak_confirmed      BIGINT,
    covid_peak_deaths         BIGINT,
    covid_fatality_rate_pct   FLOAT,
    covid_who_region          NVARCHAR(200),

    -- Computed KPI
    health_risk_tier          NVARCHAR(20), -- Low / Medium / High Risk

    _gold_created             DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- Populate scorecard
WITH
who_latest AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY country_name ORDER BY year DESC) AS rn
    FROM silver.who_health_indicators
),
beds_latest AS (
    SELECT country_name, hospital_beds_per1k, year,
           ROW_NUMBER() OVER (PARTITION BY country_name ORDER BY year DESC) AS rn
    FROM silver.hospital_capacity
),
covid_agg AS (
    SELECT
        country_region,
        who_region,
        MAX(confirmed)  AS peak_confirmed,
        MAX(deaths)     AS peak_deaths,
        CASE WHEN MAX(confirmed) > 0
             THEN ROUND(CAST(MAX(deaths) AS FLOAT) / MAX(confirmed) * 100, 3)
             ELSE NULL END AS cfr
    FROM silver.disease_outbreaks
    GROUP BY country_region, who_region
)
INSERT INTO gold.health_scorecard (
    country_name, development_status,
    who_latest_year, life_expectancy, adult_mortality, infant_deaths, under_five_deaths,
    gdp_per_capita, schooling_years, income_composition, health_expenditure_pct,
    hiv_aids_deaths, hepatitis_b_pct, polio_pct, diphtheria_pct,
    hospital_beds_per1k, beds_latest_year,
    covid_peak_confirmed, covid_peak_deaths, covid_fatality_rate_pct, covid_who_region,
    health_risk_tier
)
SELECT
    w.country_name,
    w.status,
    w.year,
    w.life_expectancy,
    w.adult_mortality,
    w.infant_deaths,
    w.under_five_deaths,
    w.gdp,
    w.schooling,
    w.income_composition,
    w.total_expenditure,
    w.hiv_aids,
    w.hepatitis_b,
    w.polio,
    w.diphtheria,
    b.hospital_beds_per1k,
    b.year,
    c.peak_confirmed,
    c.peak_deaths,
    c.cfr,
    c.who_region,
    CASE
        WHEN w.life_expectancy >= 70 AND ISNULL(w.infant_deaths, 9999) < 50  THEN 'Low Risk'
        WHEN w.life_expectancy >= 60 AND ISNULL(w.infant_deaths, 9999) < 200 THEN 'Medium Risk'
        ELSE 'High Risk'
    END
FROM who_latest w
LEFT JOIN beds_latest b ON LOWER(TRIM(w.country_name)) = LOWER(TRIM(b.country_name)) AND b.rn = 1
LEFT JOIN covid_agg   c ON LOWER(TRIM(w.country_name)) = LOWER(TRIM(c.country_region))
WHERE w.rn = 1;

PRINT 'Gold health_scorecard populated: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows.';
GO

-- ─────────────────────────────────────────────────────────────
-- GOLD VERIFICATION
-- ─────────────────────────────────────────────────────────────
PRINT '=== GOLD ZONE VERIFICATION ===';
SELECT 'gold.health_scorecard'           AS gold_object, COUNT(*) AS rows FROM gold.health_scorecard
UNION ALL
SELECT 'gold.vw_country_health_profile',  COUNT(*) FROM gold.vw_country_health_profile
UNION ALL
SELECT 'gold.vw_covid_country_summary',   COUNT(*) FROM gold.vw_covid_country_summary
UNION ALL
SELECT 'gold.vw_hospital_beds_trend',     COUNT(*) FROM gold.vw_hospital_beds_trend;
GO

-- Sample output
SELECT
    country_name, development_status, who_latest_year,
    life_expectancy, infant_deaths, under_five_deaths,
    hospital_beds_per1k, covid_peak_confirmed, covid_peak_deaths,
    covid_fatality_rate_pct, health_risk_tier
FROM gold.health_scorecard
ORDER BY life_expectancy DESC;
GO

PRINT '=== FULL PIPELINE COMPLETE: Bronze -> Silver -> Gold ===';
GO
