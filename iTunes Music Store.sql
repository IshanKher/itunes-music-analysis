												# Apple iTunes Music Analysis #

Create schema apple_music_store;

												# Table Creation #

create table album (
  album_id int primary key,
  title varchar(250),
  artist_id int);

create table artist (
  artist_id integer primary key,
  name text
);

create table customer (
  customer_id integer primary key,
  first_name text,
  last_name text,
  company text,
  address text,
  city text,
  state text,
  country text,
  postal_code text,
  phone text,
  fax text,
  email text,
  support_rep_id integer
);

create table employee (
  employee_id integer primary key,
  last_name text,
  first_name text,
  title text,
  reports_to int,
  levels text,
  birthdate date,
  hire_date date,
  address text,
  city text,
  state text,
  country text,
  postal_code text,
  phone varchar(20),
  fax varchar(20),
  email text
);

create table genre (
  genre_id integer primary key,
  name text
);

create table invoice (
  invoice_id integer primary key,
  customer_id integer,
  invoice_date date,
  billing_address text,
  billing_city text,
  billing_state text,
  billing_country text,
  billing_postal_code text,
  total real
);

create table invoice_line (
  invoice_line_id integer primary key,
  invoice_id integer,
  track_id integer,
  unit_price real,
  quantity integer
);

create table media_type (
  media_type_id integer primary key,
  name text
);

create table playlist (
  playlist_id integer primary key,
  name text
);

create table playlist_track (
  playlist_id integer,
  track_id integer,
  primary key (playlist_id, track_id)
);

create table track (
  track_id int primary key,
  name varchar(255),
  album_id int,
  media_type_id int,
  genre_id int,
  composer varchar(255),
  milliseconds int,
  bytes int,
  unit_price decimal(5,2),
  foreign key (album_id) references album(album_id),
  foreign key (media_type_id) references media_type(media_type_id),
  foreign key (genre_id) references genre(genre_id)
);


Create or replace view vw_itune_data AS
select
	il.invoice_line_id,
    il.invoice_id,
    il.track_id,
    il.unit_price,
    il.quantity,

    i.invoice_date,
    i.total AS invoice_total,

    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.country AS customer_country,

    e.first_name AS support_rep_first,
    e.last_name AS support_rep_last,

    mt.name AS media_type,
    g.name AS genre,
    
    pt.playlist_id

from invoice_line il
join invoice i on il.invoice_id = i.invoice_id
join customer c on i.customer_id = c.customer_id
join employee e on c.support_rep_id = e.employee_id
left join playlist_track pt on il.track_id = pt.track_id
left join media_type mt on il.track_id = mt.media_type_id
left join genre g on il.track_id = g.genre_id;

Select 
	customer_id, 
    invoice_id
From vw_itune_data
order by invoice_id desc
Limit 5;


-- 1 - total rows in each table

select 'album' as table_name, count(*) as total_rows from album
union all
select 'artist', count(*) from artist
union all
select 'customer', count(*) from customer
union all
select 'employee', count(*) from employee
union all
select 'genre', count(*) from genre
union all
select 'invoice', count(*) from invoice
union all
select 'invoice_line', count(*) from invoice_line
union all
select 'media_type', count(*) from media_type
union all
select 'playlist', count(*) from playlist
union all
select 'playlist_track', count(*) from playlist_track;

-- 2 - total revenue by country

Select
	c.country,
    round(sum(i.total),2) as total_revenue,
    count(i.invoice_id) as total_invoices
from customer c
join invoice i on c.customer_id = i.customer_id
group by c.country
order by total_revenue desc;

-- 3 -  top customers by spend

select 
    c.customer_id,
    concat(c.first_name, ' ', c.last_name) as customer_name,
    c.country,
    sum(i.total) as total_spent
from customer c
join invoice i on c.customer_id = i.customer_id
group by c.customer_id, c.first_name, c.last_name, c.country
order by total_spent desc
limit 10;

-- 4 - top employees by revenue (support rep performance)

select 
    concat(e.first_name, ' ', e.last_name) as employee_name,
    round(sum(i.total), 2) as total_revenue
from employee e
join customer c on e.employee_id = c.support_rep_id
join invoice i on c.customer_id = i.customer_id
group by e.employee_id
order by total_revenue desc;

-- 5 - top playlists by track count

select
	p.name as playlist_name,
    count(pt.track_id) as total_tracks
from playlist p
join playlist_track pt on p.playlist_id = pt.playlist_id
group by p.playlist_id
order by total_tracks desc
limit 10;

select count(*) as total_track
From track;

-- 6 - average customer lifetime value

select 
    round(avg(customer_lifetime_value), 2) as avg_lifetime_value
from (
    select 
        c.customer_id,
        sum(i.total) as customer_lifetime_value
    from customer c
    join invoice i on c.customer_id = i.customer_id
    group by c.customer_id
) as lifetime_values;

-- 7 - customers who made repeat vs one-time purchases

select 
    'One-Time Purchase' as purchase_type,
    count(*) as customer_count
from (
    select customer_id
    from invoice
    group by customer_id
    having count(invoice_id) = 1
) as one_time

union all

select 
    'Repeat Purchase' as purchase_type,
    count(*) as customer_count
from (
    select customer_id
    from invoice
    group by customer_id
    having count(invoice_id) > 1
) as Repeat_customer;

-- 8 - country that generates the most revenue per customer

select
	c.country,
    round(sum(i.total) / count(distinct c.customer_id), 2) as revenue_per_customer
from customer c
join invoice i on c.customer_id = i.customer_id
group by c.country
order by revenue_per_customer desc;

-- 9 - customers haven't made a purchase in the last 6 months

select
	c.customer_id,
    concat(c.first_name, ' ', c.last_name) as customer_name,
    max(i.invoice_date) as last_purchase_date
from customer c
left join invoice i on c.customer_id = i.customer_id
group by c.customer_id, c.first_name, c.last_name
having max(i.invoice_date) < '2025-01-11' or max(i.invoice_date) is null;


-- Sales & Revenue Analysis
-- 1 - monthly revenue trends for the last two years

-- to check the date range
SELECT 
    MIN(invoice_date) AS earliest_date,
    MAX(invoice_date) AS latest_date
FROM invoice;

--

SELECT 
    DATE_FORMAT(invoice_date, '%Y-%m') AS month,
    ROUND(SUM(total), 2) AS monthly_revenue
FROM invoice
WHERE YEAR(invoice_date) IN (2019, 2020)
GROUP BY month
ORDER BY month;

-- 2 - average value of an invoice 

Select
	avg(total) As Average_invoice
From invoice;

-- 3 - sales contribution of each sales representative

select 
    concat(e.first_name, ' ', e.last_name) as employee_name,
    round(sum(i.total), 2) as total_revenue
from employee e
join customer c on e.employee_id = c.support_rep_id
join invoice i on c.customer_id = i.customer_id
group by employee_name
order by total_revenue desc;

-- 4 - months or quarters have peak music sales
-- monthly trends

select 
    date_format(invoice_date, '%Y-%m') as yearmonth,
    round(sum(total), 2) as total_revenue
from invoice
group by yearmonth
order by total_revenue desc;

-- quarterly trends

select 
    concat(year(invoice_date), '-Q', quarter(invoice_date)) as year_quarter,
    round(sum(total), 2) as total_revenue
from invoice
group by year_quarter
order by total_revenue desc;

-- 5 - Which tracks generated the most revenue

select 
    t.name as track_name,
    round(sum(il.unit_price * il.quantity), 2) as total_revenue
from invoice_line il
join track t on il.track_id = t.track_id
group by t.track_id, t.name
order by total_revenue desc
limit 10;

-- 6 - most frequently included albums or playlists in purchases
-- Albums in purchases

select 
    al.title as album_title,
    count(il.invoice_line_id) as purchase_count
from invoice_line il
join track t on il.track_id = t.track_id
join album al on t.album_id = al.album_id
group by al.album_id, al.title
order by purchase_count desc
limit 10;

-- Playlists in Purchases

select 
    p.name as playlist_name,
    count(il.invoice_line_id) as times_purchased
from playlist_track pt
join track t on pt.track_id = t.track_id
join invoice_line il on t.track_id = il.track_id
join playlist p on pt.playlist_id = p.playlist_id
group by p.playlist_id, p.name
order by times_purchased desc
limit 10;

-- 7 - tracks or albums that have never been purchased
-- Track 

Select
	t.track_id,
    t.name as track_name
from track t
left join invoice_line il on t.track_id and il.track_id
where il.track_id is null;

-- Album

Select
	a.album_id,
    a.title as album_title
from album a
join track t on a.album_id and t.album_id
left join invoice_line il on t.track_id and il.track_id
where a.album_id is null
group by a.album_id, a.title;

-- 8 - average price per track across different genres

select
	g.name as genre_name,
    round(avg(t.unit_price), 2) as avg_price
From track t
join genre g on g.genre_id = t.genre_id
group by g.name
order by avg_price desc;

-- 9 - How many tracks does the store have per genre and how does it correlate with sales

select
	g.name as genre_name,
    count(distinct t.track_id) as total_tracks,
    sum(il.unit_price * il.quantity) as total_revenue
from genre g
left join track t on g.genre_id = t.track_id
left join invoice_line il on t.track_id = il.track_id
group by g.name
order by total_revenue desc;

-- 10 - op 5 highest-grossing artists

Select
	ar.name as artist,
    round(sum(il.unit_price * il.quantity),2) as total_revenue
from artist ar
join album a on ar.artist_id = a.artist_id
join track t on a.album_id = t.album_id
join invoice_line il on t.track_id = il.track_id
group by ar.name
order by total_revenue desc
Limit 5;

-- 11 - most popular genres in Number of tracks sold and Total revenue

Select
    g.name as genre,
    sum(il.quantity) as total_tracks_sold,
    round(sum(il.unit_price * il.quantity), 2) as total_revenue
from genre g
join track t on g.genre_id = t.genre_id
join invoice_line il on t.track_id = il.track_id
group by g.name
order by total_revenue desc;

-- 12 - genres that are more popular in specific countries

select 
    c.country,
    g.name as genre,
    sum(il.quantity) as total_tracks_sold,
    round(sum(il.unit_price * il.quantity), 2) as total_revenue
from customer c
join invoice i on c.customer_id = i.customer_id
join invoice_line il on i.invoice_id = il.invoice_id
join track t on il.track_id = t.track_id
join genre g on t.genre_id = g.genre_id
group by c.country, g.name
order by c.country, total_tracks_sold desc;

-- 13 - employees that are managing the highest-spending customers

select 
    e.employee_id,
    concat(e.first_name, ' ', e.last_name) as employee_name,
    round(sum(i.total), 2) as total_revenue_handled
from employee e
join customer c on e.employee_id = c.support_rep_id
join invoice i on c.customer_id = i.customer_id
group by e.employee_id, employee_name
order by total_revenue_handled desc;

-- 14 - average number of customers per employee

select
	round(count(*) / (select count(*) from employee), 2) as avg_customers_per_employee
from customer
where support_rep_id is not null;

-- 15 - employee regions that bring in the most revenue

Select
    e.country as employee_region,
    round(sum(i.total), 2) as total_revenue
from customer c
join employee e on c.support_rep_id = e.employee_id
join invoice i on c.customer_id = i.customer_id
group by e.country
order by total_revenue desc;

-- 16 - Countries or cities that have the highest number of customers

select 
    country,
    city,
    count(customer_id) as customer_count
from customer
group by country, city
order by customer_count desc;

-- 17 - ow does revenue vary by region

select
	billing_country,
    sum(total) as total_revenue
From invoice
group by billing_country
order by total_revenue desc;

-- 18 - underserved geographic regions

select
c.country,
    count(distinct c.customer_id) as customer_count,
    sum(i.total) as total_revenue,
    round(sum(i.total) / count(distinct c.customer_id), 2) as revenue_per_customer
from customer c
left join invoice i on c.customer_id = i.customer_id
group by c.country
order by revenue_per_customer asc;


-- 19 - distribution of purchase frequency per customer

Select
purchase_count,
    count(*) as customer_count
from (
    select 
        customer_id,
        count(invoice_id) as purchase_count
    from invoice
    group by customer_id
) as sub
group by purchase_count
order by purchase_count;

-- 20 - average time between customer purchases

select 
    customer_id,
    round(avg(datediff(invoice_date, prev_invoice_date)), 2) as avg_days_between_purchases
from (
    select 
        customer_id,
        invoice_date,
        lag(invoice_date) over (partition by customer_id order by invoice_date) as prev_invoice_date
    from invoice
) as sub
where prev_invoice_date is not null
group by customer_id
order by avg_days_between_purchases;

-- 21 - percentage of customers purchase tracks from more than one genre

select 
    round(
        (count(case when genre_count > 1 then 1 end) / count(*)) * 100, 
        2
    ) as percent_multi_genre_customers
from (
    select 
        i.customer_id,
        count(distinct t.genre_id) as genre_count
    from invoice i
    join invoice_line il on i.invoice_id = il.invoice_id
    join track t on il.track_id = t.track_id
    group by i.customer_id
) as genre_data;

-- 22 - most common combinations of tracks purchased together

select 
    least(il1.track_id, il2.track_id) as track_id_1,
    greatest(il1.track_id, il2.track_id) as track_id_2,
    count(*) as times_purchased_together
from invoice_line il1
join invoice_line il2 
    on il1.invoice_id = il2.invoice_id 
    and il1.track_id < il2.track_id
group by 
    least(il1.track_id, il2.track_id),
    greatest(il1.track_id, il2.track_id)
order by times_purchased_together desc
limit 10;

-- 23 - pricing patterns that lead to higher or lower sales

select 
    t.unit_price,
    sum(il.quantity) as total_quantity_sold,
    count(distinct il.track_id) as track_count
from invoice_line il
join track t on il.track_id = t.track_id
group by t.unit_price
order by t.unit_price;

-- 24 - media types (e.g., MPEG, AAC) are declining or increasing in usage

select 
    mt.name as media_type,
    year(i.invoice_date) as year,
    sum(il.quantity) as total_quantity_sold
from invoice_line il
join invoice i on il.invoice_id = i.invoice_id
join track t on il.track_id = t.track_id
join media_type mt on t.media_type_id = mt.media_type_id
group by mt.name, year(i.invoice_date)
order by mt.name, year;


