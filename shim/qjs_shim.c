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
    QJSLink contexts;
    QJSLink values;
};

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
   script itself. Bellard and quickjs-ng up to 0.17.0 pass the runtime; ng
   master after 0.17.0 passes the context. Adapt when the ng pin moves. */
static int interrupt_handler(JSRuntime *rt, void *opaque)
{
    QJSOwner *owner = opaque;
    return owner->deadline_ms > 0 && now_ms() > owner->deadline_ms;
}

static void owner_unref(QJSOwner *owner)
{
    if (--owner->refs == 0) {
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
    JS_SetInterruptHandler(owner->rt, interrupt_handler, owner);
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

    /* the calling thread's stack may differ between calls */
    JS_UpdateStackTop(owner->rt);
    owner->deadline_ms = owner->timeout_ms > 0 ? now_ms() + owner->timeout_ms : 0;
    result = JS_Eval(context->ctx, copy, length, "<pharo>", JS_EVAL_TYPE_GLOBAL);
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
