#!/usr/bin/env coffee
log = console.log.bind console
tap = require '@sa0001/wrap-tap'

SimpleProxy = require './index'

##======================================================================================================================

tap.test 'simple-proxy', (t) ->
	
	testFlatObj = -> { a: 0, b: 1 }
	testDeepObj = -> { a: b: {} }
	testFlatArr = -> [ 'a', 'b' ]
	
	##--------------------------------------------------------------------------
	
	# ensure the proxy works as expected with native getters/setters,
	#  which were already applied on the raw input object
	t.test 'native getter/setter', (t) ->
		
		get_raw = ->
			raw = {}
			do ->
				Object.defineProperty raw, 'g',
					enumerable: true
					get: -> 'getter'
					set: ->
			do ->
				v = undefined
				Object.defineProperty raw, 's',
					enumerable: true
					get: -> v
					set: -> v = 'setter'
			return raw
		
		obj = get_raw()
		
		t.noDiff obj, { g: 'getter',  s: undefined }
		obj.g = '...'
		obj.s = '...'
		t.noDiff obj, { g: 'getter',  s: 'setter' }
		
		obj = SimpleProxy.new get_raw(),
			preventAccess: true
			preventDefine: true
			preventDelete: true
			preventExtend: true
		
		t.noDiff obj, { g: 'getter',  s: undefined }
		obj.g = '...'
		obj.s = '...'
		t.noDiff obj, { g: 'getter',  s: 'setter' }
	
	##--------------------------------------------------------------------------
	
	t.test 'onError', (t) ->
		
		raw = { a: 'a', b: 'b' }
		obj = null
		last_error = null
		
		error_access_fn = -> obj.c
		error_delete_fn = -> delete obj.a
		error_mutate_fn = -> obj.b = 'c'
		
		error_access_msg = "SimpleProxy: cannot access non-defined key 'c'"
		error_delete_msg = "SimpleProxy: cannot delete key 'a'"
		error_mutate_msg = "SimpleProxy: cannot mutate key 'b'"
		
		obj = SimpleProxy.freeze raw
		
		# the expected errors will be thrown
		t.throwMatch error_access_fn, error_access_msg
		t.throwMatch error_delete_fn, error_delete_msg
		t.throwMatch error_mutate_fn, error_mutate_msg
		
		obj = SimpleProxy.freeze raw, { onError: (err) -> last_error = err }
		
		# the expected errors will *not* be thrown, but will be received by the callback
		t.notThrow error_access_fn ; t.eq last_error.message, error_access_msg ; t.eq last_error.code, 'ACCESS'
		t.notThrow error_delete_fn ; t.eq last_error.message, error_delete_msg ; t.eq last_error.code, 'DELETE'
		t.notThrow error_mutate_fn ; t.eq last_error.message, error_mutate_msg ; t.eq last_error.code, 'MUTATE'
	
	t.test 'onGet, onSet, onChange', (t) ->
		
		getReports = []
		setReports = []
		changeReports = []
		
		obj = SimpleProxy.new testFlatObj(),
			onGet: (k) -> getReports.push k
			onSet: (k) -> setReports.push k
			onChange: (k) -> changeReports.push k
		
		# get,set
		val = obj.c
		obj.c = val
		
		# set,get 1
		obj.d = val
		val = obj.d
		
		# set,get 2
		obj.d = val
		val = obj.d
		
		# change
		obj.e = null
		obj.e = 'e'
		
		# all gets/sets should have been reported
		t.eq getReports.join(', '), 'c, d, d'
		t.eq setReports.join(', '), 'c, d, d, e, e'
		t.eq changeReports.join(', '), 'e, e'
	
	t.test 'onChange with setter', (t) ->
		
		obj = {}
		do ->
			val = undefined
			Object.defineProperty obj, 'name',
				get: -> val
				set: (v) -> val = v.trim()
		
		result = undefined
		
		proxy = SimpleProxy.new obj,
			onChange: (key, newVal, oldVal) ->
				result = [arguments...]
		
		# set a string which will be trimmed
		proxy.name = ' alpha beta '
		
		# the newVal in the onChange will be the trimmed string
		t.eq proxy.name, 'alpha beta'
		t.noDiff result, [ 'name', 'alpha beta', undefined ]
	
	t.test 'onGetNonDefined, onSetNonDefined', (t) ->
		
		getReports = []
		setReports = []
		
		obj = SimpleProxy.new testFlatObj(),
			onGetNonDefined: (k) -> getReports.push k
			onSetNonDefined: (k) -> setReports.push k
		
		# get,set
		val = obj.c
		obj.c = val
		
		# set,get 1
		obj.d = val
		val = obj.d
		
		# set,get 2
		obj.d = val
		val = obj.d
		
		# should only have reported gets/sets of non-defined properties
		t.eq getReports.join(', '), 'c'
		t.eq setReports.join(', '), 'c, d'
	
	##--------------------------------------------------------------------------
	
	t.test 'deep onGet, onSet, onChange', (t) ->
		
		getReports = []
		setReports = []
		changeReports = []
		
		obj = SimpleProxy.new testDeepObj(),
			deepProxy: true
			onGet: (k) -> getReports.push k
			onSet: (k) -> setReports.push k
			onChange: (k) -> changeReports.push k
		
		# get,set
		val = obj.a.b.c
		obj.a.b.c = true
		
		# set,get 1
		obj.a.b.d = true
		val = obj.a.b.d
		
		# set,get 2
		obj.a.b.d = true
		val = obj.a.b.d
		
		# change
		obj.a.b.e = null
		obj.a.b.e = 'e'
		
		t.eq val, true
		
		# all gets/sets should have been reported
		t.eq getReports.join(', '), 'a, a.b, a.b.c, a, a.b, a, a.b, a, a.b, a.b.d, a, a.b, a, a.b, a.b.d, a, a.b, a, a.b'
		t.eq setReports.join(', '), 'a.b.c, a.b.d, a.b.d, a.b.e, a.b.e'
		t.eq changeReports.join(', '), 'a.b.c, a.b.d, a.b.e, a.b.e'
	
	t.test 'deep onGetNonDefined, onSetNonDefined', (t) ->
		
		getReports = []
		setReports = []
		
		obj = SimpleProxy.new testDeepObj(),
			deepProxy: true
			onGetNonDefined: (k) -> getReports.push k
			onSetNonDefined: (k) -> setReports.push k
		
		# get,set
		val = obj.a.b.c
		obj.a.b.c = true
		
		# set,get 1
		obj.a.b.d = true
		val = obj.a.b.d
		
		# set,get 2
		obj.a.b.d = true
		val = obj.a.b.d
		
		t.eq val, true
		
		# should only have reported gets/sets of non-defined properties
		t.eq getReports.join(', '), 'a.b.c'
		t.eq setReports.join(', '), 'a.b.c, a.b.d'
	
	##--------------------------------------------------------------------------
	
	t.test 'convertUndefinedToNull == true', (t) ->
		
		raw_obj =
			a: undefined
			b: null
		
		# native getters which also return undefined/null
		Object.defineProperty raw_obj, 'c',
			configurable: true
			enumerable: true
			get: -> undefined
		Object.defineProperty raw_obj, 'd',
			configurable: true
			enumerable: true
			get: -> null
		
		obj = SimpleProxy.new raw_obj,
			convertUndefinedToNull: true
		
		t.noDiff obj, {
			a: null
			b: null
			c: null
			d: null
		}, { ignoreNullVsUndefined: false }
		
		obj.b = undefined
		Object.defineProperty obj, 'd',
			configurable: true
			enumerable: true
			get: -> undefined
		obj.g = undefined
		
		t.noDiff obj, {
			a: null
			b: null
			c: null
			d: null
			g: null
		}, { ignoreNullVsUndefined: false }
	
	##--------------------------------------------------------------------------
	
	t.test 'preventAccess == true', (t) ->
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventAccess: true }
			t.eq obj.c, undefined
		
		t.throwMatch fn, "SimpleProxy: cannot access non-defined key 'c'"
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventAccess: true }
			t.eq arr[2], undefined
		
		t.throwMatch fn, "SimpleProxy: cannot access non-defined key '2'"
	
	t.test 'preventAccess == false', (t) ->
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventAccess: false }
			t.eq obj.c, undefined
		
		t.notThrow fn
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventAccess: false }
			t.eq arr[2], undefined
		
		t.notThrow fn
	
	##--------------------------------------------------------------------------
	
	t.test 'preventDefine == true', (t) ->
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventDefine: true }
			Object.defineProperty obj, 'a', { value: 2 }
		
		t.throwMatch fn, "SimpleProxy: cannot define key 'a'"
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventDefine: true }
			Object.defineProperty arr, 0, { value: 'c' }
		
		t.throwMatch fn, "SimpleProxy: cannot define key '0'"
	
	t.test 'preventDefine == false', (t) ->
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventDefine: false }
			Object.defineProperty obj, 'a', { value: 2 }
		
		t.notThrow fn
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventDefine: false }
			Object.defineProperty arr, 0, { value: 'c' }
		
		t.notThrow fn
	
	##--------------------------------------------------------------------------
	
	t.test 'preventDelete == true', (t) ->
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventDelete: true }
			delete obj.a
		
		t.throwMatch fn, "SimpleProxy: cannot delete key 'a'"
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventDelete: true }
			delete arr[0]
		
		t.throwMatch fn, "SimpleProxy: cannot delete key '0'"
	
	t.test 'preventDelete == false', (t) ->
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventDelete: false }
			delete obj.a
		
		t.notThrow fn
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventDelete: false }
			delete arr[0]
		
		t.notThrow fn
	
	##--------------------------------------------------------------------------
	
	t.test 'preventExtend == true', (t) ->
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventExtend: true }
			obj.c = 2
		
		t.throwMatch fn, "SimpleProxy: cannot extend key 'c'"
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventExtend: true }
			arr.push 'c'
		
		t.throwMatch fn, "SimpleProxy: cannot extend key '2'"
	
	t.test 'preventExtend == false', (t) ->
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventExtend: false }
			obj.c = 2
		
		t.notThrow fn
		
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventExtend: false }
			Object.defineProperty obj, 'c', { value: 2 }
		
		t.notThrow fn
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventExtend: false }
			arr.push 'c'
		
		t.notThrow fn
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventExtend: false }
			Object.defineProperty arr, 2, { value: 'c' }
		
		t.notThrow fn
	
	##--------------------------------------------------------------------------
	
	t.test 'preventMutate == true', (t) ->
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventMutate: true }
			obj.a = false
		
		t.throwMatch fn, "SimpleProxy: cannot mutate key 'a'"
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventMutate: true }
			arr.push 'c'
		
		t.throwMatch fn, "SimpleProxy: cannot mutate key '2'"
	
	t.test 'preventMutate == false', (t) ->
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventMutate: false }
			obj.a = false
		
		t.notThrow fn
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventMutate: false }
			arr.push 'c'
		
		t.notThrow fn
	
	##--------------------------------------------------------------------------
	
	t.test 'preventUndefined == true', (t) ->
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventUndefined: true }
			obj.c = undefined
		
		t.throwMatch fn, "SimpleProxy: cannot set undefined on key 'c'"
		
		fn = ->
			SimpleProxy.new { a: 0, b: 1, c: undefined }, { preventUndefined: true }
		
		t.throwMatch fn, "SimpleProxy: cannot set undefined on key 'c'"
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventUndefined: true }
			arr.push undefined
		
		t.throwMatch fn, "SimpleProxy: cannot set undefined on key '2'"
		
		fn = ->
			SimpleProxy.new [ 'a', 'b', undefined ], { preventUndefined: true }
		
		t.throwMatch fn, "SimpleProxy: cannot set undefined on key '2'"
	
	t.test 'preventUndefined == false', (t) ->
		fn = ->
			obj = SimpleProxy.new testFlatObj(), { preventUndefined: false }
			obj.c = undefined
		
		t.notThrow fn
		
		fn = ->
			SimpleProxy.new { a: 0, b: 1, c: undefined }, { preventUndefined: false }
		
		t.notThrow fn
		
		fn = ->
			arr = SimpleProxy.new testFlatArr(), { preventUndefined: false }
			arr.push undefined
		
		t.notThrow fn
		
		fn = ->
			SimpleProxy.new [ 'a', 'b', undefined ], { preventUndefined: false }
		
		t.notThrow fn
	
	##--------------------------------------------------------------------------
	
	t.test 'deepProxy simple', (t) ->
		fn = ->
			obj = SimpleProxy.new
				a: b: c: d: e: {}
			,
				deepProxy: true
			t.eq obj.a.b.c.d.e.f, undefined
		
		t.notThrow fn
		
		obj = SimpleProxy.new
			a: b: c: d: e: 'Hello World!'
		,
			preventAccess: true
			preventDefine: true
			preventDelete: true
			preventExtend: true
			preventMutate: true
			preventUndefined: true
			deepProxy: true
		
		t.throwMatch ->
			t.eq obj.a.b.c.d.f, undefined
		, "SimpleProxy: cannot access non-defined key 'a.b.c.d.f'"
		
		t.throwMatch ->
			Object.defineProperty obj.a.b.c.d, 'e', { enumerable: false }
		, "SimpleProxy: cannot define key 'a.b.c.d.e'"
		
		t.throwMatch ->
			Object.defineProperty obj.a.b.c.d, 'f', { value: true }
		, "SimpleProxy: cannot define key 'a.b.c.d.f'"
		
		t.throwMatch ->
			delete obj.a.b.c.d.e
		, "SimpleProxy: cannot delete key 'a.b.c.d.e'"
		
		t.throwMatch ->
			obj.a.b.c.d.f = 'g'
		, "SimpleProxy: cannot extend key 'a.b.c.d.f'"
		
		t.throwMatch ->
			obj.a.b.c.d.e = false
		, "SimpleProxy: cannot mutate key 'a.b.c.d.e'"
		
		obj = SimpleProxy.new
			a: b: c: d: e: 'Hello World!'
		,
			preventUndefined: true
			deepProxy: true
		
		t.throwMatch ->
			obj.a.b.c.d.e = undefined
		, "SimpleProxy: cannot set undefined on key 'a.b.c.d.e'"
	
	t.test 'deepProxy simple', (t) ->
		obj = SimpleProxy.new
			a: [{ b: [{ c: [{ d: [{ e: 'Hello World!' }] }] }] }]
		,
			preventAccess: true
			preventDefine: true
			preventDelete: true
			preventExtend: true
			preventMutate: true
			preventUndefined: true
			deepProxy: true
		
		t.eq obj.a[0].b[0].c[0].d[0].e, 'Hello World!'
		
		t.throwMatch ->
			obj.a[0].b[0].c[0].d[0].e = false
		, "SimpleProxy: cannot mutate key 'a[0].b[0].c[0].d[0].e'"
	
	##--------------------------------------------------------------------------
	
	t.test 'nested proxies', (t) ->
		
		raw = { a: 'a' }
		
		proxy1 = SimpleProxy.access raw, { name: 'proxy1' }
		proxy2 = SimpleProxy.access proxy1, { name: 'proxy2' }
		proxy3 = SimpleProxy.access proxy2, { name: 'proxy3' }
		
		# all values are the same, and do not throw an error
		t.ok proxy1.a == proxy2.a == proxy3.a == 'a'
		
		t.throwMatch (-> proxy1.b), "proxy1: cannot access non-defined key 'b'"
		t.throwMatch (-> proxy2.b), "proxy2: cannot access non-defined key 'b'"
		t.throwMatch (-> proxy3.b), "proxy3: cannot access non-defined key 'b'"
		
		# set value on non-defined field, on outermost proxy
		proxy3.b = 'b'
		
		# all values are the same, and do not throw an error
		t.ok proxy1.b == proxy2.b == proxy3.b == 'b'
