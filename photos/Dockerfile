FROM djannot/python-cassandra-kafka
RUN pip install exifread
RUN pip install boto3
ADD functions.py /
ADD photos.py /
WORKDIR /
