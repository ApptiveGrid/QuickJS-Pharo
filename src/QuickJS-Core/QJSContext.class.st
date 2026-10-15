"
I am a QuickJS context: a global object in a runtime. #eval: runs a script and answers its result as a Pharo value; a JS exception is signalled as a QJSError.

Results are converted right away and their handles freed: undefined and null become nil, numbers Integer or Float, strings String, arrays and objects go through JSON.
"
Class {
	#name : 'QJSContext',
	#superclass : 'Object',
	#instVars : [
		'runtime',
		'handle'
	],
	#category : 'QuickJS-Core',
	#package : 'QuickJS-Core'
}

{ #category : 'instance creation' }
QJSContext class >> runtime: aRuntime [

	^ self new setRuntime: aRuntime
]

{ #category : 'evaluating' }
QJSContext >> eval: aString [

	| bytes value |
	bytes := aString utf8Encoded.
	bytes pinInMemory.
	value := self library eval: handle source: bytes length: bytes size.
	^ [ self valueOf: value ] ensure: [ self freeValue: value ]
]

{ #category : 'releasing' }
QJSContext >> free [

	handle ifNil: [ ^ self ].
	self library contextFree: handle.
	handle := nil
]

{ #category : 'private' }
QJSContext >> freeValue: value [

	self library context: handle valueFree: value
]

{ #category : 'accessing' }
QJSContext >> library [

	^ QJSLibrary uniqueInstance
]

{ #category : 'private' }
QJSContext >> numberOf: value [

	| float |
	(self library valueIsInt: value) = 1 ifTrue: [
		^ self library context: handle valueToInt64: value ].
	float := self library context: handle valueToFloat64: value.
	^ (float isFinite and: [ float fractionPart = 0 and: [ float abs <= (2 raisedTo: 53) ] ])
		  ifTrue: [ float asInteger ]
		  ifFalse: [ float ]
]

{ #category : 'initialization' }
QJSContext >> setRuntime: aRuntime [

	runtime := aRuntime.
	handle := self library contextNew: aRuntime handle.
	handle isNull ifTrue: [ self error: 'QuickJS could not create a context' ]
]

{ #category : 'private' }
QJSContext >> signalPendingException [

	| exception message stackValue stack |
	exception := self library exception: handle.
	[
	message := self stringOf: exception.
	stackValue := self library context: handle getProperty: 'stack' of: exception.
	[ stack := self stringOf: stackValue ] ensure: [ self freeValue: stackValue ] ]
		ensure: [ self freeValue: exception ].
	^ QJSError new
		  jsStack: stack;
		  signal: message
]

{ #category : 'private' }
QJSContext >> stringOf: value [
	"JS toString of the value, decoded from UTF-8; nil if toString throws"

	| lengthBuffer utf8 |
	lengthBuffer := ExternalAddress allocate: 8.
	[
	utf8 := self library context: handle valueToUtf8: value length: lengthBuffer.
	utf8 isNull ifTrue: [ ^ nil ].
	^ [ (utf8 structAt: 1 length: (lengthBuffer unsignedLongLongAt: 1)) utf8Decoded ]
		  ensure: [ self library context: handle utf8Free: utf8 ] ]
		ensure: [ lengthBuffer free ]
]

{ #category : 'private' }
QJSContext >> valueOf: value [

	| type json |
	type := self library context: handle valueType: value.
	type = 10 ifTrue: [ ^ self signalPendingException ].
	(type = 0 or: [ type = 1 ]) ifTrue: [ ^ nil ].
	type = 2 ifTrue: [ ^ (self library context: handle valueToBool: value) = 1 ].
	type = 3 ifTrue: [ ^ self numberOf: value ].
	type = 8 ifTrue: [ ^ (self stringOf: value) asInteger ].
	(type = 5 or: [ type = 6 ]) ifTrue: [
		json := self library context: handle valueToJson: value.
		^ [ STONJSON fromString: (self valueOf: json) ] ensure: [ self freeValue: json ] ].
	^ self stringOf: value
]
