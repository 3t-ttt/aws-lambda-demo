# BackupJobCompleted event
import json
import boto3

# Region
REGION = 'ap-southeast-1'

def lambda_handler(event, context):
    
    print(event)
    
    instance_id = event['detail']['resourceArn'].split("/")[-1]
    imageId = event['resources'][0].split("/")[-1]
    print("instance_id: ", instance_id)
    print("imageId: ", imageId)
    
    client = boto3.client('ssm', region_name=REGION)

    response_put =  client.put_parameter(
    # Name = instance_id,
    Name=f"/EC2Backup/latestAMI/{instance_id}",
    Value = imageId,
    Type = 'String',
    Overwrite = True
    )