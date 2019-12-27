--sql for auction schema, used in postgres

CREATE TABLE auctions.auction
(
    auction_id integer,
    item_id character varying(30) COLLATE pg_catalog."default",
    item_name character varying(100) COLLATE pg_catalog."default",
    auction_link character varying(150) COLLATE pg_catalog."default",
    winner character varying(100) COLLATE pg_catalog."default",
    win_price numeric(7,2),
    actual_price numeric(7,2),
	voucher character varying(100) COLLATE pg_catalog."default",
	bidomatic_on boolean
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE auctions.auction
    OWNER to auction_user;

--after load
ALTER TABLE auctions.auction ADD PRIMARY KEY (auction_id);
	
CREATE TABLE auctions.bid_history
(
    auction_id integer,
    bid_number integer,
    bidder character varying(100) COLLATE pg_catalog."default",
    price numeric(7,2),
    bid_method character varying(30) COLLATE pg_catalog."default",
    auction_time integer,
    retrieval_time timestamp without time zone,
    lock_state boolean
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE auctions.bid_history
    OWNER to auction_user;
	
--after load
ALTER TABLE auctions.bid_history ADD PRIMARY KEY (auction_id,price);