"
A stand-in for an object returned by a domain object in the binding tests.
"
Class {
	#name : 'QJSTestRow',
	#superclass : 'Object',
	#instVars : [
		'name'
	],
	#category : 'QuickJS-Tests',
	#package : 'QuickJS-Tests'
}

{ #category : 'instance creation' }
QJSTestRow class >> named: aString [

	^ self new setName: aString
]

{ #category : 'accessing' }
QJSTestRow >> name [

	^ name
]

{ #category : 'initialization' }
QJSTestRow >> setName: aString [

	name := aString
]
