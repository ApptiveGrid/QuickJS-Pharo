"Headless test run: loads BaselineOfQuickJS from this checkout, runs the QuickJS tests, prints the result and quits without saving.

	QJS_LIB=/abs/path/libqjsshim.dylib QJS_REPO=/abs/path/QuickJS-Pharo pharo --headless Pharo.image st scripts/run-tests.st

Exit code 0 when all tests pass, 1 otherwise."
| out result env suite |
out := Stdio stdout.
env := Smalltalk os environment.
result := nil.
[
Metacello new
	baseline: 'QuickJS';
	repository: 'tonel://' , (env at: 'QJS_REPO') , '/src';
	load.
(Smalltalk at: #QJSLibrary) libraryPath: (env at: 'QJS_LIB').
out nextPutAll: 'Pharo ' , SystemVersion current printString; lf.
out nextPutAll: 'Intl in lib: ' , (Smalltalk at: #QJSRuntime) hasIntl printString; lf; flush.
suite := TestSuite named: 'QuickJS'.
((TestCase allSubclasses select: [ :each | each package name = 'QuickJS-Tests' ])
	sorted: [ :a :b | a name <= b name ]) do: [ :each | suite addTests: each suite tests ].
result := suite run.
result passed do: [ :t | out nextPutAll: 'ok    '; print: t; lf ].
result skipped do: [ :t | out nextPutAll: 'skip  '; print: t; lf ].
(result failures , result errors) do: [ :t |
	out nextPutAll: 'FAIL  '; print: t; lf.
	[ t runCase ] on: Exception do: [ :e |
		out nextPutAll: '      '; nextPutAll: e description; lf ] ].
out nextPutAll: result printString; lf
] on: Error do: [ :e |
	out nextPutAll: 'SCRIPT ERROR '; nextPutAll: e description; lf.
	(e signalerContext stack first: 12) do: [ :c | out nextPutAll: '  '; print: c; lf ] ].
out flush.
Smalltalk exit: ((result notNil and: [ result hasPassed ]) ifTrue: [ 0 ] ifFalse: [ 1 ])
