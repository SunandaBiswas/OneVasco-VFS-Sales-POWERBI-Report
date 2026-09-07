# VFS Dashboard

**Travel & visa insurance analytics for Green Delta Insurance, built in Power BI.**

A two-page Power BI dashboard that tracks travel/visa insurance policies sold to applicants processed through VFS visa application centers, covering both Schengen and Non-Schengen visa categories. It gives Green Delta Insurance an executive-level view of premium performance alongside full policy-level detail, all reported in BDT.

## Pages

### 1. At a Glance
An executive summary view designed to be read at a glance, with no digging required:

- **KPI cards** — Total Premium, YTD Premium, Avg Coverage Duration, Avg Premium per Policy, Total Policies, Policies Expiring in the Next 30 Days, and Active Policies.
- **Total Premium by Year Month** — a trend line showing premium revenue over time.
- **Filters** — Date of Policy Sold (date range) and Visa Types (Schengen / Non-Schengen), both with multi-select "Select all" dropdowns.

### 2. PolicyWiseData
A searchable, filterable table of every individual policy, for detailed lookups and audits:

- Policy Number, Policy Status (Active / Inactive)
- Premium excluding VAT & stamp, and premium including VAT & stamp
- Product type (Regular / Annual), Sales Country, Visa Type
- Coverage Band and Day Coverage
- **Filters** — Date of Policy Sold, Policy Number, Visa Types, and Year Month, all with multi-select "Select all" dropdowns.

## Design

The dashboard uses a consistent Green Delta Insurance brand theme — dark green backgrounds with gold accent text — applied uniformly across KPI cards, the trend chart, the data table, and all filter dropdowns, for a clean, uncluttered, executive-friendly look on both pages.

## Built With

- Power BI Desktop

## Data

Policy-level data (policy number, status, premiums, product type, visa type, coverage) sourced from Green Delta Insurance's VFS-channel policy records.
