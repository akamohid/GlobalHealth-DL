-- ============================================================
-- DS 312 Term Project: Healthcare Data Lake
-- Script 02: Silver Zone – FULL REAL DATASET CLEANING
-- Handles complete 2938 + 49068 + 4700 row datasets
-- ============================================================

USE DWBI_HealthCare;
GO

-- ─────────────────────────────────────────────────────────────
-- QUARANTINE TABLE
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('quarantine.rejected_rows','U') IS NOT NULL DROP TABLE quarantine.rejected_rows;
GO
CREATE TABLE quarantine.rejected_rows (
    reject_id     INT IDENTITY(1,1) PRIMARY KEY,
    source_table  NVARCHAR(200) NOT NULL,
    reason_code   NVARCHAR(10)  NOT NULL,
    reject_reason NVARCHAR(500) NOT NULL,
    raw_snapshot  NVARCHAR(MAX),
    rejected_at   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
PRINT 'Quarantine table created.';
GO

-- ═════════════════════════════════════════════════════════════
-- SILVER TABLE 1: who_health_indicators
-- Full dataset: 193 countries, 2000-2015, 2938 rows
-- Expected Silver rows after cleaning: ~2800-2900
-- ═════════════════════════════════════════════════════════════
IF OBJECT_ID('silver.who_health_indicators','U') IS NOT NULL DROP TABLE silver.who_health_indicators;
GO
CREATE TABLE silver.who_health_indicators (
    country_name          NVARCHAR(200) NOT NULL,
    year                  SMALLINT      NOT NULL,
    status                NVARCHAR(20),
    life_expectancy       FLOAT,
    adult_mortality       FLOAT,
    infant_deaths         INT,
    alcohol               FLOAT,
    pct_expenditure       FLOAT,
    hepatitis_b           FLOAT,
    measles               INT,
    bmi                   FLOAT,
    under_five_deaths     INT,
    polio                 FLOAT,
    total_expenditure     FLOAT,
    diphtheria            FLOAT,
    hiv_aids              FLOAT,
    gdp                   FLOAT,
    population            BIGINT,
    thinness_1_19_years   FLOAT,
    thinness_5_9_years    FLOAT,
    income_composition    FLOAT,
    schooling             FLOAT,
    _silver_loaded        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    -- Add index for Gold join performance
    CONSTRAINT PK_silver_who PRIMARY KEY (country_name, year)
);
GO

-- ── QG-001: NULL or empty Country ────────────────────────────
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.who_health_indicators', 'QG-001',
       'Country is NULL or empty – primary geographic key missing',
       CONCAT('Country=[', ISNULL(Country,'NULL'), '] | Year=[', ISNULL(Year,'NULL'), ']')
FROM bronze.who_health_indicators
WHERE NULLIF(TRIM(ISNULL(Country,'')),'') IS NULL;

-- ── QG-001b: NULL Year ────────────────────────────────────────
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.who_health_indicators', 'QG-001',
       'Year is NULL – time dimension key missing',
       CONCAT('Country=[', ISNULL(Country,'NULL'), '] | Year=[NULL]')
FROM bronze.who_health_indicators
WHERE NULLIF(TRIM(ISNULL(Country,'')),'') IS NOT NULL
  AND NULLIF(TRIM(ISNULL(Year,'')),'') IS NULL;

-- ── QG-002: Year outside valid range 2000-2015 ───────────────
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.who_health_indicators', 'QG-002',
       'Year outside valid dataset range (2000-2015)',
       CONCAT('Country=[', ISNULL(Country,'NULL'), '] | Year=[', ISNULL(Year,'NULL'), ']')
FROM bronze.who_health_indicators
WHERE NULLIF(TRIM(ISNULL(Country,'')),'') IS NOT NULL
  AND NULLIF(TRIM(ISNULL(Year,'')),'') IS NOT NULL
  AND (TRY_CAST(TRIM(Year) AS SMALLINT) IS NULL
    OR TRY_CAST(TRIM(Year) AS SMALLINT) < 2000
    OR TRY_CAST(TRIM(Year) AS SMALLINT) > 2015);

-- ── QG-003: Duplicate Country + Year (keep first ingested) ───
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
SELECT 'bronze.who_health_indicators', 'QG-003',
       'Duplicate Country+Year – only first-ingested row retained',
       CONCAT('Country=[', Country, '] | Year=[', Year, ']')
FROM ranked WHERE rn > 1;

-- ── Load FULL CLEAN rows → Silver ────────────────────────────
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
    TRY_CAST(TRIM(ISNULL([Life expectancy],''))        AS FLOAT),
    TRY_CAST(TRIM(ISNULL([Adult Mortality],''))         AS FLOAT),
    TRY_CAST(TRIM(ISNULL([infant deaths],''))           AS INT),
    TRY_CAST(TRIM(ISNULL(Alcohol,''))                   AS FLOAT),
    TRY_CAST(TRIM(ISNULL([percentage expenditure],''))  AS FLOAT),
    TRY_CAST(TRIM(ISNULL([Hepatitis B],''))             AS FLOAT),
    TRY_CAST(TRIM(ISNULL(Measles,''))                   AS INT),
    TRY_CAST(TRIM(ISNULL(BMI,''))                       AS FLOAT),
    TRY_CAST(TRIM(ISNULL([under-five deaths],''))       AS INT),
    TRY_CAST(TRIM(ISNULL(Polio,''))                     AS FLOAT),
    TRY_CAST(TRIM(ISNULL([Total expenditure],''))       AS FLOAT),
    TRY_CAST(TRIM(ISNULL(Diphtheria,''))                AS FLOAT),
    TRY_CAST(TRIM(ISNULL([HIV/AIDS],''))                AS FLOAT),
    TRY_CAST(TRIM(ISNULL(GDP,''))                       AS FLOAT),
    TRY_CAST(TRIM(ISNULL(Population,''))                AS BIGINT),
    TRY_CAST(TRIM(ISNULL([thinness 1-19 years],''))     AS FLOAT),
    TRY_CAST(TRIM(ISNULL([thinness 5-9 years],''))      AS FLOAT),
    TRY_CAST(TRIM(ISNULL([Income composition of resources],'')) AS FLOAT),
    TRY_CAST(TRIM(ISNULL(Schooling,''))                 AS FLOAT)
FROM ranked WHERE rn = 1;

DECLARE @s1 INT; SELECT @s1 = COUNT(*) FROM silver.who_health_indicators;
PRINT 'Silver who_health_indicators: ' + CAST(@s1 AS NVARCHAR) + ' rows loaded.';
GO

-- ═════════════════════════════════════════════════════════════
-- SILVER TABLE 2: disease_outbreaks
-- Full dataset: ~49,068 rows, 180+ countries, Jan 2020 – Jul 2020
-- Expected Silver rows after cleaning: ~47,000-48,000
-- ═════════════════════════════════════════════════════════════
IF OBJECT_ID('silver.disease_outbreaks','U') IS NOT NULL DROP TABLE silver.disease_outbreaks;
GO
CREATE TABLE silver.disease_outbreaks (
    country_region   NVARCHAR(200) NOT NULL,
    province_state   NVARCHAR(200),
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

-- Index for Gold join and aggregation performance
CREATE INDEX IX_silver_outbreaks_country ON silver.disease_outbreaks (country_region, report_date);
GO

-- ── QG-001: NULL or empty Country/Region ─────────────────────
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.disease_outbreaks', 'QG-001',
       'Country/Region is NULL or empty – geographic key missing',
       CONCAT('Country/Region=[', ISNULL([Country/Region],'NULL'), '] | Date=[', ISNULL(Date,'NULL'), ']')
FROM bronze.disease_outbreaks
WHERE NULLIF(TRIM(ISNULL([Country/Region],'')),'') IS NULL;

-- ── QG-002: Unparseable Date ──────────────────────────────────
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.disease_outbreaks', 'QG-002',
       'Date value cannot be parsed as a valid calendar date',
       CONCAT('Country/Region=[', ISNULL([Country/Region],'NULL'), '] | Date=[', ISNULL(Date,'NULL'), ']')
FROM bronze.disease_outbreaks
WHERE NULLIF(TRIM(ISNULL([Country/Region],'')),'') IS NOT NULL
  AND TRY_CAST(Date AS DATE) IS NULL;

-- ── QG-003: Duplicate Country + Province + Date ───────────────
-- NOTE: The COVID dataset has many Province/State level rows
-- Dedup is on the full composite key to preserve sub-national data
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY
            TRIM(ISNULL([Country/Region],'')),
            TRIM(ISNULL([Province/State],'')),
            TRIM(ISNULL(Date,''))
        ORDER BY _ingested_at
    ) AS rn
    FROM bronze.disease_outbreaks
    WHERE NULLIF(TRIM(ISNULL([Country/Region],'')),'') IS NOT NULL
      AND TRY_CAST(Date AS DATE) IS NOT NULL
)
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.disease_outbreaks', 'QG-003',
       'Duplicate Country+Province+Date – first-ingested row retained',
       CONCAT('Country=[', [Country/Region], '] | Province=[',
              ISNULL([Province/State],'NULL'), '] | Date=[', Date, ']')
FROM ranked WHERE rn > 1;

-- ── QG-005: Non-numeric Confirmed or Deaths ───────────────────
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.disease_outbreaks', 'QG-005',
       'Confirmed or Deaths contains non-numeric text – cannot cast to BIGINT',
       CONCAT('Country=[', ISNULL([Country/Region],'NULL'),
              '] | Confirmed=[', ISNULL(Confirmed,'NULL'),
              '] | Deaths=[', ISNULL(Deaths,'NULL'), ']')
FROM bronze.disease_outbreaks
WHERE NULLIF(TRIM(ISNULL([Country/Region],'')),'') IS NOT NULL
  AND TRY_CAST(Date AS DATE) IS NOT NULL
  AND (TRY_CAST(Confirmed AS BIGINT) IS NULL
    OR TRY_CAST(Deaths    AS BIGINT) IS NULL)
  AND (NULLIF(TRIM(ISNULL(Confirmed,'')),'') IS NOT NULL
    OR NULLIF(TRIM(ISNULL(Deaths,'')),'')    IS NOT NULL);

-- ── Load FULL CLEAN rows → Silver ────────────────────────────
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY
            TRIM(ISNULL([Country/Region],'')),
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

DECLARE @s2 INT; SELECT @s2 = COUNT(*) FROM silver.disease_outbreaks;
PRINT 'Silver disease_outbreaks: ' + CAST(@s2 AS NVARCHAR) + ' rows loaded.';
GO

-- ═════════════════════════════════════════════════════════════
-- SILVER TABLE 3: hospital_capacity
-- Full dataset: ~4,700 rows, 200+ countries, multi-year panel
-- Expected Silver rows after cleaning: ~4,400-4,600
-- ═════════════════════════════════════════════════════════════
IF OBJECT_ID('silver.hospital_capacity','U') IS NOT NULL DROP TABLE silver.hospital_capacity;
GO
CREATE TABLE silver.hospital_capacity (
    country_name        NVARCHAR(200) NOT NULL,
    country_code        CHAR(3)       NOT NULL,
    year                SMALLINT      NOT NULL,
    hospital_beds_per1k FLOAT         NOT NULL,
    _silver_loaded      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_silver_beds PRIMARY KEY (country_code, year)
);
GO

-- ── QG-001: Empty Entity or Code ─────────────────────────────
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.hospital_capacity', 'QG-001',
       'Entity (country name) or Code (ISO) is NULL or empty',
       CONCAT('Entity=[', ISNULL(Entity,'NULL'), '] | Code=[', ISNULL(Code,'NULL'), ']')
FROM bronze.hospital_capacity
WHERE NULLIF(TRIM(ISNULL(Entity,'')),'') IS NULL
   OR NULLIF(TRIM(ISNULL(Code,'')),'')   IS NULL;

-- ── QG-004: Code is not exactly 3 letters ────────────────────
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.hospital_capacity', 'QG-004',
       'Country Code is not a valid 3-letter ISO 3166-1 Alpha-3 code',
       CONCAT('Entity=[', ISNULL(Entity,'NULL'), '] | Code=[', ISNULL(Code,'NULL'), ']')
FROM bronze.hospital_capacity
WHERE NULLIF(TRIM(ISNULL(Entity,'')),'') IS NOT NULL
  AND NULLIF(TRIM(ISNULL(Code,'')),'')   IS NOT NULL
  AND LEN(TRIM(Code)) <> 3;

-- ── QG-002: Unparseable or out-of-range Year ─────────────────
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.hospital_capacity', 'QG-002',
       'Year cannot be parsed or is outside valid range (1960-2024)',
       CONCAT('Entity=[', ISNULL(Entity,'NULL'), '] | Year=[', ISNULL(Year,'NULL'), ']')
FROM bronze.hospital_capacity
WHERE NULLIF(TRIM(ISNULL(Entity,'')),'') IS NOT NULL
  AND LEN(TRIM(ISNULL(Code,''))) = 3
  AND (TRY_CAST(Year AS SMALLINT) IS NULL
    OR TRY_CAST(Year AS SMALLINT) < 1960
    OR TRY_CAST(Year AS SMALLINT) > 2024);

-- ── QG-003: Duplicate Code + Year ────────────────────────────
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
INSERT INTO quarantine.rejected_rows (source_table, reason_code, reject_reason, raw_snapshot)
SELECT 'bronze.hospital_capacity', 'QG-003',
       'Duplicate Code+Year – first-ingested row retained',
       CONCAT('Entity=[', Entity, '] | Code=[', Code, '] | Year=[', Year, ']')
FROM ranked WHERE rn > 1;

-- ── Load FULL CLEAN rows → Silver ────────────────────────────
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

DECLARE @s3 INT; SELECT @s3 = COUNT(*) FROM silver.hospital_capacity;
PRINT 'Silver hospital_capacity: ' + CAST(@s3 AS NVARCHAR) + ' rows loaded.';
GO

-- ─────────────────────────────────────────────────────────────
-- QUALITY GATE FULL SUMMARY
-- ─────────────────────────────────────────────────────────────
PRINT '=== FULL QUALITY GATE SUMMARY ===';
SELECT
    source_table,
    reason_code,
    reject_reason,
    COUNT(*) AS rejected_rows
FROM quarantine.rejected_rows
GROUP BY source_table, reason_code, reject_reason
ORDER BY source_table, reason_code;

PRINT '=== TOTAL REJECTS PER TABLE ===';
SELECT source_table, COUNT(*) AS total_rejected
FROM quarantine.rejected_rows
GROUP BY source_table ORDER BY source_table;

PRINT '=== SILVER ROW COUNTS ===';
SELECT 'silver.who_health_indicators' AS silver_table,
       COUNT(*) AS total_rows,
       COUNT(DISTINCT country_name) AS distinct_countries,
       MIN(year) AS min_year, MAX(year) AS max_year
FROM silver.who_health_indicators
UNION ALL
SELECT 'silver.disease_outbreaks',
       COUNT(*),
       COUNT(DISTINCT country_region),
       NULL, NULL
FROM silver.disease_outbreaks
UNION ALL
SELECT 'silver.hospital_capacity',
       COUNT(*),
       COUNT(DISTINCT country_code),
       MIN(year), MAX(year)
FROM silver.hospital_capacity;

-- Missing value profile on Silver DS1 (most analytical columns)
PRINT '=== NULL RATE IN SILVER DS1 (key columns) ===';
SELECT
    'life_expectancy'   AS column_name, SUM(CASE WHEN life_expectancy IS NULL THEN 1 ELSE 0 END) AS null_count, COUNT(*) AS total FROM silver.who_health_indicators
UNION ALL SELECT 'gdp',        SUM(CASE WHEN gdp IS NULL THEN 1 ELSE 0 END),        COUNT(*) FROM silver.who_health_indicators
UNION ALL SELECT 'population', SUM(CASE WHEN population IS NULL THEN 1 ELSE 0 END), COUNT(*) FROM silver.who_health_indicators
UNION ALL SELECT 'hepatitis_b',SUM(CASE WHEN hepatitis_b IS NULL THEN 1 ELSE 0 END),COUNT(*) FROM silver.who_health_indicators
UNION ALL SELECT 'bmi',        SUM(CASE WHEN bmi IS NULL THEN 1 ELSE 0 END),        COUNT(*) FROM silver.who_health_indicators;

PRINT '=== SILVER ZONE COMPLETE ===';
GO
