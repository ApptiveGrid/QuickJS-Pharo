"
I am what a runtime keeps for a Pharo object it has handed to JS: the object, the selectors JS may call on it, their names in JS, and the exposure table that decides the selectors of every object coming back from those calls.

The exposure table maps classes to selectors. An object gets the selectors of the nearest class in its hierarchy that has an entry; without an entry it gets none and stays opaque to JS. That is the permission.

The name is separate from the permission: a method names itself with a pragma, e.g. `at: key put: value <jsName: 'atPut'>`; without one, the name is PharoJS-style (#at:put: becomes at_put_). Two exposed selectors with the same name signal a QJSError.

A selector without arguments is a read-only property in JS, read without parentheses (`grid.name`); its getter calls the selector on every read. Every other selector is a method. A property is not enumerable, like a method, so walking the object (Object.keys, JSON.stringify) calls nothing in Pharo.
"
Class {
	#name : 'QJSBinding',
	#superclass : 'Object',
	#instVars : [
		'object',
		'exposure',
		'selectors',
		'names'
	],
	#category : 'QuickJS-Core',
	#package : 'QuickJS-Core'
}

{ #category : 'instance creation' }
QJSBinding class >> object: anObject exposure: aDictionary [

	^ self new setObject: anObject exposure: aDictionary
]

{ #category : 'naming' }
QJSBinding class >> pharoJSNameOf: aSelector [
	"#at:put: becomes at_put_"

	^ aSelector copyReplaceAll: ':' with: '_'
]

{ #category : 'testing' }
QJSBinding >> allows: aSelector [

	^ selectors includes: aSelector
]

{ #category : 'accessing' }
QJSBinding >> exposure [

	^ exposure
]

{ #category : 'testing' }
QJSBinding >> isProperty: aSelector [
	"A selector without arguments is read as a property in JS, without parentheses"

	^ aSelector numArgs = 0
]

{ #category : 'naming' }
QJSBinding >> jsNameOf: aSelector [
	"The name the method the object runs for aSelector gives itself with <jsName:>, otherwise the PharoJS-style name"

	| name |
	(object class lookupSelector: aSelector) ifNotNil: [ :method |
		(method pragmaAt: #jsName:) ifNotNil: [ :pragma |
			name := pragma arguments first.
			(name isString and: [ name notEmpty ]) ifFalse: [
				QJSError signal: '<jsName:> of ' , method printString , ' must be a non-empty string' ].
			^ name asString ] ].
	^ self class pharoJSNameOf: aSelector
]

{ #category : 'accessing' }
QJSBinding >> names [
	"JS names to the selectors they call"

	^ names
]

{ #category : 'accessing' }
QJSBinding >> object [

	^ object
]

{ #category : 'accessing' }
QJSBinding >> selectors [

	^ selectors
]

{ #category : 'initialization' }
QJSBinding >> setNames [

	names := Dictionary new.
	selectors do: [ :each |
		| name |
		name := self jsNameOf: each.
		names at: name ifPresent: [ :other |
			QJSError signal: 'JS name ' , name , ' is used by both #' , other , ' and #' , each ].
		names at: name put: each ]
]

{ #category : 'initialization' }
QJSBinding >> setObject: anObject exposure: aDictionary [

	object := anObject.
	exposure := aDictionary.
	selectors := anObject class withAllSuperclasses
		             detect: [ :each | aDictionary includesKey: each ]
		             ifFound: [ :each | aDictionary at: each ]
		             ifNone: [ #(  ) ].
	self setNames
]
