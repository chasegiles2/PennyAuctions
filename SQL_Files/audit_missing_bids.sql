create view auctions.audit_missing_bids as
SELECT
	auction_id,
	diff
FROM 
    (SELECT a.auction_id,
         a.win_price,
         h.bid_count,
         (a.win_price*100)- h.bid_count AS diff
    FROM "auctions"."auction" a
    INNER JOIN 
        (SELECT auction_id,
         Count(*) AS bid_count
         FROM auctions.bid_history
         GROUP BY  auction_id
		) h
         ON a.auction_id = h.auction_id 
	) x
WHERE diff > 0
;