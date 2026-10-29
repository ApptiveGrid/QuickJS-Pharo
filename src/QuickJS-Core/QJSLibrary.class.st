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
QJSLibrary >> context: context getProperty: name of: value [
	"name is a NUL-terminated UTF-8 ByteArray"

	^ self ffiCall: #( void * qjs_get_property #( void * context , void * value , void * name ) )
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

{ #category : 'primitives - functions' }
QJSLibrary >> context: context call: function argc: argc argv: argv [

	^ self ffiCall: #( void * qjs_call #( void * context , void * function , int argc , void * argv ) )
]

{ #category : 'primitives - functions' }
QJSLibrary >> context: context dupValue: value [

	^ self ffiCall: #( void * qjs_value_dup #( void * context , void * value ) )
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
QJSLibrary >> runtimeDeadlinePassed: owner [

	^ self ffiCall: #( int qjs_runtime_deadline_passed #( void * owner ) )
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

{ #category : 'primitives - structure' }
QJSLibrary >> context: context arrayLength: array [

	^ self ffiCall: #( int64 qjs_array_length #( void * context , void * array ) )
]

{ #category : 'primitives - bindings' }
QJSLibrary >> context: context bindingId: value [

	^ self ffiCall: #( int64 qjs_binding_id #( void * context , void * value ) )
]

{ #category : 'primitives - bindings' }
QJSLibrary >> context: context define: binding name: name id: id selector: selector [

	^ self ffiCall: #( int qjs_binding_define #( void * context , void * binding , String name , int64 id , String selector ) )
]

{ #category : 'primitives - bindings' }
QJSLibrary >> context: context defineGetter: binding name: name id: id selector: selector [

	^ self ffiCall: #( int qjs_binding_define_getter #( void * context , void * binding , String name , int64 id , String selector ) )
]

{ #category : 'primitives - structure' }
QJSLibrary >> context: context getIndex: index of: array [

	^ self ffiCall: #( void * qjs_get_index #( void * context , void * array , uint32 index ) )
]

{ #category : 'primitives - constructors' }
QJSLibrary >> context: context newBinding: id [

	^ self ffiCall: #( void * qjs_new_binding #( void * context , int64 id ) )
]

{ #category : 'primitives - constructors' }
QJSLibrary >> context: context newBool: anInteger [

	^ self ffiCall: #( void * qjs_new_bool #( void * context , int anInteger ) )
]

{ #category : 'primitives - constructors' }
QJSLibrary >> context: context newFloat64: aFloat [

	^ self ffiCall: #( void * qjs_new_float64 #( void * context , double aFloat ) )
]

{ #category : 'primitives - constructors' }
QJSLibrary >> context: context newInt64: anInteger [

	^ self ffiCall: #( void * qjs_new_int64 #( void * context , int64 anInteger ) )
]

{ #category : 'primitives - constructors' }
QJSLibrary >> context: context newString: bytes length: length [

	^ self ffiCall: #( void * qjs_new_string #( void * context , void * bytes , size_t length ) )
]

{ #category : 'primitives - structure' }
QJSLibrary >> context: context objectKeys: object [

	^ self ffiCall: #( void * qjs_object_keys #( void * context , void * object ) )
]

{ #category : 'primitives - structure' }
QJSLibrary >> context: context setGlobal: name to: value [
	"name is a NUL-terminated UTF-8 ByteArray"

	^ self ffiCall: #( int qjs_set_global #( void * context , void * name , void * value ) )
]

{ #category : 'primitives - structure' }
QJSLibrary >> context: context setIndex: index of: array to: value [

	^ self ffiCall: #( int qjs_set_index #( void * context , void * array , uint32 index , void * value ) )
]

{ #category : 'primitives - structure' }
QJSLibrary >> context: context setProperty: name of: object to: value [
	"name is a NUL-terminated UTF-8 ByteArray"

	^ self ffiCall: #( int qjs_set_property #( void * context , void * object , void * name , void * value ) )
]

{ #category : 'primitives - constructors' }
QJSLibrary >> newArray: context [

	^ self ffiCall: #( void * qjs_new_array #( void * context ) )
]

{ #category : 'primitives - constructors' }
QJSLibrary >> newNull: context [

	^ self ffiCall: #( void * qjs_new_null #( void * context ) )
]

{ #category : 'primitives - constructors' }
QJSLibrary >> newObject: context [

	^ self ffiCall: #( void * qjs_new_object #( void * context ) )
]

{ #category : 'primitives - bindings' }
QJSLibrary >> runtime: owner releasedBindings: buffer capacity: capacity [

	^ self ffiCall: #( int qjs_released_bindings #( void * owner , void * buffer , int capacity ) )
]

{ #category : 'primitives - bindings' }
QJSLibrary >> setCallback: callback [

	^ self ffiCall: #( void qjs_set_callback #( FFICallback callback ) )
]
