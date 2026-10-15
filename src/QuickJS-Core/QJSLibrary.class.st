"
I bind libqjsshim, a flat C API over QuickJS. Runtimes, contexts and values cross the boundary as boxes owned by the C side; see qjs_shim.h for how releasing and destroying them works in any order.

Set the library path before the first call, e.g. `QJSLibrary libraryPath: '/path/to/libqjsshim.dylib'`.
"
Class {
	#name : 'QJSLibrary',
	#superclass : 'FFILibrary',
	#classVars : [
		'LibraryPath'
	],
	#category : 'QuickJS-Core',
	#package : 'QuickJS-Core'
}

{ #category : 'accessing' }
QJSLibrary class >> libraryPath [

	^ LibraryPath
]

{ #category : 'accessing' }
QJSLibrary class >> libraryPath: aString [

	LibraryPath := aString
]

{ #category : 'primitives - values' }
QJSLibrary >> bytesFree: bytes [

	^ self ffiCall: #( void qjs_bytes_free #( void * bytes ) )
]

{ #category : 'primitives - values' }
QJSLibrary >> context: context getProperty: aString of: value [

	^ self ffiCall: #( void * qjs_get_property #( void * context , void * value , String aString ) )
]

{ #category : 'primitives - values' }
QJSLibrary >> context: context valueToBool: value [

	^ self ffiCall: #( int qjs_value_to_bool #( void * context , void * value ) )
]

{ #category : 'primitives - values' }
QJSLibrary >> context: context valueToFloat64: value [

	^ self ffiCall: #( double qjs_value_to_float64 #( void * context , void * value ) )
]

{ #category : 'primitives - values' }
QJSLibrary >> context: context valueToInt64: value [

	^ self ffiCall: #( int64 qjs_value_to_int64 #( void * context , void * value ) )
]

{ #category : 'primitives - values' }
QJSLibrary >> context: context valueToJson: value [

	^ self ffiCall: #( void * qjs_value_to_json #( void * context , void * value ) )
]

{ #category : 'primitives - values' }
QJSLibrary >> context: context valueToUtf8: value length: lengthBuffer [

	^ self ffiCall: #( void * qjs_value_to_utf8 #( void * context , void * value , void * lengthBuffer ) )
]

{ #category : 'primitives - values' }
QJSLibrary >> context: context valueType: value [

	^ self ffiCall: #( int qjs_value_type #( void * context , void * value ) )
]

{ #category : 'primitives - contexts' }
QJSLibrary >> contextDestroy: context [

	^ self ffiCall: #( void qjs_context_destroy #( void * context ) )
]

{ #category : 'primitives - contexts' }
QJSLibrary >> contextIsLive: context [

	^ self ffiCall: #( int qjs_context_is_live #( void * context ) )
]

{ #category : 'primitives - contexts' }
QJSLibrary >> contextNew: owner [

	^ self ffiCall: #( void * qjs_context_new #( void * owner ) )
]

{ #category : 'primitives - contexts' }
QJSLibrary >> contextRelease: context [

	^ self ffiCall: #( void qjs_context_release #( void * context ) )
]

{ #category : 'primitives - contexts' }
QJSLibrary >> eval: context source: bytes length: length [

	^ self ffiCall: #( void * qjs_eval #( void * context , void * bytes , size_t length ) )
]

{ #category : 'primitives - contexts' }
QJSLibrary >> exception: context [

	^ self ffiCall: #( void * qjs_exception #( void * context ) )
]

{ #category : 'primitives - library' }
QJSLibrary >> hasIntl [

	^ self ffiCall: #( int qjs_has_intl #( ) )
]

{ #category : 'primitives - library' }
QJSLibrary >> liveOwners [

	^ self ffiCall: #( int64 qjs_live_owners #( ) )
]

{ #category : 'accessing - platform' }
QJSLibrary >> macLibraryName [

	^ LibraryPath ifNil: [ 'libqjsshim.dylib' ]
]

{ #category : 'primitives - runtimes' }
QJSLibrary >> runtime: owner memoryLimit: limit [

	^ self ffiCall: #( void qjs_runtime_set_memory_limit #( void * owner , size_t limit ) )
]

{ #category : 'primitives - runtimes' }
QJSLibrary >> runtime: owner timeoutMilliseconds: milliseconds [

	^ self ffiCall: #( void qjs_runtime_set_timeout_ms #( void * owner , int64 milliseconds ) )
]

{ #category : 'primitives - runtimes' }
QJSLibrary >> runtimeDestroy: owner [

	^ self ffiCall: #( void qjs_runtime_destroy #( void * owner ) )
]

{ #category : 'primitives - runtimes' }
QJSLibrary >> runtimeIsLive: owner [

	^ self ffiCall: #( int qjs_runtime_is_live #( void * owner ) )
]

{ #category : 'primitives - runtimes' }
QJSLibrary >> runtimeNew [

	^ self ffiCall: #( void * qjs_runtime_new #( ) )
]

{ #category : 'primitives - runtimes' }
QJSLibrary >> runtimeRelease: owner [

	^ self ffiCall: #( void qjs_runtime_release #( void * owner ) )
]

{ #category : 'accessing - platform' }
QJSLibrary >> unix64LibraryName [

	^ LibraryPath ifNil: [ 'libqjsshim.so' ]
]

{ #category : 'primitives - values' }
QJSLibrary >> valueFree: value [

	^ self ffiCall: #( void qjs_value_free #( void * value ) )
]

{ #category : 'primitives - values' }
QJSLibrary >> valueIsInt: value [

	^ self ffiCall: #( int qjs_value_is_int #( void * value ) )
]
