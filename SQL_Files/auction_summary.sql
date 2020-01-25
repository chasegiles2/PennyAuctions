create or replace view auctions.auction_summary as
with s as
(
	Select
	h.auction_id,
	min(h.retrieval_time) as min_retrieval_time,
	max(h.retrieval_time) as max_retrieval_time,
	max(h.retrieval_time) - min(h.retrieval_time) as duration,
	count(*) as count_total_bids,
	sum(case when h.bidder = a.winner then 1 end) as count_winner_bids,
	sum(case when h.bid_method = 'Single Bid' then 1 end) as count_single_bid,
	sum(case when h.bid_method = 'BidOMatic' then 1 end) as count_bidomatic
	from auctions.bid_history h
	inner join auctions.auction a on h.auction_id = a.auction_id
	Group by h.auction_id
)
, l as
(
	Select
	h.auction_id,
	price_when_locked,
	h.retrieval_time as retrieval_time_when_locked
	from auctions.bid_history h
	Inner Join
	(
		Select
		h.auction_id,
		min(h.price) as price_when_locked
		from auctions.bid_history h
		Where h.lock_state = true
		Group by h.auction_id
	) lock_price
	On h.auction_id = lock_price.auction_id and h.price = lock_price.price_when_locked
)
Select
a.*,
(a.actual_price - a.win_price) as price_difference,
s.min_retrieval_time,
s.max_retrieval_time,
s.duration,
EXTRACT(HOUR from s.duration)*3600 + EXTRACT(MINUTE from s.duration)*60 + EXTRACT(SECOND from s.duration) as duration_seconds,
case when l.price_when_locked is null then False else True end as is_auction_locked,
(s.max_retrieval_time - l.retrieval_time_when_locked) as duration_when_locked,
EXTRACT(HOUR from (s.max_retrieval_time - l.retrieval_time_when_locked))*3600 + EXTRACT(MINUTE from (s.max_retrieval_time - l.retrieval_time_when_locked))*60 + EXTRACT(SECOND from (s.max_retrieval_time - l.retrieval_time_when_locked)) as duration_when_locked_seconds,
l.price_when_locked,
s.count_total_bids,
s.count_single_bid,
s.count_bidomatic,
s.count_winner_bids
from auctions.auction a
left join s on a.auction_id = s.auction_id
left join l on a.auction_id = l.auction_id
;