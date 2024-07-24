import boto3
import logging
import json
import botocore

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info('Received event: ' + json.dumps(event))
    
    # Extract the necessary details from the event
    try:
        detail = event['detail']
        ec2_instance_arn = detail['resourceArn']
        image_arn = event['resources'][0]
        region = event['region']
    except KeyError as e:
        logger.error(f'Error: Missing key in event data: {str(e)}')
        return
    
    # Extract the EC2 instance ID and AMI ID from the ARNs
    try:
        ec2_instance_id = ec2_instance_arn.split('/')[-1]
        image_id = image_arn.split('/')[-1]
    except IndexError:
        logger.error('Error: Resources list is empty or does not contain AMI ARN')
        return
    
    # Initialize the EC2 and SSM clients
    ec2 = boto3.client('ec2', region_name=region)
    ssm = boto3.client('ssm', region_name=region)
    
    # Describe the instance to get its tags
    try:
        response = ec2.describe_instances(InstanceIds=[ec2_instance_id])
    except botocore.exceptions.ClientError as e:
        logger.error(f'Boto3 Client Error: {e.response}')
        return

    # Initialize instance_name
    instance_name = None
    # Find the 'Name' tag
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            if 'Tags' in instance:
                for tag in instance['Tags']:
                    if tag['Key'] == 'Name':
                        instance_name = tag['Value']
                        break

    # Determine the parameter name based on the presence of the instance name tag
    if instance_name:
        parameter_name = f'/EC2Backup/latestAMI/{instance_name}/{ec2_instance_id}'
    else:
        parameter_name = f'/EC2Backup/latestAMI/unknown/{ec2_instance_id}'

    # Store the latest AMI ID in Parameter Store
    try:
        ssm.put_parameter(
            Name=parameter_name,
            Value=image_id,
            Type='String',
            Overwrite=True
        )
    except botocore.exceptions.ParamValidationError as e:
        logger.error(f'Invalid parameter: {str(e)}')
    except botocore.exceptions.ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        logger.error(f'Parameter Store Error: {error_code} - {error_message}')
        return

    # Log the results
    logger.info(f'Stored AMI ID {image_id} for EC2 instance {ec2_instance_id} in Parameter Store as {parameter_name}')
