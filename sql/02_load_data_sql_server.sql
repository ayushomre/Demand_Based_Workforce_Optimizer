/*
Enable SQLCMD mode in SSMS before running this script.
Update DataPath to the absolute path of the project's data folder.
*/

:setvar DataPath "C:\Demand_Based_Workforce_Optimizer\data"

USE WorkforceOptimizer;
GO

BULK INSERT dbo.dim_facility
FROM '$(DataPath)\raw\dim_facility.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT dbo.dim_shift
FROM '$(DataPath)\raw\dim_shift.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT dbo.dim_date
FROM '$(DataPath)\raw\dim_date.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT dbo.fact_shift_operations
FROM '$(DataPath)\raw\fact_shift_operations.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT dbo.fact_optimized_plan
FROM '$(DataPath)\processed\fact_optimized_plan.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', ROWTERMINATOR = '0x0a', TABLOCK);
GO

-- Load validation: expected row counts are 5, 3, 123, 1,380, and 465.
SELECT 'dim_facility' AS table_name, COUNT(*) AS row_count FROM dbo.dim_facility
UNION ALL SELECT 'dim_shift', COUNT(*) FROM dbo.dim_shift
UNION ALL SELECT 'dim_date', COUNT(*) FROM dbo.dim_date
UNION ALL SELECT 'fact_shift_operations', COUNT(*) FROM dbo.fact_shift_operations
UNION ALL SELECT 'fact_optimized_plan', COUNT(*) FROM dbo.fact_optimized_plan;
GO

