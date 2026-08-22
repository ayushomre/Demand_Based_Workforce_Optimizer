USE WorkforceOptimizer;
GO

/* 1. Historical network health */
SELECT
    SUM(actual_orders) AS actual_orders,
    SUM(processed_orders) AS processed_orders,
    CAST(SUM(processed_orders) * 1.0 / NULLIF(SUM(actual_orders), 0) AS DECIMAL(10,4)) AS processing_rate,
    SUM(backlog_orders) AS backlog_orders,
    CAST(SUM(labour_cost_inr) / NULLIF(SUM(processed_orders), 0) AS DECIMAL(10,2)) AS cost_per_order_inr,
    CAST(SUM(absent_fte + absent_contract) * 1.0 /
         NULLIF(SUM(planned_fte + planned_contract), 0) AS DECIMAL(10,4)) AS weighted_absence_rate
FROM dbo.fact_shift_operations;

/* 2. Facility performance scorecard */
SELECT
    f.facility_name,
    SUM(o.processed_orders) AS processed_orders,
    CAST(SUM(o.processed_orders) * 1.0 / SUM(o.capacity_orders) AS DECIMAL(10,4)) AS capacity_utilization,
    CAST(SUM(o.labour_cost_inr) / NULLIF(SUM(o.processed_orders), 0) AS DECIMAL(10,2)) AS cost_per_order_inr,
    SUM(o.backlog_orders) AS backlog_orders,
    SUM(o.overtime_hours) AS overtime_hours
FROM dbo.fact_shift_operations o
JOIN dbo.dim_facility f ON f.facility_id = o.facility_id
GROUP BY f.facility_name
ORDER BY cost_per_order_inr;

/* 3. Seven-day rolling demand by facility */
WITH daily_demand AS (
    SELECT work_date, facility_id, SUM(actual_orders) AS daily_orders
    FROM dbo.fact_shift_operations
    GROUP BY work_date, facility_id
)
SELECT
    work_date,
    facility_id,
    daily_orders,
    CAST(AVG(daily_orders * 1.0) OVER (
        PARTITION BY facility_id ORDER BY work_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS DECIMAL(12,1)) AS rolling_7d_orders
FROM daily_demand
ORDER BY facility_id, work_date;

/* 4. Rank facilities by absence and backlog risk */
WITH facility_risk AS (
    SELECT
        facility_id,
        AVG(absence_rate) AS average_absence_rate,
        SUM(backlog_orders) AS total_backlog
    FROM dbo.fact_shift_operations
    GROUP BY facility_id
)
SELECT
    f.facility_name,
    CAST(r.average_absence_rate AS DECIMAL(10,4)) AS average_absence_rate,
    r.total_backlog,
    DENSE_RANK() OVER (ORDER BY r.average_absence_rate DESC) AS absence_risk_rank,
    DENSE_RANK() OVER (ORDER BY r.total_backlog DESC) AS backlog_risk_rank
FROM facility_risk r
JOIN dbo.dim_facility f ON f.facility_id = r.facility_id
ORDER BY backlog_risk_rank;

/* 5. Productivity and cost by shift */
SELECT
    s.shift_name,
    CAST(SUM(o.processed_orders) / NULLIF(SUM(o.productive_hours), 0) AS DECIMAL(10,2)) AS orders_per_productive_hour,
    CAST(SUM(o.labour_cost_inr) / NULLIF(SUM(o.processed_orders), 0) AS DECIMAL(10,2)) AS cost_per_order_inr,
    CAST(SUM(o.processed_orders) * 1.0 / NULLIF(SUM(o.capacity_orders), 0) AS DECIMAL(10,4)) AS utilization,
    SUM(o.overtime_hours) AS overtime_hours
FROM dbo.fact_shift_operations o
JOIN dbo.dim_shift s ON s.shift_id = o.shift_id
GROUP BY s.shift_name
ORDER BY cost_per_order_inr;

/* 6. August optimization executive summary */
SELECT
    SUM(forecast_orders) AS forecast_orders,
    SUM(baseline_labour_cost_inr) AS baseline_cost_inr,
    SUM(optimized_labour_cost_inr) AS optimized_cost_inr,
    SUM(cost_savings_inr) AS simulated_savings_inr,
    CAST(SUM(cost_savings_inr) / NULLIF(SUM(baseline_labour_cost_inr), 0) AS DECIMAL(10,4)) AS savings_pct,
    SUM(baseline_overtime_hours) AS baseline_overtime_hours,
    SUM(recommended_overtime_hours) AS optimized_overtime_hours,
    SUM(CASE WHEN baseline_capacity_gap < 0 THEN 1 ELSE 0 END) AS baseline_safety_shortfalls,
    SUM(CASE WHEN optimized_capacity_gap < 0 THEN 1 ELSE 0 END) AS optimized_safety_shortfalls
FROM dbo.fact_optimized_plan;

/* 7. Optimization impact by facility */
SELECT
    f.facility_name,
    SUM(p.baseline_labour_cost_inr) AS baseline_cost_inr,
    SUM(p.optimized_labour_cost_inr) AS optimized_cost_inr,
    SUM(p.cost_savings_inr) AS savings_inr,
    CAST(SUM(p.cost_savings_inr) / NULLIF(SUM(p.baseline_labour_cost_inr), 0) AS DECIMAL(10,4)) AS savings_pct,
    SUM(p.baseline_overtime_hours) - SUM(p.recommended_overtime_hours) AS overtime_hours_avoided
FROM dbo.fact_optimized_plan p
JOIN dbo.dim_facility f ON f.facility_id = p.facility_id
GROUP BY f.facility_name
ORDER BY savings_inr DESC;

/* 8. Cumulative weekly savings */
WITH weekly_savings AS (
    SELECT
        d.week_number,
        SUM(p.cost_savings_inr) AS weekly_savings_inr
    FROM dbo.fact_optimized_plan p
    JOIN dbo.dim_date d ON d.calendar_date = p.plan_date
    GROUP BY d.week_number
)
SELECT
    week_number,
    weekly_savings_inr,
    SUM(weekly_savings_inr) OVER (ORDER BY week_number) AS cumulative_savings_inr
FROM weekly_savings
ORDER BY week_number;

/* 9. Workforce-mix change by shift */
SELECT
    s.shift_name,
    SUM(p.baseline_fte) AS baseline_fte_shifts,
    SUM(p.recommended_fte) AS recommended_fte_shifts,
    SUM(p.baseline_contract) AS baseline_contract_shifts,
    SUM(p.recommended_contract) AS recommended_contract_shifts,
    SUM(p.baseline_overtime_hours) AS baseline_overtime_hours,
    SUM(p.recommended_overtime_hours) AS recommended_overtime_hours
FROM dbo.fact_optimized_plan p
JOIN dbo.dim_shift s ON s.shift_id = p.shift_id
GROUP BY s.shift_name
ORDER BY s.shift_name;

/* 10. Highest-demand dates for management attention */
WITH daily_plan AS (
    SELECT
        plan_date,
        SUM(forecast_orders) AS forecast_orders,
        SUM(recommended_fte + recommended_contract) AS recommended_worker_shifts,
        SUM(recommended_overtime_hours) AS recommended_overtime_hours,
        SUM(optimized_labour_cost_inr) AS optimized_cost_inr
    FROM dbo.fact_optimized_plan
    GROUP BY plan_date
)
SELECT TOP (10)
    plan_date,
    forecast_orders,
    recommended_worker_shifts,
    recommended_overtime_hours,
    optimized_cost_inr,
    DENSE_RANK() OVER (ORDER BY forecast_orders DESC) AS demand_rank
FROM daily_plan
ORDER BY demand_rank, plan_date;

/* 11. Facility-shift combinations with the largest controllable saving */
SELECT TOP (10)
    f.facility_name,
    s.shift_name,
    SUM(p.cost_savings_inr) AS savings_inr,
    CAST(SUM(p.cost_savings_inr) / NULLIF(SUM(p.baseline_labour_cost_inr), 0) AS DECIMAL(10,4)) AS savings_pct,
    SUM(p.overtime_reduction_hours) AS overtime_reduction_hours
FROM dbo.fact_optimized_plan p
JOIN dbo.dim_facility f ON f.facility_id = p.facility_id
JOIN dbo.dim_shift s ON s.shift_id = p.shift_id
GROUP BY f.facility_name, s.shift_name
ORDER BY savings_inr DESC;

/* 12. Quality-control exceptions: this should return zero rows */
SELECT *
FROM dbo.fact_optimized_plan
WHERE optimized_capacity_orders < target_capacity_orders
   OR recommended_fte < 0
   OR recommended_contract < 0
   OR recommended_overtime_hours < 0;
GO

