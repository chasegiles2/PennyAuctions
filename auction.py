import re
import sys
import time
import csv
import random
import logging

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from bs4 import BeautifulSoup
# import psycopg2
from io import StringIO
import boto3


class Auction:
    # contains all information about an auction

    def __init__(self, link, path_to_chromedriver):
        options = Options()
        options.add_argument("--headless")
        options.add_argument('--disable-gpu')
        options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.157 Safari/537.36')
        self.driver = webdriver.Chrome(executable_path=path_to_chromedriver, chrome_options=options)
        # self.driver.set_page_load_timeout(10)

        link_parsed = link.split('-', 3)
        self.link = link
        self.auction_id = link_parsed[1][:-2]  # removing US
        self.item_id = link_parsed[2]
        self.item_name = link_parsed[3]
        self.bid_count = 0
        self.attributes = {
            'winner': None,
            'win_price': None,
            'actual_price': None,
            'bid_history': []
        }

    def pretty_print(self):
        print('Auction ID: ' + self.auction_id)
        print('Item ID: ' + self.item_id)
        print('Item Name: ' + self.item_name)
        print('Link: ' + self.link)
        print('Winner: ' + str(self.attributes['winner']))
        print('Win Price: ' + str(self.attributes['win_price']))
        print('Actual Price: ' + str(self.attributes['actual_price']))

        for bid in self.attributes['bid_history'][-10:]:
            print('Bid No. ' + str(bid['bid_number']))
            print('User: ' + bid['bidder'])
            print('Price: ' + str(bid['price']))
            print('Bid Method: ' + bid['bid_method'])
            print('Seconds Remaining: ' + bid['seconds_remaining'])
            print('Retrieval Time: ' + bid['retrieval_time'])

    def watch(self):
        # loops over the auction page checking if new bids have been made
        # adds them to the auction's bid_history attribute

        def get_sec(time_str):
            # returns seconds from the hh:mm:ss format
            try:
                h, m, s = time_str.split(':')
                return int(h) * 3600 + int(m) * 60 + int(s)
            except ValueError:
                # auction has ended and string is most likely 'ended'
                pass

        logging.info("Watch started for auction: %s", self.auction_id)

        # open web page
        try:
            self.driver.get(self.link)
            logging.debug("Web page opened for auction: %s", self.auction_id)
        except Exception as e:
            logging.critical("error opening site: %s", self.link)
            logging.critical(e)
        
        # store the previous auction time each loop
        #   solves issue where the time would switch back to 10 seconds before new bid shows in history table
        previous_seconds_remaining = None
        
        refresh_lower_bound = 600
        refresh_upper_bound = 1800
        seconds_till_refresh = random.randint(refresh_lower_bound, refresh_upper_bound)
        logging.debug("Refresh set to %s seconds for auction: %s", seconds_till_refresh, self.auction_id)
        start_time = time.time()

        # for i in range(20):
        while True:
            start_perf_time_1 = time.perf_counter()
            current_time = time.time()
            if seconds_till_refresh < (current_time - start_time):
                self.driver.refresh()
                logging.info("Auction Page refreshed")
                # add additional time onto seconds_till_refresh because start_time is static
                seconds_till_refresh = seconds_till_refresh + random.randint(refresh_lower_bound, refresh_upper_bound)
            end_perf_time_1 = time.perf_counter()

            start_perf_time_2 = time.perf_counter()
            retrieval_time = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
            html = self.driver.page_source
            soup = BeautifulSoup(html, 'lxml')
            end_perf_time_2 = time.perf_counter()

            start_perf_time_3 = time.perf_counter()
            try:
                # check if there is an auction winner
                if soup.find('p', {'class': 'won_price'}):
                    winner = soup.find('span', {'class': 'won_username'}).string
                    final_price = soup.find('p', {'class': 'won_price'}).string

                    # verify there is a digit
                    if bool(re.search(r'\d', final_price)):
                        # strip the dollar sign from final and actual price
                        final_price = float(final_price.strip()[1:])
                        if winner != 'No Winner':  # no price breakdown exists if there is no winner
                            actual_price = float(soup.find('ul', {'class': 'price-breakdown'}).find('span', {'class': 'float-right'}).string.strip()[1:])
                        else:
                            actual_price = 0.0

                        self.attributes['winner'] = winner
                        self.attributes['win_price'] = final_price
                        self.attributes['actual_price'] = actual_price
                        logging.info("End of auction: %s", self.auction_id)
                        self.driver.quit()
                        break
                # check if auction has been cancelled
                elif soup.find('h3', text="Auction Cancelled"):
                    logging.info("Auction cancelled: %s", self.auction_id)
                    break
                else:
                    perf_time_3_1 = time.perf_counter()
                    # find the current auction time
                    #   use * because timer changes text when it reaches 10 seconds
                    seconds_remaining = get_sec(soup.find('p', {'class': re.compile('time large-timer*')}).string)

                    perf_time_3_2 = time.perf_counter()

                    # find the lock state
                    if soup.find('div', {'class': 'tooltip-bottom locked big', 'style': 'display: block;'}):
                        lock_state = 'locked'
                    else:
                        lock_state = 'unlocked'

                    perf_time_3_3= time.perf_counter()

                    # find the bid-history table and take only the last 3 records
                    bids = soup.find('table', {'id': 'bid-history'}).find_all('tr')[:2]

                    perf_time_3_4 = time.perf_counter()

                    # loop through the records in reverse order
                    for x in bids[::-1]:
                        # find all of the cells in the record
                        elements = x.find_all('td')

                        # search for digit in the element[2] (bid amount) ; if there is no digit it is an empty record
                        if re.search(r'\d', elements[2].string):
                            bid = {
                                'bid_number': self.bid_count,
                                'bidder': str(elements[1].string), # important to convert to a str or it takes up a lot of memory
                                'price': float(elements[2].string.strip()[1:]),
                                'bid_method': str(elements[3].string), # important to convert to a str or it takes up a lot of memory
                                'seconds_remaining': previous_seconds_remaining, # seconds remaining will be blank if bids already exist after watch is started which is the result wanted
                                'retrieval_time': retrieval_time,
                                'lock_state': lock_state
                            }
                            # check if there are any matching bid prices so there are no duplicates recorded
                            if not any(b['price'] == bid['price'] for b in self.attributes['bid_history']):
                                self.attributes['bid_history'].append(bid)
                                logging.debug("Bid added: %s", bid)
                                self.bid_count += 1
                    previous_seconds_remaining = seconds_remaining
                end_perf_time_3 = time.perf_counter()

                time_1 = str(end_perf_time_1 - start_perf_time_1)
                time_2 = str(end_perf_time_2 - start_perf_time_2)
                time_3 = str(end_perf_time_3 - start_perf_time_3)
                time_3_1 = str(perf_time_3_1 - start_perf_time_3)
                time_3_2 = str(perf_time_3_2 - perf_time_3_1)
                time_3_3 = str(perf_time_3_3 - perf_time_3_2)
                time_3_4 = str(perf_time_3_4 - perf_time_3_3)
                time_3_5 = str(end_perf_time_3 - perf_time_3_4)
                logging.debug("Performance: " + time_1 + "," + time_2 + "," + time_3 + "," + time_3_1 + "," + time_3_2 + "," + time_3_3 + "," + time_3_4 + "," + time_3_5)

                time.sleep(0.5)
            except AttributeError as e:
                print(e)
                print(e.with_traceback())
                pass

    def store_bid_history_to_csv(self, path):
        # stores all information including all past bids into a csv file        
        logging.info("start writing bid_history to csv")
        with open(path + self.auction_id + '_bids' + '.csv', mode='w', newline='') as csv_file:
            writer = csv.writer(csv_file, delimiter=',')
            for bid in self.attributes['bid_history']:
                writer.writerow([self.auction_id, bid['bid_number'], bid['bidder'], bid['price'], bid['bid_method'],
                                 bid['seconds_remaining'], bid['retrieval_time'], bid['lock_state']])
        logging.info("end writing bid_history to csv")

    def store_to_s3(self, bucket):
        # stores two files to s3 (auction and bid_history)
        def reverse_number(number):
            reverse = 0
            while number > 0:
                remainder = number % 10
                reverse = (reverse * 10) + remainder
                number = number // 10
            return reverse

        s3_resource = boto3.resource('s3')  # boto3 requires aws configuration on local machine

        # write bid_history
        logging.info("start writing bid_history to S3")

        csv_buffer = StringIO()
        writer = csv.writer(csv_buffer, delimiter=',')
        for bid in self.attributes['bid_history']:
            writer.writerow([self.auction_id, bid['bid_number'], bid['bidder'], bid['price'], bid['bid_method'],
                             bid['seconds_remaining'], bid['retrieval_time'], bid['lock_state']])

        key = 'bid_history/' + str(reverse_number(int(self.auction_id))) + '.csv'
        body = csv_buffer.getvalue()
        s3_resource.Bucket(bucket).put_object(Key=key, Body=body)
        csv_buffer.close()

        logging.info("end writing bid_history to S3")

        # write auction
        logging.info("start writing auction to S3")

        csv_buffer = StringIO()
        writer = csv.writer(csv_buffer, delimiter=',')
        writer.writerow([self.auction_id, self.item_id, self.item_name, self.link,
                         self.attributes['winner'], self.attributes['win_price'], self.attributes['actual_price']])

        key = 'auctions/' + str(reverse_number(int(self.auction_id))) + '.csv'
        body = csv_buffer.getvalue()
        s3_resource.Bucket(bucket).put_object(Key=key, Body=body)
        csv_buffer.close()

        logging.info("end writing auction to S3")

    # def store(self, host, name, user, password):
    #     # stores all information including all past bids into a database
    #     try:
    #         connection_string = "dbname=" + name + " user=" + user + " host='" + host + "' password='" + password + "'"
    #         # conn = psycopg2.connect("dbname=auctiondb user=auction_user host='localhost' password='gJ^4019B!b#f'")
    #         conn = psycopg2.connect(connection_string)
    #         cur = conn.cursor()
    #         logging.debug("Database connection opened")
    #
    #         # insert bid_history
    #         sql = """INSERT INTO auctions.bid_history (auction_id, bid_number, bidder, price, bid_method,
    #                     seconds_remaining, retrieval_time, lock_state) VALUES (%s, %s, %s, %s, %s, %s, %s, %s);"""
    #         bids = self.attributes['bid_history']
    #         for bid in bids:
    #             data = (self.auction_id, bid['bid_number'], bid['bidder'], bid['price'], bid['bid_method'],
    #                     bid['seconds_remaining'], bid['retrieval_time'], bid['lock_state'])
    #             cur.execute(sql, data)
    #         logging.info("Bid history inserted into database")
    #
    #         # insert auction information
    #         sql = """INSERT INTO auctions.auction (auction_id, item_id, item_name, auction_link, winner,
    #                     win_price, actual_price) VALUES (%s, %s, %s, %s, %s, %s, %s);"""
    #         data = (self.auction_id, self.item_id, self.item_name, self.link, self.attributes['winner'],
    #                 self.attributes['win_price'], self.attributes['actual_price'])
    #         cur.execute(sql, data)
    #         logging.info("Auction information inserted into database")
    #
    #     except psycopg2.DatabaseError as e:
    #         logging.error("Database error: %s", e)
    #         sys.exit(1)
    #     finally:
    #         conn.commit()
    #         conn.close()
    #         logging.info("Database connection closed")
