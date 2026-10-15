Class {
	#name : 'BaselineOfQuickJS',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfQuickJS',
	#package : 'BaselineOfQuickJS'
}

{ #category : 'baselines' }
BaselineOfQuickJS >> baseline: spec [

	<baseline>
	spec for: #common do: [
		spec
			package: 'QuickJS-Core';
			package: 'QuickJS-Tests' with: [ spec requires: #( 'QuickJS-Core' ) ].
		spec
			group: 'Core' with: #( 'QuickJS-Core' );
			group: 'Tests' with: #( 'QuickJS-Tests' );
			group: 'default' with: #( 'Core' 'Tests' ) ]
]
