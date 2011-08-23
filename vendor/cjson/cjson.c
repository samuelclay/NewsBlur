/*
 * Copyright (C) 2006-2007 Dan Pascu
 * Author: Dan Pascu <dan@ag-projects.com>
 *
 * Fast JSON encoder/decoder implementation for Python
 *
 * Original version: Dan Pascu <dan@ag-projects.com>
 *
 * 2007-03-16: Viktor Ferenczi <cx@cx.hu>
 *
 * Added extension keyword arguments to encode and decode functions.
 * These functions can specify encoding/decoding of non-atomic data,
 * such as Date objects. For example:
 *
 * decode('[1,new Date(2007,1,2),2]', extension=dateDecoder)
 * encode([1, datetime.date(2007,1,2), 2], extension=dateEncoder)
 *
 * See the unit tests (jsontest.py) for detailed example.
 *
 * Both encoder and decoder now has a context struct.
 * Very small optimizations for the decoder (switch order).
 *
 * 2007-03-28: Qiangning Hong <hongqn@gmail.com>
 *
 * Segfault with Python 2.5 on 64 bit platforms is fixed by using the correct
 * Py_ssize_t type for one of the parameters of PyDict_Next(). More testing
 * with Python 2.5 on 64 bit platform required.
 *
 * 2007-04-01: Fixing exception handling bug
 *
 * When a decoder extension function was called after the failure of an
 * internal decoder (for example after failing to interpret new Date(...)
 * as null) the internal exception was propagated (not cleared) and could
 * be incorrectly raised in the decoder extension function pointing to en
 * otherwise correct statement in that function. This could cause severe
 * confusion to the programmer and prevented execution of such extension
 * functions.
 *
 * 2007-04-02: Added optional automatic conversion of dict keys to string.
 *
 * Since JSON specification does not allow non-string keys in objects,
 * it's very useful to add optional automatic conversion of dictionary keys.
 * This could be useful when porting code originally written for simplejson
 * that does this by default. The feature can be enabled by passing
 * key2str=True keyword argument to the encode() function. Default behaviour
 * of python-cjson has been preserved, so without this keyword argument
 * encoding of non-string dictionary keys will raise EncodeError.
 *
 * 2007-05-05: Added automatic charset encoding/decoding for strings
 *
 * Added keyword argument named encoding for automatic str object handling.
 * Small performance optimizations. More realistic throughput test data.
 * Compatibility with MS C compilers from VC++ Toolkit 2003.
 *
 * 2007-07-12: Fixed segmentation fault
 *
 * Fixed a rare, but reproducible segmentation fault when decoding specially
 * crafted unicode strings. Bug reported by: Liu Cougar - China
 *
 */

#include <Python.h>
#include <stdio.h>
#include <ctype.h>
#include <math.h>

#if (PY_VERSION_HEX < 0x02050000)
typedef int Py_ssize_t;
#endif

typedef struct EncoderContext {
    PyObject *extension; /* callable to extend the encoder (encode user defined objects) */
    int key2str; /* flag to enable automatic dict key to string conversion */
    const char *encoding; /* encoding used to decode str objects, only ASCII is accepted if NULL */
} EncoderContext;

typedef struct DecoderContext {
    char *str; /* the actual json string */
    char *end; /* pointer to the string end */
    char *ptr; /* pointer to the current parsing position */
    int  all_unicode; /* make all output strings unicode if true */
    PyObject *extension; /* callable to extend the decoder (decode user defined sequences) or NULL */
    PyObject *jsonstr; /* the original JSON string */
    const char *encoding; /* encoding used to automatically encode unicode objects, they are left unicode if NULL */
} DecoderContext;

static PyObject* encode_object(EncoderContext *ctx, PyObject *object);
static PyObject* encode_string(PyObject *object);
static PyObject* encode_string_with_recoding(EncoderContext *ctx, PyObject *object);
static PyObject* encode_unicode(PyObject *object);
static PyObject* encode_tuple(EncoderContext *ctx, PyObject *object);
static PyObject* encode_list(EncoderContext *ctx, PyObject *object);
static PyObject* encode_dict(EncoderContext *ctx, PyObject *object);

static PyObject* decode_json(DecoderContext *ctx);
static PyObject* decode_null(DecoderContext *ctx);
static PyObject* decode_bool(DecoderContext *ctx);
static PyObject* decode_string(DecoderContext *ctx);
static PyObject* decode_inf(DecoderContext *ctx);
static PyObject* decode_nan(DecoderContext *ctx);
static PyObject* decode_number(DecoderContext *ctx);
static PyObject* decode_array(DecoderContext *ctx);
static PyObject* decode_object(DecoderContext *ctx);
static PyObject* decode_using_extension(DecoderContext *ctx);

static PyObject *JSON_Error;
static PyObject *JSON_EncodeError;
static PyObject *JSON_DecodeError;

static const char *hexdigit = "0123456789abcdef";

#define True  1
#define False 0

#ifndef INFINITY
# define INFINITY HUGE_VAL
#endif

#ifndef NAN
# define NAN (HUGE_VAL - HUGE_VAL)
#endif

#ifndef Py_IS_NAN
# define Py_IS_NAN(X) ((X) != (X))
#endif

#define skipSpaces(d) while((d)->ptr<(d)->end && *((d)->ptr) && isspace(*((d)->ptr))) (d)->ptr++


/* ------------------------------ Decoding ----------------------------- */

static PyObject*
decode_null(DecoderContext *ctx)
{
    int left;

    left = ctx->end - ctx->ptr;

    if (left >= 4 && strncmp(ctx->ptr, "null", 4)==0) {
        ctx->ptr += 4;
        Py_INCREF(Py_None);
        return Py_None;
    } else {
        PyErr_Format(JSON_DecodeError, "cannot parse JSON description: %.20s",
                     ctx->ptr);
        return NULL;
    }
}


static PyObject*
decode_bool(DecoderContext *ctx)
{
    int left;

    left = ctx->end - ctx->ptr;

    if (left >= 4 && strncmp(ctx->ptr, "true", 4)==0) {
        ctx->ptr += 4;
        Py_INCREF(Py_True);
        return Py_True;
    } else if (left >= 5 && strncmp(ctx->ptr, "false", 5)==0) {
        ctx->ptr += 5;
        Py_INCREF(Py_False);
        return Py_False;
    } else {
        PyErr_Format(JSON_DecodeError, "cannot parse JSON description: %.20s",
                     ctx->ptr);
        return NULL;
    }
}


static PyObject*
decode_string(DecoderContext *ctx)
{
    PyObject *object;
    register char *ptr;
    register char c, escaping, string_escape, has_unicode;
    int len;

    /* look for the closing quote */
    escaping = string_escape = False;
    has_unicode = ctx->all_unicode;
    ptr = ctx->ptr + 1;
    while (True) {
        c = *ptr;
        if (c == 0) {
            PyErr_Format(JSON_DecodeError,
                         "unterminated string starting at position %d",
                         ctx->ptr - ctx->str);
            return NULL;
        }
        if (escaping) {
            switch(c) {
            case 'u':
                has_unicode = True;
                break;
            case '"':
            case 'r':
            case 'n':
            case 't':
            case 'b':
            case 'f':
            case '\\':
                string_escape = True;
                break;
            }
            escaping = False;
        } else {
            if (c == '\\') {
                escaping = True;
            } else if (c == '"') {
                break;
            } else if (!isascii(c)) {
                has_unicode = True;
            }
        }
        ptr++;
    }

    len = ptr - ctx->ptr - 1;

    if (has_unicode)
        object = PyUnicode_DecodeUnicodeEscape(ctx->ptr+1, len, NULL);
    else if (string_escape)
        object = PyString_DecodeEscape(ctx->ptr+1, len, NULL, 0, NULL);
    else
        object = PyString_FromStringAndSize(ctx->ptr+1, len);

    if (object == NULL) {
        PyObject *type, *value, *tb, *reason;

        PyErr_Fetch(&type, &value, &tb);
        if (type == NULL) {
            PyErr_Format(JSON_DecodeError,
                         "invalid string starting at position %d",
                         ctx->ptr - ctx->str);
        } else {
            if (PyErr_GivenExceptionMatches(type, PyExc_UnicodeDecodeError)) {
                reason = PyObject_GetAttrString(value, "reason");
                PyErr_Format(JSON_DecodeError, "cannot decode string starting"
                             " at position %d: %s",
                             ctx->ptr - ctx->str,
                             reason ? PyString_AsString(reason) : "bad format");
                Py_XDECREF(reason);
            } else {
                PyErr_Format(JSON_DecodeError,
                             "invalid string starting at position %d",
                             ctx->ptr - ctx->str);
            }
        }
        Py_XDECREF(type);
        Py_XDECREF(value);
        Py_XDECREF(tb);
        return NULL;
    }
        
    /* Encode unicode into a specific encoding if specified */
    if (has_unicode && ctx->encoding) {
        PyObject *strobject = PyUnicode_Encode(
            PyUnicode_AS_UNICODE(object),
            PyUnicode_GET_SIZE(object),
            ctx->encoding, "strict"
        );
        Py_DECREF(object);
        object=strobject;
        if(strobject==NULL) {
            PyErr_SetString(JSON_DecodeError, "error encoding unicode object to the specified encoding after successful JSON decoding");
        }
    }
        
    /* Go to the end of the string */
    ctx->ptr = ptr+1;

    return object;
}


static PyObject*
decode_inf(DecoderContext *ctx)
{
    PyObject *object;
    int left;

    left = ctx->end - ctx->ptr;

    if (left >= 8 && strncmp(ctx->ptr, "Infinity", 8)==0) {
        ctx->ptr += 8;
        object = PyFloat_FromDouble(INFINITY);
        return object;
    } else if (left >= 9 && strncmp(ctx->ptr, "+Infinity", 9)==0) {
        ctx->ptr += 9;
        object = PyFloat_FromDouble(INFINITY);
        return object;
    } else if (left >= 9 && strncmp(ctx->ptr, "-Infinity", 9)==0) {
        ctx->ptr += 9;
        object = PyFloat_FromDouble(-INFINITY);
        return object;
    } else {
        PyErr_Format(JSON_DecodeError, "cannot parse JSON description: %.20s",
                     ctx->ptr);
        return NULL;
    }
}


static PyObject*
decode_nan(DecoderContext *ctx)
{
    PyObject *object;
    int left;

    left = ctx->end - ctx->ptr;

    if (left >= 3 && strncmp(ctx->ptr, "NaN", 3)==0) {
        ctx->ptr += 3;
        object = PyFloat_FromDouble(NAN);
        return object;
    } else {
        PyErr_Format(JSON_DecodeError, "cannot parse JSON description: %.20s",
                     ctx->ptr);
        return NULL;
    }
}


static PyObject*
decode_number(DecoderContext *ctx)
{
    PyObject *object, *str;
    int c, is_float, should_stop;
    char *ptr;

    /* check if we got a floating point number */
    ptr = ctx->ptr;
    is_float = should_stop = False;
    while (True) {
        c = *ptr;
        if (c == 0)
            break;
        switch(c) {
        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
        case '-':
        case '+':
            break;
        case '.':
        case 'e':
        case 'E':
            is_float = True;
            break;
        default:
            should_stop = True;
        }
        if (should_stop) {
            break;
        }
        ptr++;
    }

    str = PyString_FromStringAndSize(ctx->ptr, ptr - ctx->ptr);
    if (str == NULL)
        return NULL;

    if (is_float) {
        object = PyFloat_FromString(str, NULL);
    } else {
        object = PyInt_FromString(PyString_AS_STRING(str), NULL, 10);
    }

    Py_DECREF(str);

    if (object == NULL) {
        PyErr_Format(JSON_DecodeError, "invalid number starting at position %d",
                     ctx->ptr - ctx->str);
        puts(ptr);
    } else {
        ctx->ptr = ptr;
    }

    return object;
}


static PyObject*
decode_array(DecoderContext *ctx)
{
    PyObject *object, *item;
    int c, expect_item, items, result;
    char *start;

    object = PyList_New(0);

    start = ctx->ptr;
    ctx->ptr++;
    expect_item = True;
    items = 0;
    while (True) {
        skipSpaces(ctx);
        c = *ctx->ptr;
        if (c == 0) {
            PyErr_Format(JSON_DecodeError, "unterminated array starting at "
                         "position %d", start - ctx->str);
            goto failure;;
        } else if (c == ']') {
            if (expect_item && items>0) {
                PyErr_Format(JSON_DecodeError, "expecting array item at "
                             "position %d", ctx->ptr - ctx->str);
                goto failure;
            }
            ctx->ptr++;
            break;
        } else if (c == ',') {
            if (expect_item) {
                PyErr_Format(JSON_DecodeError, "expecting array item at "
                             "position %d", ctx->ptr - ctx->str);
                goto failure;
            }
            expect_item = True;
            ctx->ptr++;
            continue;
        } else {
            item = decode_json(ctx);
            if (item == NULL)
                goto failure;
            result = PyList_Append(object, item);
            Py_DECREF(item);
            if (result == -1)
                goto failure;
            expect_item = False;
            items++;
        }
    }

    return object;

failure:
    Py_DECREF(object);
    return NULL;
}


static PyObject*
decode_object(DecoderContext *ctx)
{
    PyObject *object, *key, *value;
    int c, expect_key, items, result;
    char *start;

    object = PyDict_New();

    expect_key = True;
    items = 0;
    start = ctx->ptr;
    ctx->ptr++;

    while (True) {
        skipSpaces(ctx);
        c = *ctx->ptr;
        if (c == 0) {
            PyErr_Format(JSON_DecodeError, "unterminated object starting at "
                         "position %d", start - ctx->str);
            goto failure;;
        } else if (c == '}') {
            if (expect_key && items>0) {
                PyErr_Format(JSON_DecodeError, "expecting object property name"
                             " at position %d", ctx->ptr - ctx->str);
                goto failure;
            }
            ctx->ptr++;
            break;
        } else if (c == ',') {
            if (expect_key) {
                PyErr_Format(JSON_DecodeError, "expecting object property name"
                             "at position %d", ctx->ptr - ctx->str);
                goto failure;
            }
            expect_key = True;
            ctx->ptr++;
            continue;
        } else {
            if (c != '"') {
                PyErr_Format(JSON_DecodeError,
                             "expecting property name in object at "
                             "position %d", ctx->ptr - ctx->str);
                goto failure;
            }

            key = decode_json(ctx);
            if (key == NULL)
                goto failure;

            skipSpaces(ctx);
            if (*ctx->ptr != ':') {
                PyErr_Format(JSON_DecodeError,
                             "missing colon after object property name at "
                             "position %d", ctx->ptr - ctx->str);
                Py_DECREF(key);
                goto failure;
            } else {
                ctx->ptr++;
            }

            value = decode_json(ctx);
            if (value == NULL) {
                Py_DECREF(key);
                goto failure;
            }

            result = PyDict_SetItem(object, key, value);
            Py_DECREF(key);
            Py_DECREF(value);
            if (result == -1)
                goto failure;
            expect_key = False;
            items++;
        }
    }

    return object;

failure:
    Py_DECREF(object);
    return NULL;
}

static PyObject*
decode_using_extension(DecoderContext *ctx)
{
    PyObject *object, *index, *tuple, *delta;
    long chars;

    index = PyInt_FromLong(ctx->ptr - ctx->str);
    tuple = PyObject_CallFunctionObjArgs(ctx->extension, ctx->jsonstr, index, NULL);
    Py_DECREF(index);
    
    if(!tuple) return NULL;

    if(!PyTuple_Check(tuple) || PyTuple_Size(tuple)!=2) {
        Py_DECREF(tuple);
        PyErr_SetString(JSON_DecodeError, "extension function should return tuple: (object, parsed_chars)");
        return NULL;
    }
    
    object = PyTuple_GET_ITEM(tuple,0);
    delta = PyTuple_GET_ITEM(tuple,1);
    chars = PyInt_AsLong(delta);
    Py_INCREF(object);
    Py_DECREF(tuple);
    
    if(chars<1) {
        Py_DECREF(object);
        PyErr_SetString(JSON_DecodeError, "extension function should return positive integer as number of parsed characters");
        return NULL;
    }
    
    ctx->ptr += chars;
    if(ctx->ptr > ctx->end) {
        Py_DECREF(object);
        PyErr_SetString(JSON_DecodeError, "extension function returned parsed character count beyond the end of the JSON string");
        return NULL;
    }
    
    return object;
}

static PyObject*
decode_json(DecoderContext *ctx)
{
    PyObject *object;

    skipSpaces(ctx);
    switch(*ctx->ptr) {
    case 0:
        PyErr_SetString(JSON_DecodeError, "empty JSON description");
        return NULL;
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
        object = decode_number(ctx);
        break;
    case '-':
    case '+':
        if (*(ctx->ptr+1) == 'I') {
            object = decode_inf(ctx);
        } else {
            object = decode_number(ctx);
        }
        break;
    case '"':
        object = decode_string(ctx);
        break;
    case 't':
    case 'f':
        object = decode_bool(ctx);
        break;
    case 'n':
        object = decode_null(ctx);
        break;
    case '{':
        object = decode_object(ctx);
        break;
    case '[':
        object = decode_array(ctx);
        break;
    case 'N':
        object = decode_nan(ctx);
        break;
    case 'I':
        object = decode_inf(ctx);
        break;
    default:
        if ( ctx->extension ) {
            return decode_using_extension(ctx);
        }
        PyErr_SetString(JSON_DecodeError, "cannot parse JSON description");
        return NULL;
    }
    
    if( !object && ctx->extension ) {
        PyErr_Clear();
        object = decode_using_extension(ctx);
    }

    return object;
}


/* ------------------------------ Encoding ----------------------------- */

/*
 * This function is an almost verbatim copy of PyString_Repr() from
 * Python's stringobject.c with the following differences:
 *
 * - it always quotes the output using double quotes.
 * - it also quotes \b and \f
 * - it replaces any non ASCII character hh with \u00hh instead of \xhh
 */
static PyObject*
encode_string(PyObject *string)
{
    register int i;
    register char c;
    register char *p;
    PyStringObject* op = (PyStringObject*) string;
    char quote = '"';
    size_t newsize = 2 + 6 * op->ob_size;
    PyObject *v;
    int sl;

    if (newsize > INT_MAX) {
        PyErr_SetString(PyExc_OverflowError,
                        "string is too large to make repr");
    }
    v = PyString_FromStringAndSize((char *)NULL, newsize);
    if (v == NULL) {
        return NULL;
    }
    
    p = PyString_AS_STRING(v);
    *p++ = quote;
    sl = op->ob_size;
    for (i = 0; i < sl; i++) {
        /* There's at least enough room for a hex escape
         and a closing quote. */
        assert(newsize - (p - PyString_AS_STRING(v)) >= 7);
        c = op->ob_sval[i];
        if (c == quote || c == '\\')
            *p++ = '\\', *p++ = c;
        else if (c == '\t')
            *p++ = '\\', *p++ = 't';
        else if (c == '\n')
            *p++ = '\\', *p++ = 'n';
        else if (c == '\r')
            *p++ = '\\', *p++ = 'r';
        else if (c == '\f')
            *p++ = '\\', *p++ = 'f';
        else if (c == '\b')
            *p++ = '\\', *p++ = 'b';
        else if (c < ' ' || c >= 0x7f) {
            *p++='\\'; *p++='u'; *p++='0'; *p++='0';
            *p++=hexdigit[((unsigned char)c>>4)&15];
            *p++=hexdigit[(unsigned char)c&15];
        }
        else
            *p++ = c;
    }
    assert(newsize - (p - PyString_AS_STRING(v)) >= 1);
    *p++ = quote;
    *p = '\0';
    _PyString_Resize(&v, (int) (p - PyString_AS_STRING(v)));
    return v;
}

static PyObject*
encode_string_with_recoding(EncoderContext *ctx, PyObject *object)
{
    PyObject *unicode;
    PyObject *result;

    unicode=PyUnicode_Decode(
        PyString_AS_STRING(object),
        PyString_GET_SIZE(object),
        ctx->encoding, "strict"
    );
    if(unicode==NULL) {
        PyErr_SetString(JSON_EncodeError, "error decoding str object with the specified encoding before actual JSON encoding");
        return NULL;
    }
    result=encode_unicode(unicode);
    Py_DECREF(unicode);
    return result;
}

/*
 * This function is an almost verbatim copy of unicodeescape_string() from
 * Python's unicodeobject.c with the following differences:
 *
 * - it always quotes the output using double quotes.
 * - it uses \u00hh instead of \xhh in output.
 * - it also quotes \b and \f
 */
static PyObject*
encode_unicode(PyObject *unicode)
{
    PyObject *repr;
    Py_UNICODE *s;
    int size;
    char *p;

    s = PyUnicode_AS_UNICODE(unicode);
    size = PyUnicode_GET_SIZE(unicode);

    repr = PyString_FromStringAndSize(NULL, 2 + 6*size + 1);
    if (repr == NULL)
        return NULL;

    p = PyString_AS_STRING(repr);

    *p++ = '"';

    while (size-- > 0) {
        Py_UNICODE ch = *s++;

        /* Escape quotes */
        if ((ch == (Py_UNICODE) PyString_AS_STRING(repr)[0] || ch == '\\')) {
            *p++ = '\\';
            *p++ = (char) ch;
            continue;
        }

#ifdef Py_UNICODE_WIDE
        /* Map 21-bit characters to '\U00xxxxxx' */
        else if (ch >= 0x10000) {
            int offset = p - PyString_AS_STRING(repr);

            /* Resize the string if necessary */
            if (offset + 12 > PyString_GET_SIZE(repr)) {
                if (_PyString_Resize(&repr, PyString_GET_SIZE(repr) + 100))
                    return NULL;
                p = PyString_AS_STRING(repr) + offset;
            }

            *p++ = '\\';
            *p++ = 'U';
            *p++ = hexdigit[(ch >> 28) & 0x0000000F];
            *p++ = hexdigit[(ch >> 24) & 0x0000000F];
            *p++ = hexdigit[(ch >> 20) & 0x0000000F];
            *p++ = hexdigit[(ch >> 16) & 0x0000000F];
            *p++ = hexdigit[(ch >> 12) & 0x0000000F];
            *p++ = hexdigit[(ch >> 8) & 0x0000000F];
            *p++ = hexdigit[(ch >> 4) & 0x0000000F];
            *p++ = hexdigit[ch & 0x0000000F];
            continue;
        }
#endif
        /* Map UTF-16 surrogate pairs to Unicode \UXXXXXXXX escapes */
        else if (ch >= 0xD800 && ch < 0xDC00) {
            Py_UNICODE ch2;
            Py_UCS4 ucs;

            ch2 = *s++;
            size--;
            if (ch2 >= 0xDC00 && ch2 <= 0xDFFF) {
                ucs = (((ch & 0x03FF) << 10) | (ch2 & 0x03FF)) + 0x00010000;
                *p++ = '\\';
                *p++ = 'U';
                *p++ = hexdigit[(ucs >> 28) & 0x0000000F];
                *p++ = hexdigit[(ucs >> 24) & 0x0000000F];
                *p++ = hexdigit[(ucs >> 20) & 0x0000000F];
                *p++ = hexdigit[(ucs >> 16) & 0x0000000F];
                *p++ = hexdigit[(ucs >> 12) & 0x0000000F];
                *p++ = hexdigit[(ucs >> 8) & 0x0000000F];
                *p++ = hexdigit[(ucs >> 4) & 0x0000000F];
                *p++ = hexdigit[ucs & 0x0000000F];
                continue;
            }
            /* Fall through: isolated surrogates are copied as-is */
            s--;
            size++;
        }

        /* Map 16-bit characters to '\uxxxx' */
        if (ch >= 256) {
            *p++ = '\\';
            *p++ = 'u';
            *p++ = hexdigit[(ch >> 12) & 0x000F];
            *p++ = hexdigit[(ch >> 8) & 0x000F];
            *p++ = hexdigit[(ch >> 4) & 0x000F];
            *p++ = hexdigit[ch & 0x000F];
        }

        /* Map special whitespace to '\t', \n', '\r', '\f', '\b' */
        else if (ch == '\t') {
            *p++ = '\\';
            *p++ = 't';
        }
        else if (ch == '\n') {
            *p++ = '\\';
            *p++ = 'n';
        }
        else if (ch == '\r') {
            *p++ = '\\';
            *p++ = 'r';
        }
        else if (ch == '\f') {
            *p++ = '\\';
            *p++ = 'f';
        }
        else if (ch == '\b') {
            *p++ = '\\';
            *p++ = 'b';
        }

        /* Map non-printable US ASCII to '\u00hh' */
        else if (ch < ' ' || ch >= 0x7F) {
            *p++ = '\\';
            *p++ = 'u';
            *p++ = '0';
            *p++ = '0';
            *p++ = hexdigit[(ch >> 4) & 0x000F];
            *p++ = hexdigit[ch & 0x000F];
        }

        /* Copy everything else as-is */
        else
            *p++ = (char) ch;
    }

    *p++ = PyString_AS_STRING(repr)[0];

    *p = '\0';
    _PyString_Resize(&repr, p - PyString_AS_STRING(repr));
    return repr;
}


/*
 * This function is an almost verbatim copy of tuplerepr() from
 * Python's tupleobject.c with the following differences:
 *
 * - it uses encode_object() to get the object's JSON reprezentation.
 * - it uses [] as decorations isntead of () (to masquerade as a JSON array).
 */

static PyObject*
encode_tuple(EncoderContext *ctx, PyObject *tuple)
{
    int i, n;
    PyObject *s, *temp;
    PyObject *pieces, *result = NULL;
    PyTupleObject *v = (PyTupleObject*) tuple;

    n = v->ob_size;
    if (n == 0)
        return PyString_FromString("[]");

    pieces = PyTuple_New(n);
    if (pieces == NULL)
        return NULL;

    /* Do repr() on each element. */
    for (i = 0; i < n; ++i) {
        s = encode_object(ctx, v->ob_item[i]);
        if (s == NULL)
            goto Done;
        PyTuple_SET_ITEM(pieces, i, s);
    }

    /* Add "[]" decorations to the first and last items. */
    assert(n > 0);
    s = PyString_FromString("[");
    if (s == NULL)
        goto Done;
    temp = PyTuple_GET_ITEM(pieces, 0);
    PyString_ConcatAndDel(&s, temp);
    PyTuple_SET_ITEM(pieces, 0, s);
    if (s == NULL)
        goto Done;

    s = PyString_FromString("]");
    if (s == NULL)
        goto Done;
    temp = PyTuple_GET_ITEM(pieces, n-1);
    PyString_ConcatAndDel(&temp, s);
    PyTuple_SET_ITEM(pieces, n-1, temp);
    if (temp == NULL)
        goto Done;

    /* Paste them all together with ", " between. */
    s = PyString_FromString(", ");
    if (s == NULL)
        goto Done;
    result = _PyString_Join(s, pieces);
    Py_DECREF(s);

Done:
    Py_DECREF(pieces);
    return result;
}

/*
 * This function is an almost verbatim copy of list_repr() from
 * Python's listobject.c with the following differences:
 *
 * - it uses encode_object() to get the object's JSON reprezentation.
 * - it doesn't use the ellipsis to represent a list with references
 *   to itself, instead it raises an exception as such lists cannot be
 *   represented in JSON.
 */
static PyObject*
encode_list(EncoderContext *ctx, PyObject *list)
{
    int i;
    PyObject *s, *temp;
    PyObject *pieces = NULL, *result = NULL;
    PyListObject *v = (PyListObject*) list;

    i = Py_ReprEnter((PyObject*)v);
    if (i != 0) {
        if (i > 0) {
            PyErr_SetString(JSON_EncodeError, "a list with references to "
                            "itself is not JSON encodable");
        }
        return NULL;
    }

    if (v->ob_size == 0) {
        result = PyString_FromString("[]");
        goto Done;
    }

    pieces = PyList_New(0);
    if (pieces == NULL)
        goto Done;

    /* Do repr() on each element.  Note that this may mutate the list,
     * so must refetch the list size on each iteration. */
    for (i = 0; i < v->ob_size; ++i) {
        int status;
        s = encode_object(ctx, v->ob_item[i]);
        if (s == NULL)
            goto Done;
        status = PyList_Append(pieces, s);
        Py_DECREF(s);  /* append created a new ref */
        if (status < 0)
            goto Done;
    }

    /* Add "[]" decorations to the first and last items. */
    assert(PyList_GET_SIZE(pieces) > 0);
    s = PyString_FromString("[");
    if (s == NULL)
        goto Done;
    temp = PyList_GET_ITEM(pieces, 0);
    PyString_ConcatAndDel(&s, temp);
    PyList_SET_ITEM(pieces, 0, s);
    if (s == NULL)
        goto Done;

    s = PyString_FromString("]");
    if (s == NULL)
        goto Done;
    temp = PyList_GET_ITEM(pieces, PyList_GET_SIZE(pieces) - 1);
    PyString_ConcatAndDel(&temp, s);
    PyList_SET_ITEM(pieces, PyList_GET_SIZE(pieces) - 1, temp);
    if (temp == NULL)
        goto Done;

    /* Paste them all together with ", " between. */
    s = PyString_FromString(", ");
    if (s == NULL)
        goto Done;
    result = _PyString_Join(s, pieces);
    Py_DECREF(s);

Done:
    Py_XDECREF(pieces);
    Py_ReprLeave((PyObject *)v);
    return result;
}


/*
 * This function is an almost verbatim copy of dict_repr() from
 * Python's dictobject.c with the following differences:
 *
 * - it uses encode_object() to get the object's JSON reprezentation.
 * - only accept strings for keys or convert non-string keys to string if
 *   this feature is enabled (raises exception if cannot be converted)
 * - it doesn't use the ellipsis to represent a dictionary with references
 *   to itself, instead it raises an exception as such dictionaries cannot
 *   be represented in JSON.
 */
static PyObject*
encode_dict(EncoderContext *ctx, PyObject *dict)
{
    Py_ssize_t i;
    PyObject *s, *temp, *colon = NULL;
    PyObject *pieces = NULL, *result = NULL;
    PyObject *key, *value, *strkey = NULL;
    PyDictObject *mp = (PyDictObject*) dict;

    i = Py_ReprEnter((PyObject *)mp);
    if (i != 0) {
        if (i > 0) {
            PyErr_SetString(JSON_EncodeError, "a dict with references to "
                            "itself is not JSON encodable");
        }
        return NULL;
    }

    if (mp->ma_used == 0) {
        result = PyString_FromString("{}");
        goto Done;
    }

    pieces = PyList_New(0);
    if (pieces == NULL)
        goto Done;

    colon = PyString_FromString(": ");
    if (colon == NULL)
        goto Done;

    /* Do repr() on each key+value pair, and insert ": " between them.
     * Note that repr may mutate the dict. */
    i = 0;
    while (PyDict_Next((PyObject *)mp, &i, &key, &value)) {
        int status;

        strkey = NULL;
        if (!PyString_Check(key) && !PyUnicode_Check(key)) {
            if (ctx->key2str) {
                /* Auto convert keys to strings */
                strkey = PyObject_Str(key);
                if( strkey == NULL ) {
                    PyErr_SetString(JSON_EncodeError, "Cannot convert dictionary key to string");
                    goto Done;
                }
            } else {
                PyErr_SetString(JSON_EncodeError, "JSON encodable dictionaries "
                                "must have string/unicode keys");
                goto Done;
            }
        }

        /* Prevent repr from deleting value during key format. */
        Py_INCREF(value);
        if( strkey ) {
            s = encode_object(ctx, strkey);
            Py_DECREF(strkey);
            strkey = NULL;
        } else {
            s = encode_object(ctx, key);
        }
        PyString_Concat(&s, colon);
        PyString_ConcatAndDel(&s, encode_object(ctx, value));
        Py_DECREF(value);
        if (s == NULL)
            goto Done;
        status = PyList_Append(pieces, s);
        Py_DECREF(s);  /* append created a new ref */
        if (status < 0)
            goto Done;
    }

    /* Add "{}" decorations to the first and last items. */
    assert(PyList_GET_SIZE(pieces) > 0);
    s = PyString_FromString("{");
    if (s == NULL)
        goto Done;
    temp = PyList_GET_ITEM(pieces, 0);
    PyString_ConcatAndDel(&s, temp);
    PyList_SET_ITEM(pieces, 0, s);
    if (s == NULL)
        goto Done;

    s = PyString_FromString("}");
    if (s == NULL)
        goto Done;
    temp = PyList_GET_ITEM(pieces, PyList_GET_SIZE(pieces) - 1);
    PyString_ConcatAndDel(&temp, s);
    PyList_SET_ITEM(pieces, PyList_GET_SIZE(pieces) - 1, temp);
    if (temp == NULL)
        goto Done;

    /* Paste them all together with ", " between. */
    s = PyString_FromString(", ");
    if (s == NULL)
        goto Done;
    result = _PyString_Join(s, pieces);
    Py_DECREF(s);

Done:
    Py_XDECREF(strkey);
    Py_XDECREF(pieces);
    Py_XDECREF(colon);
    Py_ReprLeave((PyObject *)mp);
    return result;
}


static PyObject*
encode_object(EncoderContext *ctx, PyObject *object)
{
    if (object == Py_True) {
        return PyString_FromString("true");
    } else if (object == Py_False) {
        return PyString_FromString("false");
    } else if (object == Py_None) {
        return PyString_FromString("null");
    } else if (PyString_Check(object)) {
        if ( ctx->encoding ) {
            /* Recode string from the str encoding specified to unicode */
            return encode_string_with_recoding(ctx, object);
        } else {
            /* No encoding specified, string must be ASCII */
            return encode_string(object);
        }
    } else if (PyUnicode_Check(object)) {
        return encode_unicode(object);
    } else if (PyFloat_Check(object)) {
        double val = PyFloat_AS_DOUBLE(object);
        if (Py_IS_NAN(val)) {
            return PyString_FromString("NaN");
        } else if (Py_IS_INFINITY(val)) {
            if (val > 0) {
                return PyString_FromString("Infinity");
            } else {
                return PyString_FromString("-Infinity");
            }
        } else {
            return PyObject_Str(object);
        }
    } else if (PyInt_Check(object) || PyLong_Check(object)) {
        return PyObject_Str(object);
    } else if (PyList_Check(object)) {
        return encode_list(ctx, object);
    } else if (PyTuple_Check(object)) {
        return encode_tuple(ctx, object);
    } else if (PyDict_Check(object)) { /* use PyMapping_Check(object) instead? -Dan */
        return encode_dict(ctx, object);
    } else if (ctx->extension) {
        return PyObject_CallFunctionObjArgs(ctx->extension, object, NULL);
    } else {
        PyErr_SetString(JSON_EncodeError, "object is not JSON encodable");
        return NULL;
    }
}


/* Encode object into its JSON representation */

static PyObject*
JSON_encode(PyObject *self, PyObject *args, PyObject *kwargs)
{
    static char *kwlist[] = {"obj", "extension", "key2str", "encoding", NULL};
    PyObject *object, *key2str = NULL;
    EncoderContext ctx;
    
    ctx.extension=NULL;
    ctx.encoding=NULL;
    
    if (!PyArg_ParseTupleAndKeywords(args, kwargs, "O|OOz:encode", kwlist,
                                     &object, &ctx.extension, &key2str, &ctx.encoding))
        return NULL;

    if (ctx.extension==Py_None) ctx.extension=NULL;
    ctx.key2str=key2str?PyObject_IsTrue(key2str):0;
    
    if(ctx.extension && !PyCallable_Check(ctx.extension)) {
        PyErr_SetString(JSON_EncodeError, "extension is not callable");
        return NULL;
    }
    
    return encode_object(&ctx, object);
}


/* Decode JSON representation into python objects */

static PyObject*
JSON_decode(PyObject *self, PyObject *args, PyObject *kwargs)
{
    static char *kwlist[] = {"json", "all_unicode", "extension", "encoding", NULL};
    int all_unicode = False; /* by default return unicode only when needed */
    PyObject *object, *string, *str, *oAllUnicode = NULL;
    DecoderContext ctx;
    
    ctx.extension=NULL;
    ctx.jsonstr=NULL;
    ctx.encoding=NULL;

    if (!PyArg_ParseTupleAndKeywords(args, kwargs, "O|OOz:decode", kwlist,
                                     &string, &oAllUnicode, &ctx.extension, &ctx.encoding))
        return NULL;

    all_unicode=oAllUnicode?PyObject_IsTrue(oAllUnicode):0;
    
    if (PyUnicode_Check(string)) {
        str = PyUnicode_AsRawUnicodeEscapeString(string);
        if (str == NULL) {
            return NULL;
        }
    } else {
        Py_INCREF(string);
        str = string;
    }

    if (PyString_AsStringAndSize(str, &(ctx.str), NULL) == -1) {
        Py_DECREF(str);
        return NULL; /* not a string object or it contains null bytes */
    }

    ctx.ptr = ctx.str;
    ctx.end = ctx.str + strlen(ctx.str);
    ctx.all_unicode = all_unicode;
    ctx.jsonstr = str;
    
    if (ctx.extension==Py_None) ctx.extension=NULL;
    
    if (ctx.extension && !PyCallable_Check(ctx.extension)) {
        PyErr_SetString(JSON_DecodeError, "extension is not callable");
        Py_DECREF(str);
        return NULL;
    }

    object = decode_json(&ctx);

    Py_DECREF(str);

    if (object != NULL) {
        skipSpaces(&ctx);
        if (ctx.ptr < ctx.end) {
            Py_DECREF(object);
            PyErr_Format(JSON_DecodeError, "extra data after JSON description"
                        " at position %d", ctx.ptr-ctx.str);
            return NULL;
        }
    }

    return object;
}


/* List of functions defined in the module */

static PyMethodDef cjson_methods[] = {
    {"encode", (PyCFunction)JSON_encode,  METH_VARARGS|METH_KEYWORDS,
    PyDoc_STR("encode(object, extension=None, key2str=False, encoding='ascii') -> \n"
              "generate the JSON representation for object. The optional argument\n"
              "`extension' defines a function to encode objects not in the original\n"
              "JSON specification. For example this can be used to convert\n"
              "datetime.date objects to new Date(...) expressions. The extension\n"
              "function must have a single argument and must return the JSON\n"
              "representation of the object passed or raise EncodeError if the\n"
              "object cannot be converted to JSON format. Automatically convert\n"
              "dictionary keys to str if key2str is True, otherwise EncodeError\n"
              "is raised whenever a non-str and non-unicode dictinary key is found.\n"
              "The encoding argument must specify the encoding used to decode\n"
              "python str objects."
    )},

    {"decode", (PyCFunction)JSON_decode,  METH_VARARGS|METH_KEYWORDS,
    PyDoc_STR("decode(string, all_unicode=False, extension=None, encoding=None) -> \n"
              "parse the JSON representation into python objects.\n"
              "The optional argument `all_unicode', specifies how to\n"
              "convert the strings in the JSON representation into python objects.\n"
              "If it is False (default), it will return strings everywhere possible\n"
              "and unicode objects only where necessary, else it will return unicode\n"
              "objects everywhere (this is slower). The optional argument\n"
              "`extension' defines a function to decode objects not in the original\n"
              "JSON specification. For example this can be used to convert\n"
              "new Date(...) expressions to datetime.date objects. The extension\n"
              "function must have a two arguments: json, idx. The `json' argument\n"
              "receives the original JSON string under conversion. The `idx' argument\n"
              "receives the index of the first character of the substring to be\n"
              "parsed as an extended object. The extension function must return a\n"
              "2-tuple: (obj,count) or raise DecodeError if the string cannot be\n"
              "parsed to an extended object. `obj' must be the object parsed,\n"
              "`count' must be the (positive integer) number of characters consumed\n"
              "from the JSON string (length of the object's representation).\n"
              "All unicode strings will be encoded to the specified encoding\n"
              "automatically if encoding is not None. Unicode objects are returned\n"
              "if encoding is None (this is the default). It's encouraged to set\n"
              "all_unicode=True or define an encoding to prevent mixing of str and\n"
              "unicode objects in the decoder output."
    )},

    {NULL, NULL}  /* sentinel */
};

PyDoc_STRVAR(module_doc,
"Fast JSON encoder/decoder module."
);

/* Initialization function for the module (*must* be called initcjson) */

PyMODINIT_FUNC
initcjson(void)
{
    PyObject *m;

    /* Create the module and add the functions */
    m = Py_InitModule3("cjson", cjson_methods, module_doc);

    /* Add some symbolic constants to the module */
    if (JSON_Error == NULL) {
        JSON_Error = PyErr_NewException("cjson.Error", NULL, NULL);
        if (JSON_Error == NULL)
            return;
        /*Py_INCREF(JSON_Error);*/
        PyModule_AddObject(m, "Error", JSON_Error);
    }
    if (JSON_EncodeError == NULL) {
        JSON_EncodeError = PyErr_NewException("cjson.EncodeError",
                                              JSON_Error, NULL);
        if (JSON_EncodeError == NULL)
            return;
        /*Py_INCREF(JSON_EncodeError);*/
        PyModule_AddObject(m, "EncodeError", JSON_EncodeError);
    }
    if (JSON_DecodeError == NULL) {
        JSON_DecodeError = PyErr_NewException("cjson.DecodeError",
                                              JSON_Error, NULL);
        if (JSON_DecodeError == NULL)
            return;
        /*Py_INCREF(JSON_DecodeError);*/
        PyModule_AddObject(m, "DecodeError", JSON_DecodeError);
    }
}
