/* Exercises the shim the way Pharo will: only through boxes. */
#include <stdio.h>
#include <string.h>
#include "qjs_shim.h"

static int failures = 0;

static void check(const char *name, int ok)
{
    printf("%s %s\n", ok ? "ok  " : "FAIL", name);
    if (!ok)
        failures++;
}

static QJSValueBox *eval(QJSContextBox *ctx, const char *source)
{
    return qjs_eval(ctx, source, strlen(source));
}

static int string_equals(QJSContextBox *ctx, QJSValueBox *value, const char *expected)
{
    size_t length = 0;
    char *utf8 = qjs_value_to_utf8(ctx, value, &length);
    int ok = utf8 && length == strlen(expected) && memcmp(utf8, expected, length) == 0;
    if (!ok)
        printf("     got: %.*s\n", (int)length, utf8 ? utf8 : "(null)");
    qjs_bytes_free(utf8);
    return ok;
}

static void test_values(void)
{
    QJSOwner *rt = qjs_runtime_new();
    QJSContextBox *ctx = qjs_context_new(rt);
    QJSValueBox *v, *e, *json;

    v = eval(ctx, "1 + 1");
    check("1 + 1 is the int 2", qjs_value_type(ctx, v) == QJS_TYPE_NUMBER
          && qjs_value_is_int(v) && qjs_value_to_int64(ctx, v) == 2);
    qjs_value_free(v);

    v = eval(ctx, "0.1 + 0.2");
    check("0.1 + 0.2 is a float", !qjs_value_is_int(v)
          && qjs_value_to_float64(ctx, v) == 0.1 + 0.2);
    qjs_value_free(v);

    v = eval(ctx, "'Grüße, ' + 'Pharo'");
    check("string with umlaut", qjs_value_type(ctx, v) == QJS_TYPE_STRING
          && string_equals(ctx, v, "Grüße, Pharo"));
    qjs_value_free(v);

    v = eval(ctx, "[1, 'a', {b: true}, null]");
    check("array type", qjs_value_type(ctx, v) == QJS_TYPE_ARRAY);
    json = qjs_value_to_json(ctx, v);
    check("array as JSON", string_equals(ctx, json, "[1,\"a\",{\"b\":true},null]"));
    qjs_value_free(json);
    qjs_value_free(v);

    qjs_value_free(eval(ctx, "var counter = 40"));
    v = eval(ctx, "counter + 2");
    check("globals survive between evals", qjs_value_to_int64(ctx, v) == 42);
    qjs_value_free(v);

    v = eval(ctx, "throw new TypeError('boom')");
    check("throw gives an exception box", qjs_value_type(ctx, v) == QJS_TYPE_EXCEPTION);
    qjs_value_free(v);
    e = qjs_exception(ctx);
    check("exception message", string_equals(ctx, e, "TypeError: boom"));
    qjs_value_free(e);

    v = eval(ctx, "1 +");
    check("syntax error is an exception", qjs_value_type(ctx, v) == QJS_TYPE_EXCEPTION);
    qjs_value_free(v);
    qjs_value_free(qjs_exception(ctx));

    qjs_runtime_set_timeout_ms(rt, 200);
    v = eval(ctx, "while (true) {}");
    check("endless loop is interrupted", qjs_value_type(ctx, v) == QJS_TYPE_EXCEPTION);
    qjs_value_free(v);
    e = qjs_exception(ctx);
    check("interrupt message", string_equals(ctx, e, "InternalError: interrupted"));
    qjs_value_free(e);
    qjs_runtime_set_timeout_ms(rt, 0);

    if (qjs_has_intl()) {
        v = eval(ctx, "new Intl.DateTimeFormat('de-DE', {timeZone: 'Europe/Berlin',"
                      " dateStyle: 'short', timeStyle: 'short'}).format(new Date(Date.UTC(2026, 9, 15, 12, 0)))");
        check("Intl.DateTimeFormat with timeZone", qjs_value_type(ctx, v) == QJS_TYPE_STRING
              && string_equals(ctx, v, "15.10.26, 14:00"));
        qjs_value_free(v);
    }

    qjs_context_destroy(ctx);
    qjs_runtime_destroy(rt);

    rt = qjs_runtime_new();
    ctx = qjs_context_new(rt);
    qjs_runtime_set_memory_limit(rt, 8 * 1024 * 1024);
    v = eval(ctx, "let a = []; while (true) a.push(new Array(1000).fill(1))");
    check("memory hog ends with an exception", qjs_value_type(ctx, v) == QJS_TYPE_EXCEPTION);
    qjs_value_free(v);
    qjs_value_free(qjs_exception(ctx));
    qjs_context_destroy(ctx);
    qjs_runtime_destroy(rt);
}

/* What a finalizer may do: destroy boxes in any order, after or without
   an explicit release, and release anything any number of times. */
static void test_any_order(void)
{
    QJSOwner *rt;
    QJSContextBox *ctx, *other;
    QJSValueBox *v;

    rt = qjs_runtime_new();
    ctx = qjs_context_new(rt);
    v = eval(ctx, "({kept: [1, 2, 3]})");
    qjs_runtime_release(rt);
    check("released runtime is not live", !qjs_runtime_is_live(rt));
    check("its context is released too", !qjs_context_is_live(ctx));
    check("its value answers released", qjs_value_type(ctx, v) == QJS_TYPE_RELEASED);
    check("eval on a released context answers NULL", eval(ctx, "1") == NULL);
    check("no context from a released runtime", qjs_context_new(rt) == NULL);
    qjs_value_free(v);
    qjs_context_release(ctx);
    qjs_runtime_release(rt);
    qjs_context_destroy(ctx);
    check("owner lives until the last box is destroyed", qjs_live_owners() == 1);
    qjs_runtime_destroy(rt);
    check("runtime first, then the rest", qjs_live_owners() == 0);

    rt = qjs_runtime_new();
    ctx = qjs_context_new(rt);
    other = qjs_context_new(rt);
    qjs_value_free(eval(other, "var x = 1"));
    qjs_runtime_destroy(rt);
    check("destroying the runtime box keeps the owner for its contexts", qjs_live_owners() == 1);
    qjs_context_destroy(other);
    qjs_context_destroy(ctx);
    check("finalizer order runtime, context, context", qjs_live_owners() == 0);

    rt = qjs_runtime_new();
    ctx = qjs_context_new(rt);
    v = eval(ctx, "[1, 2]");
    qjs_context_destroy(ctx);
    check("a value outlives its context", qjs_value_type(NULL, v) == QJS_TYPE_RELEASED && qjs_live_owners() == 1);
    qjs_value_free(v);
    qjs_runtime_destroy(rt);
    check("finalizer order context, value, runtime", qjs_live_owners() == 0);

    rt = qjs_runtime_new();
    for (int i = 0; i < 100; i++) {
        ctx = qjs_context_new(rt);
        qjs_value_free(eval(ctx, "'x'.repeat(1000)"));
        if (i % 2)
            qjs_context_release(ctx);
        qjs_context_destroy(ctx);
    }
    qjs_runtime_release(rt);
    qjs_runtime_release(rt);
    qjs_runtime_destroy(rt);
    check("100 contexts, some released twice", qjs_live_owners() == 0);
}

/* A stand-in for Pharo: object 7 answers name, add: and fail, can
   evaluate JS from inside a call, calls a JS function for each of 1, 2
   and 3 (each:), calls one once and fails with its exception the way
   Pharo does (again:), and keeps a JS function beyond the call (keep:). */
static int calls = 0;
static QJSValueBox *kept = NULL;

static int fake_pharo(QJSContextBox *ctx, int64_t id, QJSValueBox *selector,
                      int argc, QJSValueBox **argv, QJSValueBox **answer)
{
    size_t length;
    char *name = qjs_value_to_utf8(ctx, selector, &length);
    int status = 0;
    calls++;
    if (id != 7) {
        *answer = qjs_new_string(ctx, "unknown object", 14);
        status = 1;
    } else if (strcmp(name, "name") == 0 && argc == 0) {
        *answer = qjs_new_string(ctx, "Grid", 4);
    } else if (strcmp(name, "add:") == 0 && argc == 1) {
        *answer = qjs_new_int64(ctx, 40 + qjs_value_to_int64(ctx, argv[0]));
    } else if (strcmp(name, "nested") == 0) {
        *answer = qjs_eval(ctx, "6 * 7", 5);
    } else if (strcmp(name, "each:") == 0 && argc == 1) {
        for (int i = 1; i <= 3; i++) {
            QJSValueBox *element = qjs_new_int64(ctx, i);
            qjs_value_free(qjs_call(ctx, argv[0], 1, &element));
            qjs_value_free(element);
        }
        *answer = qjs_new_undefined(ctx);
    } else if (strcmp(name, "again:") == 0 && argc == 1) {
        QJSValueBox *result = qjs_call(ctx, argv[0], 0, NULL);
        if (qjs_value_type(ctx, result) == QJS_TYPE_EXCEPTION) {
            QJSValueBox *e = qjs_exception(ctx);
            size_t message_length = 0;
            char *message = qjs_value_to_utf8(ctx, e, &message_length);
            *answer = message ? qjs_new_string(ctx, message, message_length) : qjs_new_string(ctx, "QJSError", 8);
            qjs_bytes_free(message);
            qjs_value_free(e);
            status = 1;
        } else {
            *answer = qjs_new_undefined(ctx);
        }
        qjs_value_free(result);
    } else if (strcmp(name, "keep:") == 0 && argc == 1) {
        kept = qjs_value_dup(ctx, argv[0]);
        *answer = qjs_new_undefined(ctx);
    } else {
        *answer = qjs_new_string(ctx, "boom from Pharo", 15);
        status = 1;
    }
    qjs_bytes_free(name);
    return status;
}

static void test_bindings(void)
{
    QJSOwner *rt = qjs_runtime_new();
    QJSContextBox *ctx = qjs_context_new(rt);
    QJSValueBox *grid, *v, *e;
    int64_t ids[8];

    qjs_set_callback(fake_pharo);
    grid = qjs_new_binding(ctx, 7);
    qjs_binding_define(ctx, grid, "name", 7, "name");
    qjs_binding_define(ctx, grid, "add_", 7, "add:");
    qjs_binding_define(ctx, grid, "nested", 7, "nested");
    qjs_binding_define(ctx, grid, "fail", 7, "fail");
    qjs_binding_define_getter(ctx, grid, "title", 7, "name");
    qjs_set_global(ctx, "grid", grid);
    check("binding has its id", qjs_binding_id(ctx, grid) == 7);
    check("binding has the binding type", qjs_value_type(ctx, grid) == QJS_TYPE_BINDING);
    qjs_value_free(grid);

    v = eval(ctx, "grid.name() + ' ' + grid.add_(2)");
    check("JS calls into Pharo", string_equals(ctx, v, "Grid 42") && calls == 2);
    qjs_value_free(v);

    v = eval(ctx, "grid.nested() + 1");
    check("Pharo evaluates JS from inside a call", qjs_value_to_int64(ctx, v) == 43);
    qjs_value_free(v);

    v = eval(ctx, "grid.fail()");
    check("a failing call throws in JS", qjs_value_type(ctx, v) == QJS_TYPE_EXCEPTION);
    qjs_value_free(v);
    e = qjs_exception(ctx);
    check("with the message from Pharo", string_equals(ctx, e, "Error: boom from Pharo"));
    qjs_value_free(e);

    v = eval(ctx, "try { grid.fail() } catch (e) { 'caught ' + e.message }");
    check("JS can catch it", string_equals(ctx, v, "caught boom from Pharo"));
    qjs_value_free(v);

    v = eval(ctx, "typeof grid.size");
    check("an unexposed selector does not exist", string_equals(ctx, v, "undefined"));
    qjs_value_free(v);

    v = eval(ctx, "grid.title + ' ' + typeof Object.getOwnPropertyDescriptor(grid, 'title').get");
    check("a property reads from Pharo through its getter", string_equals(ctx, v, "Grid function"));
    qjs_value_free(v);

    v = eval(ctx, "grid.title = 'other'; grid.title");
    check("a property cannot be set", string_equals(ctx, v, "Grid"));
    qjs_value_free(v);

    calls = 0;
    v = eval(ctx, "JSON.stringify(grid) + Object.keys(grid).length");
    check("walking a binding calls nothing in Pharo", string_equals(ctx, v, "{}0") && calls == 0);
    qjs_value_free(v);

    check("nothing released while JS holds it", qjs_released_bindings(rt, ids, 8) == 0);
    qjs_value_free(eval(ctx, "delete globalThis.grid"));
    check("JS letting go reports the id", qjs_released_bindings(rt, ids, 8) == 1 && ids[0] == 7);

    v = eval(ctx, "[1, 'two', {three: 3}]");
    check("array length", qjs_array_length(ctx, v) == 3);
    e = qjs_get_index(ctx, v, 1);
    check("array element", string_equals(ctx, e, "two"));
    qjs_value_free(e);
    e = qjs_get_index(ctx, v, 2);
    {
        QJSValueBox *keys = qjs_object_keys(ctx, e), *key = qjs_get_index(ctx, keys, 0);
        check("object keys", qjs_array_length(ctx, keys) == 1 && string_equals(ctx, key, "three"));
        qjs_value_free(key);
        qjs_value_free(keys);
    }
    qjs_value_free(e);
    qjs_value_free(v);

    v = qjs_new_array(ctx);
    e = qjs_new_float64(ctx, 1.5);
    qjs_set_index(ctx, v, 0, e);
    qjs_value_free(e);
    e = qjs_new_object(ctx);
    {
        QJSValueBox *t = qjs_new_bool(ctx, 1);
        qjs_set_property(ctx, e, "ok", t);
        qjs_value_free(t);
    }
    qjs_set_index(ctx, v, 1, e);
    qjs_value_free(e);
    qjs_set_global(ctx, "built", v);
    qjs_value_free(v);
    v = eval(ctx, "JSON.stringify(built)");
    check("values built from outside", string_equals(ctx, v, "[1.5,{\"ok\":true}]"));
    qjs_value_free(v);

    grid = qjs_new_binding(ctx, 7);
    qjs_set_global(ctx, "kept", grid);
    qjs_value_free(grid);
    qjs_runtime_release(rt);
    check("a released runtime reports nothing", qjs_released_bindings(rt, ids, 8) == 0);
    qjs_context_destroy(ctx);
    qjs_runtime_destroy(rt);
    check("bindings leave nothing behind", qjs_live_owners() == 0);
    qjs_set_callback(NULL);
}

static void test_functions(void)
{
    QJSOwner *rt = qjs_runtime_new(), *other;
    QJSContextBox *ctx = qjs_context_new(rt), *other_ctx;
    QJSValueBox *grid, *v, *e;

    qjs_set_callback(fake_pharo);
    grid = qjs_new_binding(ctx, 7);
    qjs_binding_define(ctx, grid, "each_", 7, "each:");
    qjs_binding_define(ctx, grid, "keep_", 7, "keep:");
    qjs_set_global(ctx, "grid", grid);
    qjs_value_free(grid);

    v = eval(ctx, "const seen = []; grid.each_(x => seen.push(x * 10)); seen.join()");
    check("Pharo calls a JS closure for each element", string_equals(ctx, v, "10,20,30"));
    qjs_value_free(v);

    v = eval(ctx, "x => x");
    check("a function has the function type", qjs_value_type(ctx, v) == QJS_TYPE_FUNCTION);
    qjs_value_free(v);

    qjs_value_free(eval(ctx, "grid.keep_((a, b) => a + b)"));
    check("Pharo keeps a function beyond the call", qjs_value_type(ctx, kept) == QJS_TYPE_FUNCTION);
    {
        QJSValueBox *args[2] = { qjs_new_int64(ctx, 40), qjs_new_int64(ctx, 2) };
        v = qjs_call(ctx, kept, 2, args);
        check("and calls it from outside an evaluation", qjs_value_to_int64(ctx, v) == 42);
        qjs_value_free(v);
        qjs_value_free(args[0]);
        qjs_value_free(args[1]);
    }
    qjs_value_free(kept);

    qjs_value_free(eval(ctx, "grid.keep_(() => { throw new Error('no') })"));
    v = qjs_call(ctx, kept, 0, NULL);
    check("a throwing function answers an exception", qjs_value_type(ctx, v) == QJS_TYPE_EXCEPTION);
    qjs_value_free(v);
    e = qjs_exception(ctx);
    check("with its message", string_equals(ctx, e, "Error: no"));
    qjs_value_free(e);
    qjs_value_free(kept);

    qjs_runtime_set_timeout_ms(rt, 200);
    qjs_value_free(eval(ctx, "grid.keep_(() => { while (true) {} })"));
    v = qjs_call(ctx, kept, 0, NULL);
    check("a call from outside has a deadline of its own", qjs_value_type(ctx, v) == QJS_TYPE_EXCEPTION);
    qjs_value_free(v);
    qjs_value_free(qjs_exception(ctx));
    qjs_runtime_set_timeout_ms(rt, 0);

    other = qjs_runtime_new();
    other_ctx = qjs_context_new(other);
    check("a function stays in its runtime",
          qjs_value_dup(other_ctx, kept) == NULL && qjs_call(other_ctx, kept, 0, NULL) == NULL);
    qjs_context_destroy(other_ctx);
    qjs_runtime_destroy(other);

    qjs_runtime_release(rt);
    check("a kept function is released with its runtime", qjs_call(ctx, kept, 0, NULL) == NULL);
    qjs_value_free(kept);
    kept = NULL;
    qjs_context_destroy(ctx);
    qjs_runtime_destroy(rt);
    check("functions leave nothing behind", qjs_live_owners() == 0);
    qjs_set_callback(NULL);
}

/* A closure that calls the method calling it: each level runs JS, Pharo and
   JS again on the one C stack. The stack top stays where the outermost
   evaluation entered, so the stack limit of QuickJS counts the frames in
   between and ends the recursion with an exception. */
static void test_recursion_through_pharo(void)
{
    QJSOwner *rt = qjs_runtime_new();
    QJSContextBox *ctx = qjs_context_new(rt);
    QJSValueBox *grid, *v;

    qjs_set_callback(fake_pharo);
    grid = qjs_new_binding(ctx, 7);
    qjs_binding_define(ctx, grid, "again_", 7, "again:");
    qjs_set_global(ctx, "grid", grid);
    qjs_value_free(grid);

    v = eval(ctx, "var depth = 0; function f() { depth++; grid.again_(() => f()) } f()");
    check("recursion through Pharo ends with an exception", qjs_value_type(ctx, v) == QJS_TYPE_EXCEPTION);
    qjs_value_free(v);
    qjs_value_free(qjs_exception(ctx));
    v = eval(ctx, "depth");
    check("after many levels", qjs_value_to_int64(ctx, v) > 10);
    qjs_value_free(v);
    v = eval(ctx, "1 + 1");
    check("and the context works afterwards", qjs_value_to_int64(ctx, v) == 2);
    qjs_value_free(v);

    qjs_context_destroy(ctx);
    qjs_runtime_destroy(rt);
    check("the recursion leaves nothing behind", qjs_live_owners() == 0);
    qjs_set_callback(NULL);
}

/* Reading a result runs JS too (getters, toString, Proxy traps); it stays
   within the deadline of the evaluation that made the result. Without that
   a failing check here hangs instead of failing. */
static void test_reading_results(void)
{
    QJSOwner *rt = qjs_runtime_new();
    QJSContextBox *ctx = qjs_context_new(rt);
    QJSValueBox *v, *keys, *json, *p, *e;
    size_t length;
    char *utf8;

    qjs_runtime_set_timeout_ms(rt, 200);
    v = eval(ctx, "Object.keys = () => { while (true) {} }; ({b: 1, 2: 1, a: 1, 1: 1})");
    keys = qjs_object_keys(ctx, v);
    json = qjs_value_to_json(ctx, keys);
    check("keys come in the order of Object.keys, whatever a script made of it",
          string_equals(ctx, json, "[\"1\",\"2\",\"b\",\"a\"]"));
    qjs_value_free(json);
    qjs_value_free(keys);
    qjs_value_free(v);

    v = eval(ctx, "({ get a() { while (true) {} } })");
    p = qjs_get_property(ctx, v, "a");
    check("a getter run while reading the result stops at the deadline", qjs_value_type(ctx, p) == QJS_TYPE_EXCEPTION);
    qjs_value_free(p);
    e = qjs_exception(ctx);
    check("as an interrupt", string_equals(ctx, e, "InternalError: interrupted"));
    qjs_value_free(e);
    check("the deadline has passed", qjs_runtime_deadline_passed(rt));
    qjs_value_free(v);

    v = eval(ctx, "new Proxy({}, { ownKeys() { while (true) {} } })");
    keys = qjs_object_keys(ctx, v);
    check("so does a Proxy trap asked for the keys", qjs_value_type(ctx, keys) == QJS_TYPE_EXCEPTION);
    qjs_value_free(keys);
    qjs_value_free(qjs_exception(ctx));
    qjs_value_free(v);

    v = eval(ctx, "new Proxy([], { get() { while (true) {} } })");
    check("or for the length, which answers -1 then", qjs_array_length(ctx, v) == -1);
    qjs_value_free(qjs_exception(ctx));
    qjs_value_free(v);

    /* what it answers then differs: Bellard NULL, quickjs-ng the message */
    v = eval(ctx, "Error.prototype.toString = function () { while (true) {} }; null.x");
    e = qjs_exception(ctx);
    utf8 = qjs_value_to_utf8(ctx, e, &length);
    check("and the toString of a thrown error", qjs_runtime_deadline_passed(rt));
    qjs_bytes_free(utf8);
    qjs_value_free(e);
    qjs_value_free(v);

    qjs_runtime_set_timeout_ms(rt, 0);
    v = eval(ctx, "({a: 1})");
    check("the next evaluation sets a deadline of its own",
          !qjs_runtime_deadline_passed(rt) && qjs_value_type(ctx, v) == QJS_TYPE_OBJECT);
    qjs_value_free(v);

    qjs_context_destroy(ctx);
    qjs_runtime_destroy(rt);
    check("reading results leaves nothing behind", qjs_live_owners() == 0);
}

int main(void)
{
    test_values();
    test_any_order();
    test_bindings();
    test_functions();
    test_recursion_through_pharo();
    test_reading_results();
    printf("%s (%d failures)\n", failures ? "FAILED" : "PASSED", failures);
    return failures ? 1 : 0;
}
