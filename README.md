# Penny Auction Scraping

Monitors active auctions and stores all history. Currently supports Quibids.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

Chrome and matching chromedriver (matching chrome version)

Python 3 and pip install these packages:
- selenium
- lxml
- boto3
- aws cli

### Installing

A step by step series of examples that tell you how to get a development env running

#### Centos 7

Install chrome and matching chromedriver version (https://gist.github.com/xiaol825/625b94f97c0580c0586ded2b8f0d76e2)

Install python 3 by enabling software collections (https://linuxize.com/post/how-to-install-python-3-on-centos-7/)
```
sudo yum install centos-release-scl
sudo yum install rh-python36
```

Install pip with yum (option 2 at: https://phoenixnap.com/kb/how-to-install-pip-centos-7)
```
sudo yum install epel-release
sudo yum –y update
pip –V
```

Create a symbolic link for sudo to run pip
```
sudo ln -s /opt/rh/rh-python36/root/usr/bin/pip /usr/bin/pip
```

Install packages with pip
```
sudo pip install selenium
sudo pip install lxml
sudo pip install boto3
sudo pip3 install awscli --upgrade --user
```

Configure boto3 with aws cli
```
!!!Example needed!!!
default region = us-east-1
```

(Optional) Adjust config.json

(Optional) Adjust server time to match current timezone

(Optional) Add memory monitoring bash script and schedule with crontab
```
echo "$(date '+%Y-%m-%d %H:%M:%S') $(free -m | grep Mem: | sed 's/Mem://g')" >> memory_usage.log
```
```
*/1 * * * * /home/centos/memory_usage.sh
```


## Deployment

When running on Centos7 from the console make sure to use command that moves session to python 3 default
```
scl enable rh-python36 bash
python main.py &
```

You could also create a crontab job
```
* * * * * scl enable rh-python36 'python /home/centos/main.py'
```


## File Descriptions

### SQL Files Folder

- athena_create_tables.txt: Create table SQL for use with Athena querying S3. These tables will have the same structure as exists in the Postgres.
- auction_summary.sql: SQL to create auction_summary view in Postgres. This view displays calculated features at the grain of one auction per row.
- audit_missing_bids.sql: SQL to create audit_missing_bids view in Postgres. This view displays the number of bids that were not captured in an auction.
- create_tables.sql: Create table SQL for postgres. One table to capture auction level attributes and another to hold the bids captured for all auctions.
- monitor_hour_threshold.sql: SQL to create monitor_hour_threshold view in Postgres. This view displays the expected latency of on S3 based on the hour of day. This information is used in the S3 monitoring script to detect failure.
- sp_clean_auctions.sql: SQL to create stored procedure sp_clean_auctions in Postgres. This procedure removes duplicate bids captured when there is overlap from multiple instances running.

### Config Files

- config.json: This file contains the follwing parameters:
	- number_of_workers: more workers (processes) enabled requires more CPU but increases the probability of capturing all auctions
	- link_generator_home_url: the base url where auction links are generated from
	- chrome_driver_path: file path to the installed chrome driver
	- csv: if active is set to true it enables local csv storage, path determines the file path of the created csv
	- s3: if active is set to true it enables storage to s3 (recommended), bucket defines which s3 bucket is used
	- database: if active is set to true it enables storage to postgres, connection details are required if active

- config_log.json: determines logging settings
	

## Versioning

Use [SemVer](http://semver.org/) for inspiration

MAJOR.MINOR.PATCH

MAJOR version when you make incompatible API changes,

MINOR version when you add functionality in a backwards-compatible manner, and

PATCH version when you make backwards-compatible bug fixes.
