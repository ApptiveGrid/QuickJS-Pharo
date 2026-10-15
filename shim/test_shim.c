/* Exercises the shim the way Pharo will: only through handles. */
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

static JSValue *eval(JSContext *ctx, const char *source)
{
    return qjs_eval(ctx, source, strlen(source));
}

static int string_equals(JSContext *ctx, JSValue *value, const char *expected)
{
    size_t length = 0;
    const char *utf8 = qjs_value_to_utf8(ctx, value, &length);
    int ok = utf8 && length == strlen(expected) && memcmp(utf8, expected, length) == 0;
    if (!ok)
        printf("     got: %.*s\n", (int)length, utf8 ? utf8 : "(null)");
    qjs_utf8_free(ctx, utf8);
    return ok;
}

int main(void)
{
    JSRuntime *rt = qjs_runtime_new();
    JSContext *ctx = qjs_context_new(rt);
    JSValue *v, *e, *json;

    v = eval(ctx, "1 + 1");
    check("1 + 1 is the int 2", qjs_value_type(ctx, v) == QJS_TYPE_NUMBER
          && qjs_value_is_int(v) && qjs_value_to_int64(ctx, v) == 2);
    qjs_value_free(ctx, v);

    v = eval(ctx, "0.1 + 0.2");
    check("0.1 + 0.2 is a float", !qjs_value_is_int(v)
          && qjs_value_to_float64(ctx, v) == 0.1 + 0.2);
    qjs_value_free(ctx, v);

    v = eval(ctx, "'Grüße, ' + 'Pharo'");
    check("string with umlaut", qjs_value_type(ctx, v) == QJS_TYPE_STRING
          && string_equals(ctx, v, "Grüße, Pharo"));
    qjs_value_free(ctx, v);

    v = eval(ctx, "[1, 'a', {b: true}, null]");
    check("array type", qjs_value_type(ctx, v) == QJS_TYPE_ARRAY);
    json = qjs_value_to_json(ctx, v);
    check("array as JSON", string_equals(ctx, json, "[1,\"a\",{\"b\":true},null]"));
    qjs_value_free(ctx, json);
    qjs_value_free(ctx, v);

    v = eval(ctx, "var counter = 40; counter");
    qjs_value_free(ctx, v);
    v = eval(ctx, "counter + 2");
    check("globals survive between evals", qjs_value_to_int64(ctx, v) == 42);
    qjs_value_free(ctx, v);

    v = eval(ctx, "throw new TypeError('boom')");
    check("throw gives an exception handle", qjs_value_type(ctx, v) == QJS_TYPE_EXCEPTION);
    qjs_value_free(ctx, v);
    e = qjs_exception(ctx);
    check("exception message", string_equals(ctx, e, "TypeError: boom"));
    qjs_value_free(ctx, e);

    v = eval(ctx, "1 +");
    check("syntax error is an exception", qjs_value_type(ctx, v) == QJS_TYPE_EXCEPTION);
    qjs_value_free(ctx, v);
    qjs_value_free(ctx, qjs_exception(ctx));

    qjs_runtime_set_timeout_ms(rt, 200);
    v = eval(ctx, "while (true) {}");
    check("endless loop is interrupted", qjs_value_type(ctx, v) == QJS_TYPE_EXCEPTION);
    qjs_value_free(ctx, v);
    e = qjs_exception(ctx);
    check("interrupt message", string_equals(ctx, e, "InternalError: interrupted"));
    qjs_value_free(ctx, e);
    qjs_runtime_set_timeout_ms(rt, 0);

    if (qjs_has_intl()) {
        v = eval(ctx, "new Intl.DateTimeFormat('de-DE', {timeZone: 'Europe/Berlin',"
                      " dateStyle: 'short', timeStyle: 'short'}).format(new Date(Date.UTC(2026, 9, 15, 12, 0)))");
        check("Intl.DateTimeFormat with timeZone", qjs_value_type(ctx, v) == QJS_TYPE_STRING
              && string_equals(ctx, v, "15.10.26, 14:00"));
        qjs_value_free(ctx, v);
    }

    qjs_context_free(ctx);
    qjs_runtime_free(rt);

    /* memory limit in a fresh runtime, so the first one stays usable above */
    rt = qjs_runtime_new();
    ctx = qjs_context_new(rt);
    qjs_runtime_set_memory_limit(rt, 8 * 1024 * 1024);
    v = eval(ctx, "let a = []; while (true) a.push(new Array(1000).fill(1))");
    check("memory hog ends with an exception", qjs_value_type(ctx, v) == QJS_TYPE_EXCEPTION);
    qjs_value_free(ctx, v);
    qjs_value_free(ctx, qjs_exception(ctx));
    qjs_context_free(ctx);
    qjs_runtime_free(rt);

    printf("%s (%d failures)\n", failures ? "FAILED" : "PASSED", failures);
    return failures ? 1 : 0;
}
