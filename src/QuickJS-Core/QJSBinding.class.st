"
I am what a runtime keeps for a Pharo object it has handed to JS: the object, the selectors JS may call on it, and the exposure table that decides the selectors of every object coming back from those calls.

The exposure table maps classes to selectors. An object gets the selectors of the nearest class in its hierarchy that has an entry; without an entry it gets none and stays opaque to JS.
"
Class {
	#name : 'QJSBinding',
	#superclass : 'Object',
	#instVars : [
		'object',
		'exposure',
		'selectors'
	],
	#category : 'QuickJS-Core',
	#package : 'QuickJS-Core'
}

{ #category : 'instance creation' }
QJSBinding class >> object: anObject exposure: aDictionary [

	^ self new setObject: anObject exposure: aDictionary
]

{ #category : 'testing' }
QJSBinding >> allows: aSelector [

	^ selectors includes: aSelector
]

{ #category : 'accessing' }
QJSBinding >> exposure [

	^ exposure
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
QJSBinding >> setObject: anObject exposure: aDictionary [

	object := anObject.
	exposure := aDictionary.
	selectors := anObject class withAllSuperclasses
		             detect: [ :each | aDictionary includesKey: each ]
		             ifFound: [ :each | aDictionary at: each ]
		             ifNone: [ #(  ) ]
]
