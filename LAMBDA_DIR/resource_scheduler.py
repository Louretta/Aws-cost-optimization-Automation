import boto3 
import os

def handler(event, context):
    ec2 = boto3.client('ec2')
    rds = boto3.client('rds')

    # Get instances with the 'Schedule' tag set to 'true'
    instances = ec2.describe_instances(
        Filters=[{'Name': 'tag:Schedule', 'Values': ['true']}]
    )

    # Start or stop based on time
    current_hour = int(event['time'][-8:-6])  # Extract the current hour from the event's time
    start_hour = int(os.environ['START_TIME'])  # Get the start hour from environment variables
    stop_hour = int(os.environ['STOP_TIME'])  # Get the stop hour from environment variables

    if start_hour <= current_hour < stop_hour:
        print("Starting resources...")
        for reservation in instances['Reservations']:
            for instance in reservation['Instances']:
                instance_id = instance['InstanceId']
                print(f"Starting instance: {instance_id}")
                ec2.start_instances(InstanceIds=[instance_id])
    else:
        print("Stopping resources...")
        for reservation in instances['Reservations']:
            for instance in reservation['Instances']:
                instance_id = instance['InstanceId']
                print(f"Stopping instance: {instance_id}")
                ec2.stop_instances(InstanceIds=[instance_id])
