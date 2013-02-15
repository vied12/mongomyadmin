# -----------------------------------------------------------------------------
# Project : MongoMyAdmin
# -----------------------------------------------------------------------------
# Author : Edouard Richard                                  <edou4rd@gmail.com>
# -----------------------------------------------------------------------------
# License : GNU Lesser General Public License
# -----------------------------------------------------------------------------
# Creation : 24-Jan-2013
# Last mod : 24-Jan-2013
# -----------------------------------------------------------------------------
window.mongomyadmin = {}

Widget   = window.serious.Widget
URL      = new window.serious.URL()
# Format   = window.serious.format
Utils    = window.serious.Utils

# -----------------------------------------------------------------------------
#
# Select Collection
#
# -----------------------------------------------------------------------------
class mongomyadmin.ChooseCollection extends Widget

	constructor: ->

		@UIS = {
			databaseList       : "ul.databases"
			databaseTemplate   : "li.database"
			collectionList     : "ul.collections"
			collectionTemplate : "li.collection"
		}

		@ip   = "localhost"
		@port = 27017

	bindUI: (ui) =>
		super
		URL.onStateChanged(this.onURLChanged)
		URL.enableLinks(@ui)
		params = URL.get()
		Widget.ensureWidget('#Explorer')
		$(document).on('connect', this.onConnect)
		if params.db? and params.collection?
			$(document).trigger('collectionSelected', [@ip, @port, params.db, params.collection])

	onConnect: (event, ip, port) =>
		if ip
			@ip   = ip
		if port
			@port = port
		this.getDatabases()

	onURLChanged: =>
		if URL.hasChanged("db")
			this.getCollections(URL.get('db'))
		if URL.hasChanged("collection")
			$(document).trigger('collectionSelected', [@ip, @port, URL.get('db'), URL.get('collection')])
	
	getDatabases: =>
		$.ajax({url:"/api/#{@ip}/#{@port}/databases", success:this.setDatabases, dataType:'json'})

	setDatabases: (databases) =>
		@uis.databaseList.find('.actual').remove()
		for db in databases
			uis = this.cloneTemplate(@uis.databaseTemplate, {value:db})
			uis.find("a").attr('href', "#db=#{db}")
			@uis.databaseList.append(uis)

	getCollections: (db) =>
		$.ajax({url:"/api/#{@ip}/#{@port}/#{db}/collections", success:this.setCollections, dataType:'json'})

	setCollections: (collections) =>
		@uis.collectionList.find('.actual').remove()
		for col in collections
			uis = this.cloneTemplate(@uis.collectionTemplate, {value:col})
			uis.find("a").attr('href', "#+collection=#{col}")
			@uis.collectionList.append(uis)
		URL.enableLinks(@uis.collectionList)

# -----------------------------------------------------------------------------
#
# Explorer for a Collection
#
# -----------------------------------------------------------------------------
class mongomyadmin.Explorer extends Widget

	constructor: ->

		@UIS = {
			fieldsList    : "ul.fields"
			fieldTemplate : "li.field"
			textarea      : "textarea"
			result        : "#result pre"
			map           : "#map"
		}

		@ACTIONS = ['doQueryAction', 'onSubCollectionClick']

		@db         = null
		@collection = null
		@ip         = null
		@port       = null
		@schema     = null
		@map        = null
		@map_markers = []

	bindUI: (ui) =>
		super
		URL.onStateChanged(this.onURLChanged)
		URL.enableLinks(@ui)
		params = URL.get()
		# if params['db'] and params['collection']
		# 	this.getData(params["db"], params["collection"])
		$(document).on('collectionSelected', this.onCollectionSelected)
		$(window).resize(this.relayout)
		this.relayout()

	relayout: =>
		code_height = $(window).height() - @uis.result.offset().top - 10
		if @map?
			code_height = code_height/2
			map_height = $(window).height() - @uis.result.offset().top - code_height
			@uis.map.css('height', map_height)

		@uis.result.css('height', code_height)

	onCollectionSelected: (event, ip, port, db, collection) =>
			@ip         = ip
			@port       = port
			@db         = db
			@collection = collection
			this.getData()

	onSubCollectionClick: (e) =>
		parent_list = $(e.currentTarget).parent('li')
		data        = Utils.clone(@schema)
		keys        = []
		for parent in $(e.currentTarget).parents('li').reverse()
			_key = $(parent).attr('data-key')
			data    = data[_key]
			keys.push(_key)
		if parent_list.find('li').length > 0
			parent_list.find('li.actual').remove()
		for key, value of data
			if key != '_occurence' and key != '_documents' and key != '_lists' and key != '_2d'
				nui = this.createRepresentation(key, value, keys.join('.'))
				parent_list.append(nui)
		URL.enableLinks(@uis.fieldsList)
		
	onURLChanged: =>
		if URL.hasChanged("field") and URL.get("field")
			this.containThatField(URL.get("field"))
		if URL.hasChanged("list") and URL.get("list")
			this.containThatList(URL.get("list"))

	getData: =>
		$.ajax({url:"/api/#{@ip}/#{@port}/#{@db}/#{@collection}/schema", success:this.setData, dataType:'json'})

	setData: (data) =>
		@schema = data
		@uis.fieldsList.find('.actual').remove()
		for key, value of data
			nui = this.createRepresentation(key, value)
			@uis.fieldsList.append(nui)
		URL.enableLinks(@uis.fieldsList)

	createRepresentation: (key, value, sub_key="") =>
		if sub_key != ""
			sub_key = sub_key + '.'
		nui = this.cloneTemplate(@uis.fieldTemplate, {
			value     : key
			occurence : value._occurence
			list      : value._lists
			doc       : value._documents
		})
		nui.find('.occurence').attr('href', "#+field=#{sub_key}#{key}")
		nui.find('.list'     ).attr('href', "#+list=#{sub_key}#{key}")
		nui.find('.doc'      ).attr('href', "#+doc=#{sub_key}#{key}")
		if value._2d?
			nui.append('[geo]')
		if not value._documents?
			nui.find('.doc').addClass('hidden')
		if not value._lists?
			nui.find('.list').addClass('hidden')
		nui.attr('data-key', key)
		return nui

	setResults: (data) =>
		data = JSON.parse(data)
		if @limit > 0
			data = data[0..@limit]
		@limit = 0
		@uis.result.html(JSON.stringify(data, undefined, 4))
		prettyPrint()
		this.initMap()
		# markers
		for doc in data
			for key, value of doc
				if @schema[key]['_2d']
					marker = L.marker([value['lat'], value['long']]).addTo(@map)
					marker.bindPopup(doc['_id']['$oid'])
					@map_markers.push(marker)

	initMap: =>
		if not @map?
			@map = L.map('map').setView([51.505, -0.09], 2)
			@map.on('click', this.onMapClick)
			L.tileLayer('http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {maxZoom: 4}).addTo(@map)
		for marker in @map_markers
			@map.removeLayer(marker)
		this.relayout()

	onMapClick: (e) =>
		query = "{\"loc\": { \"$near\": [ #{e.latlng.lat}, #{e.latlng.lng} ] } }"
		@uis.textarea.val(query)
		this.doQuery(query, 3)

	containThatField: (field) =>
		query = "{\"#{field}\":{\"$exists\":1}}"
		@uis.textarea.val(query)
		this.doQuery(query)

	containThatList: (list) =>
		query = "{\"$where\" : \"Array.isArray(this.#{list})\" }"
		@uis.textarea.val(query)
		this.doQuery(query)

	doQueryAction: (e) =>
		this.doQuery(@uis.textarea.val())

	doQuery: (query, limit=0) =>
		@limit = limit
		$.ajax({
			url      : "/api/do/#{@ip}/#{@port}/#{@db}/#{@collection}"
			success  : this.setResults
			dataType : 'text'
			type     : 'POST'
			data     : query
		})

# -----------------------------------------------------------------------------
#
# Connect
#
# -----------------------------------------------------------------------------
class mongomyadmin.Connect extends Widget

	constructor: ->

		@UIS = {
			ipInput   : "#inputIp"
			portInput : "#inputPort"
		}

		@ACTIONS = ['connect']

	bindUI: (ui) =>
		super

	connect: =>
		ip   = @uis.ipInput.val()
		port = @uis.portInput.val()
		$(document).trigger('connect', [ip, port])
		if port != ""
			PORT = port
		if ip != ""
			IP = ip
		this.hide()

Widget.bindAll()

# EOF