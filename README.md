# Case 2 – Early Retention as the Primary Growth Constraint

## Business Question
Is long-term business growth constrained by early customer retention, and should acquisition be scaled before early retention improves?

## Decision
Do not scale acquisition until first-month retention is materially improved. Growth efforts should prioritize early value reinforcement rather than downstream engagement optimizations.

## Data
- Transaction-level retail data
- Public Kaggle dataset (anonymized)
- Returns, invalid transactions, and missing customers excluded

## Analysis Overview
- SQL used to define customer cohorts by first purchase month and calculate cohort-based retention.
- Python used to compute customer and revenue retention matrices and visualize cohort behavior over time.
- Retention is defined as a customer making at least one purchase in a given month.

## Key Findings
- Sharp churn occurs in the first month across nearly all cohorts.
- Retention stabilizes after month one, indicating repeat usage rather than habit-forming growth.
- Later cohorts do not meaningfully outperform earlier cohorts, suggesting limited product improvement over time.
- Scaling acquisition under current conditions would increase volume without proportionate retained users or revenue.

## Repo Structure
- `sql/core_analysis.sql` – cohort definition and retention calculation
- `python/core_analysis.ipynb` – cohort retention and revenue analysis with visualizations
- `outputs/customer_retention_by_cohort_month.png` – customer retention heatmap
- `outputs/revenue_retention_by_cohort_month.png` – revenue retention heatmap

## Notes
This repository focuses on analysis logic and decision-making.  
Environment setup, data ingestion, and execution steps are intentionally omitted.

## Portfolio Link
<https://portfolio-home.notion.site/Case-2-Index-Page-2eabf1a14b4980769845cbce6b6969c8/>
