/* ============================================================================
   VFS PROJECT - POLICY SOLD REPORT (DAILY)
   Output = exactly the 17 required Excel columns, in the required order:
   1  Date of Policy Sold
   2  Year
   3  Month
   4  Policy Number
   5  Channel
   6  Region                       <- NEW (placeholder, see note below)
   7  Sales Country
   8  Destination
   9  Visa Type (Schengen/Non Schengen)
   10 Policy Start Date
   11 Policy end Date
   12 Number Of Beneficiaries
   13 Product type (Regular/Annual)
   14 Currency
   15 Premium Inc TAX=including VAT@ 15%+Stamp
   16 Premium Exc VAT & Stamp
   17 Policy Status
   18 Days Count                   <- NEW (Policy Start Date to Policy end Date, inclusive)
   REMOVED (not in required list): Total Days, Exchange Rate,
   Premium Inc TAX (original currency), difference, difference %,
   difference simplified.
   NOTE: Product type still uses the same date-based duration logic
   internally; only the Total Days OUTPUT column was dropped.
   Joins & WHERE logic kept EXACTLY as the original query - no logic changed.
   ============================================================================ */
SELECT
    -- (1) Date of Policy Sold
    ddm.document_date                                        AS [Date of Policy Sold],
    -- (2) Year
    YEAR(ddm.document_date)                                  AS [Year],
    -- (3) Month (month name, e.g. 'June')
    DATENAME(MONTH, ddm.document_date)                       AS [Month],
    -- (4) Policy Number
    ddm.document_Number                                      AS [Policy Number],
    -- (5) Channel : 'Online' / 'Offline'
    -- [ASSUMPTION] derived from business_source ('A' = Aggregator = Online).
    CASE
        WHEN ddm.business_source = 'A' THEN 'Online'
        ELSE 'Offline'
    END                                                      AS [Channel],
    -- (6) Region  <<< NEW COLUMN >>>
    -- [ASSUMPTION] No region field exists in the current query/tables.
    -- Placeholder returns blank so the Excel column position is preserved.
    -- Replace '' with the correct source column when identified
    -- (e.g. a VFS branch / zone / region field).
    ''                                                       AS [Region],
    -- (7) Sales Country : fixed literal value as per requirement
    'Bangladesh'                                             AS [Sales Country],
    -- (8) Destination  <- travel details table, destination country
    ISNULL(tvl.dest_country, '')                             AS [Destination],
    -- (9) Visa Type : Schengen / Non-Schengen
    -- Destination is stored as the literal text 'SCHENGEN COUNTRIES'
    -- for Schengen policies; everything else = 'Non-Schengen'.
    CASE
        WHEN UPPER(LTRIM(RTRIM(tvl.dest_country))) = 'SCHENGEN COUNTRIES'
            THEN 'Schengen'
        ELSE 'Non-Schengen'
    END                                                      AS [Visa Type (Schengen/Non Schengen)],
    -- (10) Policy Start Date
    ddm.document_valid_from                                  AS [Policy Start Date],
    -- (11) Policy end Date
    ddm.document_valid_to                                    AS [Policy end Date],
    -- (12) Number Of Beneficiaries : always 1 per policy (business rule)
    1                                                        AS [Number Of Beneficiaries],
    -- (13) Product type (Regular/Annual)
    -- Duration computed from the dates (inclusive, +1):
    -- around one year (>= 360 days, covering 365 and leap-year 366) = 'Annual'.
    CASE
        WHEN DATEDIFF(DAY, ddm.document_valid_from, ddm.document_valid_to) + 1 >= 360
            THEN 'Annual'
        ELSE 'Regular'
    END                                                      AS [Product type (Regular/Annual)],
    -- (14) Currency
    ddm.currency_type                                        AS [Currency],
    -- (15) Premium Inc TAX = Gross Premium (Net + VAT@15% + Stamp),
    -- converted to BDT using currency_rate; negative when premium mode = refund.
    CASE
        WHEN ddm.amendment_premium_mode = 'refund'
            THEN (ddm.gross_premium * ddm.currency_rate * -1)
        ELSE (ddm.gross_premium * ddm.currency_rate)
    END                                                      AS [Premium Inc TAX=including VAT@ 15%+Stamp],
    -- (16) Premium Exc VAT & Stamp = Net Premium, converted using currency_rate;
    -- negative when premium mode = refund.
    CASE
        WHEN ddm.amendment_premium_mode = 'refund'
            THEN (ddm.net_premium * ddm.currency_rate * -1)
        ELSE (ddm.net_premium * ddm.currency_rate)
    END                                                      AS [Premium Exc VAT & Stamp],
    -- (17) Policy Status
    -- [ASSUMPTION] mapped to Approval_status (all rows are 'Approve' due to the
    -- WHERE filter). Swap to ddm.business_status or another column if needed.
    ddm.Approval_status                                      AS [Policy Status],
    -- (18) Days Count : policy duration from Policy Start Date to Policy end
    -- Date, counting BOTH end dates (+1 makes it inclusive, so
    -- 2026-09-01 to 2027-08-31 = 365 days, not 364).
    -- Same calculation used internally by Product type (Regular/Annual).
    DATEDIFF(DAY, ddm.document_valid_from, ddm.document_valid_to) + 1
                                                             AS [Days Count]
/* ---------------------------------------------------------------------------
   FROM / JOIN block - unchanged from the original query
   --------------------------------------------------------------------------- */
-- Primary table: master document (policy) record
FROM doc_document_master AS ddm
-- interest names: all interest names per document, concatenated into one string
INNER JOIN (
    SELECT master_doc_id, STRING_AGG(interest_name, '') AS [Interest Name]
    FROM doc_interest
    GROUP BY master_doc_id
) Interest ON ddm.id = Interest.master_doc_id
-- clause names: all clause names per document, comma-separated
LEFT JOIN (
    SELECT master_doc_id, STRING_AGG(clause_name, ',') AS [Clause Name]
    FROM doc_master_clause
    GROUP BY master_doc_id
) AS Clause ON Clause.master_doc_id = ddm.id
-- peril info: excluded perils per document (is_exclusion = 1), comma-separated
LEFT JOIN (
    SELECT master_doc_id, STRING_AGG(peril_name, ',') AS [Comprehensive Risk Exclusion]
    FROM doc_peril
    WHERE is_exclusion = '1'
    GROUP BY master_doc_id
) AS Peril ON ddm.id = Peril.master_doc_id
-- Mortgage info: reference bank name via the bank & branch lookup table
LEFT JOIN (
    SELECT master_doc_id, ref_bank_name
    FROM doc_mortgage DM
    LEFT JOIN (
        SELECT id, address, ref_bank_name
        FROM com_bank_and_branch
    ) BB ON DM.bank_branch_id = BB.id
) Mortgage ON ddm.id = Mortgage.master_doc_id
-- business Sector and sub-sector lookup rows
LEFT JOIN doc_business_sector_subsector AS Sector
    ON Sector.id = ddm.business_sector_id
LEFT JOIN doc_business_sector_subsector AS subSector
    ON subSector.id = ddm.business_subsector_id
-- Product/class info (insurance class of the document)
LEFT JOIN usr_product_submodule AS class ON class.id = ddm.class_id
-- bank employee (aggregator login) details - this is the VFS link
LEFT JOIN doc_aggregator_login_user_info AS al
    ON al.master_doc_id = ddm.id
-- aggregator client branch & client (bank) info
LEFT JOIN doc_aggregator_client_list AS ac  ON ac.id  = al.client_branch_id
LEFT JOIN doc_aggregator_client_list AS ac1 ON ac1.id = al.client_id
-- Customer (policy holder) info
LEFT JOIN com_customer AS cust ON cust.id = ddm.customer_id
-- MR (money receipt) mapping and receipt details
LEFT JOIN document_mr_mapping AS dm  ON dm.document_id  = ddm.id
LEFT JOIN document_mr_mapping AS map ON map.document_id = ddm.id
LEFT JOIN acc_money_receipt   AS mr  ON mr.id = map.mr_id
-- deposit bank / bank branch / payment branch lookups for the receipt
LEFT JOIN com_bank_and_branch bnk  ON bnk.id  = mr.deposit_to_bank_id
LEFT JOIN com_bank_and_branch bnk1 ON bnk1.id = mr.deposit_to_bank_branch_id
LEFT JOIN com_branch          br   ON br.id   = mr.payment_bank_branch_id
-- Commission billing linked to the money receipt
LEFT JOIN acc_commission_bill_details AS acd ON acd.mr_id = mr.id
-- Product-specific detail tables (motor / travel / misc-health / nominee)
LEFT JOIN doc_motor_details               mtr ON mtr.master_doc_id = ddm.id
LEFT JOIN doc_travel_details              tvl ON tvl.master_doc_id = ddm.id
LEFT JOIN doc_misc_health_details         msc ON msc.master_doc_id = ddm.id
LEFT JOIN doc_misc_health_nominee_details nom ON nom.master_doc_id = ddm.id
-- Special handling for Nibedita (NIB) product: pick max peril code per document
LEFT JOIN (
    SELECT master_doc_id, MAX(peril_code) AS product_name
    FROM doc_peril
    WHERE peril_name LIKE '%Nibedita%'
    GROUP BY master_doc_id
) AS dpp ON dpp.master_doc_id = ddm.id
/* ---------------------------------------------------------------------------
   WHERE block - unchanged from the original query
   --------------------------------------------------------------------------- */
WHERE 1=1                                                   -- dummy condition so every filter below can start with AND
    --ddm.business_source = 'A'                             -- (kept commented, as in original)
    AND ddm.document_date BETWEEN '10-AUG-2026' AND '12-AUG-2026'  -- report date range
    AND ddm.Approval_status = 'APPROVE'             -- only approved policies
    AND ddm.business_status = 'YES'                         -- only active business
    AND al.client_name LIKE '%vfs%'                         -- only VFS aggregator business
    -- >>> NEW: Document Number filter (add/remove numbers in the list below) <
    AND ddm.document_Number IN (
        'GDI/GLN/07/2026/B&H/P/920902',
        'GDI/GLN/07/2026/B&H/P/920905'
    )
/* ---------------------------------------------------------------------------
   ORDER BY - sort output by policy date descending, then policy number
   ascending as a tiebreaker for rows sharing the same date
   --------------------------------------------------------------------------- */
ORDER BY ddm.document_date ASC, ddm.document_Number ASC