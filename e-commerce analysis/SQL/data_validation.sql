-- размер таблиц и проверка уникальности ключевых полей
select 
	'users',
	count(*) as total_rows, 
	count(distinct user_id) as unique_id 
from users u
	union all
select 
	'orders',
	count(*) as total_rows, 
	count(distinct order_id) as unique_id 
from orders
	union all
select 
	'order_items',
	count(*) as total_rows, 
	count(distinct oi.order_item_id ) as unique_id 
from order_items oi
	union all
select
	'products',
	count(*) as total_rows, 
	count(distinct product_id) as unique_id 
from products p
	union all
select 
	'reviews',
	count(*) as total_rows, 
	count(distinct review_id) as unique_id 
from reviews r
	union all
select 
	'events',
	count(*) as total_rows, 
	count(distinct event_id) as unique_id 
from events e ;

-- проверка на NULL-значения

-- users
select 
	count(*) filter(where user_id is null) as null_user_id,
	count(*) filter(where signup_date is null) as null_signup_date
from users u;
-- orders
select
	count(*) filter(where order_id is null) as null_order_id,
	count(*) filter(where user_id is null) as null_user_id,
	count(*) filter(where order_date is null) as null_order_date
from orders o;
-- order_items
select
	count(*) filter(where order_item_id is null) as null_order_item_id,
	count(*) filter(where order_id is null) as null_order_id,
	count(*) filter(where product_id is null) as null_product_id,
	count(*) filter(where user_id is null) as null_user_id,
	count(*) filter(where quantity is null) as null_order_quantity,
	count(*) filter(where item_price is null) as null_item_price,
	count(*) filter(where item_total is null) as null_item_total
from order_items oi;
-- products
select
	count(*) filter(where product_id is null) as null_product_id,
	count(*) filter(where price is null) as null_price
from products p;
-- reviews
select
	count(*) filter(where review_id is null) as null_review_id,
	count(*) filter(where order_id is null) as null_order_id,
	count(*) filter(where product_id is null) as null_product_id,
	count(*) filter(where user_id is null) as null_user_id,
	count(*) filter(where rating is null) as null_rating
from reviews r;
-- events
select
	count(*) filter(where event_id is null) as null_event_id,
	count(*) filter(where user_id is null) as null_user_id,
	count(*) filter(where product_id is null) as null_product_id,
	count(*) filter(where event_type is null) as null_event_type,
	count(*) filter(where event_timestamp is null) as null_event_timestamp
from events e;

-- проверка дубликатов
select count(*) as count_duplicates
from 
	(select count(*) from users u 
	group by u.user_id 
	having count(*) > 1
		union all
	select count(*) from orders o 
	group by o.order_id 
	having count(*) > 1
		union all
	select count(*) from order_items oi  
	group by oi.order_item_id 
	having count(*) > 1
		union all
	select count(*) from products p  
	group by p.product_id 
	having count(*) > 1
		union all
	select count(*) from reviews r 
	group by r.review_id  
	having count(*) > 1
		union all
	select count(*) from events e 
	group by e.event_id 
	having count(*) > 1) t;

-- проверка диапазонов значений

-- отрицательная цена в  products
select * 
from products p 
where price < 0;
-- рейтинг вне диапазона в products
select * 
from products p
where rating not between 1 and 5;
-- отрицательное количество товаров в order_items
select * from order_items oi
where quantity <= 0;
-- отрицательная цена в order_items
select * from order_items oi
where item_price < 0;
-- отрицательная сумма в order_items
select * from orders o
where total_amount < 0;
-- рейтинг вне диапазона в reviews
select * from reviews r
where rating not between 1 and 5

-- проверка соответствия временных диапазонов
select 
	min(o.order_date ),
	max(o.order_date )
from orders o 
union all
select
	min(review_date),
	max(review_date)
from reviews r
union all
select
	min(event_timestamp),
	max(event_timestamp)
from events e
union all
select
	min(signup_date),
	max(u.signup_date )
from users u 

-- проверка согласованности таблиц

-- orders
select 
	count(*) filter(where u.user_id is null) as missing_users
from orders o 
left join users u 
	on o.user_id = u.user_id;
-- order_items
select 
	count(*) filter(where oi.order_id is not null and o.order_id is null) as missing_orders,
	count(*) filter(where oi.order_id is not null and p.product_id is null) as missing_products,
	count(*) filter(where oi.order_id is not null and u.user_id is null) as missing_users
from order_items oi 
left join orders o 
	on oi.order_id = o.order_id 
left join products p 
	on oi.product_id = p.product_id 
left join users u 
	on oi.user_id = u.user_id;
--reviews
select 
	count(*) filter(where r.product_id is not null and p.product_id is null) as missing_products,
	count(*) filter(where r.order_id is not null and o.order_id is null) as missing_orders,
	count(*) filter(where r.user_id is not null and u.user_id is null) as missing_users
from reviews r
left join products p
	on r.product_id = p.product_id
left join orders o 
	on r.order_id = o.order_id
left join users u
	on r.user_id = u.user_id;
--events
select 
	count(*) filter(where e.user_id is not null and u.user_id is null) as missing_users,
	count(*) filter(where e.product_id is not null and p.product_id is null) as missing_products
from events e
left join users u 
	on e.user_id = u.user_id
left join products p 
	on e.product_id = p.product_id

-- оценка согласованности агрегатов

-- сравнение рейтингов в таблицах reviews и products
select count(*) from
	(select
		p.rating as rating_from_products,
		round(avg(r.rating), 2) as rating_from_reviews
	from products p
	inner join reviews r 
		on p.product_id = r.product_id
	group by p.product_id
	having round(p.rating::numeric, 2) != round(avg(r.rating::numeric), 2)) t;
-- количество товаров с отзывами
select count(distinct r.product_id)
from products p 
inner join reviews r 
	on p.product_id = r.product_id;
-- сравнение цен в таблицах order_items и orders
select count(*) from 
	(select
		p.price as price_from_product,
		oi.item_price as price_from_oi
	from products p 
	inner join order_items oi 
		on p.product_id = oi.product_id
	where p.price::numeric != oi.item_price::numeric) t;
-- сравнение сумм заказа в order_items и orders
select count(*) from
	(select
		o.order_id ,
		o.total_amount as total_from_orders,
		round(sum(oi.item_total)::numeric, 2) as sum_total
	from orders o 
	inner join order_items oi 
		on o.order_id = oi.order_id
	group by o.order_id
	having round(o.total_amount::numeric, 2) 
		!= round(sum(oi.item_total)::numeric, 2)) t
		



