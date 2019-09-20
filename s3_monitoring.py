import boto3
import time
from datetime import datetime, timedelta


def get_seconds_threshold(hour):
    # returns the seconds threshold based on the hour of day
    thresholds = {
        0: 1261, 1: 1081, 2: 2641, 3: 5521, 4: 6001, 5: 9481, 6: 13981, 7: 2941, 8: 1681, 9: 1021, 10: 781, 11: 1081,
        12: 901, 13: 1321, 14: 1141, 15: 841, 16: 721, 17: 721, 18: 1261, 19: 1141, 20: 661, 21: 781, 22: 1201,
        23: 1081
    }
    return thresholds.get(hour, 86400)


def start_new_instance():
    ec2Client = boto3.client('ec2')
    response = ec2Client.describe_instance_status()
    responseList = response['InstanceStatuses']
    responseListLength = len(responseList)
    print("Current number of instances: " + str(responseListLength))

    if responseListLength <= 3:
        ec2 = boto3.resource('ec2')
        instances = ec2.create_instances(
            LaunchTemplate={
                'LaunchTemplateName': 'centos7_auctions_with_startup'
            },
            MaxCount=1,
            MinCount=1
        )
        print("New instance launched")
    else:
        print("Maximum instances reached, instance not launched")


# timezone_adjustment_seconds = 18000 # 5 hours
timezone_adjustment_seconds = 0  # 5 hours

s3_resource = boto3.resource('s3')  # boto3 requires aws configuration on local machine
bucket = s3_resource.Bucket(str(38783070318518296997))

current_timestamp = time.time()
hour = datetime.now().hour
seconds_threshold = get_seconds_threshold(hour)

object_total_counter = 0
main_script_failed = True

for object in bucket.objects.all():
    object_total_counter += 1
    object_timestamp = time.mktime(time.strptime(str(object.last_modified).split("+")[0], "%Y-%m-%d %H:%M:%S"))
    object_timestamp = object_timestamp - timezone_adjustment_seconds
    difference = current_timestamp - object_timestamp
    if seconds_threshold > int(difference):
        # print("Main script is still running!")
        main_script_failed = False
        break
print("Total objects scanned: " + str(object_total_counter))

if main_script_failed:
    print("Launching new instance: Latest modified S3 files are out of date")
    start_new_instance()
else:
    print("No action taken: Latest modified S3 files are within threshold")