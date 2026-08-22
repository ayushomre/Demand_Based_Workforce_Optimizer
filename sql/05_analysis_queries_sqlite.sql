-- Run these queries directly against database/workforce_optimizer.sqlite.

-- Facility optimization scorecard
SELECT
    f.facility_name,
    ROUND(SUM(p.baseline_labour_cost_inr), 2) AS baseline_cost_inr,
    ROUND(SUM(p.optimized_labour_cost_inr), 2) AS optimized_cost_inr,
    ROUND(SUM(p.cost_savings_inr), 2) AS savings_inr,
    ROUND(SUM(p.cost_savings_inr) / SUM(p.baseline_labour_cost_inr) * 100, 2) AS savings_pct,
    SUM(p.baseline_overtime_hours) - SUM(p.recommended_overtime_hours) AS overtime_hours_avoided
FROM fact_optimized_plan p
JOIN dim_facility f ON f.facility_id = p.facility_id
GROUP BY f.facility_name
ORDER BY savings_inr DESC;

-- Seven-day rolling demand
WITH daily_demand AS (
    SELECT work_date, facility_id, SUM(actual_orders) AS daily_orders
    FROM fact_shift_operations
    GROUP BY work_date, facility_id
)
SELECT
    work_date,
    facility_id,
    daily_orders,
    ROUND(AVG(daily_orders * 1.0) OVER (
        PARTITION BY facility_id ORDER BY work_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 1) AS rolling_7d_orders
FROM daily_demand
ORDER BY facility_id, work_date;

-- Historical shift scorecard
SELECT
    s.shift_name,
    ROUND(SUM(o.processed_orders) / SUM(o.productive_hours), 2) AS orders_per_productive_hour,
    ROUND(SUM(o.labour_cost_inr) / SUM(o.processed_orders), 2) AS cost_per_order_inr,
    ROUND(SUM(o.processed_orders) / SUM(o.capacity_orders) * 100, 2) AS utilization_pct,
    SUM(o.overtime_hours) AS overtime_hours
FROM fact_shift_operations o
JOIN dim_shift s ON s.shift_id = o.shift_id
GROUP BY s.shift_name
ORDER BY cost_per_order_inr;

-- Verify that optimized plans meet the safety-buffer capacity target
SELECT COUNT(*) AS optimized_shortfalls
FROM fact_optimized_plan
WHERE optimized_capacity_orders < target_capacity_orders;

