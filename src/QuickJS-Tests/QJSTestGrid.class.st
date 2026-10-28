"
A stand-in for a domain object handed to JS in the binding tests.
"
Class {
	#name : 'QJSTestGrid',
	#superclass : 'Object',
	#instVars : [
		'name',
		'rows',
		'context',
		'values'
	],
	#category : 'QuickJS-Tests',
	#package : 'QuickJS-Tests'
}

{ #category : 'instance creation' }
QJSTestGrid class >> named: aString rows: names [

	^ self new setName: aString rows: names
]

{ #category : 'accessing' }
QJSTestGrid >> at: aKey [

	<jsName: 'get'>
	^ values at: aKey ifAbsent: [ nil ]
]

{ #category : 'accessing' }
QJSTestGrid >> at: aKey put: aValue [

	<jsName: 'atPut'>
	^ values at: aKey put: aValue
]

{ #category : 'accessing' }
QJSTestGrid >> context: aContext [

	context := aContext
]

{ #category : 'accessing' }
QJSTestGrid >> echo: anObject [

	^ anObject
]

{ #category : 'accessing' }
QJSTestGrid >> fail [

	^ self error: 'nope'
]

{ #category : 'accessing' }
QJSTestGrid >> indexOf: aRow [

	^ rows indexOf: aRow
]

{ #category : 'accessing' }
QJSTestGrid >> name [

	^ name
]

{ #category : 'accessing' }
QJSTestGrid >> nameAgain [
	"Takes a name another selector already has"

	<jsName: 'name'>
	^ name
]

{ #category : 'accessing' }
QJSTestGrid >> nested [
	"Evaluates JS while JS is calling this method"

	^ context eval: '6 * 7'
]

{ #category : 'accessing' }
QJSTestGrid >> rowAt: anIndex [

	^ rows at: anIndex
]

{ #category : 'accessing' }
QJSTestGrid >> rows [

	^ rows
]

{ #category : 'enumerating' }
QJSTestGrid >> rowsDo: aBlock [

	rows do: aBlock
]

{ #category : 'accessing' }
QJSTestGrid >> secret [

	^ 'not for JS'
]

{ #category : 'initialization' }
QJSTestGrid >> setName: aString rows: names [

	name := aString.
	rows := names collect: [ :each | QJSTestRow named: each ].
	values := Dictionary new
]
