# Case 2 – Early Retention as the Primary Growth Constraint

## Business Question
Is long-term business growth constrained by early customer retention, and should acquisition be scaled before early retention improves?

## Decision
Do not scale acquisition until first-month retention is materially improved. Growth efforts should prioritize early value reinforcement rather than downstream engagement optimizations

## Data
- Transaction-level retail data
- Public Kaggle dataset (anonymized)
- Returns, invalid transactions, and missing customers excluded

## Analysis Overview
- SQL used to define customer cohorts by first purchase month and calculate cohort-based retention
- Python used to compute customer and revenue retention matrices and visualize cohort behavior over time
- Power BI used to build an executive dashboard summarizing retention behavior, customer segmentation, and geographic distribution

Retention is defined as a customer making at least one purchase in a given cohort month.

## Key Findings
- Sharp churn occurs in the first month across nearly all cohorts
- Retention stabilizes after month one, indicating repeat usage rather than habit-forming growth
- Later cohorts do not meaningfully outperform earlier cohorts, suggesting limited product improvement over time
- Scaling acquisition under current conditions would increase volume without proportionate retained users or revenue

## Repo Structure
- `sql/core_analysis.sql` – Cohort definition and retention calculation
- `python/core_analysis.ipynb` – Cohort retention and revenue analysis with visualizations
- `Power BI/Online_Retail_Customer_Retention_Dashboard.pbit` – Executive dashboard template for retention, segmentation, and geographic distribution analysis

## Outputs
- `outputs/customer_retention_by_cohort_month.png` – Customer retention heatmap
- `outputs/revenue_retention_by_cohort_month.png` – Revenue retention heatmap
- `outputs/avg_revenue_per_retained_user_by_cohort_month.png` – Average revenue per retained customer by cohort month
- `outputs/month_1_customer_retention_by_country.png` – Month 1 retention comparison by country
- `outputs/Dashboard_preview.png` – Power BI executive dashboard overview
- `outputs/Dashboard_map_view.png` – Geographic distribution dashboard view

## Notes
This repository focuses on analysis logic and decision-making
Environment setup, data ingestion, and execution steps are intentionally omitted

## Portfolio Link
<https://portfolio-home.notion.site/Case-2-Index-Page-2eabf1a14b4980769845cbce6b6969c8/>
