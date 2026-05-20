-- ============================================================
-- DS 312 Term Project: Healthcare Data Lake
-- Script 03: Gold Zone – FULL REAL DATASET
-- Works on complete Silver tables (193 countries, ~49k COVID rows)
-- ============================================================

USE DWBI_HealthCare;
GO

-- ─────────────────────────────────────────────────────────────
-- GOLD VIEW 1: Country Health Profile
-- Grain: one row per country (latest year available in DS1)
-- Covers all 193 countries from the full WHO dataset
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('gold.vw_country_health_profile','V') IS NOT NULL DROP VIEW gold.vw_country_health_profile;
GO
CREATE VIEW gold.vw_country_health_profile AS
WITH latest AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY country_name
               ORDER BY year DESC
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
    population,
    schooling,
    income_composition,
    total_expenditure,
    hiv_aids,
    hepatitis_b,
    polio,
    diphtheria,
    alcohol,
    bmi,
    pct_expenditure,
    measles,
    thinness_1_19_years,
    thinness_5_9_years
FROM latest WHERE rn = 1;
GO

-- ─────────────────────────────────────────────────────────────
-- GOLD VIEW 2: COVID-19 Country Summary
-- Grain: one row per country_region (peak figures)
-- Covers all countries in the COVID dataset
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('gold.vw_covid_country_summary','V') IS NOT NULL DROP VIEW gold.vw_covid_country_summary;
GO
CREATE VIEW gold.vw_covid_country_summary AS
SELECT
    country_region,
    who_region,
    MIN(report_date)            AS first_report_date,
    MAX(report_date)            AS last_report_date,
    DATEDIFF(DAY,
        MIN(report_date),
        MAX(report_date))       AS days_tracked,
    MAX(confirmed)              AS peak_confirmed,
    MAX(deaths)                 AS peak_deaths,
    MAX(recovered)              AS peak_recovered,
    MAX(active)                 AS peak_active,
    -- Case Fatality Rate
    CASE
        WHEN MAX(confirmed) > 0
        THEN ROUND(CAST(MAX(deaths) AS FLOAT) / MAX(confirmed) * 100, 4)
        ELSE NULL
    END                         AS case_fatality_rate_pct,
    -- Recovery Rate
    CASE
        WHEN MAX(confirmed) > 0
        THEN ROUND(CAST(MAX(recovered) AS FLOAT) / MAX(confirmed) * 100, 2)
        ELSE NULL
    END                         AS recovery_rate_pct,
    COUNT(DISTINCT report_date) AS reporting_days,
    COUNT(DISTINCT province_state) - 1 AS province_count  -- -1 for NULL (country-level)
FROM silver.disease_outbreaks
GROUP BY country_region, who_region;
GO

-- ─────────────────────────────────────────────────────────────
-- GOLD VIEW 3: Hospital Beds Trend (all years, all countries)
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
    whi.life_expectancy     AS life_expectancy_latest,
    whi.gdp                 AS gdp_latest,
    -- WHO threshold flag (10 beds per 10,000 = 1 per 1,000)
    CASE
        WHEN hc.hospital_beds_per1k >= 3.0 THEN 'Above WHO Recommended'
        WHEN hc.hospital_beds_per1k >= 1.0 THEN 'Near WHO Threshold'
        ELSE 'Below WHO Threshold'
    END                     AS capacity_tier
FROM silver.hospital_capacity hc
LEFT JOIN gold.vw_country_health_profile whi
    ON LOWER(TRIM(hc.country_name)) = LOWER(TRIM(whi.country_name));
GO

-- ─────────────────────────────────────────────────────────────
-- GOLD VIEW 4: WHO Region Summary
-- Grain: one row per WHO region (aggregated from DS2)
-- NEW: not in demo — only possible with full dataset
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('gold.vw_region_summary','V') IS NOT NULL DROP VIEW gold.vw_region_summary;
GO
CREATE VIEW gold.vw_region_summary AS
SELECT
    who_region,
    COUNT(DISTINCT country_region)  AS countries_in_region,
    SUM(MAX(confirmed))             OVER(PARTITION BY who_region) AS region_total_confirmed,
    SUM(MAX(deaths))                OVER(PARTITION BY who_region) AS region_total_deaths,
    AVG(CASE WHEN MAX(confirmed) > 0
        THEN CAST(MAX(deaths) AS FLOAT) / MAX(confirmed) * 100
        ELSE NULL END)              OVER(PARTITION BY who_region) AS avg_cfr_pct
FROM silver.disease_outbreaks
GROUP BY who_region, country_region;
GO

-- ─────────────────────────────────────────────────────────────
-- GOLD TABLE: Integrated Health Scorecard (FULL – all countries)
-- Grain: one row per country
-- Joins all 3 Silver datasets
-- Full dataset will have ~140-160 matched countries
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('gold.health_scorecard','U') IS NOT NULL DROP TABLE gold.health_scorecard;
GO
CREATE TABLE gold.health_scorecard (
    country_name              NVARCHAR(200) NOT NULL,
    development_status        NVARCHAR(20),

    -- DS1: WHO indicators (latest year)
    who_latest_year           SMALLINT,
    life_expectancy           FLOAT,
    adult_mortality           FLOAT,
    infant_deaths             INT,
    under_five_deaths         INT,
    population                BIGINT,
    gdp_per_capita            FLOAT,
    schooling_years           FLOAT,
    income_composition        FLOAT,
    health_expenditure_pct    FLOAT,
    hiv_aids_deaths           FLOAT,
    hepatitis_b_pct           FLOAT,
    polio_pct                 FLOAT,
    diphtheria_pct            FLOAT,
    bmi_avg                   FLOAT,
    alcohol_consumption       FLOAT,
    thinness_1_19_pct         FLOAT,

    -- DS3: Hospital beds (latest year in DS3)
    hospital_beds_per1k       FLOAT,
    beds_latest_year          SMALLINT,
    beds_capacity_tier        NVARCHAR(30),

    -- DS2: COVID-19 peak figures
    covid_peak_confirmed      BIGINT,
    covid_peak_deaths         BIGINT,
    covid_peak_recovered      BIGINT,
    covid_fatality_rate_pct   FLOAT,
    covid_recovery_rate_pct   FLOAT,
    covid_who_region          NVARCHAR(200),
    covid_days_tracked        INT,

    -- Computed KPIs
    health_risk_tier          NVARCHAR(20),
    -- Composite score (0-100, higher = better health)
    composite_health_score    FLOAT,

    _gold_created             DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_gold_scorecard PRIMARY KEY (country_name)
);
GO

-- ── Populate full scorecard ───────────────────────────────────
WITH
-- DS1: latest year per country
who_latest AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY country_name ORDER BY year DESC) AS rn
    FROM silver.who_health_indicators
),
-- DS3: latest beds reading per country
beds_latest AS (
    SELECT
        country_name,
        country_code,
        hospital_beds_per1k,
        year,
        CASE
            WHEN hospital_beds_per1k >= 3.0 THEN 'Above WHO Recommended'
            WHEN hospital_beds_per1k >= 1.0 THEN 'Near WHO Threshold'
            ELSE 'Below WHO Threshold'
        END AS capacity_tier,
        ROW_NUMBER() OVER (PARTITION BY country_name ORDER BY year DESC) AS rn
    FROM silver.hospital_capacity
),
-- DS2: peak COVID figures per country (country-level only, no province drill)
covid_agg AS (
    SELECT
        country_region,
        who_region,
        MAX(confirmed)  AS peak_confirmed,
        MAX(deaths)     AS peak_deaths,
        MAX(recovered)  AS peak_recovered,
        DATEDIFF(DAY, MIN(report_date), MAX(report_date)) AS days_tracked,
        CASE WHEN MAX(confirmed) > 0
             THEN ROUND(CAST(MAX(deaths) AS FLOAT) / MAX(confirmed) * 100, 4)
             ELSE NULL END AS cfr,
        CASE WHEN MAX(confirmed) > 0
             THEN ROUND(CAST(MAX(recovered) AS FLOAT) / MAX(confirmed) * 100, 2)
             ELSE NULL END AS recovery_rate
    FROM silver.disease_outbreaks
    GROUP BY country_region, who_region
)
INSERT INTO gold.health_scorecard (
    country_name, development_status,
    who_latest_year, life_expectancy, adult_mortality, infant_deaths, under_five_deaths,
    population, gdp_per_capita, schooling_years, income_composition, health_expenditure_pct,
    hiv_aids_deaths, hepatitis_b_pct, polio_pct, diphtheria_pct, bmi_avg,
    alcohol_consumption, thinness_1_19_pct,
    hospital_beds_per1k, beds_latest_year, beds_capacity_tier,
    covid_peak_confirmed, covid_peak_deaths, covid_peak_recovered,
    covid_fatality_rate_pct, covid_recovery_rate_pct, covid_who_region, covid_days_tracked,
    health_risk_tier, composite_health_score
)
SELECT
    w.country_name,
    w.status,
    w.year,
    w.life_expectancy,
    w.adult_mortality,
    w.infant_deaths,
    w.under_five_deaths,
    w.population,
    w.gdp,
    w.schooling,
    w.income_composition,
    w.total_expenditure,
    w.hiv_aids,
    w.hepatitis_b,
    w.polio,
    w.diphtheria,
    w.bmi,
    w.alcohol,
    w.thinness_1_19_years,
    b.hospital_beds_per1k,
    b.year,
    b.capacity_tier,
    c.peak_confirmed,
    c.peak_deaths,
    c.peak_recovered,
    c.cfr,
    c.recovery_rate,
    c.who_region,
    c.days_tracked,
    -- Risk tier classification
    CASE
        WHEN w.life_expectancy >= 70 AND ISNULL(w.infant_deaths, 9999) < 50  THEN 'Low Risk'
        WHEN w.life_expectancy >= 60 AND ISNULL(w.infant_deaths, 9999) < 200 THEN 'Medium Risk'
        ELSE 'High Risk'
    END,
    -- Composite health score (0-100 normalised)
    -- Higher is better. Weights: life_exp 40%, income_composition 30%, 1-hiv_aids 15%, immunisation 15%
    ROUND(
        ISNULL((w.life_expectancy / 90.0) * 40, 0) +
        ISNULL(w.income_composition * 30, 0) +
        ISNULL((1 - LEAST(w.hiv_aids / 10.0, 1)) * 15, 0) +
        ISNULL(((ISNULL(w.hepatitis_b,0) + ISNULL(w.polio,0) + ISNULL(w.diphtheria,0)) / 300.0) * 15, 0)
    , 2)
FROM who_latest w
LEFT JOIN beds_latest b
    ON LOWER(TRIM(w.country_name)) = LOWER(TRIM(b.country_name)) AND b.rn = 1
LEFT JOIN covid_agg c
    ON LOWER(TRIM(w.country_name)) = LOWER(TRIM(c.country_region))
WHERE w.rn = 1;

DECLARE @g INT; SELECT @g = COUNT(*) FROM gold.health_scorecard;
PRINT 'Gold health_scorecard populated: ' + CAST(@g AS NVARCHAR) + ' countries.';
GO

-- ─────────────────────────────────────────────────────────────
-- GOLD ANALYTICS QUERIES (run these to explore full dataset)
-- ─────────────────────────────────────────────────────────────

-- 1. Full gold verification
PRINT '=== GOLD OBJECT ROW COUNTS ===';
SELECT 'gold.health_scorecard'           AS gold_object, COUNT(*) AS rows FROM gold.health_scorecard
UNION ALL
SELECT 'gold.vw_country_health_profile',  COUNT(*) FROM gold.vw_country_health_profile
UNION ALL
SELECT 'gold.vw_covid_country_summary',   COUNT(*) FROM gold.vw_covid_country_summary
UNION ALL
SELECT 'gold.vw_hospital_beds_trend',     COUNT(*) FROM gold.vw_hospital_beds_trend
UNION ALL
SELECT 'gold.vw_region_summary',          COUNT(*) FROM gold.vw_region_summary;
GO

-- 2. Risk tier distribution across all 193 countries
PRINT '=== HEALTH RISK TIER DISTRIBUTION (all countries) ===';
SELECT
    health_risk_tier,
    COUNT(*) AS country_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_total,
    ROUND(AVG(life_expectancy), 1)     AS avg_life_exp,
    ROUND(AVG(gdp_per_capita), 0)      AS avg_gdp,
    ROUND(AVG(CAST(infant_deaths AS FLOAT)), 1) AS avg_infant_deaths
FROM gold.health_scorecard
GROUP BY health_risk_tier
ORDER BY country_count DESC;
GO

-- 3. Top 10 and Bottom 10 countries by life expectancy
PRINT '=== TOP 10 COUNTRIES BY LIFE EXPECTANCY ===';
SELECT TOP 10
    country_name, development_status, who_latest_year,
    life_expectancy, infant_deaths, hospital_beds_per1k,
    composite_health_score, health_risk_tier
FROM gold.health_scorecard
WHERE life_expectancy IS NOT NULL
ORDER BY life_expectancy DESC;

PRINT '=== BOTTOM 10 COUNTRIES BY LIFE EXPECTANCY ===';
SELECT TOP 10
    country_name, development_status, who_latest_year,
    life_expectancy, infant_deaths, hospital_beds_per1k,
    composite_health_score, health_risk_tier
FROM gold.health_scorecard
WHERE life_expectancy IS NOT NULL
ORDER BY life_expectancy ASC;
GO

-- 4. COVID burden: Top 15 countries by peak confirmed cases
PRINT '=== TOP 15 COVID-19 COUNTRIES BY PEAK CONFIRMED ===';
SELECT TOP 15
    country_region, who_region,
    peak_confirmed, peak_deaths,
    case_fatality_rate_pct, recovery_rate_pct,
    days_tracked
FROM gold.vw_covid_country_summary
WHERE peak_confirmed IS NOT NULL
ORDER BY peak_confirmed DESC;
GO

-- 5. Hospital capacity gap analysis (countries with < 1 bed per 1000)
PRINT '=== COUNTRIES WITH CRITICAL HOSPITAL BED SHORTAGE (< 1 per 1,000) ===';
SELECT
    s.country_name, s.development_status,
    s.hospital_beds_per1k, s.beds_latest_year,
    s.life_expectancy, s.infant_deaths, s.gdp_per_capita,
    s.health_risk_tier
FROM gold.health_scorecard s
WHERE s.hospital_beds_per1k < 1.0
  AND s.hospital_beds_per1k IS NOT NULL
ORDER BY s.hospital_beds_per1k ASC;
GO

-- 6. Composite health score ranking (all countries)
PRINT '=== COMPOSITE HEALTH SCORE RANKING (all countries) ===';
SELECT
    RANK() OVER (ORDER BY composite_health_score DESC) AS rank_no,
    country_name, development_status,
    life_expectancy, income_composition,
    hepatitis_b_pct, polio_pct,
    composite_health_score, health_risk_tier
FROM gold.health_scorecard
WHERE composite_health_score IS NOT NULL
ORDER BY composite_health_score DESC;
GO

-- 7. Developing vs Developed country comparison
PRINT '=== DEVELOPING vs DEVELOPED HEALTH COMPARISON ===';
SELECT
    status                                          AS development_status,
    COUNT(*)                                        AS country_count,
    ROUND(AVG(life_expectancy), 2)                  AS avg_life_expectancy,
    ROUND(AVG(CAST(infant_deaths AS FLOAT)), 1)     AS avg_infant_deaths,
    ROUND(AVG(gdp_per_capita), 0)                   AS avg_gdp_per_capita,
    ROUND(AVG(hospital_beds_per1k), 2)              AS avg_beds_per1k,
    ROUND(AVG(hepatitis_b_pct), 1)                  AS avg_hepb_coverage,
    ROUND(AVG(schooling_years), 1)                  AS avg_schooling_yrs
FROM gold.health_scorecard
WHERE status IS NOT NULL
GROUP BY status
ORDER BY avg_life_expectancy DESC;
GO

-- 8. High Risk countries needing intervention (full dataset)
PRINT '=== HIGH RISK COUNTRIES REQUIRING PRIORITY INTERVENTION ===';
SELECT
    country_name,
    development_status,
    life_expectancy,
    infant_deaths,
    under_five_deaths,
    hospital_beds_per1k,
    gdp_per_capita,
    hepatitis_b_pct,
    polio_pct,
    composite_health_score
FROM gold.health_scorecard
WHERE health_risk_tier = 'High Risk'
ORDER BY composite_health_score ASC;
GO

PRINT '=== FULL PIPELINE COMPLETE: Bronze -> Silver -> Gold ===';
PRINT 'All queries above run on complete real Kaggle datasets.';
GO
