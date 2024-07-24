import boto3
import base64

#globalaccelerator(fixed IP) →　ALB →　lambda →　S3
# http://abc.awsglobalaccelerator.com/?bucket=data-demo&key=data/abc.zip

# Initialize the S3 client
s3_client = boto3.client('s3', region_name='ap-northeast-1')

def lambda_handler(event, context):
    try:
        # Log the event to see the structure
        print("Received event:", event)

        # Extract bucket name and object key from query parameters
        query_params = event.get('queryStringParameters', {})
        BUCKET_NAME = query_params.get('bucket', 'default-bucket-name')
        OBJECT_KEY = query_params.get('key', 'default-key')

        # Download file from S3
        print(f"Attempting to download file {OBJECT_KEY} from bucket {BUCKET_NAME}")
        response = s3_client.get_object(Bucket=BUCKET_NAME, Key=OBJECT_KEY)
        file_content = response['Body'].read()  # Read file content as binary

        # Log the file content size
        print(f"Downloaded file content size: {len(file_content)} bytes")

        # Return the file content for download
        return {
            'statusCode': 200,
            'statusDescription': '200 OK',
            'isBase64Encoded': True,
            'headers': {
                'Content-Type': 'application/octet-stream',
                'Content-Disposition': f'attachment; filename="{OBJECT_KEY.split("/")[-1]}"'
            },
            'body': base64.b64encode(file_content).decode('utf-8')  # Encode file content to base64
        }

    except Exception as e:
        print(f"Error downloading file: {e}")

        # Handle errors and return error code if necessary
        return {
            'statusCode': 500,
            'statusDescription': '500 Internal Server Error',
            'isBase64Encoded': False,
            'headers': {
                'Content-Type': 'text/plain'
            },
            'body': str(e)
        }
