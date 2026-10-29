"
I check what a script can reach: the language and nothing of the host. None of the modules of quickjs-libc (std, os, bjson) and none of its helpers (print, console, scriptArgs), no way to load a module, no blocking, no recursion beyond the stack limit.

The globals are checked against a fixed list, the union of what quickjs-ng and Bellard's QuickJS bring. A QuickJS that adds a global fails here, so it is looked at before its pin moves.
"
Class {
	#name : 'QJSSandboxTest',
	#superclass : 'TestCase',
	#instVars : [
		'runtime',
		'context'
	],
	#category : 'QuickJS-Tests',
	#package : 'QuickJS-Tests'
}

{ #category : 'accessing' }
QJSSandboxTest >> allowedGlobals [
	"ECMAScript and InternalError; quickjs-ng adds AsyncDisposableStack, DisposableStack, SuppressedError, DOMException, atob, btoa, performance and queueMicrotask, Bellard's QuickJS Intl and Temporal. Taken 2026-10-29 from quickjs-ng 0.17.0 and Bellard 84e723f"

	^ #( 'AggregateError' 'Array' 'ArrayBuffer' 'AsyncDisposableStack' 'Atomics' 'BigInt' 'BigInt64Array'
	     'BigUint64Array' 'Boolean' 'DOMException' 'DataView' 'Date' 'DisposableStack' 'Error' 'EvalError'
	     'FinalizationRegistry' 'Float16Array' 'Float32Array' 'Float64Array' 'Function' 'Infinity' 'Int16Array'
	     'Int32Array' 'Int8Array' 'InternalError' 'Intl' 'Iterator' 'JSON' 'Map' 'Math' 'NaN' 'Number' 'Object'
	     'Promise' 'Proxy' 'RangeError' 'ReferenceError' 'Reflect' 'RegExp' 'Set' 'SharedArrayBuffer' 'String'
	     'SuppressedError' 'Symbol' 'Symbol(Symbol.toStringTag)' 'SyntaxError' 'Temporal' 'TypeError' 'URIError'
	     'Uint16Array' 'Uint32Array' 'Uint8Array' 'Uint8ClampedArray' 'WeakMap' 'WeakRef' 'WeakSet' 'atob' 'btoa'
	     'decodeURI' 'decodeURIComponent' 'encodeURI' 'encodeURIComponent' 'escape' 'eval' 'globalThis' 'isFinite'
	     'isNaN' 'parseFloat' 'parseInt' 'performance' 'queueMicrotask' 'undefined' 'unescape' ) asSet
]

{ #category : 'running' }
QJSSandboxTest >> setUp [

	super setUp.
	runtime := QJSRuntime new.
	context := runtime newContext
]

{ #category : 'running' }
QJSSandboxTest >> tearDown [

	context free.
	runtime free.
	super tearDown
]

{ #category : 'tests' }
QJSSandboxTest >> testAtomicsWaitCannotBlock [

	self
		should: [ context eval: 'Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000)' ]
		raise: QJSError
		withExceptionDo: [ :error | self assert: (error messageText includesSubstring: 'cannot block') ]
]

{ #category : 'tests' }
QJSSandboxTest >> testDeepRecursionEndsAtTheStackLimit [
	"quickjs-ng answers a RangeError, Bellard's QuickJS an InternalError"

	self
		should: [ context eval: 'function f() { return f() + 1 } f()' ]
		raise: QJSError
		withExceptionDo: [ :error | self assert: (error messageText includesSubstring: 'stack') ]
]

{ #category : 'tests' }
QJSSandboxTest >> testDynamicImportLoadsNothing [
	"import() only queues a job, and nothing runs the job queue; there is no module loader either"

	context eval: 'globalThis.loaded = "no"; import("std").then(() => loaded = "yes", e => loaded = String(e))'.
	self assert: (context eval: 'loaded') equals: 'no'
]

{ #category : 'tests' }
QJSSandboxTest >> testGlobalsAreTheLanguageOnly [

	| globals |
	globals := context eval: 'Reflect.ownKeys(globalThis).map(String)'.
	self assert: (globals reject: [ :each | self allowedGlobals includes: each ]) equals: #(  )
]

{ #category : 'tests' }
QJSSandboxTest >> testNewFunctionSeesTheSameGlobals [

	self
		assert: (context eval: 'new Function("return [typeof std, typeof os, typeof print]")()')
		equals: #( 'undefined' 'undefined' 'undefined' )
]

{ #category : 'tests' }
QJSSandboxTest >> testNoHostModulesOrHelpers [

	| defined |
	defined := #( 'std' 'os' 'bjson' 'print' 'console' 'scriptArgs' '__loadScript' 'require' 'process' 'setTimeout'
	              'fetch' 'WebAssembly' ) reject: [ :each | (context eval: 'typeof ' , each) = 'undefined' ].
	self assert: defined equals: #(  )
]

{ #category : 'tests' }
QJSSandboxTest >> testStaticImportIsASyntaxError [
	"A script is evaluated as a script, never as a module"

	#( 'import * as std from "std"' 'import.meta' ) do: [ :each |
		self
			should: [ context eval: each ]
			raise: QJSError
			withExceptionDo: [ :error | self assert: (error messageText includesSubstring: 'SyntaxError') ] ]
]
