import time
import random
import logging

from lxml import etree
from lxml import html
from selenium import webdriver
from selenium.webdriver.chrome.options import Options


class LinkGenerator:
    # generates the links that the auction class will use
    # link = "http://www.quibids.com/en/" #quib
    # ids home page
    def __init__(self, link, path_to_chromedriver):
        options = Options()
        options.add_argument("--headless")
        options.add_argument('--disable-gpu')
        options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.157 Safari/537.36')
        self.driver = webdriver.Chrome(executable_path=path_to_chromedriver, chrome_options=options)
        # self.driver.set_page_load_timeout(10)

        self.link = link
        self.links_generated = []

    def generate_links(self):
        def get_sec(time_str):
            # returns seconds from the hh:mm:ss format
            try:
                h, m, s = time_str.split(':')
                return int(h) * 3600 + int(m) * 60 + int(s)
            except ValueError:
                # auction has ended and string is most likely 'ended'
                pass

        # opens web page
        try:
            self.driver.get(self.link)
            if self.driver.current_url != self.link:
                logging.warning("Attempted to connect to %s, but redirected to %s", self.link, self.driver.current_url)
                self.driver.get(self.link)
                logging.debug("Current URL is: %s", self.driver.current_url)
            else:
                logging.debug("Current URL is: %s", self.driver.current_url)

            agent = self.driver.execute_script("return navigator.userAgent")
            logging.debug("Agent is: %s", str(agent))
        except Exception as e:
            logging.error("error opening site: %s", self.link)
            logging.error(e)

        logging.info("Generating links at %s", self.driver.current_url)

        try:
            html_string = self.driver.page_source
        except Exception as e:
            logging.error("html was empty from %s", self.driver.current_url)
        else:
            tree = html.document_fromstring(html_string)

            auction_spots = tree.xpath('//div[contains(@class, "auction-item-wrapper normal")]')
            for auction in auction_spots:
                auction_link = auction.xpath('.//a')[0].get('href')

                current_price = float(auction.xpath('.//h3')[0].text_content().strip()[1:])
                seconds_remaining = get_sec(auction.xpath('.//h2[contains(@class, "time bold")]')[0].text_content())

                if seconds_remaining is not None: # auction could be ended and not displaying a time
                    if (current_price > 0 and current_price < 0.05) or (seconds_remaining >= (20) and seconds_remaining <= (60 * 10)):
                        self.links_generated.append(self.link + auction_link)  # added home page url to get full url
                        logging.debug("Auction link added: %s, Current Price: %s, Seconds Remaining: %s", auction_link, current_price, seconds_remaining)
        finally:
            self.driver.quit()
