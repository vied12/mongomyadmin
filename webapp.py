#!/usr/bin/env python
# Encoding: utf-8
# -----------------------------------------------------------------------------
# Project : 
# -----------------------------------------------------------------------------
# Author : Edouard Richard                                  <edou4rd@gmail.com>
# -----------------------------------------------------------------------------
# License : GNU Lesser General Public License
# -----------------------------------------------------------------------------
# Creation : 
# Last mod : 
# -----------------------------------------------------------------------------

from flask import Flask, render_template, request, send_file, Response, abort, session, redirect, url_for
import os, json, pymongo
import preprocessing.preprocessing as preprocessing

app = Flask(__name__)
app.config.from_pyfile("settings.cfg")

# -----------------------------------------------------------------------------
#
# API
#
# -----------------------------------------------------------------------------

@app.route("/api/<ip>/<int:port>/databases")
def getDatabases(ip, port):
	connection = pymongo.MongoClient(ip, port)
	return json.dumps(connection.database_names())

@app.route("/api/<ip>/<int:port>/<database>/collections")
def getCollections(ip, port, database):
	connection = pymongo.MongoClient(ip, port)
	db         = connection[database]
	return json.dumps(db.collection_names())

@app.route("/api/<ip>/<int:port>/<database>/<collection>/schema")
def getSchema(ip, port, database, collection):
	keys    = {}
	def _getSchema(document, result):
		if not type(document) is dict:
			return None
		for key, value in document.items():
			if not result.get(key):
				result[key] = {}
			result[key]['_occurence'] = result[key].get('_occurence', 0) + 1
			# 2d
			if key in two_d_fields:
				result[key]['_2d'] = True
			if type(value) is list:
				result[key]['_lists'] = result[key].get('_lists', 0) + 1
			elif type(value) is dict:
				result[key]['_documents'] = result[key].get('_documents', 0) + 1
				_getSchema(value, result[key])

	connection   = pymongo.MongoClient(ip, port)
	db           = connection[database]
	collection   = db[collection]
	# 2d
	indexes      = collection.index_information()
	two_d_fields = []
	for name, values in indexes.items():
		if values['key'][0][1] == '2d':
			two_d_fields.append(values['key'][0][0])
	for document in collection.find():
		_getSchema(document, keys)
	return json.dumps(keys)

import json
from bson.json_util import dumps
@app.route("/api/do/<ip>/<int:port>/<database>/<collection>", methods=['POST',])
def doQuery(ip, port, database, collection):
	query      = request.form.keys()[0]
	query      = json.loads(query)
	connection = pymongo.MongoClient(ip, port)
	db         = connection[database]
	collection = db[collection]
	res        = dumps(collection.find(query))
	return res

# -----------------------------------------------------------------------------
#
# Site pages
#
# -----------------------------------------------------------------------------

@app.route('/')
def index():
	return render_template('home.html')

# -----------------------------------------------------------------------------
#
# Main
#
# -----------------------------------------------------------------------------

if __name__ == '__main__':
	import sys
	if len(sys.argv) > 1 and sys.argv[1] == "collectstatic":
		preprocessing._collect_static(app)
	else:
		# render ccss, coffeescript and shpaml in 'templates' and 'static' dirs
		preprocessing.preprocess(app, request) 
		# run application
		app.run()
# EOF
