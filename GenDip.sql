-- After converting the excel file into a csv file in python
/* 
import pandas as pd
ds = pd.read_excel("GenDip_Dataset.xlsx", index_col=0)
ds.to_csv('GenDip_Dataset.csv')
*/

-- And creating the base dataset table

CREATE TABLE GenDip_Dataset (
    year INT,
    cname_send VARCHAR(255),
    main_posting INT,
    title INT,
    gender INT,
    cname_receive VARCHAR(255),
    ccode_send INT,
    ccodealp_send VARCHAR(10),
    ccodeCOW_send INT,
    region_send INT,
    GME_send INT,
    v2lgfemleg_send FLOAT,
    FFP_send INT,
    ccode_receive INT,
    ccodealp_receive VARCHAR(10),
    ccodeCOW_receive INT,
    region_receive INT,
    GME_receive INT,
    FFP_receive INT
)

-- We populate it by right-click on table and import/export data command to import the csv

-- We inspect the dataset first
select * from GenDip_Dataset
where ccode_send != 9999
order by ccode_send

-- (For example, diplomats from Italy)
select * from gendip_dataset
where cname_send = 'Italy' and ccode_send != 9999


----------- TIME-ANALYSIS ---------------------------------------------------------------

-- We start exploring the absolute and relative number of female/male/missing in time

CREATE VIEW male_female_count AS (
    SELECT 
        year,
        COUNT(CASE WHEN gender = 0 THEN 1 END) AS male_count,
        COUNT(CASE WHEN gender = 1 THEN 1 END) AS female_count,
        COUNT(CASE WHEN gender = 99 THEN 1 END) AS missing_count,
        COUNT(1) AS tot_count
    FROM gendip_dataset
    GROUP BY year
)

--- What is the absolute number of female/male/missing in time globally?

SELECT year, 
	   male_count,
	   female_count,  
	   missing_count,
	   tot_count
FROM male_female_count

--- What is the relative number (percentage) of female/male/missing in time globally?

SELECT 
    year, 
    ROUND(CAST(male_count AS DECIMAL(10,3)) / tot_count * 100, 2) AS male_percent,
    ROUND(CAST(female_count AS DECIMAL(10,3)) / tot_count * 100, 2) AS female_percent,
    ROUND(CAST(missing_count AS DECIMAL(10,3)) / tot_count * 100, 2) AS missing_percent
FROM male_female_count


--- Which year holds the maximum number of females?

SELECT year, female_count
FROM male_female_count
ORDER BY female_count DESC
LIMIT 1;

-- We use DROP when we want to delete the VIEW content
--DROP VIEW male_female_count

-- We do the same time-analysis for a specific country, Italy, as a sending country

CREATE VIEW male_female_count_italy AS (
    SELECT 
        year,
        COUNT(CASE WHEN gender = 0 THEN 1 END) AS male_count_italy,
        COUNT(CASE WHEN gender = 1 THEN 1 END) AS female_count_italy,
        COUNT(CASE WHEN gender = 99 THEN 1 END) AS missing_count_italy,
        COUNT(1) AS tot_count
    FROM gendip_dataset
	WHERE cname_send = 'Italy'
    GROUP BY year
	ORDER BY year
)

DROP VIEW male_female_count_italy

-- Relative number of sent diplomats from Italy
SELECT 
    year, 
    ROUND(CAST(male_count_italy AS DECIMAL(10,3)) / tot_count * 100, 2) AS male_percent_italy,
    ROUND(CAST(female_count_italy AS DECIMAL(10,3)) / tot_count * 100, 2) AS female_percent_italy,
    ROUND(CAST(missing_count_italy AS DECIMAL(10,3)) / tot_count * 100, 2) AS missing_percent_italy
FROM male_female_count_italy

-- Absolute number of sent diplomats from Italy
SELECT year, 
	   male_count_italy,
	   female_count_italy,  
	   missing_count_italy,
	   tot_count
FROM male_female_count_italy


----------- REGIONAL-ANALYSIS ---------------------------------------------------------------

-- Starting by exploring the countries and the total count of diplomats for each (sent or received)
select ccode_send, cname_send, count(1)
from GenDip_Dataset
group by ccode_send, cname_send
order by ccode_send

select ccode_receive, cname_receive, count(1)
from GenDip_Dataset
group by ccode_receive, cname_receive
order by ccode_receive


-- Create a new table 'countries' with name, code and count of sending/receiving male and females

CREATE TABLE countries AS
WITH ccount_send AS (
    SELECT 
        ccode_send, 
        cname_send, 
        region_send, 
        COUNT(CASE WHEN gender = 0 THEN 1 END) AS male_send_count,     -- Count of males using CASE
        COUNT(CASE WHEN gender = 1 THEN 1 END) AS female_send_count, -- Count of females using CASE
		FFP_send
    FROM 
        GenDip_Dataset
    GROUP BY 
        ccode_send, 
        cname_send, 
        region_send,
		FFP_send
),
ccount_receive AS (
    SELECT 
        ccode_receive, 
        cname_receive, 
        region_receive, 
        COUNT(CASE WHEN gender = 0 THEN 1 END) AS male_receive_count,   -- Count of males using CASE
        COUNT(CASE WHEN gender = 1 THEN 1 END) AS female_receive_count  -- Count of females using CASE
    FROM 
        GenDip_Dataset
    GROUP BY 
        ccode_receive, 
        cname_receive, 
        region_receive
)
SELECT 
    COALESCE(ccount_send.ccode_send, ccount_receive.ccode_receive) AS ccode,
    COALESCE(ccount_send.cname_send, ccount_receive.cname_receive) AS cname,
    COALESCE(ccount_send.region_send, ccount_receive.region_receive) AS cregion,
    COALESCE(ccount_send.male_send_count, 0) AS male_send_count,      -- Count of male senders
    COALESCE(ccount_send.female_send_count, 0) AS female_send_count,  -- Count of female senders
    COALESCE(ccount_receive.male_receive_count, 0) AS male_receive_count,  -- Count of male receivers
    COALESCE(ccount_receive.female_receive_count, 0) AS female_receive_count,  -- Count of female receivers
	FFP_send AS feminine_policy
FROM 
    ccount_send
FULL JOIN 
    ccount_receive
ON 
    ccount_send.ccode_send = ccount_receive.ccode_receive;
	

select * from countries0


-- Explore the geographic areas and create a new table with the region_code and the region name from the codebook' information

select distinct region_receive
from gendip_dataset

CREATE TABLE geographic_area(
region_code INT,
region_name VARCHAR(225)
)

INSERT INTO geographic_area(region_code, region_name)
VALUES (0, 'Africa'), (1, 'Asia'), (2, 'Central and North America'), (3, 'Europe (including Russia)'), (4, 'Middle East (including Egypt and Turkey)'), (5, 'Nordic countries'),
(6, 'Oceania'), (7, 'South America'), (9999, 'Missing')

select * from geographic_area


-- Link the region code in countries and in geographic_area
select countries.cname, geographic_area.region_name
from countries
full join geographic_area
on countries.cregion = geographic_area.region_code


-- Count the female/male sent from each region, using the geographic_area table
SELECT 
    cregion, 
	geographic_area.region_name,
    SUM(male_send_count) AS male_send_count, 
    SUM(female_send_count) AS female_send_count,
	SUM(male_send_count)/SUM(female_send_count)AS male_female_ratio
FROM countries
INNER JOIN geographic_area 
ON geographic_area.region_code	= countries.cregion
GROUP BY cregion, geographic_area.region_name, feminine_policy
HAVING feminine_policy = '1'
ORDER BY cregion





