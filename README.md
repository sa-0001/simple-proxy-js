# @sa0001/simple-proxy

[NPM][https://www.npmjs.com/package/@sa0001/simple-proxy]

This module helps you create a powerful ES6 Proxy using simple options, that otherwise would take a surprising amount of effort and knowledge to correctly implement.

## Install

```bash
npm install @sa0001/simple-proxy
```

## Usage

```javascript
const SimpleProxy = require('@sa0001/simple-proxy')

// some data you want to protect
const data = {
	goodKey: 'val'
	subObj: {
		goodKey: 'val'
	}
}

// all available proxy options
const options = {
	// give this proxy a name, which is displayed in the error message
	name: 'SimpleProxy',
	
	// prevent accessing non-defined properties (ex. `var v = proxy.wrongKey`)
	preventAccess: false,
	
	// prevent defining/reconfiguring properties using `Object.defineProperty`
	//  (compare to Object.freeze, Object.seal)
	preventDefine: false,
	
	// prevent removing properties using `delete`
	//  (compare to Object.freeze, Object.seal)
	preventDelete: false,
	
	// prevent adding new properties (ex. `proxy.newKey = true`)
	//  (compare to Object.freeze, Object.seal, Object.preventExtensions)
	preventExtend: false,
	
	// prevent changing values (ex. `proxy.key = 'new value'`)
	//  (compare to Object.freeze)
	preventMutate: false,
	
	// prevent setting/getting value undefined
	//  (can only delete the property, or set to null)
	preventUndefined: false,
	
	// when getting/setting an undefined value, instead get/set null
	//  (use this when you don't want the distinction between undefined and null)
	convertUndefinedToNull: false,
	
	// callback for all errors produced when an action was prevented;
	//  if no callback is provided, then the error is thrown
	onError: (err) => {
		if (err.code === "MUTATE") {
			throw err
		} else {
			console.error(err)
		}
	},
	
	// callback on get/set of every property
	onGet: (k) => {},
	onSet: (k, v) => {},
	
	// callback on get/set of any non-defined property
	onGetNonDefined: (k) => {},
	onSetNonDefined: (k, v) => {},
	
	// callback when a value changes
	onChange: (key, newVal, oldVal) => {},
	
	// proxy will also be applied to sub-objects
	deepProxy: false,
	
	// proxy will also be applied to sub-objects, but with different settings
	deepProxyOptions: null,
}

// create the proxy from initial data + options
const proxy = new SimpleProxy(data, options)

/**
 * some short and sweet examples:
**/

// preventAccess
const proxy = new SimpleProxy(data, { preventAccess: true })
var v = proxy.badKey // Error: SimpleProxy: cannot access non-defined key 'badKey'

// preventExtend
const proxy = new SimpleProxy(data, { preventExtend: true })
proxy.badKey = false // Error: SimpleProxy: cannot extend key 'badKey'

// preventMutate
const proxy = new SimpleProxy(data, { preventMutate: true })
proxy.goodKey = true // Error: SimpleProxy: cannot mutate key 'goodKey'

/**
 * static constructors for the three most common use-cases:
**/

// throw error when accessing (getting) non-defined properties
SimpleProxy.access(data)
var v = proxy.badKey // Error: SimpleProxy: cannot access non-defined key 'badKey'

// same, but also applied to sub-objects
SimpleProxy.deepAccess(data)
var v = proxy.subObj.badKey // Error: SimpleProxy: cannot access non-defined key 'subObj.badKey'

// equivalent of Object.freeze, but also works outside of strict mode
SimpleProxy.freeze(data)
proxy.goodKey = true // Error: SimpleProxy: cannot mutate key 'goodKey'

// same, but also applied to sub-objects
SimpleProxy.deepFreeze(data)
proxy.subObj.goodKey = true // Error: SimpleProxy: cannot mutate key 'subObj.goodKey'

// equivalent of Object.seal, but also works outside of strict mode
SimpleProxy.seal(data)
proxy.badKey = true // Error: SimpleProxy: cannot extend key 'badKey'

// same, but also applied to sub-objects
SimpleProxy.deepSeal(data)
proxy.subObj.badKey = true // Error: SimpleProxy: cannot extend key 'subObj.badKey'
```

## License

[MIT](http://vjpr.mit-license.org)
