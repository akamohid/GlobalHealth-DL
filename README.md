<div align="center">

# 🏥 GlobalHealth-DL

### Healthcare Data Lake on SQL Server — Medallion Architecture for WHO & Outbreak Analytics

[![SQL Server](https://img.shields.io/badge/SQL_Server-2022-CC2927?style=flat-square&logo=microsoftsqlserver)](https://www.microsoft.com/en-us/sql-server)
[![SSMS](https://img.shields.io/badge/SSMS-22-0078D4?style=flat-square&logo=microsoft)](https://learn.microsoft.com/en-us/sql/ssms/)
[![Architecture](https://img.shields.io/badge/Architecture-Medallion-gold?style=flat-square)]()
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

> 🗄️ A three-layer healthcare data lake built on SQL Server 2022, following the **Medallion Architecture** (Bronze → Silver → Gold). Raw CSV datasets covering WHO health indicators, disease outbreaks, and hospital capacity are ingested, cleaned, and curated into analytical views ready for BI reporting.

</div>

---

## 📋 Contents

- [About the Project](#-about-the-project)
- [Architecture](#-architecture)
- [Datasets](#-datasets)
- [Repo Structure](#-repo-structure)
- [Getting Started](#-getting-started)
- [BI Visuals](#-bi-visuals)
- [Team](#-team)

---

## 🔍 About the Project

Healthcare data is messy — inconsistent formats, missing values, and mixed sources make raw ingestion unreliable for analysis. This project implements a production-style **data lake pipeline** on SQL Server 2022 that ingests raw WHO and outbreak CSV data, validates and cleans it through a structured medallion pipeline, and exposes curated analytical views for Power BI reporting.

Key engineering decisions:
- **SHA-256 row hashing** at ingest for downstream deduplication
- **Quarantine schema** for failed silver validations — no silent data loss
- **Ingestion log table** tracking row counts and timestamps per load
- **Demo load scripts** with a trimmed dataset for fast local testing

---

## 🏗️ Architecture

The pipeline runs across four schemas inside the `DWBI_HealthCare` database:

| Layer | Schema | Description |
|---|---|---|
| 🟤 **Bronze** | `bronze` | Raw landing zone — all columns typed `NVARCHAR`, SHA-256 hash computed, ingestion log populated |
| ⚪ **Silver** | `silver` | Cleaned & typed — casts to `INT`, `DECIMAL`, `DATE`; invalid rows routed to quarantine |
| 🟡 **Gold** | `gold` | Analytical views — country health profiles, outbreak summaries, hospital capacity metrics |
| 🚫 **Quarantine** | `quarantine` | Holds rows failing silver validation for review and reprocessing |

```
CSV Files (Bronze)
      │
      ▼
  Raw Ingest ──► Ingestion Log + SHA-256 Hash
      │
      ▼
  Silver Cleaning ──► Type Casting + Null Handling ──► Quarantine (failures)
      │
      ▼
  Gold Views ──► Power BI / SSMS Reporting
```

---

## 📦 Datasets

| File | Description | Scope |
|---|---|---|
| `who_health_indicators.csv` | Life expectancy, mortality, GDP, vaccination rates | 193 countries |
| `disease_outbreaks.csv` | Historical disease outbreak records | Global |
| `hospital_capacity.csv` | Hospital capacity figures (raw) | Global |
| `hospital_capacity_clean.csv` | Pre-cleaned hospital capacity data | Global |

---

## 📁 Repo Structure

```
GlobalHealth-DL/
│
├── bronze/                              Raw source CSV files
│   ├── disease_outbreaks.csv
│   ├── hospital_capacity.csv
│   ├── hospital_capacity_clean.csv
│   └── who_health_indicators.csv
│
├── sql/                                 Main scripts — full dataset load
│   ├── 00_create_database.sql           Creates DWBI_HealthCare DB + all 4 schemas
│   ├── 01_bronze_landing_FULL.sql       Ingests raw CSVs into bronze schema
│   ├── 02_silver_cleaning_FULL.sql      Cleans, casts, validates → silver + quarantine
│   └── 03_gold_curated_FULL.sql         Builds analytical views in gold schema
│
├── sql_outputs/                         SSMS execution screenshots (full load)
│   ├── 00_db_creation.png
│   ├── 01_bronze_messages.png
│   ├── 01_bronze_results.png
│   ├── 02_silver_messages.png
│   ├── 02_silver_results.png
│   ├── 03_gold_messages.png
│   └── 03_gold_results.png
│
├── sql_demo/                            Trimmed demo scripts (lighter dataset)
│   ├── 00_create_database.sql
│   ├── 01_bronze_landing.sql
│   ├── 02_silver_cleaning.sql
│   └── 03_gold_curated.sql
│
├── sql_demo_outputs/                    SSMS execution screenshots (demo load)
│   ├── 00_db_creation_demo.png
│   ├── 01_bronze_demo.png
│   ├── 02_silver_demo.png
│   └── 03_gold_demo.png
│
├── visuals/                             Power BI report + exported visuals
│   ├── GlobalHealth.pbix
│   ├── visuals_x1.pdf
│   └── visuals_x2.pdf
│
├── presentation/
│   └── GlobalHealth-DL.pptx            Project slide deck
│
├── report/
│   └── Report.docx                      Full project report
│
├── .gitignore
├── requirements.txt
└── README.md
```

---

## 🚀 Getting Started

**Prerequisites**

- [SQL Server Express 2022](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)
- [SSMS 22](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms)

**Setup**

1. Clone the repository:
```bash
git clone https://github.com/akamohid/GlobalHealth-DL.git
cd GlobalHealth-DL
```

2. Update the file paths in all `BULK INSERT` statements inside the `sql/` scripts to match your local machine's directory.

3. Run the scripts in order via SSMS:

```
1. sql/00_create_database.sql       →  Creates DB + schemas
2. sql/01_bronze_landing_FULL.sql   →  Loads raw CSV data
3. sql/02_silver_cleaning_FULL.sql  →  Cleans + validates
4. sql/03_gold_curated_FULL.sql     →  Builds analytical views
```

> 💡 Want a faster test run? Use the scripts inside `sql_demo/` in the same order — same structure, trimmed dataset.

---

## 📊 BI Visuals

Power BI report (`visuals/GlobalHealth.pbix`) connects to the gold-layer views and includes:

- 🌍 Country health profiles — latest WHO indicators per country
- 🦠 Disease outbreak summaries — frequency and severity trends
- 🏨 Hospital capacity metrics — beds per population, regional comparisons

Exported PDF snapshots are available in `visuals/` for quick reference without Power BI Desktop.

---

## 👥 Team

**DS 312 — Data Warehousing & Business Intelligence | Term Project**

| Name | Student ID |
|---|---|
| Mohid Arshad | 455977 |
| Tahir Mehmood | 458593 |
| Mohammad Hasnain | 462247 |

---

<div align="center">
Built with 🏥 healthcare data, ⚙️ SQL, and way too many <code>BULK INSERT</code> path fixes.
</div>
