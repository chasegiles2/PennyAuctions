Create or replace view auctions.monitor_hour_threshold as
/*
use this query to set the threshold by hour for the monitoring
suggest to add 5 minutes to the max result and use that in the monitoring script
*/
Select auction_hour, min(difference), avg(difference), max(difference) from
(
	Select 
	auction_time,
	extract(HOUR from auction_time) as auction_hour,
	auction_time - lag(auction_time) over (order by auction_time) as difference from
	(
	Select max(retrieval_time) as auction_time from auctions.bid_history
	Group by auction_id
	Order by max(retrieval_time)
	) auction_end
) y
Where difference < '06:00:00' --removes outliers caused by outages
Group by auction_hour