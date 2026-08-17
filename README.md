# Customer RFM Segmentation Analysis

**[View the Analysis Dashboard (Tableau)](https://public.tableau.com/app/profile/hakeem.leonard/viz/RFM_Analysis_17689706416300/Dashboard1)**

## Objective
An RFM (Recency, Frequency, Monetary) segmentation of a retailer's customer base — scoring
every customer on how recently, how often, and how much they buy, then grouping them into
named personas to identify which customers are most valuable, which are at risk of churn,
and where retention effort would have the most impact.

## Data Source
A UK-based online retailer's transaction history (the widely-used "Online Retail" dataset),
covering invoices from December 2010 through December 2011 — customer ID, country, invoice
number/date, unit price, and quantity per line item.

## Methodology
1. **Calculate Recency, Frequency, Monetary per customer** — recency (days since last
   invoice, relative to 2011-12-02), frequency (count of distinct invoices), and monetary
   value (total spend).
2. **Score each dimension on a 1–4 scale using quartiles** — customers are bucketed into
   quartiles for each of the three metrics (recency scoring is reversed, so more recent
   activity scores higher).
3. **Build a combined RFM score** (e.g. `444`, `111`) by concatenating the three individual
   scores per customer.
4. **Map RFM score combinations to named personas** — Champions, Loyal Customers, New
   Customers, Potential Loyalists, Promising, Needing Attention, At Risk, About to Sleep,
   Hibernating, and Lost — based on standard RFM segmentation logic.
5. **Aggregate and enrich** — roll up to persona-level counts, and separately produce a
   customer-level detail table (adding cohort month, average order value, and average items
   per order) to feed the dashboard.

## Key Findings
Across 4,295 scored customers, generating $8,014,549 in total revenue:

| Persona | Customers | % of Customers | Revenue | % of Revenue | Avg Customer Value |
|---|---|---|---|---|---|
| Champions | 436 | 10.2% | $3,815,448 | 47.6% | $8,751.03 |
| Loyal Customers | 816 | 19.0% | $2,075,036 | 25.9% | $2,542.94 |
| Potential Loyalists | 517 | 12.0% | $662,362 | 8.3% | $1,281.16 |
| Needing Attention | 695 | 16.2% | $568,332 | 7.1% | $817.74 |
| Hibernating | 586 | 13.6% | $314,177 | 3.9% | $536.14 |
| Promising | 490 | 11.4% | $305,373 | 3.8% | $623.21 |
| At Risk | 95 | 2.2% | $155,134 | 1.9% | $1,632.99 |
| Lost | 387 | 9.0% | $60,834 | 0.8% | $157.19 |
| New Customers | 105 | 2.4% | $30,182 | 0.4% | $287.45 |
| About to Sleep | 168 | 3.9% | $27,672 | 0.3% | $164.72 |

- **Revenue is even more concentrated than a first pass suggested.** Champions alone are just
  10.2% of customers but drive 47.6% of total revenue — nearly half the business from one in
  ten customers. Add Loyal Customers and the top two segments (29.2% of customers) account for
  73.5% of all revenue.
- **"At Risk" customers are small in number (2.2%) but carry the second-highest average value
  of any segment** ($1,632.99) — higher than Potential Loyalists and far above every disengaged
  segment. This makes them a disproportionately high-priority win-back target relative to
  their headcount.
- **The disengaged cluster (Needing Attention, At Risk, About to Sleep, Hibernating, Lost)
  totals 1,931 customers (45.0% of the base) but only 13.0% of revenue** — broad reactivation
  campaigns across this whole group would have limited upside compared to targeting the
  higher-value pockets within it, specifically At Risk.
- **The customer base is overwhelmingly UK-based** (3,877 of 4,295 customers, ~90%), with
  Germany, France, and Spain as the next largest markets — a useful caveat on how far any
  "top countries" framing should be pushed given how UK-dominant the data is.

## Recommendations
- Protect the Champions segment above all else — losing even a handful of these customers has
  an outsized impact, since 10% of customers account for nearly half of total revenue.
- Within "at risk of churn" personas, prioritize win-back spend on **At Risk** specifically
  over the much larger but far lower-value Hibernating or Lost segments — its average customer
  value is roughly 3x Hibernating's and over 10x Lost's, so the same win-back budget recovers
  substantially more revenue per successful reactivation.
- Treat Lost, About to Sleep, and New Customers as lower priority for active retention
  spend — combined they're 15.5% of customers but just 1.5% of revenue.

## Queries
All SQL queries are in the `/queries` folder:

| File | Purpose |
|---|---|
| `queries/rfm_score_distribution.sql` | Calculates per-customer R/F/M quartile scores and counts customers per raw RFM score combination |
| `queries/customer_personas_summary.sql` | Maps RFM score combinations to named personas and aggregates customer counts per persona |
| `queries/customer_personas_detail.sql` | Customer-level output: RFM scores, persona label, cohort month, AOV, and items per order — feeds the dashboard |

## Tools
SQL (BigQuery), Google Sheets (score tables and persona summaries), Tableau (dashboard
visualization).
