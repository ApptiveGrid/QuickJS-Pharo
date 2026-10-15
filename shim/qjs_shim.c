#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "qjs_shim.h"

/* Runtime state behind JS_GetRuntimeOpaque. The deadline is checked in C:
   QuickJS calls the interrupt handler very often, a callback into the
   image on every call would cost more than the script itself. */
typedef struct {
    int64_t timeout_ms;
    int64_t deadline_ms;
} QJSRuntimeState;

static int64_t now_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

/* Bellard and quickjs-ng up to 0.17.0 pass the runtime; ng master after
   0.17.0 passes the context. Adapt when the ng pin moves past 0.17. */
static int interrupt_handler(JSRuntime *rt, void *opaque)
{
    QJSRuntimeState *state = opaque;
    return state->deadline_ms > 0 && now_ms() > state->deadline_ms;
}

static JSValue *to_heap(JSValue value)
{
    JSValue *handle = malloc(sizeof(JSValue));
    if (handle)
        *handle = value;
    return handle;
}

JSRuntime *qjs_runtime_new(void)
{
    JSRuntime *rt = JS_NewRuntime();
    QJSRuntimeState *state;
    if (!rt)
        return NULL;
    state = calloc(1, sizeof(QJSRuntimeState));
    if (!state) {
        JS_FreeRuntime(rt);
        return NULL;
    }
    JS_SetRuntimeOpaque(rt, state);
    JS_SetInterruptHandler(rt, interrupt_handler, state);
    return rt;
}

void qjs_runtime_free(JSRuntime *rt)
{
    QJSRuntimeState *state = JS_GetRuntimeOpaque(rt);
    JS_FreeRuntime(rt);
    free(state);
}

void qjs_runtime_set_memory_limit(JSRuntime *rt, size_t limit)
{
    JS_SetMemoryLimit(rt, limit);
}

void qjs_runtime_set_timeout_ms(JSRuntime *rt, int64_t timeout_ms)
{
    QJSRuntimeState *state = JS_GetRuntimeOpaque(rt);
    state->timeout_ms = timeout_ms;
}

int qjs_has_intl(void)
{
#ifdef CONFIG_TEMPORAL_INTL
    return 1;
#else
    return 0;
#endif
}

JSContext *qjs_context_new(JSRuntime *rt)
{
    JSContext *ctx = JS_NewContext(rt);
#ifdef CONFIG_TEMPORAL_INTL
    if (ctx) {
        JS_AddIntrinsicTemporal(ctx);
        JS_AddIntrinsicIntl(ctx);
    }
#endif
    return ctx;
}

void qjs_context_free(JSContext *ctx)
{
    JS_FreeContext(ctx);
}

/* JS_Eval needs a NUL at source[length]; Pharo hands over bare bytes,
   so the source is copied once. */
JSValue *qjs_eval(JSContext *ctx, const char *source, size_t length)
{
    JSRuntime *rt = JS_GetRuntime(ctx);
    QJSRuntimeState *state = JS_GetRuntimeOpaque(rt);
    char *copy;
    JSValue result;

    copy = malloc(length + 1);
    if (!copy)
        return to_heap(JS_ThrowOutOfMemory(ctx));
    memcpy(copy, source, length);
    copy[length] = '\0';

    /* the calling thread's stack may differ between calls */
    JS_UpdateStackTop(rt);
    state->deadline_ms = state->timeout_ms > 0 ? now_ms() + state->timeout_ms : 0;
    result = JS_Eval(ctx, copy, length, "<pharo>", JS_EVAL_TYPE_GLOBAL);
    state->deadline_ms = 0;

    free(copy);
    return to_heap(result);
}

JSValue *qjs_exception(JSContext *ctx)
{
    return to_heap(JS_GetException(ctx));
}

int qjs_value_type(JSContext *ctx, JSValue *value)
{
    JSValue v = *value;
    if (JS_IsException(v))
        return QJS_TYPE_EXCEPTION;
    if (JS_IsUndefined(v))
        return QJS_TYPE_UNDEFINED;
    if (JS_IsNull(v))
        return QJS_TYPE_NULL;
    if (JS_IsBool(v))
        return QJS_TYPE_BOOL;
    if (JS_IsNumber(v))
        return QJS_TYPE_NUMBER;
    if (JS_IsString(v))
        return QJS_TYPE_STRING;
#ifdef QJS_VERSION_MAJOR
    if (JS_IsBigInt(v))
#else
    if (JS_IsBigInt(ctx, v))
#endif
        return QJS_TYPE_BIGINT;
    if (JS_IsSymbol(v))
        return QJS_TYPE_SYMBOL;
#ifdef QJS_VERSION_MAJOR
    if (JS_IsArray(v))
#else
    if (JS_IsArray(ctx, v) > 0)
#endif
        return QJS_TYPE_ARRAY;
    if (JS_IsFunction(ctx, v))
        return QJS_TYPE_FUNCTION;
    if (JS_IsObject(v))
        return QJS_TYPE_OBJECT;
    return QJS_TYPE_OTHER;
}

int qjs_value_is_int(JSValue *value)
{
    return JS_VALUE_GET_TAG(*value) == JS_TAG_INT;
}

int qjs_value_to_bool(JSContext *ctx, JSValue *value)
{
    return JS_ToBool(ctx, *value);
}

int64_t qjs_value_to_int64(JSContext *ctx, JSValue *value)
{
    int64_t result = 0;
    JS_ToInt64(ctx, &result, *value);
    return result;
}

double qjs_value_to_float64(JSContext *ctx, JSValue *value)
{
    double result = 0;
    JS_ToFloat64(ctx, &result, *value);
    return result;
}

const char *qjs_value_to_utf8(JSContext *ctx, JSValue *value, size_t *length)
{
    return JS_ToCStringLen(ctx, length, *value);
}

void qjs_utf8_free(JSContext *ctx, const char *utf8)
{
    JS_FreeCString(ctx, utf8);
}

JSValue *qjs_value_to_json(JSContext *ctx, JSValue *value)
{
    return to_heap(JS_JSONStringify(ctx, *value, JS_UNDEFINED, JS_UNDEFINED));
}

JSValue *qjs_get_property(JSContext *ctx, JSValue *object, const char *name)
{
    return to_heap(JS_GetPropertyStr(ctx, *object, name));
}

void qjs_value_free(JSContext *ctx, JSValue *value)
{
    if (!value)
        return;
    JS_FreeValue(ctx, *value);
    free(value);
}
