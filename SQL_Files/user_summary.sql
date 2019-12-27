Create materialized view auctions.user_summary as
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
    --min(bid_response_time_seconds) as min_bid_response_time_seconds,
    avg(bid_response_time_seconds) as avg_bid_response_time_seconds,
    max(bid_response_time_seconds) as max_bid_response_time_seconds,
    sum(case when is_bid_back then 1 else 0 end) as bid_back_count
    FROM
    (
        Select
        auction_id,
        bid_number,
        retrieval_time,
        EXTRACT(epoch from h.retrieval_time - lag(h.retrieval_time,1) 
                Over (PARTITION BY h.auction_id ORDER BY  h.bid_number)) as bid_response_time_seconds,
        bidder,
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
    Select winner as bidder, sum(voucher_bids_number) as voucher_bids_number_total FROM
    (
		Select winner, cast(substring(item_name for position('-' in item_name) - 1) as INTEGER) as voucher_bids_number
		from auctions.auction Where item_name like '%voucher%'
		Union ALL
		Select winner, cast(substring(voucher for position(' ' in voucher) - 1) as INTEGER) as voucher_bids_number
		from auctions.auction Where voucher != ''
		Union ALL
		/*added to capture all bidders making the join more clear in the result*/
		Select distinct bidder as winner, 0 as voucher_bids_number
		from auctions.bid_history
    ) t
    Group by winner
),
value AS
(
    --user value generated and bid ratio summary
    Select
    t.bidder,
    round(max(bid_count_over_max_bids_ratio),3) as max_bid_ratio,
    sum(CASE WHEN is_winner THEN 1 ELSE 0 END) as win_count,
    sum(CASE WHEN is_winner THEN price_difference ELSE 0 END) as total_winning_value,
    --sum(t.bid_count)*0.4 as total_bid_cost,
    sum(CASE WHEN NOT is_winner AND should_buy THEN gain_if_buy_now ELSE 0 END) as total_gain_if_buy_now
    From
    (
        --need to subtract out number of voucher bids won from calculation of total cost of all bids
        --group by auction, bidder
        Select h.auction_id, h.bidder, count(*) as bid_count,
        a.actual_price/0.4 as max_bids_per_user,
        count(*)/(a.actual_price/0.4) as bid_count_over_max_bids_ratio,
        (a.actual_price - a.win_price) as price_difference,
        case when h.bidder = a.winner then true else false end as is_winner,
        /*additional logic may be required here*/
        case when h.bidder != a.winner and ((count(*)*0.4)/a.actual_price) > 0.3  then true else false end as should_buy,
        /*assumes 20 percent loss on product resell, this could vary widely and needs to be enhanced with product data*/
        (count(*)*0.4) - (a.actual_price - a.actual_price*0.8) as gain_if_buy_now
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
    count(*) as total_bid_count,
    count(distinct auction_id) as total_auction_count,
    min(retrieval_time) as min_retrieval_time,
    max(retrieval_time) as max_retrieval_time,
    max(retrieval_time) - min(retrieval_time) as duration_active,
    case when max(retrieval_time) > current_date - interval '21 days' then true else false end as is_currently_active
    From auctions.bid_history b
    Group by bidder
)
Select
bidder.bidder,
bidder.total_bid_count,
voucher.voucher_bids_number_total,
bidder.total_bid_count - voucher.voucher_bids_number_total as total_bids_less_voucher,
bidder.total_auction_count,
bidder.min_retrieval_time,
bidder.max_retrieval_time,
bidder.duration_active,
bidder.is_currently_active,
bid.avg_bid_response_time_seconds,
bid.max_bid_response_time_seconds,
bid.bid_back_count,
round(bid.bid_back_count/cast(total_bid_count as numeric),3) as bid_back_ratio,
value.max_bid_ratio,
value.win_count,
round(value.win_count/cast(bidder.total_auction_count as numeric),3) as win_ratio,
value.total_winning_value,
value.total_gain_if_buy_now,
(bidder.total_bid_count - voucher.voucher_bids_number_total)*0.4 as total_bids_cost,
value.total_winning_value + value.total_gain_if_buy_now - ((bidder.total_bid_count - voucher.voucher_bids_number_total)*0.4)/*total_bids_cost*/ as net_profit
From bidder
Full Outer Join bid on bidder.bidder = bid.bidder
Left Outer Join voucher on bidder.bidder = voucher.bidder
Full Outer Join value on bidder.bidder = value.bidder
)