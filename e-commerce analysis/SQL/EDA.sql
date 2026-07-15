-- GMV & ORDERS
select count(*)
from orders o 
where date_trunc('month', o.order_date ) != date '2025-11-01'

-- GMV и количество заказов по месяцам
select
	date_trunc('month', o.order_date) as month,
	round(sum(o.total_amount) filter(where o.order_status not in ('cancelled', 'returned'))::numeric) as gmv,
	count(*) as total_orders,
	count(*) filter(where o.order_status not in ('cancelled', 'returned')) as successful_orders
from orders o
where date_trunc('month', o.order_date) != date '2025-11-01'
group by month
order by month

-- распределение стоимости заказов
select 
	o.order_id ,
	o.total_amount 
from orders o 
where date_trunc('month', o.order_date ) != date '2025-11-01'


-- распределение статусов заказов
select
	order_status,
	count(*) as orders_count,
	round(count(*)::numeric/(select count(*) from orders)::numeric*100, 2) as pct_of_total
from orders o 
group by o.order_status
order by orders_count desc;

select
	date_trunc('month',o.order_date) as month,
	order_status,
	count(*) as orders_count
from orders o 
where (o.order_status in ('cancelled', 'returned')) and date_trunc('month',o.order_date) != date '2025-11-01'
group by date_trunc('month',o.order_date), o.order_status
order by date_trunc('month',o.order_date);

-- AOV

select 
	round(avg(o.total_amount )::numeric, 2) as total_aov,
	round(avg(o.total_amount ) filter(where o.order_status not in ('cancelled', 'returned'))::numeric, 2) as clear_aov
from orders o;

select 
	date_trunc('month', o.order_date) as month,
	round(avg(o.total_amount )::numeric, 2) as total_aov
from orders o 
where date_trunc('month', o.order_date) != '2025-11-01'
group by date_trunc('month', o.order_date)
order by date_trunc('month', o.order_date)

-- PRODUCTS

-- выручка и количество проданных единиц по категориям
select 
	p.category , 
	sum(oi.quantity ) as sold_items, 
	round(sum(oi.item_total )) as gmv,
	round(avg(oi.item_price)::numeric, 2) as avg_price
from order_items oi 
inner join orders o 
	on oi.order_id = o.order_id 
inner join products p 
	on oi.product_id = p.product_id
group by p.category 
order by gmv desc;

select
	date_trunc('month', order_date) as month,
	p.category ,
	sum(oi.item_total ) as gmv
from products p
inner join order_items oi 
	on p.product_id = oi.product_id
inner join orders o 
	on oi.order_id = o.order_id
where date_trunc('month', order_date) != date '2025-11-01'
group by month , p.category 


-- топ 5 товаров по выручке в каждой категории
select * from 
	(select 
		p.category , 
		p.product_name , 
		round(sum(item_total)) as revenue, 
		sum(oi.quantity) as sold_items,
		dense_rank()over(partition by p.category 
						order by sum(item_total) desc) as rnk
	from order_items oi 
	inner join orders o 
		on oi.order_id = o.order_id 
	inner join products p 
		on oi.product_id = p.product_id
	group by p.product_id , p.category 
	order by p.category , rnk ) t1
where rnk <= 5;

-- cancellation rate по категориям
select 
	p.category,
	count(distinct o.order_id) 
		filter(where o.order_status = 'cancelled') as count_cancellations,
	round(count(distinct o.order_id) 
		filter(where o.order_status = 'cancelled')::numeric / count(distinct o.order_id)*100, 1) as cancellation_rate,
	round(sum(o.total_amount) 
		filter(where o.order_status = 'cancelled')::numeric) as revenue_lost
from orders o 
inner join order_items oi 
	on o.order_id = oi.order_id
inner join products p 
	on oi.product_id = p.product_id
group by p.category;

-- returned rate по категориям
select 
	p.category,
	count(distinct o.order_id) 
		filter(where o.order_status = 'returned') as count_returns,
	round(count(distinct o.order_id) 
		filter(where o.order_status = 'returned')::numeric / count(distinct o.order_id)*100, 1) as returns_rate,
	round(sum(o.total_amount) 
		filter(where o.order_status = 'returned')::numeric) as revenue_lost
from orders o 
inner join order_items oi 
	on o.order_id = oi.order_id
inner join products p 
	on oi.product_id = p.product_id
group by p.category;

-- когорты на основании даты первой покупки

with c as (
select 
	date(date_trunc('month', min(o.order_date) )) as cohort_month,
	o.user_id 
from orders o
where o.order_status not in ('cancelled', 'returned')
group by o.user_id 
)

select 
	c.cohort_month,
	date(date_trunc('month', o.order_date)) as purchase_month,
	extract(month from age(date(date_trunc('month', o.order_date)),cohort_month))
	+
	extract(year from age(date(date_trunc('month', o.order_date)),cohort_month))*12 as purchase_month_number,
	count(distinct o.user_id ) count_users,
	round(sum(o.total_amount )) as gmv,
	round(sum(o.total_amount )::numeric/count(distinct o.user_id ), 2) arppu
from c
inner join orders o 
	on c.user_id = o.user_id 
where o.order_status not in ('cancelled', 'returned')
group by cohort_month, date(date_trunc('month', o.order_date))
order by cohort_month, date(date_trunc('month', o.order_date));

-- при попытке написать CTE для дальнейшегорасчета gmv, arpu и arppu, 
-- столкнулась с тем, что таблицы events и orders не связаны синхронными данными
-- на это указывает одинаковый timestamp событий purchase, при одинакогом user_id и разных order_id
with user_gmv as (
select
    e.user_id,
    o.order_id,
    o.total_amount,
    e.event_timestamp
from events e
inner join orders o
    on e.user_id = o.user_id
where e.event_type = 'purchase'
)

-- запрос для оценки количества заказов на один timestamp+user_id
with purchase_events as (
select 
	e.user_id,
	e.event_timestamp 
from events e
where e.event_type = 'purchase'
)

select 
	pe.user_id,
	pe.event_timestamp,
	count(distinct o.order_id) as count_orders
from purchase_events pe
left join orders o
	on pe.user_id = o.user_id
group by pe.user_id, pe.event_timestamp
having count(distinct o.order_id) > 1
order by count_orders desc
limit 20;

--событийная аналитика
select 
	date_trunc('month', e.event_timestamp ) as month,
	count(distinct e.user_id) as active_users,
	count(distinct e.user_id ) filter(where e.event_type = 'view') as users_with_view,
	count(distinct e.user_id ) filter(where e.event_type = 'wishlist') as users_with_wishlist,
	count(distinct e.user_id ) filter(where e.event_type = 'cart') as users_with_cart,
	count(distinct e.user_id ) filter(where e.event_type = 'purchase') as users_with_purchase
from events e 
where date_trunc('month', e.event_timestamp ) != date '2025-11-01'
group by date_trunc('month', e.event_timestamp );

-- рейтинг
select 
	rating,
	count(rating)	
from reviews r
group by rating
order by 1 desc;

-- зависимость цены товара от рейтинга
select 
	rating,
	round(avg(oi.item_price::numeric),2) as avg_price,
	round(PERCENTILE_CONT(0.5) within group (order by oi.item_price )::numeric, 2) as median_price
from reviews r 
inner join order_items oi 
	on r.order_id = oi.order_id 
group by rating;
-- рейтинг товара от цены не зависит

-- рейтинги товаров в зависимости от бренда
select
	p.brand ,
	round(avg(r.rating)::numeric, 2) as avg_rating,
	PERCENTILE_CONT(0.5) within group (order by r.rating ) as median_rating
from reviews r 
inner join products p 
	on r.product_id = p.product_id 
group by p.brand 
order by 2;
-- нет различий

-- рейтинги товаров в зависимости от категории
select
	p.category,
	round(avg(r.rating)::numeric, 2) as avg_rating,
	PERCENTILE_CONT(0.5) within group (order by r.rating ) as median_rating
from reviews r 
inner join products p 
	on r.product_id = p.product_id 
group by p.category  
order by 2;
-- нет различий
