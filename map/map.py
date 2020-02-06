from flask import Flask, flash, request, redirect, url_for, render_template, jsonify
from cassandra.cluster import Cluster
from cassandra.query import dict_factory
import os

cassandra_endpoint = os.environ['CASSANDRA_ENDPOINT']

cluster = Cluster([cassandra_endpoint])
session = cluster.connect()
session.row_factory = dict_factory
keyspace = os.environ['CASSANDRA_KEYSPACE']
session.set_keyspace(keyspace)


app = Flask(__name__, static_url_path='', static_folder='static')

@app.route('/', methods=['GET'])
def main_page():
    return render_template("index.html")

@app.route('/getimages', methods=['GET'])
def get_images():
    rows = session.execute("SELECT * FROM images")
    data = []
    for row in rows:
        obj = {}
        for key, value in row.items():
            obj[key] = value
        data.append(obj)
    return jsonify(data)

# Trigger build and deploy 2
