Class {
	#name : 'QJSContextTest',
	#superclass : 'TestCase',
	#instVars : [
		'runtime',
		'context'
	],
	#category : 'QuickJS-Tests',
	#package : 'QuickJS-Tests'
}

{ #category : 'running' }
QJSContextTest >> setUp [

	super setUp.
	runtime := QJSRuntime new.
	context := runtime newContext
]

{ #category : 'running' }
QJSContextTest >> tearDown [

	context free.
	runtime free.
	super tearDown
]

{ #category : 'tests' }
QJSContextTest >> testArrayAndObject [

	self
		assert: (context eval: '[1, "a", {b: true}, null]')
		equals: { 1. 'a'. (Dictionary with: 'b' -> true). nil }
]

{ #category : 'tests' }
QJSContextTest >> testBoolean [

	self assert: (context eval: '3 > 2').
	self deny: (context eval: '3 < 2')
]

{ #category : 'tests' }
QJSContextTest >> testCyclicResultEndsWithError [

	self
		should: [ context eval: 'const o = {}; o.self = o; o' ]
		raise: QJSError
		withExceptionDo: [ :error | self assert: (error messageText includesSubstring: 'nests deeper') ]
]

{ #category : 'tests' }
QJSContextTest >> testEndlessLoopIsInterrupted [

	runtime timeoutMilliseconds: 200.
	self
		should: [ context eval: 'while (true) {}' ]
		raise: QJSError
		withExceptionDo: [ :error | self assert: error messageText equals: 'InternalError: interrupted' ].
	runtime timeoutMilliseconds: 0.
	self assert: (context eval: '1 + 1') equals: 2
]

{ #category : 'tests' }
QJSContextTest >> testFloat [

	self assert: (context eval: '0.1 + 0.2') equals: 0.1 + 0.2
]

{ #category : 'tests' }
QJSContextTest >> testFunctionResult [

	self assert: (context eval: '[1, 2, 3].map(x => x * x).reduce((a, b) => a + b)') equals: 14
]

{ #category : 'tests' }
QJSContextTest >> testGetterInTheResultRunsWithinTheDeadline [
	"Reading the result runs JS too; without the deadline this test hangs the VM"

	runtime timeoutMilliseconds: 200.
	self
		should: [ context eval: '({ get a() { while (true) {} } })' ]
		raise: QJSError
		withExceptionDo: [ :error | self assert: error messageText equals: 'InternalError: interrupted' ]
]

{ #category : 'tests' }
QJSContextTest >> testGlobalsSurviveBetweenEvals [

	context eval: 'var counter = 40'.
	self assert: (context eval: 'counter + 2') equals: 42
]

{ #category : 'tests' }
QJSContextTest >> testIntlDateTimeFormatWithTimeZone [

	QJSRuntime hasIntl ifFalse: [ ^ self skip: 'libqjsshim built without Intl' ].
	self
		assert: (context eval:
				 'new Intl.DateTimeFormat("de-DE", {timeZone: "Europe/Berlin", dateStyle: "short", timeStyle: "short"}).format(new Date(Date.UTC(2026, 9, 15, 12, 0)))')
		equals: '15.10.26, 14:00'
]

{ #category : 'tests' }
QJSContextTest >> testIntegralNumberIsInteger [

	self assert: (context eval: '2 ** 40') equals: 1099511627776.
	self assert: (context eval: '6 / 2') isInteger
]

{ #category : 'tests' }
QJSContextTest >> testManyEvalsReleaseTheirValues [

	1 to: 1000 do: [ :i | context eval: '"x".repeat(1000) + ' , i printString ].
	self assert: (context eval: '"done"') equals: 'done'
]

{ #category : 'tests' }
QJSContextTest >> testMemoryHogEndsWithError [

	runtime memoryLimit: 8 * 1024 * 1024.
	self
		should: [ context eval: 'let a = []; while (true) a.push(new Array(1000).fill(1))' ]
		raise: QJSError
]

{ #category : 'tests' }
QJSContextTest >> testNestedResultBelowTheLimitIsRead [

	| value |
	value := context eval: 'let a = 1; for (let i = 0; i < 100; i++) a = [a]; a'.
	100 timesRepeat: [ value := value first ].
	self assert: value equals: 1
]

{ #category : 'tests' }
QJSContextTest >> testNullAndUndefinedAreNil [

	self assert: (context eval: 'null') isNil.
	self assert: (context eval: 'undefined') isNil
]

{ #category : 'tests' }
QJSContextTest >> testOnePlusOne [

	self assert: (context eval: '1 + 1') equals: 2
]

{ #category : 'tests' }
QJSContextTest >> testReplacedObjectKeysDoesNotReadTheResult [

	runtime timeoutMilliseconds: 200.
	self
		assert: (context eval: 'Object.keys = () => { while (true) {} }; ({a: 1})')
		equals: (Dictionary with: 'a' -> 1)
]

{ #category : 'tests' }
QJSContextTest >> testSharedPartsInTheResultStopAtTheDeadline [
	"2^40 elements from a few hundred bytes of JS. Reading arrays runs no JS, so only asking for the deadline in between ends it"

	runtime timeoutMilliseconds: 200.
	self
		should: [ context eval: 'let a = [1]; for (let i = 0; i < 40; i++) a = [a, a]; a' ]
		raise: QJSError
		withExceptionDo: [ :error | self assert: error messageText equals: 'InternalError: interrupted' ]
]

{ #category : 'tests' }
QJSContextTest >> testStringWithUmlaut [

	self assert: (context eval: '"Grüße, " + "Pharo"') equals: 'Grüße, Pharo'
]

{ #category : 'tests' }
QJSContextTest >> testSyntaxErrorSignalsError [

	self should: [ context eval: '1 +' ] raise: QJSError
]

{ #category : 'tests' }
QJSContextTest >> testThrowSignalsErrorWithStack [

	self
		should: [ context eval: 'function f() { throw new TypeError("boom") }; f()' ]
		raise: QJSError
		withExceptionDo: [ :error |
			self assert: error messageText equals: 'TypeError: boom'.
			self assert: (error jsStack includesSubstring: 'at f') ]
]

{ #category : 'tests' }
QJSContextTest >> testToStringOfAThrownErrorRunsWithinTheDeadline [

	runtime timeoutMilliseconds: 200.
	self
		should: [ context eval: 'Error.prototype.toString = function () { while (true) {} }; null.x' ]
		raise: QJSError
]
