-- View: auctions.monitor_hour_threshold

-- DROP VIEW auctions.monitor_hour_threshold;

CREATE OR REPLACE VIEW auctions.monitor_hour_threshold AS
 SELECT y.auction_hour,
    min(y.difference) AS min,
    avg(y.difference) AS avg,
    max(y.difference) AS max,
	extract(hour FROM max(y.difference))*3600 + extract(minute FROM max(y.difference))*60 + extract(second FROM max(y.difference)) AS max_seconds
   FROM ( SELECT auction_end.auction_time,
		
			  
            date_part('hour'::text, auction_end.auction_time) AS auction_hour,
            auction_end.auction_time - lag(auction_end.auction_time) OVER (ORDER BY auction_end.auction_time) AS difference
           FROM ( SELECT max(bid_history.retrieval_time) AS auction_time
                   FROM auctions.bid_history
                  GROUP BY bid_history.auction_id
                  ORDER BY (max(bid_history.retrieval_time))) auction_end) y
			  
   
  WHERE y.difference < '06:00:00'::interval
  GROUP BY y.auction_hour;

ALTER TABLE auctions.monitor_hour_threshold
    OWNER TO auction_user;

