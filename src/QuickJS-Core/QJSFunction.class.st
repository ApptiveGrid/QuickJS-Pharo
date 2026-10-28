"
I am a JS function held by Pharo, as JS handed it over: as the argument of an exposed method or as the result of an evaluation. I understand #value, #value:, #value:value:, #cull: and #valueWithArguments: like a block, so a Pharo method that takes a block takes me too:

	context at: 'grid' put: aGrid exposing: { QJSTestGrid -> #(rowsDo:). QJSTestRow -> #(name) }.
	context eval: 'const names = []; grid.rowsDo_(row => names.push(row.name())); names'

Arguments cross into JS like any value, with the exposure of the binding I came through, and the result comes back the same way. Called from inside a call from JS I run within the deadline of the evaluation around it, called from outside I get a deadline of my own. Handed back to JS I am the same function again.

I keep the function alive in JS until I am garbage or my runtime is released; calling me after that signals QJSError.
"
Class {
	#name : 'QJSFunction',
	#superclass : 'Object',
	#instVars : [
		'context',
		'handle',
		'exposure'
	],
	#category : 'QuickJS-Core',
	#package : 'QuickJS-Core'
}

{ #category : 'instance creation' }
QJSFunction class >> context: aContext handle: aHandle exposure: aDictionary [

	^ self new setContext: aContext handle: aHandle exposure: aDictionary
]

{ #category : 'finalization' }
QJSFunction class >> finalizeResourceData: aHandle [

	QJSLibrary uniqueInstance valueFree: aHandle
]

{ #category : 'evaluating' }
QJSFunction >> cull: anObject [
	"JS ignores arguments a function does not declare"

	^ self value: anObject
]

{ #category : 'accessing' }
QJSFunction >> exposure [

	^ exposure
]

{ #category : 'accessing' }
QJSFunction >> handle [

	^ handle
]

{ #category : 'initialization' }
QJSFunction >> setContext: aContext handle: aHandle exposure: aDictionary [

	context := aContext.
	handle := aHandle.
	exposure := aDictionary.
	FFIExternalResourceManager addResource: self data: handle
]

{ #category : 'evaluating' }
QJSFunction >> value [

	^ self valueWithArguments: #(  )
]

{ #category : 'evaluating' }
QJSFunction >> value: anObject [

	^ self valueWithArguments: { anObject }
]

{ #category : 'evaluating' }
QJSFunction >> value: anObject value: anotherObject [

	^ self valueWithArguments: {
			  anObject.
			  anotherObject }
]

{ #category : 'evaluating' }
QJSFunction >> valueWithArguments: anArray [

	^ context call: self withArguments: anArray
]
