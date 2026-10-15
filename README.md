# QuickJS-Pharo

A binding to the [quickjs-ng](https://github.com/quickjs-ng/quickjs) runtime for Pharo: evaluate JavaScript inside the image and get Pharo values back.

```smalltalk
QJSLibrary libraryPath: '/path/to/libqjsshim.dylib'.

QJSRuntime evaluate: '[1, 2, 3].map(x => x * x)'.	"#(1 4 9)"

QJSRuntime during: [ :context |
	context runtime timeoutMilliseconds: 1000.
	context eval: 'function sq(x) { return x * x }'.
	context eval: 'sq(12)' ]	"144"
```

`evaluate:` and `during:` create a fresh runtime and context and release both afterwards, also on error. A fresh runtime with its context costs some 40 µs (quickjs-ng) to 70 µs (Bellard with Intl); an `eval:` in an existing context some 2 µs.

## Pharo objects in JS

```smalltalk
QJSRuntime during: [ :context |
	context at: 'grid' put: aGrid exposing: #(name rowAt:).
	context eval: 'grid.name() + " has " + grid.rowAt_(1)' ]
```

Only the selectors you list exist in JS, named PharoJS-style: `#rowAt:` becomes `rowAt_`, and `#at:put:` becomes `at_put_`. To decide what JS may do with objects that come back from those calls, give a table of classes instead:

```smalltalk
context at: 'grid' put: aGrid exposing: {
	AGGrid -> #(name rows).
	AGRow -> #(id name) }.
context eval: 'grid.rows().map(r => r.name())'
```

The table applies to everything reachable through the binding. An object gets the selectors of the nearest class in its hierarchy that has an entry. Without an entry it reaches JS opaque: JS can hold it and pass it back, but call nothing on it. Values cross as values in both directions: `nil`, Booleans, numbers, strings, sequenceable collections and dictionaries. A binding that comes back from JS is the Pharo object itself. An error in Pharo becomes a JS `Error` that JS can catch. `context at: 'n' put: 42` sets a plain value.

A call from JS into Pharo costs some 13 µs. The runtime keeps the objects handed to JS until JS lets go of them; it forgets them after the next evaluation.

## Lifetime

You can also hold a runtime and contexts yourself. `free` releases them at once and may be called any number of times, in any order; releasing a runtime releases its contexts too. Without `free`, finalization releases them when they become garbage. After an image restart they are stale and signal `QJSError` instead of reaching into freed memory.

## How it fits together

- **`shim/`** holds a small C library, `libqjsshim`, linked together with QuickJS. QuickJS passes `JSValue` by value and keeps many helpers `static inline`, so UFFI cannot call it directly. The shim gives Pharo a flat API of boxes for runtimes, contexts and values; all other values are integers, doubles or UTF-8 bytes. The runtime box keeps track of every context and value box, so they can be released and destroyed in any order (see `qjs_shim.h`). Time and memory limits are checked in C.
- **`src/`** holds the Pharo packages (Tonel). `QuickJS-Core` contains `QJSLibrary` (UFFI), `QJSRuntime`, `QJSContext`, `QJSBinding` and `QJSError`; `QuickJS-Tests` contains the tests.
- **`vendor/`** holds QuickJS as git submodules, both pinned:
  - `quickjs-ng` at `v0.17.0`, the default.
  - `quickjs-bellard` on `master`, which since 2026-10-10 carries experimental `Intl` and `Temporal` support.

Results are converted as follows:
- `undefined` and `null` become `nil`.
- Numbers become `Integer` or `Float`; integral values up to 2^53 come back as `Integer`.
- Strings become `String`.
- Arrays and plain objects come back as `Array` and `Dictionary`, element by element.
- A binding comes back as the Pharo object it stands for.
- A JS exception is signalled as `QJSError`, carrying the JS message and stack.

Not there yet: promises (the job queue), and a build for Linux in CI.

## Building

```bash
git submodule update --init
cd shim
make test                   # quickjs-ng, writes build/ng/libqjsshim.(dylib|so)
make VARIANT=bellard test   # Bellard's QuickJS with Intl, writes build/bellard/
```

`make test` also builds and runs `test_shim`, which exercises the shim from C without Pharo. `make asan` (with or without `VARIANT=bellard`) runs the same test under AddressSanitizer.

## Loading and testing in Pharo

```smalltalk
Metacello new
	baseline: 'QuickJS';
	repository: 'github://ApptiveGrid/QuickJS-Pharo:main/src';
	load.
QJSLibrary libraryPath: '/path/to/libqjsshim.dylib'.
```

To run the tests headless from a checkout:

```bash
QJS_LIB=$PWD/build/ng/libqjsshim.dylib QJS_REPO=$PWD pharo --headless Pharo.image st scripts/run-tests.st
```

Tested with Pharo 13.1 on macOS arm64.
