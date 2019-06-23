import time
import random
import logging

from bs4 import BeautifulSoup
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
            logging.critical("error opening site: %s", self.link)
            logging.critical(e)


        logging.info("Generating links at %s", self.driver.current_url)

        html = self.driver.page_source
        if html:
            soup = BeautifulSoup(html, 'html.parser')

            # locate container that holds the auctions and then grab the links
            auction_spots = soup.find('div', {'id': 'spots'})
            for auction in auction_spots.find_all('div', {'class': 'auction-item-wrapper normal'}):
                auction_link = auction.find('a').get('href')
                logging.debug("Auction link found: %s", auction_link)

                current_price = float(auction.find('h3').get_text().strip()[1:])
                if current_price <= 0.02:
                    # there are not that many bids so we can start watching the auction without missing any information
                    self.links_generated.append(self.link + auction_link)  # added home page url to get full url

            # potential to add random sleep time here??
            # time.sleep(random.randint(5,60))
        else:
            logging.critical("html was empty from %s", self.driver.current_url)
        self.driver.quit()
