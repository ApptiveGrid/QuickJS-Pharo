"
I am a QuickJS runtime: one heap with its limits. A runtime belongs to one thread; calls go through the same-thread runner, so a running script holds the VM until it ends or its timeout strikes.
"
Class {
	#name : 'QJSRuntime',
	#superclass : 'Object',
	#instVars : [
		'handle'
	],
	#category : 'QuickJS-Core',
	#package : 'QuickJS-Core'
}

{ #category : 'testing' }
QJSRuntime class >> hasIntl [

	^ QJSLibrary uniqueInstance hasIntl = 1
]

{ #category : 'releasing' }
QJSRuntime >> free [

	handle ifNil: [ ^ self ].
	self library runtimeFree: handle.
	handle := nil
]

{ #category : 'accessing' }
QJSRuntime >> handle [

	^ handle
]

{ #category : 'initialization' }
QJSRuntime >> initialize [

	super initialize.
	handle := self library runtimeNew.
	handle isNull ifTrue: [ self error: 'QuickJS could not create a runtime' ]
]

{ #category : 'accessing' }
QJSRuntime >> library [

	^ QJSLibrary uniqueInstance
]

{ #category : 'limits' }
QJSRuntime >> memoryLimit: bytes [

	self library runtime: handle memoryLimit: bytes
]

{ #category : 'instance creation' }
QJSRuntime >> newContext [

	^ QJSContext runtime: self
]

{ #category : 'limits' }
QJSRuntime >> timeoutMilliseconds: milliseconds [

	self library runtime: handle timeoutMilliseconds: milliseconds
]
