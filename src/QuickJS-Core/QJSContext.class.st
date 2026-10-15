"
I am a QuickJS context: a global object in a runtime. #eval: runs a script and answers its result as a Pharo value; a JS exception is signalled as a QJSError.

Values cross in both directions the same way: nil and null (undefined becomes nil too), Booleans, numbers as Integer or Float, strings, sequenceable collections and arrays, dictionaries and plain objects. Every other Pharo object reaches JS as a binding: a JS object with one method per exposed selector, named PharoJS-style (#at:put: becomes at_put_). A binding coming back from JS is the Pharo object itself.

	context at: 'grid' put: aGrid exposing: #(name rows).
	context at: 'grid' put: aGrid exposing: { AGGrid -> #(name rows). AGRow -> #(id name) }.

The exposure table applies to every object reachable through the binding: an object returned by an exposed method gets the selectors of its class from the table, or none and stays opaque. A selector not exposed does not exist in JS. An error in Pharo becomes a JS Error with its messageText.

#free releases me and may be called again; releasing my runtime releases me too. If you forget it, finalization takes care of it.
"
Class {
	#name : 'QJSContext',
	#superclass : 'Object',
	#instVars : [
		'runtime',
		'handle',
		'session'
	],
	#classVars : [
		'Callback',
		'CallbackSession',
		'Registry'
	],
	#category : 'QuickJS-Core',
	#package : 'QuickJS-Core'
}

{ #category : 'callbacks' }
QJSContext class >> ensureCallback [
	"One callback serves every call from JS into Pharo; it dies with the session"

	(Callback notNil and: [ CallbackSession == Smalltalk session ]) ifTrue: [ ^ self ].
	Callback := FFICallback
		            signature: #( int #( void * context , int64 id , void * selector , int argc , void * argv , void * answer ) )
		            block: [ :context :id :selector :argc :argv :answer |
		            self handleCall: context id: id selector: selector argc: argc argv: argv answer: answer ].
	CallbackSession := Smalltalk session.
	QJSLibrary uniqueInstance setCallback: Callback
]

{ #category : 'finalization' }
QJSContext class >> finalizeResourceData: aHandle [

	QJSLibrary uniqueInstance contextDestroy: aHandle
]

{ #category : 'callbacks' }
QJSContext class >> handleCall: contextHandle id: id selector: selector argc: argc argv: argv answer: answer [

	| context |
	context := self registry at: contextHandle asInteger ifAbsent: [ ^ 1 ].
	^ context handleCall: id selector: selector argc: argc argv: argv answer: answer
]

{ #category : 'callbacks' }
QJSContext class >> registry [
	"Contexts by the address of their C box, so the callback finds the one it is called for"

	^ Registry ifNil: [ Registry := WeakValueDictionary new ]
]

{ #category : 'instance creation' }
QJSContext class >> runtime: aRuntime [

	^ self new setRuntime: aRuntime
]

{ #category : 'private - to JS' }
QJSContext >> arrayBoxFor: aCollection exposure: aDictionary [

	| array |
	array := self library newArray: handle.
	aCollection doWithIndex: [ :each :index |
		| element |
		element := self boxFor: each exposure: aDictionary.
		[ self library context: handle setIndex: index - 1 of: array to: element ] ensure: [ self freeValue: element ] ].
	^ array
]

{ #category : 'private - to Pharo' }
QJSContext >> arrayOf: value [

	^ (0 to: (self library context: handle arrayLength: value) - 1) asArray collect: [ :index |
		  | element |
		  element := self library context: handle getIndex: index of: value.
		  [ self valueOf: element ] ensure: [ self freeValue: element ] ]
]

{ #category : 'accessing' }
QJSContext >> at: aName put: anObject [
	"Set a global in JS. Objects that are not values reach JS opaque, without methods"

	self at: aName put: anObject exposing: Dictionary new
]

{ #category : 'accessing' }
QJSContext >> at: aName put: anObject exposing: selectorsOrTable [
	"Set a global in JS. selectorsOrTable is either the selectors JS may call on anObject, or a table of classes and their selectors that applies to everything reachable through anObject"

	| value |
	self checkLive.
	self class ensureCallback.
	value := self boxFor: anObject exposure: (self exposureFor: anObject from: selectorsOrTable).
	[ self library context: handle setGlobal: (self cString: aName) to: value ] ensure: [ self freeValue: value ]
]

{ #category : 'private - to JS' }
QJSContext >> bindingBoxFor: anObject exposure: aDictionary [

	| binding id box |
	binding := QJSBinding object: anObject exposure: aDictionary.
	id := runtime registerBinding: binding.
	box := self library context: handle newBinding: id.
	binding selectors do: [ :each |
		self library context: handle define: box name: (self jsNameOf: each) id: id selector: each ].
	^ box
]

{ #category : 'private - to JS' }
QJSContext >> boxFor: anObject exposure: aDictionary [
	"A new value box for anObject; the caller frees it"

	anObject ifNil: [ ^ self library newNull: handle ].
	anObject == true ifTrue: [ ^ self library context: handle newBool: 1 ].
	anObject == false ifTrue: [ ^ self library context: handle newBool: 0 ].
	anObject isInteger ifTrue: [
		^ (anObject between: -9223372036854775808 and: 9223372036854775807)
			  ifTrue: [ self library context: handle newInt64: anObject ]
			  ifFalse: [ self library context: handle newFloat64: anObject asFloat ] ].
	anObject isNumber ifTrue: [ ^ self library context: handle newFloat64: anObject asFloat ].
	(anObject isString or: [ anObject isCharacter ]) ifTrue: [ ^ self stringBoxFor: anObject asString ].
	anObject isDictionary ifTrue: [ ^ self objectBoxFor: anObject exposure: aDictionary ].
	(anObject isCollection and: [ anObject isSequenceable ]) ifTrue: [
		^ self arrayBoxFor: anObject exposure: aDictionary ].
	^ self bindingBoxFor: anObject exposure: aDictionary
]

{ #category : 'private' }
QJSContext >> cString: aString [
	"NUL-terminated UTF-8 bytes, pinned for the call"

	| bytes |
	bytes := aString utf8Encoded , #[ 0 ].
	bytes pinInMemory.
	^ bytes
]

{ #category : 'private' }
QJSContext >> checkLive [

	self isFromThisSession ifFalse: [ QJSError signal: 'QuickJS context is stale after an image restart' ].
	(self library contextIsLive: handle) = 1 ifFalse: [ QJSError signal: 'QuickJS context is released' ]
]

{ #category : 'private - to Pharo' }
QJSContext >> dictionaryOf: value [

	| keys dictionary |
	dictionary := Dictionary new.
	keys := self library context: handle objectKeys: value.
	[
	(self arrayOf: keys) do: [ :key |
		| property |
		property := self library context: handle getProperty: (self cString: key) of: value.
		[ dictionary at: key put: (self valueOf: property) ] ensure: [ self freeValue: property ] ] ]
		ensure: [ self freeValue: keys ].
	^ dictionary
]

{ #category : 'evaluating' }
QJSContext >> eval: aString [

	| bytes value |
	self checkLive.
	self class ensureCallback.
	bytes := aString utf8Encoded.
	bytes pinInMemory.
	value := self library eval: handle source: bytes length: bytes size.
	^ [ self valueOf: value ] ensure: [
		  self freeValue: value.
		  runtime dropReleasedBindings ]
]

{ #category : 'private - to JS' }
QJSContext >> exposureFor: anObject from: selectorsOrTable [

	| table |
	table := selectorsOrTable isDictionary
		         ifTrue: [ selectorsOrTable ]
		         ifFalse: [
			         (selectorsOrTable allSatisfy: [ :each | each isString ])
				         ifTrue: [ Dictionary with: anObject class -> selectorsOrTable ]
				         ifFalse: [ selectorsOrTable asDictionary ] ].
	^ table collect: [ :selectors |
		  selectors asArray collect: [ :each |
			  each first isLetter ifFalse: [ QJSError signal: 'binary selector ' , each , ' cannot be exposed to JS' ].
			  each asSymbol ] ]
]

{ #category : 'releasing' }
QJSContext >> free [
	"Release the context. Harmless when called again or after the runtime is released"

	self isFromThisSession ifTrue: [ self library contextRelease: handle ]
]

{ #category : 'private' }
QJSContext >> freeValue: value [

	self library valueFree: value
]

{ #category : 'callbacks' }
QJSContext >> handleCall: id selector: selectorValue argc: argc argv: argv answer: answer [
	"Called from JS through the callback. Answers 0 with the result in answer, or 1 with an error message; nothing may escape into C"

	^ [
	  | binding selector arguments result |
	  binding := runtime bindingAt: id.
	  selector := (self stringOf: selectorValue) asSymbol.
	  (binding allows: selector) ifFalse: [ QJSError signal: selector , ' is not exposed to JS' ].
	  selector numArgs = argc ifFalse: [
		  QJSError signal: selector , ' expects ' , selector numArgs printString , ' arguments, not ' , argc printString ].
	  arguments := (1 to: argc) collect: [ :index | self valueOf: (argv pointerAt: index - 1 * 8 + 1) ].
	  result := binding object perform: selector withArguments: arguments asArray.
	  answer pointerAt: 1 put: (self boxFor: result exposure: binding exposure).
	  0 ]
		  on: Error
		  do: [ :error |
			  answer pointerAt: 1 put: (self stringBoxFor: error messageText asString).
			  1 ]
]

{ #category : 'testing' }
QJSContext >> isFromThisSession [

	^ session == Smalltalk session
]

{ #category : 'testing' }
QJSContext >> isLive [

	^ self isFromThisSession and: [ (self library contextIsLive: handle) = 1 ]
]

{ #category : 'private - to JS' }
QJSContext >> jsNameOf: aSelector [
	"PharoJS-style: #at:put: becomes at_put_"

	^ aSelector copyReplaceAll: ':' with: '_'
]

{ #category : 'accessing' }
QJSContext >> library [

	^ QJSLibrary uniqueInstance
]

{ #category : 'private - to Pharo' }
QJSContext >> numberOf: value [

	| float |
	(self library valueIsInt: value) = 1 ifTrue: [
		^ self library context: handle valueToInt64: value ].
	float := self library context: handle valueToFloat64: value.
	^ (float isFinite and: [ float fractionPart = 0 and: [ float abs <= (2 raisedTo: 53) ] ])
		  ifTrue: [ float asInteger ]
		  ifFalse: [ float ]
]

{ #category : 'private - to JS' }
QJSContext >> objectBoxFor: aDictionary exposure: anExposure [

	| object |
	object := self library newObject: handle.
	aDictionary keysAndValuesDo: [ :key :each |
		| property |
		property := self boxFor: each exposure: anExposure.
		[
		self library
			context: handle
			setProperty: (self cString: (key isString ifTrue: [ key ] ifFalse: [ key printString ]))
			of: object
			to: property ] ensure: [ self freeValue: property ] ].
	^ object
]

{ #category : 'accessing' }
QJSContext >> runtime [

	^ runtime
]

{ #category : 'initialization' }
QJSContext >> setRuntime: aRuntime [

	runtime := aRuntime.
	handle := self library contextNew: aRuntime handle.
	handle isNull ifTrue: [ QJSError signal: 'QuickJS could not create a context' ].
	session := Smalltalk session.
	FFIExternalResourceManager addResource: self data: handle.
	self class registry at: handle asInteger put: self
]

{ #category : 'private - to Pharo' }
QJSContext >> signalPendingException [

	| exception message stackValue stack |
	exception := self library exception: handle.
	[
	message := self stringOf: exception.
	stackValue := self library context: handle getProperty: (self cString: 'stack') of: exception.
	[ stack := self stringOf: stackValue ] ensure: [ self freeValue: stackValue ] ]
		ensure: [ self freeValue: exception ].
	^ QJSError new
		  jsStack: stack;
		  signal: message
]

{ #category : 'private - to JS' }
QJSContext >> stringBoxFor: aString [

	| bytes |
	bytes := aString utf8Encoded.
	bytes pinInMemory.
	^ self library context: handle newString: bytes length: bytes size
]

{ #category : 'private - to Pharo' }
QJSContext >> stringOf: value [
	"JS toString of the value, decoded from UTF-8; nil if toString throws"

	| lengthBuffer utf8 |
	lengthBuffer := ExternalAddress allocate: 8.
	[
	utf8 := self library context: handle valueToUtf8: value length: lengthBuffer.
	utf8 isNull ifTrue: [ ^ nil ].
	^ [ (utf8 structAt: 1 length: (lengthBuffer unsignedLongLongAt: 1)) utf8Decoded ]
		  ensure: [ self library bytesFree: utf8 ] ]
		ensure: [ lengthBuffer free ]
]

{ #category : 'private - to Pharo' }
QJSContext >> valueOf: value [

	| type |
	type := self library context: handle valueType: value.
	type = 12 ifTrue: [ QJSError signal: 'QuickJS context is released' ].
	type = 10 ifTrue: [ ^ self signalPendingException ].
	(type = 0 or: [ type = 1 ]) ifTrue: [ ^ nil ].
	type = 2 ifTrue: [ ^ (self library context: handle valueToBool: value) = 1 ].
	type = 3 ifTrue: [ ^ self numberOf: value ].
	type = 8 ifTrue: [ ^ (self stringOf: value) asInteger ].
	type = 13 ifTrue: [ ^ (runtime bindingAt: (self library context: handle bindingId: value)) object ].
	type = 6 ifTrue: [ ^ self arrayOf: value ].
	type = 5 ifTrue: [ ^ self dictionaryOf: value ].
	^ self stringOf: value
]
