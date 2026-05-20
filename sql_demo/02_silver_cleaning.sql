-- ============================================================
-- DS 312 Term Project: Healthcare Data Lake
-- Script 02: Silver Zone – Cleaning, Quality Gates & Rejects
-- ============================================================

USE HealthcareDL;
GO

-- ─────────────────────────────────────────────────────────────
-- QUARANTINE TABLE  (all QG failures land here)
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('quarantine.rejected_rows','U') IS NOT NULL DROP TABLE quarantine.rejected_rows;
GO
CREATE TABLE quarantine.rejected_rows (
    reject_id     INT IDENTITY(1,1) PRIMARY KEY,
    source_table  NVARCHAR(200) NOT NULL,
    reason_code   NVARCHAR(10)  NOT NULL,   -- QG-001 … QG-005
    reject_reason NVARCHAR(500) NOT NULL,
    raw_snapshot  NVARCHAR(MAX),            -- key field dump of the bad row
    rejected_at   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
PRINT 'Quarantine table created.';
GO

-- ═════════════════════════════════════════════════════════════
-- SILVER TABLE 1: who_health_indicators
-- Source columns: 22 NVARCHAR → properly typed Silver columns
-- ═════════════════════════════════════════════════════════════
IF OBJECT_ID('silver.who_health_indicators','U') IS NOT NULL DROP TABLE silver.who_health_indicators;
GO
CREATE TABLE silver.who_health_indicators (
    -- Properly typed equivalents of all 22 source columns
    country_name          NVARCHAR(200) NOT NULL,
    year                  SMALLINT      NOT NULL,
    status                NVARCHAR(20),              -- 'Developed' or 'Developing'
    life_expectancy       FLOAT,                     -- years
    adult_mortality       FLOAT,                     -- per 1,000 population (15-60 yrs)
    infant_deaths         INT,                       -- per 1,000 population
    alcohol               FLOAT,                     -- litres of pure alcohol per capita
    pct_expenditure       FLOAT,                     -- health exp % of GDP per capita
    hepatitis_b           FLOAT,                     -- immunisation coverage % (1-yr-olds)
    measles               INT,                       -- reported cases per 1,000
    bmi                   FLOAT,                     -- average BMI
    under_five_deaths     INT,                       -- per 1,000 population
    polio                 FLOAT,                     -- immunisation coverage %
    total_expenditure     FLOAT,                     -- govt health exp % of total govt exp
    diphtheria            FLOAT,                     -- immunisation coverage %
    hiv_aids              FLOAT,                     -- deaths per 1,000 (0-4 yr olds)
    gdp                   FLOAT,                     -- GDP per capita (USD)
    population            BIGINT,
    thinness_1_19_years   FLOAT,                     -- prevalence % (10-19 yrs)
    thinness_5_9_years    FLOAT,                     -- prevalence % (5-9 yrs)
    income_composition    FLOAT,                     -- Human Development Index (0-1)
    schooling             FLOAT,                     -- avg years of schooling
    _silver_loaded        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- QG-001a: Empty or NULL Country
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.who_health_indicators','QG-001',
       'Country is NULL or empty string – primary geographic key missing',
       CONCAT('Country=[',ISNULL(Country,'NULL'),'] | Year=[',ISNULL(Year,'NULL'),']')
FROM bronze.who_health_indicators
WHERE NULLIF(TRIM(ISNULL(Country,'')),'') IS NULL;

-- QG-001b: NULL Year
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.who_health_indicators','QG-001',
       'Year is NULL – time dimension key missing',
       CONCAT('Country=[',ISNULL(Country,'NULL'),'] | Year=[NULL]')
FROM bronze.who_health_indicators
WHERE NULLIF(TRIM(ISNULL(Country,'')),'') IS NOT NULL
  AND NULLIF(TRIM(ISNULL(Year,'')),'') IS NULL;

-- QG-002: Year outside dataset range 2000-2015
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.who_health_indicators','QG-002',
       'Year is outside valid dataset range (2000-2015) – likely data entry error',
       CONCAT('Country=[',ISNULL(Country,'NULL'),'] | Year=[',ISNULL(Year,'NULL'),']')
FROM bronze.who_health_indicators
WHERE NULLIF(TRIM(ISNULL(Country,'')),'') IS NOT NULL
  AND NULLIF(TRIM(ISNULL(Year,'')),'') IS NOT NULL
  AND (TRY_CAST(TRIM(Year) AS SMALLINT) IS NULL
    OR TRY_CAST(TRIM(Year) AS SMALLINT) < 2000
    OR TRY_CAST(TRIM(Year) AS SMALLINT) > 2015);

-- QG-003: Duplicate Country + Year (keep first ingested)
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY TRIM(ISNULL(Country,'')), TRIM(ISNULL(Year,''))
        ORDER BY _ingested_at
    ) AS rn
    FROM bronze.who_health_indicators
    WHERE NULLIF(TRIM(ISNULL(Country,'')),'') IS NOT NULL
      AND TRY_CAST(TRIM(Year) AS SMALLINT) BETWEEN 2000 AND 2015
)
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.who_health_indicators','QG-003',
       'Duplicate Country+Year – only first-ingested row retained',
       CONCAT('Country=[',Country,'] | Year=[',Year,']')
FROM ranked WHERE rn > 1;

-- Load clean rows into Silver
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY TRIM(ISNULL(Country,'')), TRIM(ISNULL(Year,''))
        ORDER BY _ingested_at
    ) AS rn
    FROM bronze.who_health_indicators
    WHERE NULLIF(TRIM(ISNULL(Country,'')),'') IS NOT NULL
      AND TRY_CAST(TRIM(Year) AS SMALLINT) BETWEEN 2000 AND 2015
)
INSERT INTO silver.who_health_indicators (
    country_name, year, status, life_expectancy, adult_mortality,
    infant_deaths, alcohol, pct_expenditure, hepatitis_b, measles,
    bmi, under_five_deaths, polio, total_expenditure, diphtheria,
    hiv_aids, gdp, population, thinness_1_19_years, thinness_5_9_years,
    income_composition, schooling)
SELECT
    TRIM(Country),
    CAST(TRIM(Year) AS SMALLINT),
    NULLIF(TRIM(ISNULL(Status,'')),''),
    TRY_CAST(TRIM([Life expectancy])                  AS FLOAT),
    TRY_CAST(TRIM([Adult Mortality])                  AS FLOAT),
    TRY_CAST(TRIM([infant deaths])                    AS INT),
    TRY_CAST(TRIM(Alcohol)                            AS FLOAT),
    TRY_CAST(TRIM([percentage expenditure])           AS FLOAT),
    TRY_CAST(TRIM([Hepatitis B])                      AS FLOAT),
    TRY_CAST(TRIM(Measles)                            AS INT),
    TRY_CAST(TRIM(ISNULL(BMI,''))                     AS FLOAT),
    TRY_CAST(TRIM([under-five deaths])                AS INT),
    TRY_CAST(TRIM(Polio)                              AS FLOAT),
    TRY_CAST(TRIM([Total expenditure])                AS FLOAT),
    TRY_CAST(TRIM(Diphtheria)                         AS FLOAT),
    TRY_CAST(TRIM([HIV/AIDS])                         AS FLOAT),
    TRY_CAST(TRIM(GDP)                                AS FLOAT),
    TRY_CAST(TRIM(Population)                         AS BIGINT),
    TRY_CAST(TRIM([thinness 1-19 years])              AS FLOAT),
    TRY_CAST(TRIM([thinness 5-9 years])               AS FLOAT),
    TRY_CAST(TRIM([Income composition of resources])  AS FLOAT),
    TRY_CAST(TRIM(Schooling)                          AS FLOAT)
FROM ranked WHERE rn = 1;

PRINT 'Silver who_health_indicators loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows.';
GO

-- ═════════════════════════════════════════════════════════════
-- SILVER TABLE 2: disease_outbreaks
-- Source: covid_19_clean_complete.csv (10 columns)
-- ═════════════════════════════════════════════════════════════
IF OBJECT_ID('silver.disease_outbreaks','U') IS NOT NULL DROP TABLE silver.disease_outbreaks;
GO
CREATE TABLE silver.disease_outbreaks (
    country_region   NVARCHAR(200) NOT NULL,
    province_state   NVARCHAR(200),           -- NULL for country-level rows
    who_region       NVARCHAR(200),
    report_date      DATE          NOT NULL,
    confirmed        BIGINT,
    deaths           BIGINT,
    recovered        BIGINT,
    active           BIGINT,
    lat              FLOAT,
    long             FLOAT,
    _silver_loaded   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- QG-001: NULL or empty Country/Region
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.disease_outbreaks','QG-001',
       'Country/Region is NULL or empty – cannot assign row to any geography',
       CONCAT('Country/Region=[',ISNULL([Country/Region],'NULL'),'] | Date=[',ISNULL(Date,'NULL'),']')
FROM bronze.disease_outbreaks
WHERE NULLIF(TRIM(ISNULL([Country/Region],'')),'') IS NULL;

-- QG-002: Date cannot be parsed as DATE
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.disease_outbreaks','QG-002',
       'Date value cannot be parsed as a valid calendar date',
       CONCAT('Country/Region=[',ISNULL([Country/Region],'NULL'),'] | Date=[',ISNULL(Date,'NULL'),']')
FROM bronze.disease_outbreaks
WHERE NULLIF(TRIM(ISNULL([Country/Region],'')),'') IS NOT NULL
  AND TRY_CAST(Date AS DATE) IS NULL;

-- QG-003: Duplicate Country + Province + Date
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY TRIM(ISNULL([Country/Region],'')),
                     TRIM(ISNULL([Province/State],'')),
                     TRIM(ISNULL(Date,''))
        ORDER BY _ingested_at
    ) AS rn
    FROM bronze.disease_outbreaks
    WHERE NULLIF(TRIM(ISNULL([Country/Region],'')),'') IS NOT NULL
      AND TRY_CAST(Date AS DATE) IS NOT NULL
)
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.disease_outbreaks','QG-003',
       'Duplicate Country/Region + Province/State + Date – first-ingested row kept',
       CONCAT('Country=[', [Country/Region],'] | Date=[',Date,']')
FROM ranked WHERE rn > 1;

-- QG-005: Non-numeric Confirmed or Deaths
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.disease_outbreaks','QG-005',
       'Confirmed or Deaths contains non-numeric text (cannot be cast to integer)',
       CONCAT('Country=[',ISNULL([Country/Region],'NULL'),
              '] | Confirmed=[',ISNULL(Confirmed,'NULL'),
              '] | Deaths=[',ISNULL(Deaths,'NULL'),']')
FROM bronze.disease_outbreaks
WHERE NULLIF(TRIM(ISNULL([Country/Region],'')),'') IS NOT NULL
  AND TRY_CAST(Date AS DATE) IS NOT NULL
  AND (TRY_CAST(Confirmed AS BIGINT) IS NULL
    OR TRY_CAST(Deaths    AS BIGINT) IS NULL)
  AND (NULLIF(TRIM(ISNULL(Confirmed,'')),'') IS NOT NULL
    OR NULLIF(TRIM(ISNULL(Deaths,'')),'') IS NOT NULL);

-- Load clean rows into Silver
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY TRIM(ISNULL([Country/Region],'')),
                     TRIM(ISNULL([Province/State],'')),
                     TRIM(ISNULL(Date,''))
        ORDER BY _ingested_at
    ) AS rn
    FROM bronze.disease_outbreaks
    WHERE NULLIF(TRIM(ISNULL([Country/Region],'')),'') IS NOT NULL
      AND TRY_CAST(Date AS DATE) IS NOT NULL
      AND TRY_CAST(Confirmed AS BIGINT) IS NOT NULL
      AND TRY_CAST(Deaths    AS BIGINT) IS NOT NULL
)
INSERT INTO silver.disease_outbreaks (
    country_region, province_state, who_region, report_date,
    confirmed, deaths, recovered, active, lat, long)
SELECT
    TRIM([Country/Region]),
    NULLIF(TRIM(ISNULL([Province/State],'')),''),
    NULLIF(TRIM(ISNULL([WHO Region],'')),''),
    CAST(Date AS DATE),
    TRY_CAST(Confirmed AS BIGINT),
    TRY_CAST(Deaths    AS BIGINT),
    TRY_CAST(Recovered AS BIGINT),
    TRY_CAST(Active    AS BIGINT),
    TRY_CAST(Lat  AS FLOAT),
    TRY_CAST(Long AS FLOAT)
FROM ranked WHERE rn = 1;

PRINT 'Silver disease_outbreaks loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows.';
GO

-- ═════════════════════════════════════════════════════════════
-- SILVER TABLE 3: hospital_capacity
-- Source: hospital_beds_by_country.csv (4 columns)
-- ═════════════════════════════════════════════════════════════
IF OBJECT_ID('silver.hospital_capacity','U') IS NOT NULL DROP TABLE silver.hospital_capacity;
GO
CREATE TABLE silver.hospital_capacity (
    country_name        NVARCHAR(200) NOT NULL,
    country_code        CHAR(3)       NOT NULL,   -- ISO-3 Alpha-3
    year                SMALLINT      NOT NULL,
    hospital_beds_per1k FLOAT         NOT NULL,   -- beds per 1,000 people
    _silver_loaded      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- QG-001: Empty Entity or Code
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.hospital_capacity','QG-001',
       'Entity (country name) or Code (ISO) is NULL or empty string',
       CONCAT('Entity=[',ISNULL(Entity,'NULL'),'] | Code=[',ISNULL(Code,'NULL'),']')
FROM bronze.hospital_capacity
WHERE NULLIF(TRIM(ISNULL(Entity,'')),'') IS NULL
   OR NULLIF(TRIM(ISNULL(Code,'')),'')   IS NULL;

-- QG-004: Code is not exactly 3 letters
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.hospital_capacity','QG-004',
       'Country Code is not a valid 3-letter ISO 3166-1 Alpha-3 code',
       CONCAT('Entity=[',ISNULL(Entity,'NULL'),'] | Code=[',ISNULL(Code,'NULL'),']')
FROM bronze.hospital_capacity
WHERE NULLIF(TRIM(ISNULL(Entity,'')),'') IS NOT NULL
  AND NULLIF(TRIM(ISNULL(Code,'')),'')   IS NOT NULL
  AND LEN(TRIM(Code)) <> 3;

-- QG-003: Duplicate Code + Year
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY TRIM(ISNULL(Code,'')), TRIM(ISNULL(Year,''))
        ORDER BY _ingested_at
    ) AS rn
    FROM bronze.hospital_capacity
    WHERE NULLIF(TRIM(ISNULL(Entity,'')),'') IS NOT NULL
      AND LEN(TRIM(ISNULL(Code,''))) = 3
      AND TRY_CAST(Year AS SMALLINT) BETWEEN 1960 AND 2024
)
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.hospital_capacity','QG-003',
       'Duplicate Code+Year – first-ingested row kept',
       CONCAT('Entity=[',Entity,'] | Code=[',Code,'] | Year=[',Year,']')
FROM ranked WHERE rn > 1;

-- Load clean rows
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY TRIM(ISNULL(Code,'')), TRIM(ISNULL(Year,''))
        ORDER BY _ingested_at
    ) AS rn
    FROM bronze.hospital_capacity
    WHERE NULLIF(TRIM(ISNULL(Entity,'')),'') IS NOT NULL
      AND LEN(TRIM(ISNULL(Code,''))) = 3
      AND TRY_CAST(Year AS SMALLINT) BETWEEN 1960 AND 2024
      AND TRY_CAST([Hospital beds (per 1,000 people)] AS FLOAT) IS NOT NULL
)
INSERT INTO silver.hospital_capacity (country_name, country_code, year, hospital_beds_per1k)
SELECT
    TRIM(Entity),
    UPPER(TRIM(Code)),
    CAST(Year AS SMALLINT),
    CAST([Hospital beds (per 1,000 people)] AS FLOAT)
FROM ranked WHERE rn = 1;

PRINT 'Silver hospital_capacity loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows.';
GO

-- ─────────────────────────────────────────────────────────────
-- QUALITY GATE SUMMARY REPORT
-- ─────────────────────────────────────────────────────────────
PRINT '=== QUALITY GATE SUMMARY ===';
SELECT
    source_table,
    reason_code,
    reject_reason,
    COUNT(*) AS rejected_rows
FROM quarantine.rejected_rows
GROUP BY source_table, reason_code, reject_reason
ORDER BY source_table, reason_code;
GO

-- Silver row counts
PRINT '=== SILVER ROW COUNTS ===';
SELECT 'silver.who_health_indicators' AS silver_table, COUNT(*) AS rows FROM silver.who_health_indicators
UNION ALL
SELECT 'silver.disease_outbreaks',                      COUNT(*) FROM silver.disease_outbreaks
UNION ALL
SELECT 'silver.hospital_capacity',                      COUNT(*) FROM silver.hospital_capacity;
GO

PRINT '=== SILVER ZONE COMPLETE ===';
GO
