import boto3
import time
from datetime import datetime, timedelta


def get_seconds_threshold(hour):
    # returns the seconds threshold based on the hour of day
    thresholds = {
        0: 6939, 1: 3728, 2: 2264, 3: 3975, 4: 2168, 5: 3727, 6: 2995, 7: 4927, 8: 4911, 
		9: 6049, 10: 4736, 11: 5044, 12: 3167, 13: 2153, 14: 2867, 15: 1494, 16: 1665, 
		17: 2700, 18: 4419, 19: 3361, 20: 2422, 21: 2576, 22: 2069, 23: 4368
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