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
		}

		@ACTIONS = ['doQueryAction', 'onSubCollectionClick']

		@db         = null
		@collection = null
		@ip         = null
		@port       = null
		@schema     = null

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
		height = $(window).height() - @uis.result.offset().top - 10
		@uis.result.css('height', height)

	onCollectionSelected: (event, ip, port, db, collection) =>
			@ip         = ip
			@port       = port
			@db         = db
			@collection = collection
			this.getData()

	onSubCollectionClick: (e) =>
		parent_list = $(e.currentTarget).parent('li')
		data        = Utils.clone(@data)
		keys        = []
		for parent in $(e.currentTarget).parents('li').reverse()
			_key = $(parent).attr('data-key')
			data    = data[_key]
			keys.push(_key)
		if parent_list.find('li').length > 0
			parent_list.find('li.actual').remove()
		for key, value of data
			if key != '_occurence' and key != '_documents' and key != '_lists'
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
		@data = data
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
		# nui.find('.doc'      ).attr('href', "#+doc=#{sub_key}#{key}")
		if not value._documents?
			nui.find('.doc').addClass('hidden')
		if not value._lists?
			nui.find('.list').addClass('hidden')
		nui.attr('data-key', key)
		return nui

	setResults: (data) =>
		@uis.result.html(JSON.stringify(JSON.parse(data), undefined, 4))
		prettyPrint()

	containThatField: (field) =>
		query = "{\"#{field}\":{\"$exists\":1}}"
		@uis.textarea.text(query)
		this.doQuery(query)

	containThatList: (list) =>
		query = "{\"$where\" : \"Array.isArray(this.#{list})\" }"
		@uis.textarea.text(query)
		this.doQuery(query)

	doQueryAction: (e) =>
		this.doQuery(@uis.textarea.text())

	doQuery: (query) =>
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