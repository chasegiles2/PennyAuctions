--z-scores of user attributes from user_summary
-- drop view auctions.user_summary_z_scores;
create view auctions.user_summary_z_scores AS
(
with base as
(
    --get average and standard deviation of certain columns
    SELECT
    avg(count_bids) as avg_count_bids, stddev(count_bids) as stddev_count_bids,
    avg(bidomatic_ratio) as avg_bidomatic_ratio, stddev(bidomatic_ratio) as stddev_bidomatic_ratio,
    avg(voucher_bid_ratio) as avg_voucher_bid_ratio, stddev(voucher_bid_ratio) as stddev_voucher_bid_ratio,
    avg(count_auctions) as avg_count_auctions, stddev(count_auctions) as stddev_count_auctions,
    avg(active_days_ratio) as avg_active_days_ratio, stddev(active_days_ratio) as stddev_active_days_ratio,
    avg(bids_per_active_day) as avg_bids_per_active_day, stddev(bids_per_active_day) as stddev_bids_per_active_day,
    avg(avg_bid_response_time_seconds) as avg_avg_bid_response_time_seconds, stddev(avg_bid_response_time_seconds) as stddev_avg_bid_response_time_seconds,
    avg(max_bid_response_time_seconds) as avg_max_bid_response_time_seconds, stddev(max_bid_response_time_seconds) as stddev_max_bid_response_time_seconds,
    avg(bid_back_ratio) as avg_bid_back_ratio, stddev(bid_back_ratio) as stddev_bid_back_ratio,
    avg(max_bid_ratio) as avg_max_bid_ratio, stddev(max_bid_ratio) as stddev_max_bid_ratio
    FROM auctions.user_summary_mv
)
Select
bidder,
(count_bids-avg_count_bids)/stddev_count_bids as z_score_count_bids,
(bidomatic_ratio-avg_bidomatic_ratio)/stddev_bidomatic_ratio as z_score_bidomatic_ratio,
(voucher_bid_ratio-avg_voucher_bid_ratio)/stddev_voucher_bid_ratio as z_score_voucher_bid_ratio,
(count_auctions-avg_count_auctions)/stddev_count_auctions as z_score_count_auctions,
(active_days_ratio-avg_active_days_ratio)/stddev_active_days_ratio as z_score_active_days_ratio,
(bids_per_active_day-avg_bids_per_active_day)/stddev_bids_per_active_day as z_score_bids_per_active_day,
(avg_bid_response_time_seconds-avg_avg_bid_response_time_seconds)/stddev_avg_bid_response_time_seconds as z_score_avg_bid_response_time_seconds,
(max_bid_response_time_seconds-avg_max_bid_response_time_seconds)/stddev_max_bid_response_time_seconds as z_score_max_bid_response_time_seconds,
(bid_back_ratio-avg_bid_back_ratio)/stddev_bid_back_ratio as z_score_bid_back_ratio,
(max_bid_ratio-avg_max_bid_ratio)/stddev_max_bid_ratio as z_score_max_bid_ratio
FROM auctions.user_summary_mv 
CROSS Join base
)
;

--python user summary
SELECT
bidder,
count_bids,
bidomatic_ratio,
voucher_bid_ratio,
count_auctions,
active_days_ratio,
bids_per_active_day,
avg_bid_response_time_seconds,
max_bid_response_time_seconds,
bid_back_ratio,
max_bid_ratio,
sum_value_won_less_vouchers,
sum_value_won_less_vouchers_per_auction,
cost_bids_less_vouchers
From auctions.user_summary_mv u
Where u.duration_active >= (Select (max(h.retrieval_time) - min(h.retrieval_time))*0.75 from auctions.bid_history h)
And u.count_auctions >= 20
;

--python zscores
SELECT
z.bidder,
z_score_count_bids,
z_score_bidomatic_ratio,
z_score_voucher_bid_ratio,
z_score_count_auctions,
z_score_active_days_ratio,
z_score_bids_per_active_day,
z_score_avg_bid_response_time_seconds,
z_score_max_bid_response_time_seconds,
z_score_bid_back_ratio,
z_score_max_bid_ratio
From auctions.user_summary_z_scores z
Inner join 
(
    Select u.bidder from auctions.user_summary_mv u
    Where u.duration_active >= (Select (max(h.retrieval_time) - min(h.retrieval_time))*0.75 from auctions.bid_history h)
    And u.count_auctions >= 20
) u
on z.bidder = u.bidder
;

SELECT
*
From auctions.user_summary_z_scores z
Inner join 
(
    Select u.bidder from auctions.user_summary_mv u
    Where u.duration_active >= (Select (max(h.retrieval_time) - min(h.retrieval_time))*0.75 from auctions.bid_history h)
    And u.count_auctions >= 20
) u
on z.bidder = u.bidder
;
