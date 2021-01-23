_ =
	defaults: require 'lodash/defaults'
	isEqual: require 'lodash/isEqual'
	keys: require 'lodash/keys'
	omit: require 'lodash/omit'
	pick: require 'lodash/pick'
_.typeOf = require '@sa0001/type-of'

debug = -> #console.log.bind console

##======================================================================================================================

defaultOpts =
	
	# give this proxy a name
	name: 'SimpleProxy'
	
	# prevent accessing non-defined properties
	preventAccess: false
	
	# prevent reconfiguring properties
	#  (compare to Object.freeze, Object.seal)
	preventDefine: false
	
	# prevent removing properties
	#  (compare to Object.freeze, Object.seal)
	preventDelete: false
	
	# prevent adding new properties
	#  (compare to Object.freeze, Object.seal, Object.preventExtensions)
	preventExtend: false
	
	# prevent changing values
	#  (compare to Object.freeze)
	preventMutate: false
	
	# prevent setting/getting value undefined
	preventUndefined: false
	
	# when getting/setting an undefined value, instead get/set null
	convertUndefinedToNull: false
	
	# callback on error;
	#  if not provided then errors are simply thrown
	onError: null
	
	# callback on get/set/change of every property
	onGet: undefined # (k) ->
	onSet: undefined # (k, v) ->
	onChange: undefined # (k, v) ->
	
	# callback on get/set of any non-defined property
	onGetNonDefined: undefined # (k) ->
	onSetNonDefined: undefined # (k, v) ->
	
	# proxy also applied to sub-objects
	deepProxy: false
	
	# proxy also applied to sub-objects, with different settings
	deepProxyOptions: null
	
	# root object name
	#  (used by deepProxy)
	_rootName: null

local =
	makeError: (code, message) ->
		err = Error message
		err.code = code
		return err
	
	makeKey: (root, key) ->
		if !root
			return key
		if /^[\d]$/.test key
			return root + '[' + key + ']'
		else
			return root + '.' + key
	
	prototypeFields: ['__esModule','constructor','inspect','length','toJSON','toString']

##------------------------------------------------------------------------------

class SimpleProxy
	@new: -> new this arguments...
	
	constructor: (self = {}, opts = {}) ->
		# if Proxy is not supported, then return input object
		return self if !Proxy?
		
		_.defaults opts, defaultOpts
		
		currentOpts = _.pick opts, _.keys defaultOpts
		
		# default error handler = simply throw
		currentOpts.onError ?= (err) -> throw err
		
		proxy = new Proxy self,
			
			# default behavior
			
			###
			getOwnPropertyDescriptor: (obj, key) ->
				debug 'getOwnPropertyDescriptor:'+key
				
				# default behavior
				return Reflect.getOwnPropertyDescriptor obj, key
			
			getPrototypeOf: (obj) ->
				debug 'getPrototypeOf'
				
				# default behavior
				return Reflect.getPrototypeOf obj
			
			isExtensible: (obj) ->
				debug 'isExtensible'
				
				# default behavior
				return Reflect.isExtensible obj
			
			ownKeys: (obj) ->
				debug 'ownKeys'
				
				# default behavior
				return Reflect.ownKeys obj
			###
			
			##------------------------------------------------------------------
			
			# prevent default behavior
			
			preventExtensions: (obj) ->
				debug 'preventExtensions'
				
				# do nothing
				return false
			
			setPrototypeOf: (obj) ->
				debug 'setPrototypeOf'
				
				# do nothing
				return false
			
			##------------------------------------------------------------------
			
			# less important traps
			
			defineProperty: (obj, key, descriptor) ->
				debug 'defineProperty:'+key
				
				if currentOpts.preventDefine == true
					err = local.makeError 'DEFINE', "#{currentOpts.name}: cannot define key '#{local.makeKey(opts._rootName, key)}'"
					return currentOpts.onError err
				
				# else default behavior
				Reflect.defineProperty obj, key, descriptor
				return true
			
			deleteProperty: (obj, key) ->
				debug 'deleteProperty:'+key
				
				if currentOpts.preventDelete == true
					err = local.makeError 'DELETE', "#{currentOpts.name}: cannot delete key '#{local.makeKey(opts._rootName, key)}'"
					return currentOpts.onError err
				
				# else default behavior
				delete obj[key]
				return true
			
			has: (obj, key) ->
				return if typeof key == 'symbol'
				debug 'has:'+key
				
				return key of obj
			
			##------------------------------------------------------------------
			
			# most important traps
			
			get: (obj, key) ->
				return if typeof key == 'symbol'
				debug 'get:'+key
				
				hasKey = key of obj
				hasOwnKey = Object.prototype.hasOwnProperty.call obj, key
				hasProtoKey = (hasKey && !hasOwnKey) || local.prototypeFields.indexOf(key) > -1
				
				# return properties on prototype
				return obj[key] if hasProtoKey
				
				# full key path, ex. $.subobj.subarr[0]
				fullKey = local.makeKey opts._rootName, key
				
				# report get of any property
				if currentOpts.onGet
					currentOpts.onGet fullKey
				
				# report get of undefined property
				if currentOpts.onGetNonDefined && !hasOwnKey
					currentOpts.onGetNonDefined fullKey
				
				if currentOpts.preventAccess == true && !hasOwnKey
					err = local.makeError 'ACCESS', "#{currentOpts.name}: cannot access non-defined key '#{fullKey}'"
					return currentOpts.onError err
				
				val = obj[key]
				
				if val == undefined && currentOpts.convertUndefinedToNull
					val = null
				
				return val
			
			set: (obj, key, val) ->
				return true if typeof key == 'symbol'
				debug 'set:'+key
				
				hasKey = key of obj
				
				# full key path, ex. $.subobj.subarr[0]
				fullKey = local.makeKey opts._rootName, key
				
				# report set of any property
				if currentOpts.onSet
					currentOpts.onSet fullKey, val
				
				# report set of undefined property
				if currentOpts.onSetNonDefined && !hasKey
					currentOpts.onSetNonDefined fullKey, val
				
				if currentOpts.preventExtend == true && !hasKey
					err = local.makeError 'EXTEND', "#{currentOpts.name}: cannot extend key '#{fullKey}'"
					return currentOpts.onError err
				
				if currentOpts.preventMutate == true
					err = local.makeError 'MUTATE', "#{currentOpts.name}: cannot mutate key '#{fullKey}'"
					return currentOpts.onError err
				
				if currentOpts.preventUndefined == true && val == undefined
					err = local.makeError 'SET_UNDEFINED', "#{currentOpts.name}: cannot set undefined on key '#{fullKey}'"
					return currentOpts.onError err
				
				if currentOpts.deepProxy == true
					if _.typeOf(val) in ['array', 'object']
						childOpts = _.omit currentOpts.deepProxyOptions || currentOpts
						childOpts._rootName = local.makeKey childOpts._rootName, key
						val = SimpleProxy.new val, childOpts
				
				if val == undefined && currentOpts.convertUndefinedToNull
					val = null
				
				oldVal = if hasKey then obj[key] else undefined
				obj[key] = val
				
				# if the property has a setter,
				#  then its output may be different than its input, so get the value on the object after set.
				#  the property must also have a getter, which will now be called, but this is unavoidable.
				# if the property has no setter,
				#  then it can also have no getter, so there will be no side-effect.
				newVal = obj[key]
				
				# report change of any property
				if currentOpts.onChange && !_.isEqual oldVal, newVal
					currentOpts.onChange fullKey, newVal, oldVal
				
				return true
		
		if currentOpts.preventUndefined == true && val == undefined
			for key,val of self
				continue unless typeof val == 'undefined'
				err = local.makeError 'SET_UNDEFINED', "#{currentOpts.name}: cannot set undefined on key '#{key}'"
				return currentOpts.onError err
		
		if currentOpts.deepProxy == true
			for key,val of self
				if currentOpts.convertUndefinedToNull && val == undefined
					self[key] = null
				
				continue unless _.typeOf(val) in ['array','object']
				childOpts = _.omit currentOpts.deepProxyOptions || currentOpts
				childOpts._rootName = local.makeKey childOpts._rootName, key
				self[key] = SimpleProxy.new val, childOpts
		
		return proxy
	
	##--------------------------------------------------------------------------
	
	# static constructors for typical options
	
	# prevent adding/reconfiguring/removing properties
	# prevent accessing non-defined properties
	# prevent changing values
	@freeze: (self, opts = {}) ->
		_.defaults opts,
			preventAccess: true
			preventDefine: true
			preventDelete: true
			preventExtend: true
			preventMutate: true
		return SimpleProxy.new self, opts
	
	# prevent adding/reconfiguring/removing properties
	# prevent accessing non-defined properties
	# prevent changing values
	# apply proxy to sub-objects
	@deepFreeze: (self, opts = {}) ->
		_.defaults opts,
			deepProxy: true
			preventAccess: true
			preventDefine: true
			preventDelete: true
			preventExtend: true
			preventMutate: true
		return SimpleProxy.new self, opts
	
	# prevent adding/reconfiguring/removing properties
	# prevent accessing non-defined properties
	# DO NOT prevent changing values
	# apply proxy to sub-objects
	@seal: (self, opts = {}) ->
		_.defaults opts,
			preventAccess: true
			preventDefine: true
			preventDelete: true
			preventExtend: true
		return SimpleProxy.new self, opts
	
	# prevent adding/reconfiguring/removing properties
	# prevent accessing non-defined properties
	# DO NOT prevent changing values
	# apply proxy to sub-objects
	@deepSeal: (self, opts = {}) ->
		_.defaults opts,
			deepProxy: true
			preventAccess: true
			preventDefine: true
			preventDelete: true
			preventExtend: true
		return SimpleProxy.new self, opts
	
	# prevent accessing non-defined properties
	# DO NOT prevent adding/reconfiguring/removing properties
	# DO NOT prevent changing values
	@access: (self, opts = {}) ->
		_.defaults opts,
			preventAccess: true
		return SimpleProxy.new self, opts
	
	# prevent accessing non-defined properties
	# DO NOT prevent adding/reconfiguring/removing properties
	# DO NOT prevent changing values
	# apply proxy to sub-objects
	@deepAccess: (self, opts = {}) ->
		_.defaults opts,
			deepProxy: true
			preventAccess: true
		return SimpleProxy.new self, opts

module.exports = SimpleProxy
