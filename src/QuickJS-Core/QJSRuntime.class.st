"
I am a QuickJS runtime: one heap with its limits. A runtime belongs to one thread; calls go through the same-thread runner, so a running script holds the VM until it ends or its timeout strikes.

Usually you do not hold me yourself: `QJSRuntime evaluate: '6 * 7'` or `QJSRuntime during: [ :context | ... ]` give a fresh runtime and context and release both afterwards. A runtime costs next to nothing; the context is what takes time to build (some 40-70 µs).

If you hold me, #free releases me with all my contexts and values, and may be called again. If you forget it, finalization releases me when I am garbage, in whatever order my contexts go. After an image restart I am stale and signal QJSError instead of reaching into freed memory.
"
Class {
	#name : 'QJSRuntime',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'session'
	],
	#category : 'QuickJS-Core',
	#package : 'QuickJS-Core'
}

{ #category : 'evaluating' }
QJSRuntime class >> during: aBlock [
	"Evaluate aBlock with a fresh context in a fresh runtime and release both afterwards, also on error"

	| runtime |
	runtime := self new.
	^ [ aBlock value: runtime newContext ] ensure: [ runtime free ]
]

{ #category : 'evaluating' }
QJSRuntime class >> evaluate: aString [

	^ self during: [ :context | context eval: aString ]
]

{ #category : 'finalization' }
QJSRuntime class >> finalizeResourceData: aHandle [

	QJSLibrary uniqueInstance runtimeDestroy: aHandle
]

{ #category : 'testing' }
QJSRuntime class >> hasIntl [

	^ QJSLibrary uniqueInstance hasIntl = 1
]

{ #category : 'accessing' }
QJSRuntime class >> liveCount [
	"Runtimes whose C side is not destroyed yet, including those only waiting for finalization"

	^ QJSLibrary uniqueInstance liveOwners
]

{ #category : 'private' }
QJSRuntime >> checkLive [

	self isFromThisSession ifFalse: [ QJSError signal: 'QuickJS runtime is stale after an image restart' ].
	(self library runtimeIsLive: handle) = 1 ifFalse: [ QJSError signal: 'QuickJS runtime is released' ]
]

{ #category : 'releasing' }
QJSRuntime >> free [
	"Release the runtime with all its contexts and values. Harmless when called again"

	self isFromThisSession ifTrue: [ self library runtimeRelease: handle ]
]

{ #category : 'accessing' }
QJSRuntime >> handle [

	^ handle
]

{ #category : 'initialization' }
QJSRuntime >> initialize [

	super initialize.
	handle := self library runtimeNew.
	handle isNull ifTrue: [ QJSError signal: 'QuickJS could not create a runtime' ].
	session := Smalltalk session.
	FFIExternalResourceManager addResource: self data: handle
]

{ #category : 'testing' }
QJSRuntime >> isFromThisSession [

	^ session == Smalltalk session
]

{ #category : 'testing' }
QJSRuntime >> isLive [

	^ self isFromThisSession and: [ (self library runtimeIsLive: handle) = 1 ]
]

{ #category : 'accessing' }
QJSRuntime >> library [

	^ QJSLibrary uniqueInstance
]

{ #category : 'limits' }
QJSRuntime >> memoryLimit: bytes [

	self checkLive.
	self library runtime: handle memoryLimit: bytes
]

{ #category : 'instance creation' }
QJSRuntime >> newContext [

	self checkLive.
	^ QJSContext runtime: self
]

{ #category : 'limits' }
QJSRuntime >> timeoutMilliseconds: milliseconds [

	self checkLive.
	self library runtime: handle timeoutMilliseconds: milliseconds
]
