/*
 * qjs_shim — a flat C API over QuickJS for Pharo UFFI (spike).
 *
 * Pharo never sees a JSValue by value. Every JS value crosses the
 * boundary as a pointer to a heap copy (a "handle"); qjs_value_free
 * releases the reference and the copy. All other arguments and results
 * are pointers, integers, doubles or UTF-8 bytes.
 */
#ifndef QJS_SHIM_H
#define QJS_SHIM_H

#include <stddef.h>
#include <stdint.h>
#include "quickjs.h"

enum {
    QJS_TYPE_UNDEFINED = 0,
    QJS_TYPE_NULL      = 1,
    QJS_TYPE_BOOL      = 2,
    QJS_TYPE_NUMBER    = 3,
    QJS_TYPE_STRING    = 4,
    QJS_TYPE_OBJECT    = 5,
    QJS_TYPE_ARRAY     = 6,
    QJS_TYPE_FUNCTION  = 7,
    QJS_TYPE_BIGINT    = 8,
    QJS_TYPE_SYMBOL    = 9,
    QJS_TYPE_EXCEPTION = 10,
    QJS_TYPE_OTHER     = 11
};

/* runtime: one per thread, owns the heap and the limits */
JSRuntime *qjs_runtime_new(void);
void qjs_runtime_free(JSRuntime *rt);
void qjs_runtime_set_memory_limit(JSRuntime *rt, size_t limit);
void qjs_runtime_set_timeout_ms(JSRuntime *rt, int64_t timeout_ms);
int qjs_has_intl(void);

/* context: a global object with the standard intrinsics */
JSContext *qjs_context_new(JSRuntime *rt);
void qjs_context_free(JSContext *ctx);

/* evaluation: always returns a handle, which may be an exception */
JSValue *qjs_eval(JSContext *ctx, const char *source, size_t length);
JSValue *qjs_exception(JSContext *ctx);

/* values */
int qjs_value_type(JSContext *ctx, JSValue *value);
int qjs_value_is_int(JSValue *value);
int qjs_value_to_bool(JSContext *ctx, JSValue *value);
int64_t qjs_value_to_int64(JSContext *ctx, JSValue *value);
double qjs_value_to_float64(JSContext *ctx, JSValue *value);
const char *qjs_value_to_utf8(JSContext *ctx, JSValue *value, size_t *length);
void qjs_utf8_free(JSContext *ctx, const char *utf8);
JSValue *qjs_value_to_json(JSContext *ctx, JSValue *value);
JSValue *qjs_get_property(JSContext *ctx, JSValue *object, const char *name);
void qjs_value_free(JSContext *ctx, JSValue *value);

#endif
