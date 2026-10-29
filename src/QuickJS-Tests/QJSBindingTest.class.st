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

	context at: 'grid' put: grid exposing: #( echo: ).
	self assert: (context eval: 'grid.echo_(42)') equals: 42
]

{ #category : 'tests' }
QJSBindingTest >> testFollowUpObjectWithoutEntryIsOpaque [

	context at: 'grid' put: grid exposing: #( rows indexOf: ).
	self assert: (context eval: 'typeof grid.rows[0].name') equals: 'undefined'.
	self assert: (context eval: 'grid.indexOf_(grid.rows[1])') equals: 2
]

{ #category : 'tests' }
QJSBindingTest >> testFollowUpObjectsUseTheTable [

	context at: 'grid' put: grid exposing: {
			(QJSTestGrid -> #( rows rowAt: )).
			(QJSTestRow -> #( name )) }.
	self assert: (context eval: 'grid.rows.map(r => r.name)') equals: #( 'a' 'b' ).
	self assert: (context eval: 'grid.rowAt_(2).name') equals: 'b'
]

{ #category : 'tests' }
QJSBindingTest >> testInheritedPragmaAndOverrideWithout [
	"The name comes from the method the object runs: #at:put: inherited with its pragma, #at: overridden without one"

	context
		at: 'grid'
		put: (QJSTestSubGrid named: 'Kunden' rows: #(  ))
		exposing: { (QJSTestGrid -> #( at:put: at: )) }.
	self assert: (context eval: 'grid.atPut("k", 4); grid.at_("k")') equals: 40.
	self assert: (context eval: 'typeof grid.get') equals: 'undefined'
]

{ #category : 'tests' }
QJSBindingTest >> testKeywordSelectorIsNamedLikePharoJS [

	context at: 'grid' put: grid exposing: #( rowAt: ).
	self assert: (context eval: 'typeof grid.rowAt_') equals: 'function'
]

{ #category : 'tests' }
QJSBindingTest >> testNameAloneDoesNotExpose [
	"Naming and permission are separate: a method with <jsName:> that is not exposed does not exist in JS"

	context at: 'grid' put: grid exposing: #( name ).
	self assert: (context eval: 'typeof grid.atPut') equals: 'undefined'.
	self assert: (context eval: 'typeof grid.at_put_') equals: 'undefined'
]

{ #category : 'tests' }
QJSBindingTest >> testClosureIsCalledForEachElement [
	"Pharo iterates and calls the JS closure for each row, the rows follow the exposure table"

	context at: 'grid' put: grid exposing: {
			(QJSTestGrid -> #( rowsDo: )).
			(QJSTestRow -> #( name )) }.
	self
		assert: (context eval: 'const names = []; grid.rowsDo_(row => names.push(row.name)); names')
		equals: #( 'a' 'b' )
]

{ #category : 'tests' }
QJSBindingTest >> testErrorInAClosureReachesJS [

	context at: 'grid' put: grid exposing: #( rowsDo: ).
	self
		assert: (context eval: 'try { grid.rowsDo_(row => { throw new Error("stop") }) } catch (e) { e.message }')
		equals: 'Error: stop'
]

{ #category : 'tests' }
QJSBindingTest >> testFunctionCalledFromOutsideHasADeadline [

	| loop |
	runtime timeoutMilliseconds: 100.
	loop := context eval: '() => { while (true) {} }'.
	self should: [ loop value ] raise: QJSError
]

{ #category : 'tests' }
QJSBindingTest >> testFunctionGoesBackAsTheSameFunction [

	context at: 'grid' put: grid exposing: #( echo: ).
	self assert: (context eval: 'const f = x => x * 2; grid.echo_(f) === f') equals: true
]

{ #category : 'tests' }
QJSBindingTest >> testFunctionOfAReleasedRuntimeIsAnError [

	| identity |
	identity := context eval: 'x => x'.
	runtime free.
	self should: [ identity value: 1 ] raise: QJSError
]

{ #category : 'tests' }
QJSBindingTest >> testNestedEvaluationFromPharo [

	grid context: context.
	context at: 'grid' put: grid exposing: #( nested ).
	self assert: (context eval: 'grid.nested + 1') equals: 43
]

{ #category : 'tests' }
QJSBindingTest >> testPharoCallsAFunctionFromOutside [

	| add |
	add := context eval: '(a, b) => a + b'.
	self assert: (add value: 40 value: 2) equals: 42.
	self assert: ((context eval: '[x => x + 1]') first value: 1) equals: 2
]

{ #category : 'tests' }
QJSBindingTest >> testPragmaNamesTheMethod [

	context at: 'grid' put: grid exposing: #( at:put: at: rowAt: ).
	self assert: (context eval: 'grid.atPut("k", 42); grid.get("k")') equals: 42.
	self assert: (context eval: 'typeof grid.at_put_') equals: 'undefined'.
	self assert: (context eval: 'typeof grid.rowAt_') equals: 'function'
]

{ #category : 'tests' }
QJSBindingTest >> testPharoErrorBecomesJSError [

	context at: 'grid' put: grid exposing: #( fail ).
	self assert: (context eval: 'try { grid.fail } catch (e) { e.message }') equals: 'nope'.
	self
		should: [ context eval: 'grid.fail' ]
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
QJSBindingTest >> testTwoSelectorsWithOneNameAreRefused [

	self
		should: [ context at: 'grid' put: grid exposing: #( name nameAgain ) ]
		raise: QJSError
		withExceptionDo: [ :error | self assert: (error messageText includesSubstring: 'JS name name') ].
	self assert: runtime bindingCount equals: 0
]

{ #category : 'tests' }
QJSBindingTest >> testUnexposedSelectorDoesNotExist [

	context at: 'grid' put: grid exposing: #( name ).
	self assert: (context eval: 'typeof grid.secret') equals: 'undefined'.
	self should: [ context eval: 'grid.secret()' ] raise: QJSError
]

{ #category : 'tests' }
QJSBindingTest >> testUnarySelectorIsAReadOnlyProperty [
	"Read without parentheses; not enumerable, so walking the object calls nothing in Pharo"

	context at: 'grid' put: grid exposing: #( name ).
	self assert: (context eval: 'grid.name') equals: 'Kunden'.
	self assert: (context eval: 'typeof Object.getOwnPropertyDescriptor(grid, "name").get') equals: 'function'.
	self assert: (context eval: 'grid.name = "other"; grid.name') equals: 'Kunden'.
	self assert: (context eval: 'JSON.stringify(grid)') equals: '{}'
]

{ #category : 'tests' }
QJSBindingTest >> testWrongArgumentCountIsAnError [

	context at: 'grid' put: grid exposing: #( rowAt: ).
	self should: [ context eval: 'grid.rowAt_()' ] raise: QJSError
]
