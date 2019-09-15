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

## Versioning

Use [SemVer](http://semver.org/) for inspiration

MAJOR.MINOR.PATCH

MAJOR version when you make incompatible API changes,

MINOR version when you add functionality in a backwards-compatible manner, and

PATCH version when you make backwards-compatible bug fixes.
