"
A stand-in for the proxy of an object database: a class of its own, and everything it does not understand it hands on to its object.
"
Class {
	#name : 'QJSTestProxy',
	#superclass : 'ProtoObject',
	#instVars : [
		'object'
	],
	#category : 'QuickJS-Tests',
	#package : 'QuickJS-Tests'
}

{ #category : 'instance creation' }
QJSTestProxy class >> on: anObject [

	^ self new setObject: anObject
]

{ #category : 'reflective operations' }
QJSTestProxy >> doesNotUnderstand: aMessage [

	^ aMessage sendTo: object
]

{ #category : 'initialization' }
QJSTestProxy >> setObject: anObject [

	object := anObject
]
