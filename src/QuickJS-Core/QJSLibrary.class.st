"
I bind libqjsshim, a flat C API over QuickJS. Every JS value crosses the boundary as a pointer to a heap copy (a handle); my callers free each handle with #context:valueFree:.

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

{ #category : 'primitives' }
QJSLibrary >> context: ctx getProperty: aString of: value [

	^ self ffiCall: #( void * qjs_get_property #( void * ctx , void * value , String aString ) )
]

{ #category : 'primitives' }
QJSLibrary >> context: ctx utf8Free: utf8 [

	^ self ffiCall: #( void qjs_utf8_free #( void * ctx , void * utf8 ) )
]

{ #category : 'primitives' }
QJSLibrary >> context: ctx valueFree: value [

	^ self ffiCall: #( void qjs_value_free #( void * ctx , void * value ) )
]

{ #category : 'primitives' }
QJSLibrary >> context: ctx valueToBool: value [

	^ self ffiCall: #( int qjs_value_to_bool #( void * ctx , void * value ) )
]

{ #category : 'primitives' }
QJSLibrary >> context: ctx valueToFloat64: value [

	^ self ffiCall: #( double qjs_value_to_float64 #( void * ctx , void * value ) )
]

{ #category : 'primitives' }
QJSLibrary >> context: ctx valueToInt64: value [

	^ self ffiCall: #( int64 qjs_value_to_int64 #( void * ctx , void * value ) )
]

{ #category : 'primitives' }
QJSLibrary >> context: ctx valueToJson: value [

	^ self ffiCall: #( void * qjs_value_to_json #( void * ctx , void * value ) )
]

{ #category : 'primitives' }
QJSLibrary >> context: ctx valueToUtf8: value length: lengthBuffer [

	^ self ffiCall: #( void * qjs_value_to_utf8 #( void * ctx , void * value , void * lengthBuffer ) )
]

{ #category : 'primitives' }
QJSLibrary >> context: ctx valueType: value [

	^ self ffiCall: #( int qjs_value_type #( void * ctx , void * value ) )
]

{ #category : 'primitives' }
QJSLibrary >> contextFree: ctx [

	^ self ffiCall: #( void qjs_context_free #( void * ctx ) )
]

{ #category : 'primitives' }
QJSLibrary >> contextNew: rt [

	^ self ffiCall: #( void * qjs_context_new #( void * rt ) )
]

{ #category : 'primitives' }
QJSLibrary >> eval: ctx source: bytes length: length [

	^ self ffiCall: #( void * qjs_eval #( void * ctx , void * bytes , size_t length ) )
]

{ #category : 'primitives' }
QJSLibrary >> exception: ctx [

	^ self ffiCall: #( void * qjs_exception #( void * ctx ) )
]

{ #category : 'primitives' }
QJSLibrary >> hasIntl [

	^ self ffiCall: #( int qjs_has_intl #( ) )
]

{ #category : 'accessing - platform' }
QJSLibrary >> macLibraryName [

	^ LibraryPath ifNil: [ 'libqjsshim.dylib' ]
]

{ #category : 'primitives' }
QJSLibrary >> runtime: rt memoryLimit: limit [

	^ self ffiCall: #( void qjs_runtime_set_memory_limit #( void * rt , size_t limit ) )
]

{ #category : 'primitives' }
QJSLibrary >> runtime: rt timeoutMilliseconds: milliseconds [

	^ self ffiCall: #( void qjs_runtime_set_timeout_ms #( void * rt , int64 milliseconds ) )
]

{ #category : 'primitives' }
QJSLibrary >> runtimeFree: rt [

	^ self ffiCall: #( void qjs_runtime_free #( void * rt ) )
]

{ #category : 'primitives' }
QJSLibrary >> runtimeNew [

	^ self ffiCall: #( void * qjs_runtime_new #( ) )
]

{ #category : 'accessing - platform' }
QJSLibrary >> unix64LibraryName [

	^ LibraryPath ifNil: [ 'libqjsshim.so' ]
]

{ #category : 'primitives' }
QJSLibrary >> valueIsInt: value [

	^ self ffiCall: #( int qjs_value_is_int #( void * value ) )
]
