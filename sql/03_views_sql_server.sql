USE WorkforceOptimizer;
GO

CREATE OR ALTER VIEW dbo.vw_shift_performance AS
SELECT
    o.operation_id,
    o.work_date,
    d.year_month,
    d.week_number,
    d.day_name,
    f.facility_name,
    f.city,
    f.region,
    s.shift_name,
    o.forecast_orders,
    o.actual_orders,
    o.processed_orders,
    o.capacity_orders,
    o.backlog_orders,
    o.planned_fte + o.planned_contract AS planned_workers,
    o.present_fte + o.present_contract AS present_workers,
    o.absent_fte + o.absent_contract AS absent_workers,
    o.absence_rate,
    o.capacity_utilization,
    o.actual_productivity_per_hour,
    o.overtime_hours,
    o.labour_cost_inr,
    o.cost_per_processed_order
FROM dbo.fact_shift_operations o
JOIN dbo.dim_date d ON d.calendar_date = o.work_date
JOIN dbo.dim_facility f ON f.facility_id = o.facility_id
JOIN dbo.dim_shift s ON s.shift_id = o.shift_id;
GO

CREATE OR ALTER VIEW dbo.vw_optimization_impact AS
SELECT
    p.plan_id,
    p.plan_date,
    d.week_number,
    d.day_name,
    f.facility_name,
    f.city,
    f.region,
    s.shift_name,
    p.forecast_orders,
    p.target_capacity_orders,
    p.baseline_fte,
    p.baseline_contract,
    p.baseline_overtime_hours,
    p.baseline_capacity_orders,
    p.baseline_labour_cost_inr,
    p.recommended_fte,
    p.recommended_contract,
    p.recommended_overtime_hours,
    p.optimized_capacity_orders,
    p.optimized_labour_cost_inr,
    p.baseline_capacity_gap,
    p.optimized_capacity_gap,
    p.optimized_utilization,
    p.cost_savings_inr,
    p.cost_savings_pct,
    p.overtime_reduction_hours
FROM dbo.fact_optimized_plan p
JOIN dbo.dim_date d ON d.calendar_date = p.plan_date
JOIN dbo.dim_facility f ON f.facility_id = p.facility_id
JOIN dbo.dim_shift s ON s.shift_id = p.shift_id;
GO

