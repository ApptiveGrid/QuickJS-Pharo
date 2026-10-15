#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "qjs_shim.h"

/* Every box sits in a list of its owner while its QuickJS side lives, so
   releasing the runtime can release whatever Pharo has not released yet. */
typedef struct QJSLink {
    struct QJSLink *prev, *next;
} QJSLink;

struct QJSOwner {
    JSRuntime *rt;      /* NULL once released */
    int64_t timeout_ms;
    int64_t deadline_ms;
    int64_t refs;       /* the runtime box itself plus every context and value box */
    int depth;          /* nesting of qjs_eval, > 1 when Pharo evaluates from a callback */
    QJSLink contexts;
    QJSLink values;
    int64_t *released;  /* ids of bindings JS has let go of, drained by Pharo */
    int released_count;
    int released_capacity;
};

/* What a JS binding object carries: the id under which Pharo keeps the
   object. The owner is where the finalizer reports the id back. */
typedef struct {
    QJSOwner *owner;
    int64_t id;
} QJSBinding;

struct QJSContextBox {
    QJSLink link;       /* first member: a link is its box */
    QJSOwner *owner;
    JSContext *ctx;     /* NULL once released */
};

struct QJSValueBox {
    QJSLink link;       /* first member: a link is its box */
    QJSOwner *owner;
    JSValue value;
    int live;
};

static int64_t live_owners = 0;
static QJSPharoCallback pharo_callback = NULL;
static JSClassID binding_class_id = 0;

static void list_init(QJSLink *head)
{
    head->prev = head->next = head;
}

static void list_add(QJSLink *head, QJSLink *link)
{
    link->next = head->next;
    link->prev = head;
    head->next->prev = link;
    head->next = link;
}

static void list_remove(QJSLink *link)
{
    link->prev->next = link->next;
    link->next->prev = link->prev;
    link->prev = link->next = link;
}

static int64_t now_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

/* The deadline is checked in C: QuickJS calls the interrupt handler very
   often, a callback into the image on every call would cost more than the
   script itself. Bellard and quickjs-ng up to 0.17.0 pass the runtime as
   the first argument, later quickjs-ng the context; the handler uses
   neither, so it takes a plain pointer and fits whichever QuickJS it is
   built against (the cast below). */
static int interrupt_handler(void *runtime_or_context, void *opaque)
{
    QJSOwner *owner = opaque;
    return owner->deadline_ms > 0 && now_ms() > owner->deadline_ms;
}

static void owner_unref(QJSOwner *owner)
{
    if (--owner->refs == 0) {
        free(owner->released);
        free(owner);
        live_owners--;
    }
}

static void value_release(QJSValueBox *box)
{
    if (!box->live)
        return;
    list_remove(&box->link);
    JS_FreeValueRT(box->owner->rt, box->value);
    box->live = 0;
}

static void context_release(QJSContextBox *box)
{
    if (!box->ctx)
        return;
    list_remove(&box->link);
    JS_FreeContext(box->ctx);
    box->ctx = NULL;
}

static int context_live(QJSContextBox *box)
{
    return box && box->ctx;
}

static int value_live(QJSValueBox *box)
{
    return box && box->live;
}

static QJSValueBox *box_value(QJSContextBox *context, JSValue value)
{
    QJSValueBox *box = malloc(sizeof(QJSValueBox));
    if (!box) {
        JS_FreeValue(context->ctx, value);
        return NULL;
    }
    box->owner = context->owner;
    box->value = value;
    box->live = 1;
    context->owner->refs++;
    list_add(&context->owner->values, &box->link);
    return box;
}

/* Runs inside the JS garbage collector, so it must not call into Pharo.
   It only notes the id; Pharo drains the list after each evaluation. */
static void binding_finalizer(JSRuntime *rt, JSValue value)
{
    QJSBinding *binding = JS_GetOpaque(value, binding_class_id);
    QJSOwner *owner;
    if (!binding)
        return;
    owner = binding->owner;
    if (owner->released_count == owner->released_capacity) {
        int capacity = owner->released_capacity ? owner->released_capacity * 2 : 64;
        int64_t *grown = realloc(owner->released, capacity * sizeof(int64_t));
        if (grown) {
            owner->released = grown;
            owner->released_capacity = capacity;
        }
    }
    if (owner->released_count < owner->released_capacity)
        owner->released[owner->released_count++] = binding->id;
    free(binding);
}

static JSClassDef binding_class = {
    "PharoObject",
    .finalizer = binding_finalizer,
};

int qjs_has_intl(void)
{
#ifdef CONFIG_TEMPORAL_INTL
    return 1;
#else
    return 0;
#endif
}

int64_t qjs_live_owners(void)
{
    return live_owners;
}

QJSOwner *qjs_runtime_new(void)
{
    QJSOwner *owner = calloc(1, sizeof(QJSOwner));
    if (!owner)
        return NULL;
    owner->rt = JS_NewRuntime();
    if (!owner->rt) {
        free(owner);
        return NULL;
    }
    owner->refs = 1;
    list_init(&owner->contexts);
    list_init(&owner->values);
    JS_SetInterruptHandler(owner->rt, (JSInterruptHandler *)interrupt_handler, owner);
    /* one class id for all runtimes, registered in each of them */
#ifdef QJS_VERSION_MAJOR
    JS_NewClassID(owner->rt, &binding_class_id);
#else
    if (binding_class_id == 0)
        JS_NewClassID(&binding_class_id);
#endif
    JS_NewClass(owner->rt, binding_class_id, &binding_class);
    live_owners++;
    return owner;
}

void qjs_runtime_release(QJSOwner *owner)
{
    if (!owner || !owner->rt)
        return;
    while (owner->values.next != &owner->values)
        value_release((QJSValueBox *)owner->values.next);
    while (owner->contexts.next != &owner->contexts)
        context_release((QJSContextBox *)owner->contexts.next);
    JS_FreeRuntime(owner->rt);
    owner->rt = NULL;
    /* Pharo drops all bindings of a released runtime at once */
    owner->released_count = 0;
}

void qjs_runtime_destroy(QJSOwner *owner)
{
    if (!owner)
        return;
    qjs_runtime_release(owner);
    owner_unref(owner);
}

int qjs_runtime_is_live(QJSOwner *owner)
{
    return owner && owner->rt;
}

void qjs_runtime_set_memory_limit(QJSOwner *owner, size_t limit)
{
    if (qjs_runtime_is_live(owner))
        JS_SetMemoryLimit(owner->rt, limit);
}

void qjs_runtime_set_timeout_ms(QJSOwner *owner, int64_t timeout_ms)
{
    if (owner)
        owner->timeout_ms = timeout_ms;
}

QJSContextBox *qjs_context_new(QJSOwner *owner)
{
    QJSContextBox *box;
    if (!qjs_runtime_is_live(owner))
        return NULL;
    box = calloc(1, sizeof(QJSContextBox));
    if (!box)
        return NULL;
    box->ctx = JS_NewContext(owner->rt);
    if (!box->ctx) {
        free(box);
        return NULL;
    }
#ifdef CONFIG_TEMPORAL_INTL
    JS_AddIntrinsicTemporal(box->ctx);
    JS_AddIntrinsicIntl(box->ctx);
#endif
    box->owner = owner;
    owner->refs++;
    list_add(&owner->contexts, &box->link);
    JS_SetContextOpaque(box->ctx, box);
    return box;
}

void qjs_context_release(QJSContextBox *context)
{
    if (context)
        context_release(context);
}

void qjs_context_destroy(QJSContextBox *context)
{
    QJSOwner *owner;
    if (!context)
        return;
    owner = context->owner;
    context_release(context);
    free(context);
    owner_unref(owner);
}

int qjs_context_is_live(QJSContextBox *context)
{
    return context_live(context);
}

/* JS_Eval needs a NUL at source[length]; Pharo hands over bare bytes,
   so the source is copied once. */
QJSValueBox *qjs_eval(QJSContextBox *context, const char *source, size_t length)
{
    QJSOwner *owner;
    char *copy;
    JSValue result;

    if (!context_live(context))
        return NULL;
    owner = context->owner;
    copy = malloc(length + 1);
    if (!copy)
        return box_value(context, JS_ThrowOutOfMemory(context->ctx));
    memcpy(copy, source, length);
    copy[length] = '\0';

    /* Only the outermost evaluation sets the stack top (the calling thread
       may differ between calls) and the deadline; an evaluation from a
       Pharo callback runs deeper on the same stack and within the same
       deadline. */
    if (owner->depth++ == 0) {
        JS_UpdateStackTop(owner->rt);
        owner->deadline_ms = owner->timeout_ms > 0 ? now_ms() + owner->timeout_ms : 0;
    }
    result = JS_Eval(context->ctx, copy, length, "<pharo>", JS_EVAL_TYPE_GLOBAL);
    if (--owner->depth == 0)
        owner->deadline_ms = 0;

    free(copy);
    return box_value(context, result);
}

QJSValueBox *qjs_exception(QJSContextBox *context)
{
    if (!context_live(context))
        return NULL;
    return box_value(context, JS_GetException(context->ctx));
}

int qjs_value_type(QJSContextBox *context, QJSValueBox *value)
{
    JSValue v;
    if (!context_live(context) || !value_live(value))
        return QJS_TYPE_RELEASED;
    v = value->value;
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
    if (JS_IsBigInt(context->ctx, v))
#endif
        return QJS_TYPE_BIGINT;
    if (JS_IsSymbol(v))
        return QJS_TYPE_SYMBOL;
    if (JS_GetOpaque(v, binding_class_id))
        return QJS_TYPE_BINDING;
#ifdef QJS_VERSION_MAJOR
    if (JS_IsArray(v))
#else
    if (JS_IsArray(context->ctx, v) > 0)
#endif
        return QJS_TYPE_ARRAY;
    if (JS_IsFunction(context->ctx, v))
        return QJS_TYPE_FUNCTION;
    if (JS_IsObject(v))
        return QJS_TYPE_OBJECT;
    return QJS_TYPE_OTHER;
}

int qjs_value_is_int(QJSValueBox *value)
{
    return value_live(value) && JS_VALUE_GET_TAG(value->value) == JS_TAG_INT;
}

int qjs_value_to_bool(QJSContextBox *context, QJSValueBox *value)
{
    if (!context_live(context) || !value_live(value))
        return 0;
    return JS_ToBool(context->ctx, value->value);
}

int64_t qjs_value_to_int64(QJSContextBox *context, QJSValueBox *value)
{
    int64_t result = 0;
    if (context_live(context) && value_live(value))
        JS_ToInt64(context->ctx, &result, value->value);
    return result;
}

double qjs_value_to_float64(QJSContextBox *context, QJSValueBox *value)
{
    double result = 0;
    if (context_live(context) && value_live(value))
        JS_ToFloat64(context->ctx, &result, value->value);
    return result;
}

/* A copy in malloc'ed memory, freed with qjs_bytes_free, so the bytes do
   not depend on the context staying alive. NULL if toString throws. */
char *qjs_value_to_utf8(QJSContextBox *context, QJSValueBox *value, size_t *length)
{
    const char *utf8;
    size_t len = 0;
    char *copy;

    *length = 0;
    if (!context_live(context) || !value_live(value))
        return NULL;
    utf8 = JS_ToCStringLen(context->ctx, &len, value->value);
    if (!utf8) {
        JS_FreeValue(context->ctx, JS_GetException(context->ctx));
        return NULL;
    }
    copy = malloc(len + 1);
    if (copy) {
        memcpy(copy, utf8, len);
        copy[len] = '\0';
        *length = len;
    }
    JS_FreeCString(context->ctx, utf8);
    return copy;
}

QJSValueBox *qjs_value_to_json(QJSContextBox *context, QJSValueBox *value)
{
    if (!context_live(context) || !value_live(value))
        return NULL;
    return box_value(context, JS_JSONStringify(context->ctx, value->value, JS_UNDEFINED, JS_UNDEFINED));
}

QJSValueBox *qjs_get_property(QJSContextBox *context, QJSValueBox *object, const char *name)
{
    if (!context_live(context) || !value_live(object))
        return NULL;
    return box_value(context, JS_GetPropertyStr(context->ctx, object->value, name));
}

void qjs_value_free(QJSValueBox *value)
{
    QJSOwner *owner;
    if (!value)
        return;
    owner = value->owner;
    value_release(value);
    free(value);
    owner_unref(owner);
}

void qjs_bytes_free(char *bytes)
{
    free(bytes);
}

/* ---- calls from JS into Pharo ---- */

void qjs_set_callback(QJSPharoCallback callback)
{
    pharo_callback = callback;
}

/* The one C function behind every exposed selector. func_data holds the
   binding id and the Smalltalk selector; the arguments go to Pharo as
   value boxes, the answer comes back as one. A status other than 0 means
   Pharo failed, and the answer is the message to throw. */
#ifdef QJS_VERSION_MAJOR
static JSValue call_pharo(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv, int magic, JSValueConst *func_data)
#else
static JSValue call_pharo(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv, int magic, JSValue *func_data)
#endif
{
    QJSContextBox *context = JS_GetContextOpaque(ctx);
    QJSValueBox **args = NULL;
    QJSValueBox *selector, *answer = NULL;
    int64_t id = 0;
    int status;
    JSValue result;

    if (!pharo_callback || !context)
        return JS_ThrowInternalError(ctx, "no Pharo callback registered");
    JS_ToInt64(ctx, &id, func_data[0]);
    selector = box_value(context, JS_DupValue(ctx, func_data[1]));
    if (argc > 0) {
        args = calloc(argc, sizeof(QJSValueBox *));
        if (!args) {
            qjs_value_free(selector);
            return JS_ThrowOutOfMemory(ctx);
        }
        for (int i = 0; i < argc; i++)
            args[i] = box_value(context, JS_DupValue(ctx, argv[i]));
    }

    status = pharo_callback(context, id, selector, argc, args, &answer);

    for (int i = 0; i < argc; i++)
        qjs_value_free(args[i]);
    free(args);
    qjs_value_free(selector);

    result = value_live(answer) ? JS_DupValue(ctx, answer->value) : JS_UNDEFINED;
    qjs_value_free(answer);
    if (status == 0)
        return result;
    if (JS_IsString(result)) {
        JSValue error = JS_NewError(ctx);
        JS_DefinePropertyValueStr(ctx, error, "message", result, JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE);
        return JS_Throw(ctx, error);
    }
    JS_FreeValue(ctx, result);
    return JS_ThrowInternalError(ctx, "Pharo callback failed");
}

/* ---- building values from Pharo ---- */

QJSValueBox *qjs_new_undefined(QJSContextBox *context)
{
    return context_live(context) ? box_value(context, JS_UNDEFINED) : NULL;
}

QJSValueBox *qjs_new_null(QJSContextBox *context)
{
    return context_live(context) ? box_value(context, JS_NULL) : NULL;
}

QJSValueBox *qjs_new_bool(QJSContextBox *context, int value)
{
    return context_live(context) ? box_value(context, JS_NewBool(context->ctx, value != 0)) : NULL;
}

QJSValueBox *qjs_new_int64(QJSContextBox *context, int64_t value)
{
    return context_live(context) ? box_value(context, JS_NewInt64(context->ctx, value)) : NULL;
}

QJSValueBox *qjs_new_float64(QJSContextBox *context, double value)
{
    return context_live(context) ? box_value(context, JS_NewFloat64(context->ctx, value)) : NULL;
}

QJSValueBox *qjs_new_string(QJSContextBox *context, const char *utf8, size_t length)
{
    return context_live(context) ? box_value(context, JS_NewStringLen(context->ctx, utf8, length)) : NULL;
}

QJSValueBox *qjs_new_array(QJSContextBox *context)
{
    return context_live(context) ? box_value(context, JS_NewArray(context->ctx)) : NULL;
}

QJSValueBox *qjs_new_object(QJSContextBox *context)
{
    return context_live(context) ? box_value(context, JS_NewObject(context->ctx)) : NULL;
}

/* A JS object standing for the Pharo object Pharo keeps under id. It has
   no methods until qjs_binding_define adds them. */
QJSValueBox *qjs_new_binding(QJSContextBox *context, int64_t id)
{
    QJSBinding *binding;
    JSValue object;
    if (!context_live(context))
        return NULL;
    binding = malloc(sizeof(QJSBinding));
    if (!binding)
        return NULL;
    binding->owner = context->owner;
    binding->id = id;
    object = JS_NewObjectClass(context->ctx, binding_class_id);
    if (JS_IsException(object)) {
        free(binding);
        return box_value(context, object);
    }
    JS_SetOpaque(object, binding);
    return box_value(context, object);
}

/* Adds the method name to a binding, calling selector on the Pharo object id */
int qjs_binding_define(QJSContextBox *context, QJSValueBox *binding, const char *name, int64_t id, const char *selector)
{
    JSValue data[2];
    JSValue function;
    if (!context_live(context) || !value_live(binding))
        return -1;
    data[0] = JS_NewInt64(context->ctx, id);
    data[1] = JS_NewString(context->ctx, selector);
    function = JS_NewCFunctionData(context->ctx, call_pharo, 0, 0, 2, data);
    JS_FreeValue(context->ctx, data[1]);
    if (JS_IsException(function))
        return -1;
    return JS_DefinePropertyValueStr(context->ctx, binding->value, name, function, JS_PROP_CONFIGURABLE);
}

int64_t qjs_binding_id(QJSContextBox *context, QJSValueBox *value)
{
    QJSBinding *binding;
    if (!context_live(context) || !value_live(value))
        return -1;
    binding = JS_GetOpaque(value->value, binding_class_id);
    return binding ? binding->id : -1;
}

int qjs_released_bindings(QJSOwner *owner, int64_t *ids, int capacity)
{
    int count;
    if (!owner)
        return 0;
    count = owner->released_count < capacity ? owner->released_count : capacity;
    memcpy(ids, owner->released + owner->released_count - count, count * sizeof(int64_t));
    owner->released_count -= count;
    return count;
}

/* ---- structure, both ways ---- */

int qjs_set_index(QJSContextBox *context, QJSValueBox *array, uint32_t index, QJSValueBox *value)
{
    if (!context_live(context) || !value_live(array) || !value_live(value))
        return -1;
    return JS_SetPropertyUint32(context->ctx, array->value, index, JS_DupValue(context->ctx, value->value));
}

int qjs_set_property(QJSContextBox *context, QJSValueBox *object, const char *name, QJSValueBox *value)
{
    if (!context_live(context) || !value_live(object) || !value_live(value))
        return -1;
    return JS_SetPropertyStr(context->ctx, object->value, name, JS_DupValue(context->ctx, value->value));
}

int qjs_set_global(QJSContextBox *context, const char *name, QJSValueBox *value)
{
    JSValue global;
    int result;
    if (!context_live(context) || !value_live(value))
        return -1;
    global = JS_GetGlobalObject(context->ctx);
    result = JS_SetPropertyStr(context->ctx, global, name, JS_DupValue(context->ctx, value->value));
    JS_FreeValue(context->ctx, global);
    return result;
}

int64_t qjs_array_length(QJSContextBox *context, QJSValueBox *array)
{
    JSValue length;
    int64_t result = 0;
    if (!context_live(context) || !value_live(array))
        return 0;
    length = JS_GetPropertyStr(context->ctx, array->value, "length");
    JS_ToInt64(context->ctx, &result, length);
    JS_FreeValue(context->ctx, length);
    return result;
}

QJSValueBox *qjs_get_index(QJSContextBox *context, QJSValueBox *array, uint32_t index)
{
    if (!context_live(context) || !value_live(array))
        return NULL;
    return box_value(context, JS_GetPropertyUint32(context->ctx, array->value, index));
}

/* Object.keys(object), as an array box */
QJSValueBox *qjs_object_keys(QJSContextBox *context, QJSValueBox *object)
{
    JSValue global, constructor, keys, result;
    if (!context_live(context) || !value_live(object))
        return NULL;
    global = JS_GetGlobalObject(context->ctx);
    constructor = JS_GetPropertyStr(context->ctx, global, "Object");
    keys = JS_GetPropertyStr(context->ctx, constructor, "keys");
    result = JS_Call(context->ctx, keys, constructor, 1, &object->value);
    JS_FreeValue(context->ctx, keys);
    JS_FreeValue(context->ctx, constructor);
    JS_FreeValue(context->ctx, global);
    return box_value(context, result);
}
