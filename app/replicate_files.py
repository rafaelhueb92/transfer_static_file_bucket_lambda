import os
import boto3
from botocore.exceptions import ClientError

s3_client = boto3.client("s3")

def replicate_file(source_bucket, destination_bucket, key):
    try:
        destination_prefix = os.environ.get("DESTINATION_PREFIX", "")
        destination_key = f"{destination_prefix}{key}"

        s3_client.copy_object(
            CopySource={"Bucket": source_bucket, "Key": key},
            Bucket=destination_bucket,
            Key=destination_key
        )
        print(f"Arquivo {key} replicado de {source_bucket} para {destination_bucket}/{destination_key}")
    except ClientError as e:
        print(f"Erro ao copiar arquivo {key}: {e}")
        raise

def handler(event, context):
    source_bucket = os.environ["SOURCE_BUCKET"]
    destination_bucket = os.environ["DESTINATION_BUCKET"]

    for record in event["Records"]:
        event_name = record["eventName"]
        bucket_name = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        if bucket_name == source_bucket and event_name.startswith("ObjectCreated"):
            print(f"Arquivo {key} foi criado ou atualizado no bucket {bucket_name}")
            try:
                replicate_file(source_bucket, destination_bucket, key)
            except ClientError as e:
                print(f"Erro ao replicar arquivo {key}: {e}")
        elif bucket_name == destination_bucket and event_name.startswith("ObjectRemoved"):
            print(f"Arquivo {key} foi removido do bucket {bucket_name}")
            try:
                replicate_file(source_bucket, destination_bucket, key)
            except ClientError as e:
                print(f"Erro ao restaurar o arquivo {key}: {e}")
        else:
            print(f"Evento ignorado: {event_name}")
