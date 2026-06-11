-- ============================================================
--  SOLUTIONS.sql
--  Telco Project - i2i Systems
--  Oracle XE
-- ============================================================


-- 1.1 List customers subscribed to the 'Kobiye Destek' tariff
/*
  I joined CUSTOMERS with TARIFFS on TARIFF_ID to filter by tariff name.
  Using the name instead of a hardcoded ID makes the query more flexible.
  Results are sorted alphabetically by customer name.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE t.NAME = 'Kobiye Destek'
ORDER BY c.NAME;


-- 1.2 Find the newest customer subscribed to this tariff
/*
  I used a subquery to get the MAX(SIGNUP_DATE) among Kobiye Destek subscribers.
  Then I filtered for customers with that date in the outer query.
  Multiple customers could share the same latest date, so I didn't limit to one row.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE t.NAME = 'Kobiye Destek'
  AND c.SIGNUP_DATE = (
      SELECT MAX(c2.SIGNUP_DATE)
      FROM CUSTOMERS c2
      JOIN TARIFFS t2 ON c2.TARIFF_ID = t2.TARIFF_ID
      WHERE t2.NAME = 'Kobiye Destek'
  );


-- 2.1 Find the distribution of tariffs among customers
/*
  I joined TARIFFS and CUSTOMERS and grouped by tariff to count subscribers.
  I also calculated the percentage of total customers for each tariff.
  LEFT JOIN is used so tariffs with zero subscribers still appear in the result.
*/
SELECT
    t.NAME                                             AS TARIFF_NAME,
    t.MONTHLY_FEE,
    COUNT(c.CUSTOMER_ID)                              AS SUBSCRIBER_COUNT,
    ROUND(COUNT(c.CUSTOMER_ID) * 100.0 /
          (SELECT COUNT(*) FROM CUSTOMERS), 2)        AS PERCENTAGE
FROM TARIFFS t
LEFT JOIN CUSTOMERS c ON t.TARIFF_ID = c.TARIFF_ID
GROUP BY t.TARIFF_ID, t.NAME, t.MONTHLY_FEE
ORDER BY SUBSCRIBER_COUNT DESC;


-- 3.1 Identify the earliest customers to sign up
/*
  I used MIN(SIGNUP_DATE) in a subquery to find the earliest date in the system.
  Then I returned all customers who signed up on that date.
  As the hint suggests, the earliest customers don't necessarily have the lowest IDs,
  so filtering by date is the correct approach here.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE,
    t.NAME AS TARIFF_NAME
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE c.SIGNUP_DATE = (SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS)
ORDER BY c.CUSTOMER_ID;


-- 3.2 Distribution of earliest customers across cities
/*
  I used a CTE to isolate the earliest customers from query 3.1.
  This avoids repeating the subquery logic and keeps things readable.
  Then I grouped by city to get the count per city.
*/
WITH EARLIEST_CUSTOMERS AS (
    SELECT CITY
    FROM CUSTOMERS
    WHERE SIGNUP_DATE = (SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS)
)
SELECT
    CITY,
    COUNT(*) AS CUSTOMER_COUNT
FROM EARLIEST_CUSTOMERS
GROUP BY CITY
ORDER BY CUSTOMER_COUNT DESC;


-- 4.1 Identify customers with missing monthly records
/*
  Every customer should have a record in MONTHLY_STATS, but some are missing.
  I used NOT EXISTS to find customers with no matching entry in that table.
  NOT EXISTS handles NULLs more safely than NOT IN and tends to perform better
  on larger datasets.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME AS TARIFF_NAME
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE NOT EXISTS (
    SELECT 1
    FROM MONTHLY_STATS ms
    WHERE ms.CUSTOMER_ID = c.CUSTOMER_ID
)
ORDER BY c.CUSTOMER_ID;


-- 4.2 Distribution of missing customers across cities
/*
  I reused the NOT EXISTS logic inside a CTE to get the missing customers.
  Then I grouped by city to see how the missing records are spread geographically.
  This helps determine whether the insertion error affected specific regions or was random.
*/
WITH MISSING_CUSTOMERS AS (
    SELECT c.CITY
    FROM CUSTOMERS c
    WHERE NOT EXISTS (
        SELECT 1
        FROM MONTHLY_STATS ms
        WHERE ms.CUSTOMER_ID = c.CUSTOMER_ID
    )
)
SELECT
    CITY,
    COUNT(*) AS MISSING_COUNT
FROM MISSING_CUSTOMERS
GROUP BY CITY
ORDER BY MISSING_COUNT DESC;


-- 5.1 Find customers who used at least 75% of their data limit
/*
  I joined all three tables and filtered out tariffs with DATA_LIMIT = 0
  to avoid division by zero errors.
  The condition DATA_USAGE / DATA_LIMIT >= 0.75 gives us customers at or above the 75% threshold.
  I also included the usage percentage in the output for clarity.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME                                             AS TARIFF_NAME,
    ms.DATA_USAGE,
    t.DATA_LIMIT,
    ROUND(ms.DATA_USAGE / t.DATA_LIMIT * 100, 2)      AS DATA_USAGE_PCT
FROM CUSTOMERS c
JOIN TARIFFS t        ON c.TARIFF_ID    = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID  = ms.CUSTOMER_ID
WHERE t.DATA_LIMIT > 0
  AND ms.DATA_USAGE / t.DATA_LIMIT >= 0.75
ORDER BY DATA_USAGE_PCT DESC;


-- 5.2 Find customers who exhausted all package limits (data, minutes, and SMS)
/*
  A customer counts as fully exhausted only if all three limits are exceeded.
  For tariffs where a limit is 0 (meaning that category isn't part of the plan),
  I skip that check using OR conditions so it doesn't incorrectly exclude those customers.
  All three conditions must be true at the same time for a row to appear.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME           AS TARIFF_NAME,
    ms.DATA_USAGE,   t.DATA_LIMIT,
    ms.MINUTE_USAGE, t.MINUTE_LIMIT,
    ms.SMS_USAGE,    t.SMS_LIMIT
FROM CUSTOMERS c
JOIN TARIFFS t        ON c.TARIFF_ID    = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID  = ms.CUSTOMER_ID
WHERE
    (t.DATA_LIMIT   = 0 OR ms.DATA_USAGE   >= t.DATA_LIMIT)
    AND (t.MINUTE_LIMIT = 0 OR ms.MINUTE_USAGE >= t.MINUTE_LIMIT)
    AND (t.SMS_LIMIT    = 0 OR ms.SMS_USAGE    >= t.SMS_LIMIT)
ORDER BY c.CUSTOMER_ID;


-- 6.1 Find customers with unpaid fees
/*
  I filtered MONTHLY_STATS for PAYMENT_STATUS = 'UNPAID' and joined with
  CUSTOMERS and TARIFFS to include relevant details in the output.
  Results are ordered by city and name to make the list easier to read.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME           AS TARIFF_NAME,
    t.MONTHLY_FEE,
    ms.PAYMENT_STATUS
FROM CUSTOMERS c
JOIN TARIFFS t        ON c.TARIFF_ID    = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID  = ms.CUSTOMER_ID
WHERE ms.PAYMENT_STATUS = 'UNPAID'
ORDER BY c.CITY, c.NAME;


-- 6.2 Distribution of payment statuses across tariffs
/*
  I grouped by tariff name and payment status to count how many customers
  fall into each combination.
  I also added a percentage column scoped to each tariff using a window function,
  which makes it easy to compare payment behavior across different plans.
*/
SELECT
    t.NAME                 AS TARIFF_NAME,
    ms.PAYMENT_STATUS,
    COUNT(*)               AS COUNT,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY t.NAME), 2) AS PCT_WITHIN_TARIFF
FROM MONTHLY_STATS ms
JOIN CUSTOMERS c ON ms.CUSTOMER_ID = c.CUSTOMER_ID
JOIN TARIFFS t   ON c.TARIFF_ID    = t.TARIFF_ID
GROUP BY t.NAME, ms.PAYMENT_STATUS
ORDER BY t.NAME, ms.PAYMENT_STATUS;
