Create or Replace Procedure auctions.clean_auctions()
LANGUAGE SQL
AS $$

--Remove duplicates from both tables
Delete From auctions.auction Where auction_id in
(
	Select auction_id from
	(
		Select auction_id, ROW_NUMBER() 
			OVER (PARTITION BY (auction_id) ORDER BY auction_id) row_num
		From auctions.auction
	) x
	Where row_num > 1
)
;

Delete From auctions.bid_history Where auction_id in
(
	Select auction_id from
	(
		Select auction_id, price, ROW_NUMBER() 
			OVER (PARTITION BY (auction_id, price) ORDER BY auction_time) row_num
		From auctions.bid_history
	) x
	Where row_num > 1
)
;


/*
Remove auctions where no bids were retrieved
	- exclude where the win_price = 0 because it would be expected to have no bids
*/
Delete From auctions.auction Where auction_id in
(
	Select auction_id from auctions.auction Where win_price != 0
	Except
	Select DISTINCT auction_id from auctions.bid_history
)
;

--Remove auctions that only exist in bid_history
Delete From auctions.bid_history Where auction_id in
(
	Select DISTINCT auction_id from auctions.bid_history
	Except
	Select auction_id from auctions.auction Where win_price != 0
)
;

$$;