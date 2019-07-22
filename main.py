#!/usr/bin/env python
import link_generator as lg
import auction as a

import os
import time
import random
import logging
import logging.config
import logging.handlers
import json
import threading
import multiprocessing

import cProfile

# use ready_queue and in_progress_queue to avoid duplicate URLs
def worker_main(worker_queue, completed_queue, log_queue, config):
    # setup logging
    qh = logging.handlers.QueueHandler(log_queue)
    root = logging.getLogger()
    root.setLevel(logging.DEBUG)
    root.addHandler(qh)

    c = config
    # for i in  range(100):
    while True:
        item = worker_queue.get(True)
        
        # do work
        auction = a.Auction(item, c["chrome_driver_path"])
        auction.watch()
        # cProfile.runctx('auction.watch()', globals(), locals(), 'profile')

        # store to sources based on config settings
        if c["csv"]["active"]:
            auction.store_bid_history_to_csv(c["csv"]["path"])
        if c["s3"]["active"]:
            auction.store_to_s3(config["s3"]["bucket"])
        # if c["database"]["active"]:
        #     auction.store(c["database"]["host"], c["database"]["name"],
        #                   c["database"]["user"], c["database"]["password"])

        completed_queue.put(item)
        time.sleep(1)


def update_queue(worker_queue, inserted_list, config):
    # updates the queue with new items only
    link_generator = lg.LinkGenerator(config["link_generator_home_url"], config["chrome_driver_path"])
    link_generator.generate_links()
    
    available_links = link_generator.links_generated
    i = 0
    for link in available_links:
        try:
            inserted_list.index(link)
            logging.debug("Item has already been inserted: " + link)
        except ValueError:
            worker_queue.put(link)
            inserted_list.append(link)
            logging.debug("Item inserted added to worker_queue: " + link)
            i += 1
    logging.info(str(i) + " new items inserted into worker_queue")


def logger_thread(log_queue):
    while True:
        record = log_queue.get()
        if record is None:
            break
        logger = logging.getLogger(record.name)
        logger.handle(record)


def main():
    # setup logging using config file
    log_queue = multiprocessing.Queue()
    with open('config_log.json', 'r') as f:
        d = json.load(f)
    logging.config.dictConfig(d)
    lp = threading.Thread(target=logger_thread, args=(log_queue,))
    lp.start()

    # ingest config file for auction and link generator settings
    with open('config.json', 'r') as f:
        config = json.load(f)

    worker_queue = multiprocessing.Queue()  # can define max size here
    completed_queue = multiprocessing.Queue()  # can define max size here
    number_of_workers = config["number_of_workers"]
    multiprocessing.Pool(number_of_workers, worker_main, (worker_queue, completed_queue, log_queue, config, ))

    inserted_list = []

    # for i in range(3):
    while True:
        update_queue(worker_queue, inserted_list, config)

        random_int = random.randint(25, 90)
        logging.info("sleep for %s seconds", str(random_int))
        time.sleep(random_int)

        logging.info("Current worker queue size: " + str(worker_queue.qsize()))
        # cleanup completed queue
        while not completed_queue.empty():
            # empty() is not reliable but this is ok in this situation
            # worst case scenario is we think it is empty but its actually not, we would just cleanup on the next pass
            item = completed_queue.get()
            inserted_list.remove(item)
            logging.info("Removed item from completed_queue and inserted_list: " + item)


if __name__ == '__main__':
    multiprocessing.set_start_method('spawn')
    main()
