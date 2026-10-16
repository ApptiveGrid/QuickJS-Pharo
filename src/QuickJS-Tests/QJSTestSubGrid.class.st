"
A stand-in that inherits #at:put: with its <jsName:> and overrides #at: without one.
"
Class {
	#name : 'QJSTestSubGrid',
	#superclass : 'QJSTestGrid',
	#category : 'QuickJS-Tests',
	#package : 'QuickJS-Tests'
}

{ #category : 'accessing' }
QJSTestSubGrid >> at: aKey [

	^ (super at: aKey) ifNotNil: [ :value | value * 10 ]
]
