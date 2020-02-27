from confluent_kafka import Consumer, KafkaError
from cassandra.cluster import Cluster
import boto3
import exifread
import json
import os

def dms2dd(degrees, minutes, seconds):
     dd = float(degrees) + float(minutes)/60 + float(seconds)/3600
     return dd

from cassandra.cluster import Cluster

cluster = Cluster([os.environ['CASSANDRA_ENDPOINT']])
session = cluster.connect()

keyspace = os.environ['CASSANDRA_KEYSPACE']

session.execute("""
    CREATE KEYSPACE IF NOT EXISTS %s
    WITH replication = { 'class': 'SimpleStrategy', 'replication_factor': '2' }
    """ % keyspace)

session.set_keyspace(keyspace)

session.execute("""
    CREATE TABLE IF NOT EXISTS images (
        image text,
        latitude float,
        longitude float,
        views bigint,
        url text,
        PRIMARY KEY (image)
    )
    """)

minio_endpoint = os.environ['MINIO_ENDPOINT']
s3 = boto3.client(
    's3',
    endpoint_url=minio_endpoint,
    aws_access_key_id=os.environ['MINIO_USERNAME'],
    aws_secret_access_key=os.environ['MINIO_PASSWORD']
)
minio_external_endpoint = os.environ['MINIO_EXTERNAL_ENDPOINT']

bucket = os.environ['MINIO_BUCKET'];

c = Consumer({'bootstrap.servers': os.environ['KAFKA_BROKER'], 'group.id': 'group1', 'session.timeout.ms': 6000,
            'auto.offset.reset': 'earliest'})

c.subscribe(['minio'])

while True:
    msg = c.poll(timeout=1.0)
    if msg is None:
        continue
    if msg.error():
        raise KafkaException(msg.error())
    else:
        value = json.loads(msg.value())
        if value["EventName"] == "s3:ObjectCreated:Put":
            file = value["Key"].split("/")[1]
            try:
                s3.head_object(Bucket='images', Key=file)
            except Exception as e:
                print(e)
                continue
            s3.download_file(bucket, file, file)
            url = s3.generate_presigned_url('get_object', Params={'Bucket': bucket, 'Key': file}, ExpiresIn=604800)
            url = url.replace(minio_endpoint, minio_external_endpoint)
            with open(file, 'rb') as image_file:
                tags = exifread.process_file(image_file)
                if 'GPS GPSLatitude' in tags:
                    latitude_coords = tags['GPS GPSLatitude']
                    longitude_coords = tags['GPS GPSLongitude']
                    latitude = dms2dd(float(latitude_coords.values[0].num) / float(latitude_coords.values[0].den), float(latitude_coords.values[1].num) / float(latitude_coords.values[1].den), float(latitude_coords.values[2].num) / float(latitude_coords.values[2].den))
                    if tags['GPS GPSLatitudeRef'].values[0] != 'N':
                        latitude = 0 - latitude
                    longitude = dms2dd(float(longitude_coords.values[0].num) / float(longitude_coords.values[0].den), float(longitude_coords.values[1].num) / float(longitude_coords.values[1].den), float(longitude_coords.values[2].num) / float(longitude_coords.values[2].den))
                    if tags['GPS GPSLongitudeRef'].values[0] != 'E':
                        longitude = 0 - longitude
                    response = s3.head_object(Bucket='images', Key=file)
                    if 'Views' in response['Metadata']:
                        session.execute(
                            """
                            INSERT INTO images (image, latitude, longitude, views, url)
                            VALUES (%s, %s, %s, %s, %s)
                            """,
                            (file, latitude, longitude, int(response['Metadata']['Views']), url)
                        )
                        print("Entry added", file)
            os.remove(file)

# Trigger build and deploy 2
