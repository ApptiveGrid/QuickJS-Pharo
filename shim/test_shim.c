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

int main(void)
{
    test_values();
    test_any_order();
    printf("%s (%d failures)\n", failures ? "FAILED" : "PASSED", failures);
    return failures ? 1 : 0;
}
