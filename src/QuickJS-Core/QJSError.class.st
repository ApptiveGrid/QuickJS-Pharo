"
I am a JS exception thrown inside QuickJS. My messageText is the JS toString of the thrown value (e.g. 'TypeError: boom'), jsStack the JS stack trace if it had one.
"
Class {
	#name : 'QJSError',
	#superclass : 'Error',
	#instVars : [
		'jsStack'
	],
	#category : 'QuickJS-Core',
	#package : 'QuickJS-Core'
}

{ #category : 'accessing' }
QJSError >> jsStack [

	^ jsStack
]

{ #category : 'accessing' }
QJSError >> jsStack: aString [

	jsStack := aString
]
