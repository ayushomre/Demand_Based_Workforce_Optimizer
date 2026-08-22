/*
Demand-Based Workforce and Shift Capacity Optimizer
SQL Server schema

Run in SQL Server Management Studio. The script creates a dedicated database and
recreates only the objects inside that database so it is safe to rerun for this project.
*/

IF DB_ID('WorkforceOptimizer') IS NULL
    CREATE DATABASE WorkforceOptimizer;
GO

USE WorkforceOptimizer;
GO

DROP VIEW IF EXISTS dbo.vw_optimization_impact;
DROP VIEW IF EXISTS dbo.vw_shift_performance;
DROP TABLE IF EXISTS dbo.fact_optimized_plan;
DROP TABLE IF EXISTS dbo.fact_shift_operations;
DROP TABLE IF EXISTS dbo.dim_date;
DROP TABLE IF EXISTS dbo.dim_shift;
DROP TABLE IF EXISTS dbo.dim_facility;
GO

CREATE TABLE dbo.dim_facility (
    facility_id                 VARCHAR(10)     NOT NULL PRIMARY KEY,
    facility_name               VARCHAR(100)    NOT NULL,
    city                        VARCHAR(50)     NOT NULL,
    region                      VARCHAR(20)     NOT NULL,
    demand_scale                DECIMAL(8,4)    NOT NULL,
    max_fte_per_shift           INT             NOT NULL,
    max_contract_per_shift      INT             NOT NULL,
    fte_productivity            DECIMAL(8,2)    NOT NULL,
    contract_productivity       DECIMAL(8,2)    NOT NULL,
    fte_hourly_cost             DECIMAL(10,2)   NOT NULL,
    contract_hourly_cost        DECIMAL(10,2)   NOT NULL,
    overtime_hourly_cost        DECIMAL(10,2)   NOT NULL
);

CREATE TABLE dbo.dim_shift (
    shift_id                    VARCHAR(5)      NOT NULL PRIMARY KEY,
    shift_name                  VARCHAR(20)     NOT NULL,
    start_time                  TIME            NOT NULL,
    end_time                    TIME            NOT NULL,
    shift_hours                 DECIMAL(5,2)    NOT NULL,
    productive_hours            DECIMAL(5,2)    NOT NULL,
    demand_multiplier           DECIMAL(8,4)    NOT NULL,
    productivity_multiplier     DECIMAL(8,4)    NOT NULL,
    cost_multiplier             DECIMAL(8,4)    NOT NULL
);

CREATE TABLE dbo.dim_date (
    calendar_date               DATE            NOT NULL PRIMARY KEY,
    calendar_year               INT             NOT NULL,
    month_number                INT             NOT NULL,
    month_name                  VARCHAR(15)     NOT NULL,
    year_month                  CHAR(7)         NOT NULL,
    week_number                 INT             NOT NULL,
    day_of_week_number          INT             NOT NULL,
    day_name                    VARCHAR(15)     NOT NULL,
    is_weekend                  BIT             NOT NULL
);

CREATE TABLE dbo.fact_shift_operations (
    operation_id                    INT             NOT NULL PRIMARY KEY,
    work_date                       DATE            NOT NULL,
    facility_id                     VARCHAR(10)     NOT NULL,
    shift_id                        VARCHAR(5)      NOT NULL,
    forecast_orders                 INT             NOT NULL,
    actual_orders                   INT             NOT NULL,
    planned_fte                     INT             NOT NULL,
    planned_contract                INT             NOT NULL,
    absent_fte                      INT             NOT NULL,
    absent_contract                 INT             NOT NULL,
    present_fte                     INT             NOT NULL,
    present_contract                INT             NOT NULL,
    overtime_hours                  INT             NOT NULL,
    capacity_orders                 DECIMAL(12,2)   NOT NULL,
    processed_orders                INT             NOT NULL,
    backlog_orders                  INT             NOT NULL,
    paid_hours                      DECIMAL(12,2)   NOT NULL,
    productive_hours                DECIMAL(12,2)   NOT NULL,
    actual_productivity_per_hour    DECIMAL(10,2)   NOT NULL,
    capacity_utilization            DECIMAL(10,4)   NOT NULL,
    absence_rate                    DECIMAL(10,4)   NOT NULL,
    labour_cost_inr                 DECIMAL(14,2)   NOT NULL,
    cost_per_processed_order        DECIMAL(10,2)   NOT NULL,
    CONSTRAINT fk_operations_date FOREIGN KEY (work_date) REFERENCES dbo.dim_date(calendar_date),
    CONSTRAINT fk_operations_facility FOREIGN KEY (facility_id) REFERENCES dbo.dim_facility(facility_id),
    CONSTRAINT fk_operations_shift FOREIGN KEY (shift_id) REFERENCES dbo.dim_shift(shift_id),
    CONSTRAINT ck_operations_nonnegative CHECK (
        forecast_orders >= 0 AND actual_orders >= 0 AND processed_orders >= 0
        AND planned_fte >= 0 AND planned_contract >= 0 AND overtime_hours >= 0
    )
);

CREATE TABLE dbo.fact_optimized_plan (
    plan_id                         INT             NOT NULL PRIMARY KEY,
    plan_date                       DATE            NOT NULL,
    facility_id                     VARCHAR(10)     NOT NULL,
    shift_id                        VARCHAR(5)      NOT NULL,
    forecast_orders                 INT             NOT NULL,
    target_capacity_orders          DECIMAL(12,2)   NOT NULL,
    baseline_fte                    INT             NOT NULL,
    baseline_contract               INT             NOT NULL,
    baseline_overtime_hours         INT             NOT NULL,
    baseline_capacity_orders        DECIMAL(12,2)   NOT NULL,
    baseline_labour_cost_inr        DECIMAL(14,2)   NOT NULL,
    recommended_fte                 INT             NOT NULL,
    recommended_contract            INT             NOT NULL,
    recommended_overtime_hours      INT             NOT NULL,
    optimized_capacity_orders       DECIMAL(12,2)   NOT NULL,
    optimized_labour_cost_inr       DECIMAL(14,2)   NOT NULL,
    baseline_capacity_gap           DECIMAL(12,2)   NOT NULL,
    optimized_capacity_gap          DECIMAL(12,2)   NOT NULL,
    baseline_utilization            DECIMAL(10,4)   NOT NULL,
    optimized_utilization           DECIMAL(10,4)   NOT NULL,
    cost_savings_inr                DECIMAL(14,2)   NOT NULL,
    cost_savings_pct                DECIMAL(10,4)   NOT NULL,
    overtime_reduction_hours        INT             NOT NULL,
    CONSTRAINT fk_plan_date FOREIGN KEY (plan_date) REFERENCES dbo.dim_date(calendar_date),
    CONSTRAINT fk_plan_facility FOREIGN KEY (facility_id) REFERENCES dbo.dim_facility(facility_id),
    CONSTRAINT fk_plan_shift FOREIGN KEY (shift_id) REFERENCES dbo.dim_shift(shift_id),
    CONSTRAINT uq_plan_grain UNIQUE (plan_date, facility_id, shift_id),
    CONSTRAINT ck_plan_nonnegative CHECK (
        forecast_orders >= 0 AND recommended_fte >= 0
        AND recommended_contract >= 0 AND recommended_overtime_hours >= 0
    )
);

CREATE INDEX ix_operations_date_facility_shift
    ON dbo.fact_shift_operations(work_date, facility_id, shift_id);
CREATE INDEX ix_plan_date_facility_shift
    ON dbo.fact_optimized_plan(plan_date, facility_id, shift_id);
GO

