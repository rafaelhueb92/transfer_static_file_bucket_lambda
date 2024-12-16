import boto3
import os

s3_client = boto3.client('s3')

# Buckets configurados via variáveis de ambiente
SOURCE_BUCKET = os.environ['SOURCE_BUCKET']
DESTINATION_BUCKET = os.environ['DESTINATION_BUCKET']
FILES_TO_REPLICATE = ["users.json", "dashboards.json"]

def handler(event, context):
    try:
        # Itera sobre os objetos do evento recebido
        for record in event['detail']['object']:
            file_name = record['key']

            if file_name in FILES_TO_REPLICATE:
                print(f"Replicating {file_name} to {DESTINATION_BUCKET}")
                copy_source = {'Bucket': SOURCE_BUCKET, 'Key': file_name}
                s3_client.copy_object(
                    Bucket=DESTINATION_BUCKET,
                    CopySource=copy_source,
                    Key=file_name
                )
                print(f"Successfully replicated {file_name}")
            else:
                print(f"File {file_name} is not in the replication list. Skipping...")
    except Exception as e:
        print(f"Error processing event: {e}")
        raise e
