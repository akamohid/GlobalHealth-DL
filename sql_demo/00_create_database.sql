-- ============================================================
-- DS 312 Term Project: Healthcare Data Lake
-- Script 00: Database & Schema Setup
-- Platform: SQL Server 2022 (SSMS 22)
-- Run this FIRST before any other script
-- ============================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'HealthcareDL')
BEGIN
    CREATE DATABASE HealthcareDL;
    PRINT 'Database HealthcareDL created.';
END
ELSE
    PRINT 'Database HealthcareDL already exists – skipping creation.';
GO

USE HealthcareDL;
GO

-- Create schemas if they do not already exist
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC('CREATE SCHEMA bronze');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'quarantine')
    EXEC('CREATE SCHEMA quarantine');
GO

PRINT 'All 4 schemas ready: bronze | silver | gold | quarantine';
GO
