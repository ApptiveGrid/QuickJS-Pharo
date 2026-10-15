"
I check Pharo objects handed to JS: only exposed selectors exist, objects coming back follow the exposure table, and values cross both ways.
"
Class {
	#name : 'QJSBindingTest',
	#superclass : 'TestCase',
	#instVars : [
		'runtime',
		'context',
		'grid'
	],
	#category : 'QuickJS-Tests',
	#package : 'QuickJS-Tests'
}

{ #category : 'running' }
QJSBindingTest >> setUp [

	super setUp.
	runtime := QJSRuntime new.
	context := runtime newContext.
	grid := QJSTestGrid named: 'Kunden' rows: #( 'a' 'b' )
]

{ #category : 'running' }
QJSBindingTest >> tearDown [

	runtime free.
	super tearDown
]

{ #category : 'tests' }
QJSBindingTest >> testArgumentsAreConverted [

	context at: 'grid' put: grid exposing: #( echo: ).
	self
		assert: (context eval: 'grid.echo_([1, {a: "b"}, null, true])')
		equals: { 1. (Dictionary with: 'a' -> 'b'). nil. true }
]

{ #category : 'tests' }
QJSBindingTest >> testBinarySelectorIsRefused [

	self should: [ context at: 'grid' put: grid exposing: #( + ) ] raise: QJSError
]

{ #category : 'tests' }
QJSBindingTest >> testBindingComesBackAsTheSameObject [

	context at: 'grid' put: grid exposing: #(  ).
	self assert: (context eval: 'grid') identicalTo: grid.
	self assert: (context eval: '[grid, grid]') first identicalTo: grid
]

{ #category : 'tests' }
QJSBindingTest >> testExposedSelectorIsCallable [

	context at: 'grid' put: grid exposing: #( name ).
	self assert: (context eval: 'grid.name()') equals: 'Kunden'
]

{ #category : 'tests' }
QJSBindingTest >> testFollowUpObjectWithoutEntryIsOpaque [

	context at: 'grid' put: grid exposing: #( rows indexOf: ).
	self assert: (context eval: 'typeof grid.rows()[0].name') equals: 'undefined'.
	self assert: (context eval: 'grid.indexOf_(grid.rows()[1])') equals: 2
]

{ #category : 'tests' }
QJSBindingTest >> testFollowUpObjectsUseTheTable [

	context at: 'grid' put: grid exposing: {
			(QJSTestGrid -> #( rows rowAt: )).
			(QJSTestRow -> #( name )) }.
	self assert: (context eval: 'grid.rows().map(r => r.name())') equals: #( 'a' 'b' ).
	self assert: (context eval: 'grid.rowAt_(2).name()') equals: 'b'
]

{ #category : 'tests' }
QJSBindingTest >> testKeywordSelectorIsNamedLikePharoJS [

	context at: 'grid' put: grid exposing: #( rowAt: ).
	self assert: (context eval: 'typeof grid.rowAt_') equals: 'function'
]

{ #category : 'tests' }
QJSBindingTest >> testNestedEvaluationFromPharo [

	grid context: context.
	context at: 'grid' put: grid exposing: #( nested ).
	self assert: (context eval: 'grid.nested() + 1') equals: 43
]

{ #category : 'tests' }
QJSBindingTest >> testPharoErrorBecomesJSError [

	context at: 'grid' put: grid exposing: #( fail ).
	self assert: (context eval: 'try { grid.fail() } catch (e) { e.message }') equals: 'nope'.
	self
		should: [ context eval: 'grid.fail()' ]
		raise: QJSError
		withExceptionDo: [ :error | self assert: (error messageText includesSubstring: 'nope') ]
]

{ #category : 'tests' }
QJSBindingTest >> testPlainValues [

	context at: 'n' put: 42.
	context at: 'list' put: #( 1 2 3 ) asOrderedCollection.
	context at: 'greeting' put: 'Grüße'.
	context at: 'map' put: (Dictionary with: 'Größe' -> 2.5).
	self assert: (context eval: 'n + list.length') equals: 45.
	self assert: (context eval: 'greeting.length') equals: 5.
	self assert: (context eval: 'map["Größe"] * 2') equals: 5.
	self assert: (context eval: '({ä: [1, 2]})') equals: (Dictionary with: 'ä' -> #( 1 2 ))
]

{ #category : 'tests' }
QJSBindingTest >> testReleasedBindingsAreDropped [

	context at: 'tmp' put: grid exposing: #( name ).
	self assert: runtime bindingCount equals: 1.
	context eval: 'delete globalThis.tmp'.
	self assert: runtime bindingCount equals: 0
]

{ #category : 'tests' }
QJSBindingTest >> testUnexposedSelectorDoesNotExist [

	context at: 'grid' put: grid exposing: #( name ).
	self assert: (context eval: 'typeof grid.secret') equals: 'undefined'.
	self should: [ context eval: 'grid.secret()' ] raise: QJSError
]

{ #category : 'tests' }
QJSBindingTest >> testWrongArgumentCountIsAnError [

	context at: 'grid' put: grid exposing: #( rowAt: ).
	self should: [ context eval: 'grid.rowAt_()' ] raise: QJSError
]
