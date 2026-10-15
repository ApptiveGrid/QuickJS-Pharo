/*
 * qjs_shim — a flat C API over QuickJS for Pharo UFFI.
 *
 * Pharo never sees a JSValue, a JSContext or a JSRuntime directly. It
 * holds boxes: a runtime owner, context boxes and value boxes. The owner
 * keeps track of every live box, so freeing works in any order:
 *
 *  - release frees the QuickJS side and may be called any number of
 *    times. Releasing a runtime first releases all values and contexts
 *    still alive in it.
 *  - destroy releases and then frees the box itself. It is meant for the
 *    finalizer and must be called exactly once per box. A box of a
 *    released runtime only frees its own memory.
 *
 * All other arguments and results are integers, doubles or bytes.
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
    QJS_TYPE_OTHER     = 11,
    QJS_TYPE_RELEASED  = 12,
    QJS_TYPE_BINDING   = 13
};

typedef struct QJSOwner QJSOwner;
typedef struct QJSContextBox QJSContextBox;
typedef struct QJSValueBox QJSValueBox;

int qjs_has_intl(void);
int64_t qjs_live_owners(void);

/* runtime: one per thread, owns the heap and the limits */
QJSOwner *qjs_runtime_new(void);
void qjs_runtime_release(QJSOwner *owner);
void qjs_runtime_destroy(QJSOwner *owner);
int qjs_runtime_is_live(QJSOwner *owner);
void qjs_runtime_set_memory_limit(QJSOwner *owner, size_t limit);
void qjs_runtime_set_timeout_ms(QJSOwner *owner, int64_t timeout_ms);

/* context: a global object with the standard intrinsics;
   NULL if the runtime is released */
QJSContextBox *qjs_context_new(QJSOwner *owner);
void qjs_context_release(QJSContextBox *context);
void qjs_context_destroy(QJSContextBox *context);
int qjs_context_is_live(QJSContextBox *context);

/* evaluation: a value box, which may hold an exception;
   NULL if the context is released */
QJSValueBox *qjs_eval(QJSContextBox *context, const char *source, size_t length);
QJSValueBox *qjs_exception(QJSContextBox *context);

/* values: need a live context, answer defaults otherwise */
int qjs_value_type(QJSContextBox *context, QJSValueBox *value);
int qjs_value_is_int(QJSValueBox *value);
int qjs_value_to_bool(QJSContextBox *context, QJSValueBox *value);
int64_t qjs_value_to_int64(QJSContextBox *context, QJSValueBox *value);
double qjs_value_to_float64(QJSContextBox *context, QJSValueBox *value);
char *qjs_value_to_utf8(QJSContextBox *context, QJSValueBox *value, size_t *length);
QJSValueBox *qjs_value_to_json(QJSContextBox *context, QJSValueBox *value);
QJSValueBox *qjs_get_property(QJSContextBox *context, QJSValueBox *object, const char *name);

/* qjs_value_free releases and destroys a value box at once */
void qjs_value_free(QJSValueBox *value);
void qjs_bytes_free(char *bytes);

/* Calls from JS into Pharo. Pharo registers one callback; every exposed
   selector reaches it with the binding id, the Smalltalk selector as a
   string box and the arguments as value boxes, all owned by the shim. The
   callback stores its answer, a value box it hands over, in *answer and
   answers 0, or a non-zero status with a string box as the error message. */
typedef int (*QJSPharoCallback)(QJSContextBox *context, int64_t id, QJSValueBox *selector,
                                int argc, QJSValueBox **argv, QJSValueBox **answer);
void qjs_set_callback(QJSPharoCallback callback);

/* building values from Pharo; NULL if the context is released */
QJSValueBox *qjs_new_undefined(QJSContextBox *context);
QJSValueBox *qjs_new_null(QJSContextBox *context);
QJSValueBox *qjs_new_bool(QJSContextBox *context, int value);
QJSValueBox *qjs_new_int64(QJSContextBox *context, int64_t value);
QJSValueBox *qjs_new_float64(QJSContextBox *context, double value);
QJSValueBox *qjs_new_string(QJSContextBox *context, const char *utf8, size_t length);
QJSValueBox *qjs_new_array(QJSContextBox *context);
QJSValueBox *qjs_new_object(QJSContextBox *context);

/* Bindings: a JS object standing for the Pharo object Pharo keeps under
   id, with one method per exposed selector. When JS lets go of it, its id
   shows up in qjs_released_bindings, to be drained after an evaluation. */
QJSValueBox *qjs_new_binding(QJSContextBox *context, int64_t id);
int qjs_binding_define(QJSContextBox *context, QJSValueBox *binding, const char *name, int64_t id, const char *selector);
int64_t qjs_binding_id(QJSContextBox *context, QJSValueBox *value);
int qjs_released_bindings(QJSOwner *owner, int64_t *ids, int capacity);

/* structure: setters do not take over the value box */
int qjs_set_index(QJSContextBox *context, QJSValueBox *array, uint32_t index, QJSValueBox *value);
int qjs_set_property(QJSContextBox *context, QJSValueBox *object, const char *name, QJSValueBox *value);
int qjs_set_global(QJSContextBox *context, const char *name, QJSValueBox *value);
int64_t qjs_array_length(QJSContextBox *context, QJSValueBox *array);
QJSValueBox *qjs_get_index(QJSContextBox *context, QJSValueBox *array, uint32_t index);
QJSValueBox *qjs_object_keys(QJSContextBox *context, QJSValueBox *object);

#endif
