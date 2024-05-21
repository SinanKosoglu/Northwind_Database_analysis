select * from categories -- 8 veri
select * from customers -- 91 veri
select * from employees -- 9 veri
select * from employeeterritories -- 49 veri
select * from order_details limit 10 -- 2155 veri
select * from orders -- 830 veri
select * from products -- 77 veri
select * from region -- 4 veri
select * from shippers -- 6 veri
select * from suppliers -- 29 veri
select * from territories -- 53 veri
select * from usstates -- 51 veri

-- Power bi ve Python da analiz için kullanılan kodlar...

--1 
-- satışçı analizi
-- Satışçı bazlı ciro nedir? 

select * from employees
select * from orders
select * from order_details

select 
	e.employee_id,
	e.first_name || ' ' || e.last_name as full_name,
	e.title,
	o.order_id,
	o.customer_id,
	o.ship_city,
	o.ship_country,
	od.product_id,
	od.unit_price,
	od.quantity
from 
	employees as e 
left join
	orders as o on o.employee_id = e.employee_id
left join 
	order_details as od on od.order_id = o.order_id

-- 2 lojistik analizi
-- nakliyecilerin ülkelere göre ve adet miktarına (10 ve 10dan yüksek) göre ortalama kargo alım sürelerini (7 gün ve üzeri) getir 

select * from orders
select * from shippers

select
	o.ship_country,
	s.company_name,
	count(*) as total_number_orders,
	round(avg(o.shipped_date - o.order_date),2) as average_days_between_order_n_shipping
from
	orders as o
left join 
	shippers as s on o.ship_via = s.shipper_id
group by 
	1,2
having 
	count(*) >= 10 and round(avg(o.shipped_date - o.order_date),2) >= 7
order by 
	4 desc

--3
-- Hangi nakliye şirketi en çok yük taşımış buna göre en çok kar edilen ülke veya şehire depo kurulup nakliye operasyonunun maaliyetini düşürebilir misin?
select * from orders
select * from order_details
select * from shippers

    select
		o.order_id,
        s.company_name,
        o.ship_country,
        round(sum(o.freight)::numeric,2) as total_weight,
		round(sum(od.unit_price*od.quantity)::numeric,2) as total_revenue
    from
        orders as o
    inner join 
        shippers as s on o.ship_via = s.shipper_id
	inner join 
		order_details as od on od.order_id = o.order_id
	group by 
		1,2,3

--4
--indirim oranlarının kendi içlerinde hangi ülkelerden daha çok satış adedi ve cirosu var

with country_sales_disc_rates as(
select 
    o.ship_country as country,
	od.discount as discount,
	count(o.order_id) as order_count,
    round(sum(od.unit_price * od.quantity)::numeric, 2) as total_sales 
from
    orders as o
inner join
    order_details as od on o.order_id = od.order_id
group by 
    1,2
),
segmented_discounts as(
select
	country,
	case
		when discount = 0 then '%0 discount'
		when discount <= 0.1 then '%0-10 discount rate'
		when discount <= 0.20 then '%10-20 discount rate'
		when discount <= 0.3 then '%20-25 discount rate'
	end as discount_segments,
	order_count,
	total_sales
from
	country_sales_disc_rates
order by 1,2
)
select
	country,
	discount_segments,
	sum(order_count) as total_orders,
	sum(total_sales) as total_sales
from
	segmented_discounts
group by
	1,2
order by
	1,2
	
-- 5 -- müşteri analizi 
-- power bi da görseleştirmesi yapıldı...
-- rfm 
-- "max_invoice_date" "1998-05-06"	"min_invoice_date" "1996-07-04" 
-- today's date "1998-05-13"
-- '1998-05-13' - min(order_date) as tenure_days,
-- inner join yapıldı ve tam eşleşme yapıldı. 2 kayıp customer_id de son ve ilk siparişler yok. "FISSA" ve "PARIS"
-- son kod parçasını temp tabloya çevirebilirim - INTO temp table rfm
-- rf scorelarının müşteri segmentasyonu organizasyonu nasıl olsun? 
-- ölçtüm biçtim excelde ve en son kararım bunlar. üstte.

select * from customers
select * from orders
select * from order_details

with customers as
(
select 
	c.customer_id,
	o.order_id,
	company_name,
	o.order_date	
from
	customers as c
inner join
	orders as o on c.customer_id = o.customer_id
),
basket_sizes as
(
select 
	order_id,
	round(sum (unit_price*quantity)::numeric,2) as basket_size
from 
	order_details
group by 
	1
),
all_orders as
(
select
	c.customer_id,
	o.order_id,
	company_name,
	order_date,
	basket_size
from 
	customers as c
inner join
	basket_sizes as o on c.order_id = o.order_id 
),
rfm as  
(
select 
	customer_id,
	company_name,
	'1998-05-13' - max(order_date) as recency,
	count(order_id) as frequency,
	sum(basket_size) as monetary
from
	all_orders
group by
	1,2
),
rfm_calc as
(
select 
	r.*,
    ntile(4) over (order by Recency) rfm_recency,
    ntile(4) over (order by Frequency) rfm_frequency,
    ntile(4) over (order by Monetary) rfm_monetary
from RFM as r
),
rfm_scores as
(
select
	customer_id,
	company_name,
	recency,
	frequency,
	monetary,
	rfm_recency,
	rfm_frequency,
	rfm_monetary,
	rfm_recency+rfm_frequency+rfm_monetary as rfm_total,
    cast(rfm_recency as varchar) || cast(rfm_frequency as varchar) || cast(rfm_monetary as varchar)as rfm_score
from rfm_calc as c
)

select 
	customer_id,
	recency,
	frequency,
	monetary,
	rfm_score,
    	case 
        	when rfm_score in ('321','332') then 'At Risk' 
        	when rfm_score in ('343','344','323','333') then 'Cant loose them'
        	when rfm_score in ('244','144') then 'Champions'
        	when rfm_score in ('134','123','122','121','234','243','322') then 'Customer'
       		when rfm_score in ('432','421','422') then 'Farewelled' 
        	when rfm_score in ('143','133','142','233','232') then 'Loyal Customers'
			when rfm_score in ('444','433','434') then 'Need Attention' 
        	when rfm_score in ('111','212','211') then 'Newbies'
        	when rfm_score in ('311','312','411','412','413') then 'One Timers'
        	when rfm_score in ('222','223') then 'Potential customer'
    end rfm_segmentation
from rfm_scores

-- 6
-- python görselleştirmesi yapıldı...
-- Hangi indirim oranlarında satış daha çok ??

with country_sales_disc_rates as(
select 
    o.ship_country as country,
	od.discount as discount,
	count(o.order_id) as order_count,
    round(sum(od.unit_price * od.quantity)::numeric, 2) as total_sales 
from
    orders as o
inner join
    order_details as od on o.order_id = od.order_id
group by 
    1,2
),
segmented_discounts as(
select
	country,
	case
		when discount = 0 then '%0 discount'
		when discount <= 0.1 then '%0-10 discount rate'
		when discount <= 0.20 then '%10-20 discount rate'
		when discount <= 0.3 then '%20-25 discount rate'
	end as discount_segments,
	order_count,
	total_sales
from
	country_sales_disc_rates
order by 1,2
),
discount_segmented_totals as(
select
	country,
	discount_segments,
	sum(order_count) as total_orders,
	sum(total_sales) as total_sales
from
	segmented_discounts
group by
	1,2
order by
	1,2
)
select
	discount_segments,
	sum(total_orders) as total_orders,
	sum(total_sales) as total_sales
from
	discount_segmented_totals
group by
	1

-- 7
-- python da görselleştirmesi yapıldı...
-- aa,a,b,c segmentleri yaratıp bu segmentlerde kaç ürün satıldığına bakılacak
select * from products
select * from orders
select * from order_details

with price_segments as (
        select
			product_id,
			product_name,
            unit_price,
            case when unit_price < 30 then 'Low price segment "<30"'
					when unit_price < 75 then 'Medium price segment "<70"'
					when unit_price < 100 then 'High price segment "<100"'
					else 'Luxury price segment ">100"'
				end price_segments	
          FROM products
),
order_quantities as (
	select
		product_id,
		sum(quantity) as total_quantity_sold
	from
		order_details
	group by
		1
)
  select 
      product_name,
      unit_price,
      price_segments,
	  total_quantity_sold,
      count(product_name) over (partition by price_segments) as segment_product_count
  from 
	  price_segments as ps
  inner join
  	  order_quantities as oq on ps.product_id = oq.product_id

-- 8
-- power bi
-- Mevsimsel olarak hangi kategori en çok ciroyu ne zamanlar yapmış?
Select * from categories
select * from products
select * from order_details


with monthly_sales_all_type as 
(
select
	od.order_id,
	od.product_id,
	p.product_name,
	c.category_name,
	extract(year from o.order_date) as by_year,
	extract(month from o.order_date) as by_month,
	round((od.discount*100)::numeric,2) as discount_rate,
	round(round(sum(od.unit_price * od.quantity)::numeric,2) * round(1.00 - od.discount::numeric, 2)::numeric, 2) as actual_revenue
from 
	categories as c
left join
	products as p on p.category_id = c.category_id
left join 
	order_details as od on p.product_id = od.product_id
left join 
	orders as o on o.order_id = od.order_id
group by
	1,2,3,4,5,6,7
),
seasonal_cat_sales as(
select
	order_id,
	product_id,
	product_name,
	category_name,
	by_year,
	case 
		when by_month in (12,1,2) then 'Winter'
		when by_month in (3,4,5) then 'Spring'
		when by_month in (6,7,8) then 'Summer'
		else 'Autumn'
		end as by_season,
	sum(actual_revenue) as total_revenue_made
from
	monthly_sales_all_type
group by
	1,2,3,4,5,6
)
select
	order_id,
	product_id,
	product_name,
	category_name,
	by_year,
	sum(case when by_season = 'Summer' then total_revenue_made else 0 end) as summer_sales,
	sum(case when by_season = 'Spring' then total_revenue_made else 0 end) as spring_sales,
    sum(case when by_season = 'Autumn' then total_revenue_made else 0 end) as Autumn_sales,
	sum(case when by_season = 'Winter' then total_revenue_made else 0 end) as winter_sales
from
   	seasonal_cat_sales
group by
 	1,2,3,4,5


