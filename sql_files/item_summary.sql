--item_summary
Select
item_id,
item_name,
voucher,
-- array_to_string(array_agg(distinct voucher),',') as voucher_agg,
count(*) as count_auctions,
min(win_price) as min_win_price, max(win_price) as max_win_price, avg(win_price) as avg_win_price, stddev(win_price) as stddev_win_price, 
case when avg(actual_price) != min(actual_price) then false else true end as is_actual_price_stable, /*more accurate when you group by voucher as well*/
min(actual_price) as min_actual_price, max(actual_price) as max_actual_price, avg(actual_price) as avg_actual_price, stddev(actual_price) as stddev_actual_price, 
round(sum(case when bidomatic_on = true then 1 else 0 end)/cast(count(*) as numeric),3) as bidomatic_on_ratio,
min(duration) as min_duration, max(duration) as max_duration, avg(duration) as avg_duration,-- stddev(duration) as stddev_duration, 
round(sum(case when is_auction_locked = true then 1 else 0 end)/cast(count(*) as numeric),3) as auctions_locked_ratio,
min(duration_when_locked) as min_duration_when_locked, max(duration_when_locked) as max_duration_when_locked, avg(duration_when_locked) as avg_duration_when_locked,-- stddev(duration_when_locked) as stddev_duration_when_locked, 
min(price_when_locked) as min_price_when_locked, max(price_when_locked) as max_price_when_locked, avg(price_when_locked) as avg_price_when_locked, stddev(price_when_locked) as stddev_price_when_locked, 
min(count_total_bids) as min_count_total_bids, max(count_total_bids) as max_count_total_bids, avg(count_total_bids) as avg_count_total_bids, stddev(count_total_bids) as stddev_count_total_bids, 
min(count_single_bid) as min_count_single_bid, max(count_single_bid) as max_count_single_bid, avg(count_single_bid) as avg_count_single_bid, stddev(count_single_bid) as stddev_count_single_bid, 
min(count_bidomatic) as min_count_bidomatic, max(count_bidomatic) as max_count_bidomatic, avg(count_bidomatic) as avg_count_bidomatic, stddev(count_bidomatic) as stddev_count_bidomatic, 
min(count_winner_bids) as min_count_winner_bids, max(count_winner_bids) as max_count_winner_bids, avg(count_winner_bids) as avg_count_winner_bids, stddev(count_winner_bids) as stddev_count_winner_bids
from auctions.auction_summary
Where winner != 'No Winner'
Group by item_id, item_name, voucher
Order by item_id, voucher DESC
;

--bucketizing by price
Select
b.small_bucket,
--b.large_bucket,
count(*),
min(s.actual_price),
max(s.actual_price)
from auctions.auction_summary s
Inner join 
(
    Select auction_id,
    width_bucket(actual_price,0,100,20) as small_bucket,
    width_bucket(actual_price,100,500,20) as large_bucket
    from auctions.auction
    Where winner != 'No Winner'
) b
on b.auction_id = s.auction_id
Group by b.small_bucket
Order by small_bucket
;