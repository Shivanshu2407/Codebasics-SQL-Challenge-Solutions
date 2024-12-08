/*Q1.Provide the list of markets in which customer "Atliq Exclusive" operates its
business in the APAC region.
*/
select distinct(market) 
from dim_customer
where customer='Atliq Exclusive' and region='APAC';

/*Q2.What is the percentage of unique product increase in 2021 vs. 2020? The
final output contains these fields---
unique_products_2020
unique_products_2021
percentage_chg
*/
WITH UniqueProductCounts AS (
    SELECT 
        COUNT(DISTINCT p.product_code) AS unique_product_count,
        m.cost_year AS _year
    FROM 
        dim_product AS p
    JOIN 
        fact_manufacturing_cost AS m ON p.product_code = m.product_code
    WHERE 
        m.cost_year IN (2020, 2021)
    GROUP BY 
        m.cost_year
)

SELECT 
    u2020.unique_product_count AS count_2020,
    u2021.unique_product_count AS count_2021,
    round((u2021.unique_product_count - u2020.unique_product_count) * 100.0 / NULLIF(u2020.unique_product_count, 0),2) AS percentage_increase
FROM 
    (SELECT unique_product_count FROM UniqueProductCounts WHERE _year = 2020) AS u2020,
    (SELECT unique_product_count FROM UniqueProductCounts WHERE _year = 2021) AS u2021;
    

/*Q3.Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains 2 fields,
segment
product_count
*/
select segment,count(product) as Product_count
from dim_product
group by segment
order by Product_count desc;

/*Q4.Follow-up: Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields,
segment
product_count_2020
product_count_2021
difference
*/
WITH cte2 AS (
    SELECT 
        p.segment,
        COUNT(DISTINCT p.product_code) AS product_count,
        m.cost_year
    FROM 
        dim_product AS p
    JOIN 
        fact_manufacturing_cost AS m ON p.product_code = m.product_code
    WHERE 
        m.cost_year IN (2020, 2021)
    GROUP BY 
        p.segment, m.cost_year
),
segment_increase AS (
    SELECT 
        y20.segment,
        y20.product_count AS product_count_2020,
        y21.product_count AS product_count_2021,
        (y21.product_count - y20.product_count) AS difference
    FROM 
        (SELECT segment, product_count FROM cte2 WHERE cost_year = 2020) AS y20
    JOIN 
        (SELECT segment, product_count FROM cte2 WHERE cost_year = 2021) AS y21
    ON 
        y20.segment = y21.segment
)

SELECT 
    segment,
    product_count_2020,
    product_count_2021,
    difference
FROM 
    segment_increase
ORDER BY 
    difference DESC;


/*Q5.Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields,
product_code
product
manufacturing_cost
*/
SELECT distinct(m.product_code) as productcode,p.product as productname,
	   round(max(manufacturing_cost),2) as max_cost
	from dim_product as p join fact_manufacturing_cost as m on p.product_code = m.product_code
group by productcode,productname
order by max_cost desc limit 1;


SELECT distinct(m.product_code) as productcode,p.product as productname,
	   round(min(manufacturing_cost),2) as min_cost
	from dim_product as p join fact_manufacturing_cost as m on p.product_code = m.product_code
group by productcode,productname
order by min_cost limit 1;

/*Q6.Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields,
customer_code
customer
average_discount_percentage
*/
Select f.customer_code,c.customer,round(avg(pre_invoice_discount_pct),4) as average_discount_percentage
from dim_customer as c
join fact_pre_invoice_deductions as f
on c.customer_code = f.customer_code
where market='India' and fiscal_year=2021
group by f.customer_code,c.customer
order by average_discount_percentage desc 
limit 5;

/*Q7.Get the complete report of the Gross sales amount for the customer “Atliq
Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns:
Month
Year
Gross sales Amount
*/
select 
		concat(MONTHNAME(date),' ','(',YEAR(date),')') as mno,
		m.fiscal_year,
		round(sum(f.gross_price * m.sold_quantity),2) as total_amt
from fact_sales_monthly as m 
join fact_gross_price as f on m.product_code = f.product_code 
join dim_customer as dc on m.customer_code = dc.customer_code
where dc.customer = 'Atliq Exclusive'
group by mno,m.fiscal_year;

/*Q8.In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity,
Quarter
total_sold_quantity
*/
select
CASE
    WHEN date BETWEEN '2019-09-01' AND '2019-11-01' then 1  
    WHEN date BETWEEN '2019-12-01' AND '2020-02-01' then 2
    WHEN date BETWEEN '2020-03-01' AND '2020-05-01' then 3
    WHEN date BETWEEN '2020-06-01' AND '2020-08-01' then 4
    END AS Quarters,
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY Quarters
ORDER BY total_sold_quantity DESC;

/*Q9.Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields,
channel
gross_sales_mln
percentage

*/
WITH Output AS (
  SELECT 
    dc.channel,
    ROUND(SUM(fgp.gross_price * mn.sold_quantity) / 1000000, 2) AS Gross_sales_mln
  FROM fact_sales_monthly AS mn
  JOIN dim_customer AS dc ON mn.customer_code = dc.customer_code
  JOIN fact_gross_price AS fgp ON mn.product_code = fgp.product_code
  WHERE mn.fiscal_year = 2021
  GROUP BY dc.channel
)
SELECT 
  B.channel, 
  CONCAT(B.Gross_sales_mln, ' M') AS Gross_sales_mln, 
  CONCAT(ROUND(B.Gross_sales_mln * 100 / A.total, 2), ' %') AS percentage
FROM (
  (SELECT SUM(Gross_sales_mln) AS total FROM Output) A, 
  (SELECT * FROM Output) B 
)
ORDER BY percentage DESC;

/*Q10.Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these fields,
division
product_code
product
total_sold_quantity
rank_order
*/
with cte1 as(
select dp.division,dp.product_code,dp.product,sum(mn.sold_quantity) as total_qty
from dim_product as dp
join fact_sales_monthly as mn on dp.product_code = mn.product_code 
where mn.fiscal_year = 2021
group by dp.division,dp.product_code,dp.product
),
cte2 as(
select division,product_code,product,total_qty,
rank() over (partition by division order by total_qty desc ) as rnk 
from cte1)
select cte2.division,cte2.product_code,cte2.product,cte2.total_qty,rnk
from cte1 join cte2
on cte1.product_code=cte2.product_code
where rnk in (1,2,3);

