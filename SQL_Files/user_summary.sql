-- drop materialized view auctions.user_summary_mv;
-- drop view auctions.user_summary;

-- Create materialized view auctions.user_summary_mv as
Create or replace view auctions.user_summary as
(
/* user activity summary */
with bid AS
(
    /*
    bid response time and bid backs
    (not including any bids above 10 seconds)
    */
    Select
    bid.bidder,
    avg(bid_response_time_seconds) as avg_bid_response_time_seconds,
    avg(case when bid_method = 'BidOMatic' then bid_response_time_seconds else NULL end) as avg_bid_response_time_seconds_bidomatic,
    avg(case when bid_method = 'Single Bid' then bid_response_time_seconds else NULL end) as avg_bid_response_time_seconds_single,
    avg(case when lock_state = True and bid_method = 'Single Bid' then bid_response_time_seconds else NULL end) as avg_bid_response_time_seconds_single_locked,
    avg(case when lock_state = False and bid_method = 'Single Bid' then bid_response_time_seconds else NULL end) as avg_bid_response_time_seconds_single_not_locked,
    sum(case when is_bid_back then 1 else 0 end) as count_bid_back,
    sum(case when is_bid_back and bid_method = 'BidOMatic' then 1 else 0 end) as count_bid_back_bidomatic,
    sum(case when is_bid_back and bid_method = 'Single Bid' then 1 else 0 end) as count_bid_back_single,
    sum(case when is_bid_back and lock_state = True then 1 else 0 end) as count_bid_back_locked,
    sum(case when is_bid_back and lock_state = True and bid_method = 'BidOMatic' then 1 else 0 end) as count_bid_back_bidomatic_locked,
    sum(case when is_bid_back and lock_state = True and bid_method = 'Single Bid' then 1 else 0 end) as count_bid_back_single_locked,
    sum(case when is_bid_back and lock_state = False then 1 else 0 end) as count_bid_back_not_locked,
    sum(case when is_bid_back and lock_state = False and bid_method = 'BidOMatic'  then 1 else 0 end) as count_bid_back_bidomatic_not_locked,
    sum(case when is_bid_back and lock_state = False and bid_method = 'Single Bid'  then 1 else 0 end) as count_bid_back_single_not_locked
    FROM
    (
        Select
        bidder,
        lock_state,
        bid_method,
        EXTRACT(epoch from h.retrieval_time - lag(h.retrieval_time,1) 
                Over (PARTITION BY h.auction_id ORDER BY  h.bid_number)) as bid_response_time_seconds,
        case when lag(h.bidder,2) Over (PARTITION BY h.auction_id ORDER BY  h.bid_number) = bidder 
            then true else false end as is_bid_back
        from auctions.bid_history h
        Where auction_time <= 10
    ) bid
    Group by bid.bidder
),
voucher AS
(
    --user voucher bids won
    Select winner as bidder, sum(count_voucher_bids) as count_voucher_bids FROM
    (
		Select winner, cast(substring(item_name for position('-' in item_name) - 1) as INTEGER) as count_voucher_bids
		from auctions.auction Where item_name like '%voucher%'
		Union ALL
		Select winner, cast(substring(voucher for position(' ' in voucher) - 1) as INTEGER) as count_voucher_bids
		from auctions.auction Where voucher != ''
		Union ALL
		/*added to capture all bidders making the join more clear in the result*/
		Select distinct bidder as winner, 0 as count_voucher_bids
		from auctions.bid_history
    ) t
    Group by winner
),
value AS
(
    --user value generated and bid ratio summary
    Select
    t.bidder,
    round(max(count_bids_over_max_bids_ratio),3) as max_bid_ratio,
    sum(CASE WHEN is_auction_locked THEN 1 ELSE 0 END) as count_auctions_locked,
    sum(CASE WHEN is_winner THEN 1 ELSE 0 END) as count_wins,
    sum(CASE WHEN is_winner and is_auction_locked THEN 1 ELSE 0 END) as count_wins_locked,
    sum(CASE WHEN is_winner THEN price_difference ELSE 0 END) as sum_value_won
    From
        --group by auction, bidder
    (
        Select h.auction_id, h.bidder,
        a.actual_price/0.4 as max_bids_per_user,
        count(*)/(a.actual_price/0.4) as count_bids_over_max_bids_ratio,
        (a.actual_price - a.win_price) as price_difference,
        case when h.bidder = a.winner then true else false end as is_winner,
        bool_or(h.lock_state) as is_auction_locked
        from auctions.bid_history h
        Inner Join auctions.auction a on h.auction_id = a.auction_id
        Group by h.auction_id, h.bidder, a.actual_price, a.win_price, a.winner
    ) t
    Group by t.bidder
),
bidder as 
(
    Select
    b.bidder,
    count(*) as count_bids,
    sum(case when bid_method = 'Single Bid' then 1 else 0 end)+ 1 as count_single_bid,
    sum(case when bid_method = 'BidOMatic' then 1 else 0 end)+ 1 as count_bidomatic_bid,
    sum(case when lock_state = True then 1 else 0 end) + 1 as count_bid_locked,
    sum(case when lock_state = False then 1 else 0 end) + 1 as count_bid_not_locked,
    sum(case when bid_method = 'Single Bid' and lock_state = False then 1 else 0 end) + 1 as count_single_bid_not_locked,
    sum(case when bid_method = 'Single Bid' and lock_state = True then 1 else 0 end) + 1 as count_single_bid_locked,
    sum(case when bid_method = 'BidOMatic' and lock_state = False then 1 else 0 end) + 1 as count_bidomatic_bid_not_locked,
    sum(case when bid_method = 'BidOMatic' and lock_state = True then 1 else 0 end) + 1 as count_bidomatic_bid_locked,
    count(distinct auction_id) as count_auctions,
    min(retrieval_time) as min_retrieval_time,
    max(retrieval_time) as max_retrieval_time,
    max(retrieval_time) - min(retrieval_time) as duration,
    EXTRACT(DAY from max(retrieval_time) - min(retrieval_time)) + 1 as duration_days,
    Count(DISTINCT DATE(retrieval_time)) count_active_days,
    case when max(retrieval_time) > current_date - interval '21 days' then true else false end as is_currently_active
    From auctions.bid_history b
    Group by bidder
)
Select
bidder.bidder,
bidder.count_bids,
round(cast(bidder.count_bidomatic_bid as numeric)/bidder.count_bids,3) as bidomatic_ratio,
round(cast(bidder.count_bidomatic_bid_locked as numeric)/bidder.count_bids,3) as bidomatic_locked_ratio,
round(cast(bidder.count_bidomatic_bid_not_locked as numeric)/bidder.count_bids,3) as bidomatic_not_locked_ratio,
voucher.count_voucher_bids,
round(cast(voucher.count_voucher_bids as numeric)/bidder.count_bids,3) as voucher_bid_ratio,
bidder.count_bids - voucher.count_voucher_bids as total_bids_less_voucher,
bidder.count_auctions,
round(bidder.count_auctions/cast(bidder.count_active_days as numeric),3) as auctions_per_active_day,
-- value.count_auctions_locked,
round(cast(value.count_auctions_locked as numeric)/bidder.count_auctions,3) as locked_auctions_ratio,
-- bidder.min_retrieval_time,
-- bidder.max_retrieval_time,
-- bidder.duration_active,
bidder.duration_days,
bidder.count_active_days,
round(bidder.count_active_days/cast(bidder.duration_days as numeric),3) as active_days_ratio,
bidder.is_currently_active,
round(bidder.count_bids/cast(bidder.duration_days as numeric),3) as bids_per_day,
round(bidder.count_bids/cast(bidder.count_active_days as numeric),3) as bids_per_active_day,
round(cast(bid.avg_bid_response_time_seconds as numeric),3) as avg_bid_response_time_seconds,
round(cast(bid.avg_bid_response_time_seconds_bidomatic as numeric),3) as avg_bid_response_time_seconds_bidomatic,
round(cast(bid.avg_bid_response_time_seconds_single as numeric),3) as avg_bid_response_time_seconds_single,
round(cast(bid.avg_bid_response_time_seconds_single_locked as numeric),3) as avg_bid_response_time_seconds_single_locked,
round(cast(bid.avg_bid_response_time_seconds_single_not_locked as numeric),3) as avg_bid_response_time_seconds_single_not_locked,
round(bid.count_bid_back/cast(count_bids as numeric),3) as bid_back_ratio,
round(bid.count_bid_back_bidomatic/cast(bidder.count_bidomatic_bid as numeric),3) as bid_back_bidomatic_ratio,
round(bid.count_bid_back_single/cast(bidder.count_single_bid as numeric),3) as bid_back_single_ratio,
round(bid.count_bid_back_locked/cast(count_bid_locked as numeric),3) as bid_back_locked_ratio,
round(bid.count_bid_back_bidomatic_locked/cast(bidder.count_bidomatic_bid_locked as numeric),3) as bid_back_bidomatic_locked_ratio,
round(bid.count_bid_back_single_locked/cast(bidder.count_single_bid_locked as numeric),3) as bid_back_single_locked_ratio,
round(bid.count_bid_back_not_locked/cast(count_bid_not_locked as numeric),3) as bid_back_not_locked_ratio,
round(bid.count_bid_back_bidomatic_not_locked/cast(bidder.count_bidomatic_bid_not_locked as numeric),3) as bid_back_bidomatic_not_locked_ratio,
round(bid.count_bid_back_single_not_locked/cast(bidder.count_single_bid_not_locked as numeric),3) as bid_back_single_not_locked_ratio,
value.max_bid_ratio,
value.count_wins,
value.count_wins_locked,
round(value.count_wins/cast(bidder.count_auctions as numeric),3) as win_ratio,
case when count_wins = 0 then 0.00 else round(cast(value.count_wins_locked as numeric)/value.count_wins,3) end as wins_locked_ratio,
value.sum_value_won,
value.sum_value_won - (voucher.count_voucher_bids * 0.4) as sum_value_won_less_vouchers,
round((value.sum_value_won - (voucher.count_voucher_bids * 0.4))/count_auctions,3) as sum_value_won_less_vouchers_per_auction,
(bidder.count_bids - voucher.count_voucher_bids)*0.4 as cost_bids_less_vouchers,
round(((bidder.count_bids - voucher.count_voucher_bids)*0.4)/count_auctions,3) as cost_bids_less_vouchers_per_auction
From bidder
Full Outer Join bid on bidder.bidder = bid.bidder
Left Outer Join voucher on bidder.bidder = voucher.bidder
Full Outer Join value on bidder.bidder = value.bidder
)
;
