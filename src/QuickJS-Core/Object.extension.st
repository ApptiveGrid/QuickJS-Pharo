Extension { #name : 'Object' }

{ #category : '*QuickJS-Core' }
Object >> qjsObject [
	"The object that reaches JS for me: myself. A proxy that hands on what it does not understand answers the object it stands for, so the class of that object decides the selectors and their names in JS"

	^ self
]
