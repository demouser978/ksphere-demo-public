import urllib.request
import flickrapi
import boto3
from botocore.exceptions import ClientError
import os

s3 = boto3.client(
    's3',
    endpoint_url=os.environ['MINIO_ENDPOINT'],
    aws_access_key_id=os.environ['MINIO_USERNAME'],
    aws_secret_access_key=os.environ['MINIO_PASSWORD']
)

flickr = flickrapi.FlickrAPI(os.environ['FLICKR_API_KEY'], os.environ['FLICKR_API_SECRET'])
for photo in flickr.walk(tag_mode='all', tags=os.environ['FLICKR_TAG'], extras='views,url_l', has_geo=1):
    url_l = photo.get("url_l")
    views = photo.get("views")
    filename = photo.get("id") + '.jpg'
    if(url_l != None):
        urllib.request.urlretrieve(url_l, filename)
        try:
            response = s3.upload_file(filename, 'images', filename, {'Metadata': {'views': views}})
            print(filename)
            os.remove(filename)
        except ClientError as e:
            logging.error(e)

# Trigger build and deploy 2
