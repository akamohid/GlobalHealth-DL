-- ============================================================
-- DS 312 Term Project: Healthcare Data Lake
-- Script 01: Bronze Zone – FULL REAL DATASET LOAD
-- Database: DWBI_HealthCare
-- Platform: SQL Server Express 2022 (SSMS 22)
-- ============================================================
 
USE DWBI_HealthCare;
GO
 
-- ─────────────────────────────────────────────────────────────
-- INGESTION LOG
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('bronze.ingestion_log','U') IS NOT NULL DROP TABLE bronze.ingestion_log;
GO
CREATE TABLE bronze.ingestion_log (
    log_id      INT IDENTITY(1,1) PRIMARY KEY,
    table_name  NVARCHAR(200) NOT NULL,
    src_file    NVARCHAR(500) NOT NULL,
    rows_before INT           NOT NULL DEFAULT 0,
    rows_after  INT           NOT NULL DEFAULT 0,
    rows_loaded AS (rows_after - rows_before),
    loaded_at   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    notes       NVARCHAR(MAX)
);
GO
 
-- ─────────────────────────────────────────────────────────────
-- BRONZE TABLE 1: who_health_indicators
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('bronze.who_health_indicators','U') IS NOT NULL DROP TABLE bronze.who_health_indicators;
GO
CREATE TABLE bronze.who_health_indicators (
    Country                             NVARCHAR(200),
    Year                                NVARCHAR(10),
    Status                              NVARCHAR(50),
    [Life expectancy]                   NVARCHAR(20),
    [Adult Mortality]                   NVARCHAR(20),
    [infant deaths]                     NVARCHAR(20),
    Alcohol                             NVARCHAR(20),
    [percentage expenditure]            NVARCHAR(30),
    [Hepatitis B]                       NVARCHAR(20),
    Measles                             NVARCHAR(20),
    BMI                                 NVARCHAR(20),
    [under-five deaths]                 NVARCHAR(20),
    Polio                               NVARCHAR(20),
    [Total expenditure]                 NVARCHAR(20),
    Diphtheria                          NVARCHAR(20),
    [HIV/AIDS]                          NVARCHAR(20),
    GDP                                 NVARCHAR(30),
    Population                          NVARCHAR(30),
    [thinness 1-19 years]               NVARCHAR(20),
    [thinness 5-9 years]                NVARCHAR(20),
    [Income composition of resources]   NVARCHAR(20),
    Schooling                           NVARCHAR(20),
    -- Metadata columns (auto-filled, NOT read from CSV)
    _src_file    NVARCHAR(500) NOT NULL DEFAULT 'who_health_indicators.csv',
    _ingested_at DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    _row_hash    AS CONVERT(NVARCHAR(64),
                     HASHBYTES('SHA2_256',
                         ISNULL(Country,'') + '|' + ISNULL(Year,'')), 2) PERSISTED
);
GO
 
-- ─────────────────────────────────────────────────────────────
-- BRONZE TABLE 2: disease_outbreaks
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('bronze.disease_outbreaks','U') IS NOT NULL DROP TABLE bronze.disease_outbreaks;
GO
CREATE TABLE bronze.disease_outbreaks (
    [Province/State]  NVARCHAR(200),
    [Country/Region]  NVARCHAR(200),
    Lat               NVARCHAR(30),
    Long              NVARCHAR(30),
    Date              NVARCHAR(30),
    Confirmed         NVARCHAR(30),
    Deaths            NVARCHAR(30),
    Recovered         NVARCHAR(30),
    Active            NVARCHAR(30),
    [WHO Region]      NVARCHAR(200),
    -- Metadata columns (auto-filled, NOT read from CSV)
    _src_file    NVARCHAR(500) NOT NULL DEFAULT 'disease_outbreaks.csv',
    _ingested_at DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    _row_hash    AS CONVERT(NVARCHAR(64),
                     HASHBYTES('SHA2_256',
                         ISNULL([Country/Region],'') + '|' +
                         ISNULL([Province/State],'') + '|' +
                         ISNULL(Date,'')), 2) PERSISTED
);
GO
 
-- ─────────────────────────────────────────────────────────────
-- BRONZE TABLE 3: hospital_capacity
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('bronze.hospital_capacity','U') IS NOT NULL DROP TABLE bronze.hospital_capacity;
GO
CREATE TABLE bronze.hospital_capacity (
    Entity                              NVARCHAR(200),
    Code                                NVARCHAR(10),
    Year                                NVARCHAR(10),
    [Hospital beds (per 1,000 people)]  NVARCHAR(30),
    -- Metadata columns (auto-filled, NOT read from CSV)
    _src_file    NVARCHAR(500) NOT NULL DEFAULT 'hospital_capacity.csv',
    _ingested_at DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    _row_hash    AS CONVERT(NVARCHAR(64),
                     HASHBYTES('SHA2_256',
                         ISNULL(Code,'') + '|' + ISNULL(Year,'')), 2) PERSISTED
);
GO
 
PRINT 'All 3 bronze tables created successfully.';
GO
 
-- ═════════════════════════════════════════════════════════════
-- STAGING TABLES
-- These have ONLY the source CSV columns — no metadata columns.
-- BULK INSERT loads into staging first, then we INSERT from
-- staging into the real bronze table (which fires the defaults).
-- ═════════════════════════════════════════════════════════════
 
-- Staging 1: WHO Health Indicators (22 source columns only)
IF OBJECT_ID('bronze.stg_who','U') IS NOT NULL DROP TABLE bronze.stg_who;
GO
CREATE TABLE bronze.stg_who (
    Country                             NVARCHAR(200),
    Year                                NVARCHAR(10),
    Status                              NVARCHAR(50),
    [Life expectancy]                   NVARCHAR(20),
    [Adult Mortality]                   NVARCHAR(20),
    [infant deaths]                     NVARCHAR(20),
    Alcohol                             NVARCHAR(20),
    [percentage expenditure]            NVARCHAR(30),
    [Hepatitis B]                       NVARCHAR(20),
    Measles                             NVARCHAR(20),
    BMI                                 NVARCHAR(20),
    [under-five deaths]                 NVARCHAR(20),
    Polio                               NVARCHAR(20),
    [Total expenditure]                 NVARCHAR(20),
    Diphtheria                          NVARCHAR(20),
    [HIV/AIDS]                          NVARCHAR(20),
    GDP                                 NVARCHAR(30),
    Population                          NVARCHAR(30),
    [thinness 1-19 years]               NVARCHAR(20),
    [thinness 5-9 years]                NVARCHAR(20),
    [Income composition of resources]   NVARCHAR(20),
    Schooling                           NVARCHAR(20)
);
GO
 
-- Staging 2: Disease Outbreaks (10 source columns only)
IF OBJECT_ID('bronze.stg_disease','U') IS NOT NULL DROP TABLE bronze.stg_disease;
GO
CREATE TABLE bronze.stg_disease (
    [Province/State]  NVARCHAR(200),
    [Country/Region]  NVARCHAR(200),
    Lat               NVARCHAR(30),
    Long              NVARCHAR(30),
    Date              NVARCHAR(30),
    Confirmed         NVARCHAR(30),
    Deaths            NVARCHAR(30),
    Recovered         NVARCHAR(30),
    Active            NVARCHAR(30),
    [WHO Region]      NVARCHAR(200)
);
GO
 
-- ─────────────────────────────────────────────────────────────
-- Staging 3: Hospital Capacity – WIDE FORMAT
-- The CSV is World Bank wide format: one row per country, one
-- column per year (1960–2019).  We load all 64 columns then
-- UNPIVOT into the narrow bronze.hospital_capacity table.
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('bronze.stg_hospital','U') IS NOT NULL DROP TABLE bronze.stg_hospital;
GO
CREATE TABLE bronze.stg_hospital (
    [Country Name]   NVARCHAR(200),
    [Country Code]   NVARCHAR(10),
    [Indicator Name] NVARCHAR(200),
    [Indicator Code] NVARCHAR(100),
    [1960] NVARCHAR(30), [1961] NVARCHAR(30), [1962] NVARCHAR(30), [1963] NVARCHAR(30),
    [1964] NVARCHAR(30), [1965] NVARCHAR(30), [1966] NVARCHAR(30), [1967] NVARCHAR(30),
    [1968] NVARCHAR(30), [1969] NVARCHAR(30), [1970] NVARCHAR(30), [1971] NVARCHAR(30),
    [1972] NVARCHAR(30), [1973] NVARCHAR(30), [1974] NVARCHAR(30), [1975] NVARCHAR(30),
    [1976] NVARCHAR(30), [1977] NVARCHAR(30), [1978] NVARCHAR(30), [1979] NVARCHAR(30),
    [1980] NVARCHAR(30), [1981] NVARCHAR(30), [1982] NVARCHAR(30), [1983] NVARCHAR(30),
    [1984] NVARCHAR(30), [1985] NVARCHAR(30), [1986] NVARCHAR(30), [1987] NVARCHAR(30),
    [1988] NVARCHAR(30), [1989] NVARCHAR(30), [1990] NVARCHAR(30), [1991] NVARCHAR(30),
    [1992] NVARCHAR(30), [1993] NVARCHAR(30), [1994] NVARCHAR(30), [1995] NVARCHAR(30),
    [1996] NVARCHAR(30), [1997] NVARCHAR(30), [1998] NVARCHAR(30), [1999] NVARCHAR(30),
    [2000] NVARCHAR(30), [2001] NVARCHAR(30), [2002] NVARCHAR(30), [2003] NVARCHAR(30),
    [2004] NVARCHAR(30), [2005] NVARCHAR(30), [2006] NVARCHAR(30), [2007] NVARCHAR(30),
    [2008] NVARCHAR(30), [2009] NVARCHAR(30), [2010] NVARCHAR(30), [2011] NVARCHAR(30),
    [2012] NVARCHAR(30), [2013] NVARCHAR(30), [2014] NVARCHAR(30), [2015] NVARCHAR(30),
    [2016] NVARCHAR(30), [2017] NVARCHAR(30), [2018] NVARCHAR(30), [2019] NVARCHAR(30)
);
GO
 
PRINT 'All 3 staging tables created.';
GO
 
-- ═════════════════════════════════════════════════════════════
-- STEP 1: BULK INSERT into staging tables (no metadata columns)
-- ═════════════════════════════════════════════════════════════
 
-- ── DS1: BULK INSERT into staging ────────────────────────────
BULK INSERT bronze.stg_who
FROM 'D:\#Sp26 Projects\DWBI\v3\bronze\who_health_indicators.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = '65001',
    TABLOCK,
    MAXERRORS       = 10
);
PRINT 'DS1 staging loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows';
GO
 
-- ── DS2: BULK INSERT into staging ────────────────────────────
BULK INSERT bronze.stg_disease
FROM 'D:\#Sp26 Projects\DWBI\v3\bronze\disease_outbreaks.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = '65001',
    TABLOCK,
    MAXERRORS       = 50
);
PRINT 'DS2 staging loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows';
GO
 
-- ── DS3: BULK INSERT into wide staging ───────────────────────
-- The original CSV has double-quoted fields and a trailing comma on every row.
-- FORMAT='CSV' requires Enterprise/Developer edition (not Express).
-- FIX: use hospital_capacity_clean.csv -- a pre-processed pipe-delimited version
-- with no quotes and no trailing delimiter (generated by the companion Python script).
-- Place hospital_capacity_clean.csv in the same folder as the other CSV files.
BULK INSERT bronze.stg_hospital
FROM 'D:\#Sp26 Projects\DWBI\v3\bronze\hospital_capacity_clean.csv'
WITH (
    FIRSTROW        = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR   = '\n',
    CODEPAGE        = '65001',
    TABLOCK,
    MAXERRORS       = 10
);
PRINT 'DS3 staging loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR) + ' rows';
GO
 
-- ═════════════════════════════════════════════════════════════
-- STEP 2: INSERT from staging into real bronze tables
-- Metadata columns (_src_file, _ingested_at) fire automatically
-- via DEFAULT constraints. _row_hash is a computed column.
-- ═════════════════════════════════════════════════════════════
 
-- ── DS1: staging → bronze ─────────────────────────────────────
DECLARE @b1 INT = 0;
SELECT @b1 = COUNT(*) FROM bronze.who_health_indicators;
 
INSERT INTO bronze.who_health_indicators (
    Country, Year, Status, [Life expectancy], [Adult Mortality],
    [infant deaths], Alcohol, [percentage expenditure], [Hepatitis B],
    Measles, BMI, [under-five deaths], Polio, [Total expenditure],
    Diphtheria, [HIV/AIDS], GDP, Population, [thinness 1-19 years],
    [thinness 5-9 years], [Income composition of resources], Schooling
)
SELECT
    Country, Year, Status, [Life expectancy], [Adult Mortality],
    [infant deaths], Alcohol, [percentage expenditure], [Hepatitis B],
    Measles, BMI, [under-five deaths], Polio, [Total expenditure],
    Diphtheria, [HIV/AIDS], GDP, Population, [thinness 1-19 years],
    [thinness 5-9 years], [Income composition of resources], Schooling
FROM bronze.stg_who;
 
DECLARE @a1 INT;
SELECT @a1 = COUNT(*) FROM bronze.who_health_indicators;
INSERT INTO bronze.ingestion_log (table_name, src_file, rows_before, rows_after, notes)
VALUES ('bronze.who_health_indicators', 'who_health_indicators.csv',
        @b1, @a1, 'Full load – Life Expectancy Data.csv – expected 2938 rows');
PRINT 'DS1 bronze loaded: ' + CAST(@a1 - @b1 AS NVARCHAR) + ' rows';
 
DROP TABLE bronze.stg_who;
GO
 
-- ── DS2: staging → bronze ─────────────────────────────────────
DECLARE @b2 INT = 0;
SELECT @b2 = COUNT(*) FROM bronze.disease_outbreaks;
 
INSERT INTO bronze.disease_outbreaks (
    [Province/State], [Country/Region], Lat, Long, Date,
    Confirmed, Deaths, Recovered, Active, [WHO Region]
)
SELECT
    [Province/State], [Country/Region], Lat, Long, Date,
    Confirmed, Deaths, Recovered, Active, [WHO Region]
FROM bronze.stg_disease;
 
DECLARE @a2 INT;
SELECT @a2 = COUNT(*) FROM bronze.disease_outbreaks;
INSERT INTO bronze.ingestion_log (table_name, src_file, rows_before, rows_after, notes)
VALUES ('bronze.disease_outbreaks', 'disease_outbreaks.csv',
        @b2, @a2, 'Full load – covid_19_clean_complete.csv – expected ~49068 rows');
PRINT 'DS2 bronze loaded: ' + CAST(@a2 - @b2 AS NVARCHAR) + ' rows';
 
DROP TABLE bronze.stg_disease;
GO
 
-- ── DS3: staging → bronze (UNPIVOT wide → long) ──────────────
DECLARE @b3 INT = 0;
SELECT @b3 = COUNT(*) FROM bronze.hospital_capacity;

INSERT INTO bronze.hospital_capacity (
    Entity, Code, Year, [Hospital beds (per 1,000 people)]
)
SELECT
    [Country Name]  AS Entity,
    [Country Code]  AS Code,
    yr              AS Year,
    beds_value      AS [Hospital beds (per 1,000 people)]
FROM bronze.stg_hospital
UNPIVOT (
    beds_value FOR yr IN (
        [1960],[1961],[1962],[1963],[1964],[1965],[1966],[1967],[1968],[1969],
        [1970],[1971],[1972],[1973],[1974],[1975],[1976],[1977],[1978],[1979],
        [1980],[1981],[1982],[1983],[1984],[1985],[1986],[1987],[1988],[1989],
        [1990],[1991],[1992],[1993],[1994],[1995],[1996],[1997],[1998],[1999],
        [2000],[2001],[2002],[2003],[2004],[2005],[2006],[2007],[2008],[2009],
        [2010],[2011],[2012],[2013],[2014],[2015],[2016],[2017],[2018],[2019]
    )
) AS unpvt
-- UNPIVOT already excludes NULL cells; this also drops empty-string
-- placeholders that the World Bank CSV uses for missing years.
WHERE NULLIF(TRIM(beds_value), '') IS NOT NULL;
 
DECLARE @a3 INT;
SELECT @a3 = COUNT(*) FROM bronze.hospital_capacity;
INSERT INTO bronze.ingestion_log (table_name, src_file, rows_before, rows_after, notes)
VALUES ('bronze.hospital_capacity', 'hospital_capacity.csv',
        @b3, @a3, 'Full load – hospital_beds.csv – expected ~4700 rows');
PRINT 'DS3 bronze loaded: ' + CAST(@a3 - @b3 AS NVARCHAR) + ' rows';
 
DROP TABLE bronze.stg_hospital;
GO
 
-- ═════════════════════════════════════════════════════════════
-- BRONZE VERIFICATION
-- ═════════════════════════════════════════════════════════════
PRINT '=== BRONZE LOAD SUMMARY ===';
SELECT table_name, src_file, rows_loaded, loaded_at, notes
FROM bronze.ingestion_log ORDER BY loaded_at;
 
PRINT '=== BRONZE ROW COUNTS ===';
SELECT 'bronze.who_health_indicators' AS [table],
       COUNT(*)                       AS total_rows,
       COUNT(DISTINCT Country)        AS distinct_countries,
       COUNT(DISTINCT Year)           AS distinct_years,
       MIN(Year) AS min_year, MAX(Year) AS max_year
FROM bronze.who_health_indicators
UNION ALL
SELECT 'bronze.disease_outbreaks',
       COUNT(*), COUNT(DISTINCT [Country/Region]),
       COUNT(DISTINCT Date), MIN(Date), MAX(Date)
FROM bronze.disease_outbreaks
UNION ALL
SELECT 'bronze.hospital_capacity',
       COUNT(*), COUNT(DISTINCT Entity),
       COUNT(DISTINCT Year), MIN(Year), MAX(Year)
FROM bronze.hospital_capacity;
 
PRINT '=== NULL CHECK ON KEY COLUMNS ===';
SELECT 'DS1 - empty Country'           AS issue, COUNT(*) AS cnt
FROM bronze.who_health_indicators WHERE NULLIF(TRIM(ISNULL(Country,'')),'') IS NULL
UNION ALL SELECT 'DS1 - empty Year',    COUNT(*)
FROM bronze.who_health_indicators WHERE NULLIF(TRIM(ISNULL(Year,'')),'') IS NULL
UNION ALL SELECT 'DS2 - empty Country/Region', COUNT(*)
FROM bronze.disease_outbreaks WHERE NULLIF(TRIM(ISNULL([Country/Region],'')),'') IS NULL
UNION ALL SELECT 'DS2 - unparseable Date', COUNT(*)
FROM bronze.disease_outbreaks WHERE TRY_CAST(Date AS DATE) IS NULL
UNION ALL SELECT 'DS3 - empty Code',    COUNT(*)
FROM bronze.hospital_capacity WHERE NULLIF(TRIM(ISNULL(Code,'')),'') IS NULL
UNION ALL SELECT 'DS1 - duplicate Country+Year', COUNT(*) FROM (
    SELECT Country, Year FROM bronze.who_health_indicators
    GROUP BY Country, Year HAVING COUNT(*) > 1
) x;
 
PRINT '=== BRONZE ZONE COMPLETE ===';
GO