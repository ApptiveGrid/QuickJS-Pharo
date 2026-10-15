"
I check that runtimes and contexts can be released explicitly in any order, any number of times, or not at all and left to finalization, without crashing the image.
"
Class {
	#name : 'QJSLifecycleTest',
	#superclass : 'TestCase',
	#category : 'QuickJS-Tests',
	#package : 'QuickJS-Tests'
}

{ #category : 'private' }
QJSLifecycleTest >> settledLiveCount [
	"Finalizers run in their own process after a garbage collection. Collect until the count stops moving, so runtimes dropped by earlier tests do not shift it"

	| previous current |
	current := QJSRuntime liveCount.
	50 timesRepeat: [
		previous := current.
		Smalltalk garbageCollect.
		(Delay forMilliseconds: 20) wait.
		current := QJSRuntime liveCount.
		current = previous ifTrue: [ ^ current ] ].
	^ current
]

{ #category : 'tests' }
QJSLifecycleTest >> testDuringReleasesAfterError [

	| context |
	self
		should: [
			QJSRuntime during: [ :each |
				context := each.
				each eval: 'throw new Error("inside")' ] ]
		raise: QJSError.
	self deny: context isLive.
	self deny: context runtime isLive
]

{ #category : 'tests' }
QJSLifecycleTest >> testDuringReleasesRuntimeAndContext [

	| context result |
	result := QJSRuntime during: [ :each |
		          context := each.
		          each eval: 'var a = 20'.
		          each eval: 'a * 2 + 2' ].
	self assert: result equals: 42.
	self deny: context isLive.
	self deny: context runtime isLive
]

{ #category : 'tests' }
QJSLifecycleTest >> testEvalOnReleasedContextSignalsError [

	| runtime context |
	runtime := QJSRuntime new.
	context := runtime newContext.
	context free.
	self should: [ context eval: '1' ] raise: QJSError.
	runtime free
]

{ #category : 'tests' }
QJSLifecycleTest >> testEvaluate [

	self assert: (QJSRuntime evaluate: '6 * 7') equals: 42
]

{ #category : 'tests' }
QJSLifecycleTest >> testFinalizationInAnyOrder [

	| baseline runtime context |
	baseline := self settledLiveCount.
	1 to: 60 do: [ :i |
		runtime := QJSRuntime new.
		context := runtime newContext.
		context eval: '"x".repeat(1000) + ' , i printString.
		i \\ 3 = 1 ifTrue: [ runtime free ].
		i \\ 3 = 2 ifTrue: [ context free ] ].
	self assert: QJSRuntime liveCount >= (baseline + 60).
	runtime := context := nil.
	self assert: self settledLiveCount equals: baseline
]

{ #category : 'tests' }
QJSLifecycleTest >> testFreeTwiceIsHarmless [

	| runtime context |
	runtime := QJSRuntime new.
	context := runtime newContext.
	context free.
	context free.
	runtime free.
	runtime free.
	self deny: runtime isLive
]

{ #category : 'tests' }
QJSLifecycleTest >> testNewContextOnReleasedRuntimeSignalsError [

	| runtime |
	runtime := QJSRuntime new.
	runtime free.
	self should: [ runtime newContext ] raise: QJSError
]

{ #category : 'tests' }
QJSLifecycleTest >> testRuntimeFreedBeforeContext [

	| runtime context |
	runtime := QJSRuntime new.
	context := runtime newContext.
	context eval: 'var kept = {list: [1, 2, 3]}'.
	runtime free.
	self deny: context isLive.
	self should: [ context eval: 'kept' ] raise: QJSError.
	context free
]

{ #category : 'tests' }
QJSLifecycleTest >> testStaleAfterImageRestart [
	"An image restart is simulated by a foreign session"

	| runtime context |
	runtime := QJSRuntime new.
	context := runtime newContext.
	context instVarNamed: 'session' put: Object new.
	runtime instVarNamed: 'session' put: Object new.
	self should: [ context eval: '1' ] raise: QJSError.
	self should: [ runtime newContext ] raise: QJSError.
	context free.
	runtime free.
	context instVarNamed: 'session' put: Smalltalk session.
	runtime instVarNamed: 'session' put: Smalltalk session.
	self assert: (context eval: '1 + 1') equals: 2.
	runtime free
]
