logger = require('logger-sharelatex')
async = require("async")
metrics = require('../../infrastructure/Metrics')
Settings = require('settings-sharelatex')
ObjectId = require('mongoose').Types.ObjectId	
Project = require('../../models/Project').Project
Folder = require('../../models/Folder').Folder
ProjectEntityHandler = require('./ProjectEntityHandler')
User = require('../../models/User').User
fs = require('fs')
Path = require "path"
_ = require "underscore"
SubscriptionUpdater = require "../Subscription/SubscriptionUpdater"

module.exports =
	createBlankProject : (owner_id, projectName, callback = (error, project) ->)->
		metrics.inc("project-creation")
		logger.log owner_id:owner_id, projectName:projectName, "creating blank project"
		rootFolder = new Folder {'name':'rootFolder'}
		project = new Project
			 owner_ref  : new ObjectId(owner_id)
			 name       : projectName
			 useClsi2   : true
		project.rootFolder[0] = rootFolder
		SubscriptionUpdater.createFreeTrialIfNoSubscription owner_id, Settings.paidPlanCode, Settings.freeTrialDays, (error) ->
			return callback(error) if error?
			User.findById owner_id, "ace.spellCheckLanguage", (err, user)->
				project.spellCheckLanguage = user.ace.spellCheckLanguage
				project.save (err)->
					return callback(err) if err?
					callback err, project

	createPythonProject :  (owner_id, projectName, callback = (error, project) ->)->
		self = @
		@createBlankProject owner_id, projectName, (error, project)->
			return callback(error) if error?
			self._buildTemplate "main.py", owner_id, projectName, (error, docLines)->
				return callback(error) if error?
				ProjectEntityHandler.addDoc project._id, project.rootFolder[0]._id, "main.py", docLines, (error, doc)->
					return callback(error) if error?
					ProjectEntityHandler.setRootDoc project._id, doc._id, (error) ->
						return callback(error) if error?
						callback(error, project)

	createRProject: (owner_id, projectName, callback = (error, project) ->)->
		self = @
		@createBlankProject owner_id, projectName, (error, project)->
			return callback(error) if error?
			self._buildTemplate "main.R", owner_id, projectName, (error, docLines)->
				return callback(error) if error?
				ProjectEntityHandler.addDoc project._id, project.rootFolder[0]._id, "main.R", docLines, (error, doc)->
					return callback(error) if error?
					ProjectEntityHandler.setRootDoc project._id, doc._id, (error) ->
						return callback(error) if error?
						callback(error, project)

	_buildTemplate: (template_name, user_id, project_name, callback = (error, output) ->)->
		User.findById user_id, "first_name last_name", (error, user)->
			return callback(error) if error?
			monthNames = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ]

			templatePath = Path.resolve(__dirname + "/../../../templates/project_files/#{template_name}")
			fs.readFile templatePath, (error, template) ->
				return callback(error) if error?
				data =
					project_name: project_name
					user: user
					year: new Date().getUTCFullYear()
					month: monthNames[new Date().getUTCMonth()]
				output = _.template(template.toString(), data)
				callback null, output.split("\n")



