"Headless test run: loads BaselineOfQuickJS from this checkout, runs the QuickJS tests, prints the result and quits without saving.

	QJS_LIB=/abs/path/libqjsshim.dylib QJS_REPO=/abs/path/QuickJS-Pharo pharo --headless Pharo.image st scripts/run-tests.st

Exit code 0 when all tests pass, 1 otherwise."
| out result env |
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
result := (Smalltalk at: #QJSContextTest) suite run.
result passed do: [ :t | out nextPutAll: 'ok    '; nextPutAll: t selector; lf ].
result skipped do: [ :t | out nextPutAll: 'skip  '; nextPutAll: t selector; lf ].
(result failures , result errors) do: [ :t |
	out nextPutAll: 'FAIL  '; nextPutAll: t selector; lf.
	[ t runCase ] on: Exception do: [ :e |
		out nextPutAll: '      '; nextPutAll: e description; lf ] ].
out nextPutAll: result printString; lf
] on: Error do: [ :e |
	out nextPutAll: 'SCRIPT ERROR '; nextPutAll: e description; lf.
	(e signalerContext stack first: 12) do: [ :c | out nextPutAll: '  '; print: c; lf ] ].
out flush.
Smalltalk exit: ((result notNil and: [ result hasPassed ]) ifTrue: [ 0 ] ifFalse: [ 1 ])
