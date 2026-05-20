-- ============================================================
-- DS 312 Term Project: Healthcare Data Lake
-- Script 01: Bronze Zone – Landing Tables + Data Load
-- ============================================================
-- DATASETS (exact Kaggle column names confirmed):
--
-- DS1: Life Expectancy Data.csv  → who_health_indicators.csv
--      Source : kaggle.com/datasets/kumarajarshi/life-expectancy-who
--      License: CC0 Public Domain
--      Rows   : 2,938  |  Columns: 22
--      Exact header:
--        Country,Year,Status,Life expectancy,Adult Mortality,infant deaths,
--        Alcohol,percentage expenditure,Hepatitis B,Measles, BMI ,
--        under-five deaths ,Polio,Total expenditure,Diphtheria, HIV/AIDS ,
--        GDP,Population, thinness  1-19 years, thinness 5-9 years ,
--        Income composition of resources,Schooling
--
-- DS2: covid_19_clean_complete.csv → disease_outbreaks.csv
--      Source : kaggle.com/datasets/imdevskp/corona-virus-report
--      License: CC0 Public Domain
--      Rows   : ~49,068  |  Columns: 10
--      Exact header:
--        Province/State,Country/Region,Lat,Long,Date,
--        Confirmed,Deaths,Recovered,Active,WHO Region
--
-- DS3: hospital_beds.csv → hospital_capacity.csv
--      Source : kaggle.com/datasets/hamzael1/hospital-beds-by-country
--      License: CC BY 4.0  (World Bank / WHO)
--      Rows   : ~4,700  |  Columns: 4
--      Exact header:
--        Entity,Code,Year,Hospital beds (per 1,000 people)
-- ============================================================

USE HealthcareDL;
GO

-- ─────────────────────────────────────────────────────────────
-- INGESTION LOG  (tracks every pipeline run)
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('bronze.ingestion_log','U') IS NOT NULL DROP TABLE bronze.ingestion_log;
GO
CREATE TABLE bronze.ingestion_log (
    log_id      INT IDENTITY(1,1) PRIMARY KEY,
    table_name  NVARCHAR(200) NOT NULL,
    src_file    NVARCHAR(500) NOT NULL,
    rows_loaded INT           NOT NULL DEFAULT 0,
    loaded_at   DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    notes       NVARCHAR(MAX)
);
GO

-- ─────────────────────────────────────────────────────────────
-- BRONZE TABLE 1: who_health_indicators
-- Column names are EXACTLY as they appear in the CSV header,
-- including spaces and special characters (wrapped in []).
-- ALL columns are NVARCHAR – zero type coercion in Bronze.
-- ─────────────────────────────────────────────────────────────
IF OBJECT_ID('bronze.who_health_indicators','U') IS NOT NULL DROP TABLE bronze.who_health_indicators;
GO
CREATE TABLE bronze.who_health_indicators (
    -- 22 exact source columns (note spaces in original headers)
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
    BMI                                 NVARCHAR(20),       -- original header has spaces: " BMI "
    [under-five deaths]                 NVARCHAR(20),       -- original: "under-five deaths "
    Polio                               NVARCHAR(20),
    [Total expenditure]                 NVARCHAR(20),
    Diphtheria                          NVARCHAR(20),
    [HIV/AIDS]                          NVARCHAR(20),       -- original: " HIV/AIDS "
    GDP                                 NVARCHAR(30),
    Population                          NVARCHAR(30),
    [thinness 1-19 years]               NVARCHAR(20),       -- original: " thinness  1-19 years"
    [thinness 5-9 years]                NVARCHAR(20),       -- original: " thinness 5-9 years "
    [Income composition of resources]   NVARCHAR(20),
    Schooling                           NVARCHAR(20),

    -- Ingestion metadata (NOT in source file – added on load)
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
    Date              NVARCHAR(30),      -- raw string e.g. '2020-01-22'
    Confirmed         NVARCHAR(30),
    Deaths            NVARCHAR(30),
    Recovered         NVARCHAR(30),
    Active            NVARCHAR(30),
    [WHO Region]      NVARCHAR(200),

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
    Entity                              NVARCHAR(200),   -- country name
    Code                                NVARCHAR(10),    -- ISO-3 country code
    Year                                NVARCHAR(10),
    [Hospital beds (per 1,000 people)]  NVARCHAR(30),

    _src_file    NVARCHAR(500) NOT NULL DEFAULT 'hospital_capacity.csv',
    _ingested_at DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    _row_hash    AS CONVERT(NVARCHAR(64),
                     HASHBYTES('SHA2_256',
                         ISNULL(Code,'') + '|' + ISNULL(Year,'')), 2) PERSISTED
);
GO

PRINT 'All 3 bronze landing tables created.';
GO

-- ─────────────────────────────────────────────────────────────
-- BULK INSERT  (REAL DATA LOAD)
-- Uncomment this block after placing renamed CSVs in the folder.
-- File path: C:\ds312_datalake\bronze\raw_files\
-- ─────────────────────────────────────────────────────────────
/*
BULK INSERT bronze.who_health_indicators
FROM 'C:\ds312_datalake\bronze\raw_files\who_health_indicators.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n',
      CODEPAGE='65001', TABLOCK);

BULK INSERT bronze.disease_outbreaks
FROM 'C:\ds312_datalake\bronze\raw_files\disease_outbreaks.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n',
      CODEPAGE='65001', TABLOCK);

BULK INSERT bronze.hospital_capacity
FROM 'C:\ds312_datalake\bronze\raw_files\hospital_capacity.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n',
      CODEPAGE='65001', TABLOCK);
*/

-- ─────────────────────────────────────────────────────────────
-- DEMO / SAMPLE DATA
-- Matches exact real column structure. Includes intentional
-- bad rows to trigger every quality gate in Script 02.
-- ─────────────────────────────────────────────────────────────
DELETE FROM bronze.who_health_indicators;
DELETE FROM bronze.disease_outbreaks;
DELETE FROM bronze.hospital_capacity;

-- ── DS1: WHO Life Expectancy (22 columns) ────────────────────
-- Source: confirmed header from raw CSV on GitHub mirror
-- Country,Year,Status,Life expectancy,Adult Mortality,infant deaths,
-- Alcohol,percentage expenditure,Hepatitis B,Measles, BMI ,under-five deaths ,
-- Polio,Total expenditure,Diphtheria, HIV/AIDS ,GDP,Population,
--  thinness  1-19 years, thinness 5-9 years ,
-- Income composition of resources,Schooling
INSERT INTO bronze.who_health_indicators
  (Country,Year,Status,[Life expectancy],[Adult Mortality],[infant deaths],
   Alcohol,[percentage expenditure],[Hepatitis B],Measles,BMI,[under-five deaths],
   Polio,[Total expenditure],Diphtheria,[HIV/AIDS],GDP,Population,
   [thinness 1-19 years],[thinness 5-9 years],
   [Income composition of resources],Schooling)
VALUES
-- 10 clean representative rows
('Pakistan',      '2015','Developing','66.5','178','146','0.1','17.6','85','4809','24.6','174','85','2.8','85','0.1','1194.8','185132000','5.3','5.1','0.52','8.1'),
('Pakistan',      '2014','Developing','66.1','181','152','0.1','16.9','84','4423','24.1','182','82','2.7','84','0.1','1147.0','182142594','5.5','5.3','0.51','7.9'),
('India',         '2015','Developing','68.3','164','1414','2.6','73.5','78','38545','18.8','1693','72','3.9','72','0.1','1582.4','1293859294','21.5','21.6','0.60','11.7'),
('India',         '2014','Developing','67.9','167','1447','2.6','68.5','76','31671','18.2','1752','70','3.8','70','0.1','1556.6','1278138903','21.8','22.0','0.59','11.5'),
('Afghanistan',   '2015','Developing','65.0','263','62','0.01','71.3','65','1154','19.1','83','6','8.2','65','0.1','594.7','33736494','17.2','17.3','0.479','10.1'),
('Afghanistan',   '2014','Developing','59.9','271','64','0.01','73.5','62','492','18.6','86','58','8.2','62','0.1','612.7','327582','17.5','17.5','0.476','10.0'),
('Iran (Islamic Republic of)','2015','Developing','75.4','96','16','0.1','352.0','99','33','23.8','18','99','7.3','99','0.1','4953.0','79109272','3.0','3.0','0.75','15.3'),
('Saudi Arabia',  '2015','Developing','74.4','89','12','0.0','1574.9','98','220','27.5','14','98','4.4','98','0.1','20376.9','31557144','4.9','5.3','0.84','16.3'),
('Bangladesh',    '2015','Developing','72.0','128','116','0.0','33.9','97','1093','22.9','140','97','2.7','97','0.1','1086.0','156256278','15.3','15.5','0.56','10.2'),
('China',         '2015','Developing','76.1','93','162','7.2','419.8','99','1406','','190','99','5.5','99','0.1','8069.2','1376048943','4.0','3.8','0.73','13.1'),
-- 4 intentional bad rows (one per quality gate)
('',              '2015','Developing','66.5','178','146','0.1','17.6','85','4809','24.6','174','85','2.8','85','0.1','1194.8','185132000','5.3','5.1','0.52','8.1'),  -- QG-001: empty Country
('Pakistan',      '9999','Developing','66.5','178','146','0.1','17.6','85','4809','24.6','174','85','2.8','85','0.1','1194.8','185132000','5.3','5.1','0.52','8.1'),  -- QG-002: invalid year
('Pakistan',      '2015','Developing','66.5','178','146','0.1','17.6','85','4809','24.6','174','85','2.8','85','0.1','1194.8','185132000','5.3','5.1','0.52','8.1'),  -- QG-003: duplicate PAK 2015
(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);                                                       -- QG-001: fully null row

-- ── DS2: COVID-19 Clean Complete (10 columns) ─────────────────
INSERT INTO bronze.disease_outbreaks
  ([Province/State],[Country/Region],Lat,Long,Date,
   Confirmed,Deaths,Recovered,Active,[WHO Region])
VALUES
-- 12 clean rows
(NULL,'Pakistan',     '30.3753','69.3451','2020-03-26','1063','8','17','1038','Eastern Mediterranean'),
(NULL,'Pakistan',     '30.3753','69.3451','2020-06-01','72460','1543','26317','44600','Eastern Mediterranean'),
(NULL,'India',        '20.5937','78.9629','2020-03-26','694','16','64','614','South-East Asia'),
(NULL,'India',        '20.5937','78.9629','2020-06-01','190609','5408','91817','93384','South-East Asia'),
(NULL,'Afghanistan',  '33.9391','67.7100','2020-04-15','714','25','65','624','Eastern Mediterranean'),
(NULL,'Afghanistan',  '33.9391','67.7100','2020-06-01','15205','257','1328','13620','Eastern Mediterranean'),
(NULL,'Iran',         '32.4279','53.6880','2020-03-26','29406','2234','10457','16715','Eastern Mediterranean'),
(NULL,'Iran',         '32.4279','53.6880','2020-06-01','154445','7921','122650','23874','Eastern Mediterranean'),
(NULL,'Saudi Arabia', '23.8859','45.0792','2020-06-01','87142','524','63224','23394','Eastern Mediterranean'),
(NULL,'Bangladesh',   '23.6850','90.3563','2020-06-01','52445','711','11053','40681','South-East Asia'),
(NULL,'China',        '30.9756','112.2707','2020-01-22','548','17','28','503','Western Pacific'),
(NULL,'China',        '30.9756','112.2707','2020-03-01','79968','2873','41625','35470','Western Pacific'),
-- 3 intentional bad rows
(NULL,NULL,           '0.0','0.0','2020-03-26','100','2','10','88','Unknown'),            -- QG-001: null Country/Region
(NULL,'Unknown',      '0.0','0.0','13-45-2023','abc','xyz','0','0','Unknown'),             -- QG-002: bad date + QG-005: non-numeric
(NULL,'Pakistan',     '30.3753','69.3451','2020-03-26','1063','8','17','1038','Eastern Mediterranean'); -- QG-003: duplicate

-- ── DS3: Hospital Beds by Country (4 columns) ─────────────────
INSERT INTO bronze.hospital_capacity (Entity, Code, Year, [Hospital beds (per 1,000 people)])
VALUES
('Pakistan',     'PAK','2017','0.6'),
('Pakistan',     'PAK','2018','0.6'),
('India',        'IND','2017','0.5'),
('India',        'IND','2018','0.5'),
('Iran',         'IRN','2017','1.6'),
('Iran',         'IRN','2018','1.6'),
('Afghanistan',  'AFG','2017','0.4'),
('Afghanistan',  'AFG','2018','0.4'),
('Saudi Arabia', 'SAU','2017','2.2'),
('Saudi Arabia', 'SAU','2018','2.2'),
('Bangladesh',   'BGD','2016','0.8'),
('Bangladesh',   'BGD','2017','0.8'),
-- 3 intentional bad rows
('',             '',   '2019','1.0'),              -- QG-001: empty Entity + Code
('Unknown',      'ZZZ','2019','0.5'),              -- QG-004: invalid ISO (length=3 but not real)
('Pakistan',     'PAK','2017','0.6');              -- QG-003: duplicate PAK 2017

-- ── Update ingestion log ──────────────────────────────────────
INSERT INTO bronze.ingestion_log (table_name, src_file, rows_loaded, notes)
SELECT 'bronze.who_health_indicators','who_health_indicators.csv',
       COUNT(*),'Demo load – 14 rows (10 valid + 4 intentional bad rows)' FROM bronze.who_health_indicators;

INSERT INTO bronze.ingestion_log (table_name, src_file, rows_loaded, notes)
SELECT 'bronze.disease_outbreaks','disease_outbreaks.csv',
       COUNT(*),'Demo load – 15 rows (12 valid + 3 intentional bad rows)' FROM bronze.disease_outbreaks;

INSERT INTO bronze.ingestion_log (table_name, src_file, rows_loaded, notes)
SELECT 'bronze.hospital_capacity','hospital_capacity.csv',
       COUNT(*),'Demo load – 15 rows (12 valid + 3 intentional bad rows)' FROM bronze.hospital_capacity;

PRINT '=== BRONZE ZONE COMPLETE ===';
SELECT table_name, src_file, rows_loaded, loaded_at, notes
FROM bronze.ingestion_log ORDER BY loaded_at;
GO
