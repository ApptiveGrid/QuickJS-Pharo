# QuickJS-Pharo

A binding to the [quickjs-ng](https://github.com/quickjs-ng/quickjs) runtime for Pharo: evaluate JavaScript inside the image and get Pharo values back.

```smalltalk
| runtime context |
QJSLibrary libraryPath: '/path/to/libqjsshim.dylib'.
runtime := QJSRuntime new.
runtime timeoutMilliseconds: 1000.
context := runtime newContext.
context eval: '[1, 2, 3].map(x => x * x)'.	"#(1 4 9)"
context free.
runtime free
```

## How it fits together

- **`shim/`** holds a small C library, `libqjsshim`, linked together with QuickJS. QuickJS passes `JSValue` by value and keeps many helpers `static inline`, so UFFI cannot call it directly. The shim gives Pharo a flat API in which every JS value is a pointer to a heap copy (a handle), and all other values are integers, doubles or UTF-8 bytes. Time and memory limits are checked in C.
- **`src/`** holds the Pharo packages (Tonel). `QuickJS-Core` contains `QJSLibrary` (UFFI), `QJSRuntime`, `QJSContext` and `QJSError`; `QuickJS-Tests` contains the tests.
- **`vendor/`** holds QuickJS as git submodules, both pinned:
  - `quickjs-ng` at `v0.17.0`, the default.
  - `quickjs-bellard` on `master`, which since 2026-10-10 carries experimental `Intl` and `Temporal` support.

Results are converted as follows:
- `undefined` and `null` become `nil`.
- Numbers become `Integer` or `Float`; integral values up to 2^53 come back as `Integer`.
- Strings become `String`.
- Arrays and objects travel through JSON and come back as `Array` and `Dictionary`.
- A JS exception is signalled as `QJSError`, carrying the JS message and stack.

Not there yet: calls from JS back into Pharo, Pharo objects exposed to JS, finalization of handles.

## Building

```bash
git submodule update --init
cd shim
make test                   # quickjs-ng, writes build/ng/libqjsshim.(dylib|so)
make VARIANT=bellard test   # Bellard's QuickJS with Intl, writes build/bellard/
```

`make test` also builds and runs `test_shim`, which exercises the shim from C without Pharo.

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
