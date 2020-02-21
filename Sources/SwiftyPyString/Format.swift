//
//  Format.swift
//  SwiftyPyString
//
//  Created by 恒川大輝 on 2019/07/12.
//
#if os(OSX)
import Darwin
#elseif os(Linux)
import Glibc
#endif
import Foundation


typealias Py_ssize_t = Int
typealias PyObject = Any
typealias int = Int
typealias long = Int
typealias size_t = Int
typealias double = Double
typealias Py_UCS4 = Character

var PY_SSIZE_T_MAX = Int.max
/*
    unicode_format.h -- implementation of str.format().
*/

/************************************************************************/
/***********   Global data structures and forward declarations  *********/
/************************************************************************/

/*
   A SubString consists of the characters between two string or
   unicode pointers.
*/
class SubString {
    var str: PyObject? /* borrowed reference */
    var start: Py_ssize_t
    var end: Py_ssize_t
    
    /* fill in a SubString from a pointer and length */
    init(_ s: PyObject?, _ start: Py_ssize_t, _ end: Py_ssize_t)
    {
        self.str = s
        self.start = start
        self.end = end
    }
}


enum AutoNumberState {
    case ANS_INIT
    case ANS_AUTO
    case ANS_MANUAL
}   /* Keep track if we're auto-numbering fields */

/* Keeps track of our auto-numbering state, and which number field we're on */
class AutoNumber {
    var an_state: AutoNumberState = .ANS_INIT
    var an_field_number: int = 0
}

func PyUnicode_GET_LENGTH(_ str:PyObject) -> Int{
    return (str as! String).count
}
func _Py_RETURN_UNICODE_EMPTY() -> String {
    return ""
}
func unicode_result_unchanged(_ unicode:PyObject) -> PyObject?
{
    return unicode
}
func PyUnicode_IS_ASCII(_ str:PyObject?) -> Bool {
    return (str as! String).isascii()
}
func _PyUnicode_FromASCII(const char *buffer, Py_ssize_t size) -> PyObject?
{
    const unsigned char *s = (const unsigned char *)buffer;
    PyObject *unicode;
    if (size == 1) {
        return get_latin1_char(s[0]);
    }
    unicode = PyUnicode_New(size, 127);
    if (!unicode)
        return NULL;
    memcpy(PyUnicode_1BYTE_DATA(unicode), s, size);
    assert(_PyUnicode_CheckConsistency(unicode, 1));
    return unicode;
}
/************************************************************************/
/**************************  Utility  functions  ************************/
/************************************************************************/
func PyUnicode_Substring(_ self:PyObject?, _ start:Py_ssize_t, _ end:Py_ssize_t) -> PyObject?
{
    unsigned char *data;
    var kind: int
    var length: Py_ssize_t

    length = PyUnicode_GET_LENGTH(self);
    end = min(end, length)

    if (start == 0 && end == length){
        return unicode_result_unchanged(self);
    }

    if (start < 0 || end < 0) {
        PyErr_SetString(PyExc_IndexError, "string index out of range");
        return nil
    }
    if (start >= length || end < start){
        return _Py_RETURN_UNICODE_EMPTY();
    }

    length = end - start;
    if (PyUnicode_IS_ASCII(self)) {
        data = PyUnicode_1BYTE_DATA(self);// 先頭アドレスの取得
        return _PyUnicode_FromASCII((char*)(data + start), length);
    }
    else {
        kind = PyUnicode_KIND(self);
        data = PyUnicode_1BYTE_DATA(self);
        return PyUnicode_FromKindAndData(kind,
                                         data + kind * start,
                                         length);
    }
}

/* return a new string.  if str->str is NULL, return None */
func SubString_new_object(_ str: SubString) -> PyObject?
{
    if (str.str == nil){
        return nil
    }
    return PyUnicode_Substring(str.str, str.start, str.end);
}
func PyUnicode_New(_ n:Int,_ l:Int) -> String {
    return ""
}
/* return a new string.  if str->str is NULL, return a new empty string */
func SubString_new_object_or_empty(_ str:SubString) -> PyObject?
{
    if (str.str == nil) {
        return PyUnicode_New(0, 0);
    }
    return SubString_new_object(str);
}

/* Return 1 if an error has been detected switching between automatic
   field numbering and manual field specification, else return 0. Set
   ValueError on error. */
func
    autonumber_state_error(_ state:AutoNumberState, _ field_name_is_empty:int) -> int
{
    if (state == .ANS_MANUAL) {
        if (field_name_is_empty.asBool) {
            PyErr_SetString(PyExc_ValueError, "cannot switch from "
                            "manual field specification to "
                            "automatic field numbering");
            return 1;
        }
    }
    else {
        if (!field_name_is_empty.asBool) {
            PyErr_SetString(PyExc_ValueError, "cannot switch from "
                            "automatic field numbering to "
                            "manual field specification");
            return 1;
        }
    }
    return 0;
}
func Py_UNICODE_TODECIMAL(_ c:Character) -> Int{
    if c.isdecimal(),let n = c.unicode.properties.numericValue {
        return Int(n)
    }
    return -1
}
func PyUnicode_READ_CHAR(_ str:PyObject?,_ index: Int) -> Character{
    return (str as! String)[index]
}

/************************************************************************/
/***********  Format string parsing -- integers and identifiers *********/
/************************************************************************/

func get_integer(_ str: SubString) -> Py_ssize_t
{
    var accumulator:Py_ssize_t = 0
    var digitval:Py_ssize_t
    var i:Py_ssize_t

    /* empty string is an error */
    if (str.start >= str.end){
        return -1;

    }
    i = str.start
    while i < str.end {
        digitval = Py_UNICODE_TODECIMAL(PyUnicode_READ_CHAR(str.str, i));
        if (digitval < 0){
            return -1;
        }
        /*
           Detect possible overflow before it happens:

              accumulator * 10 + digitval > PY_SSIZE_T_MAX if and only if
              accumulator > (PY_SSIZE_T_MAX - digitval) / 10.
        */
        if (accumulator > (PY_SSIZE_T_MAX - digitval) / 10) {
            PyErr_Format(PyExc_ValueError,
                         "Too many decimal digits in format string");
            return -1;
        }
        accumulator = accumulator * 10 + digitval;
        i++
    }
    return accumulator;
}

func PyObject_GetAttr(_ v:PyObject?, _ name:PyObject?) -> PyObject?
{
    let mirror = Mirror(reflecting: v)
    let c = mirror.children
    var keyMap:[String:Any]
    for i in c {
        keyMap[i.label!] = i.value
    }

    if (!PyUnicode_Check(name)) {
        PyErr_Format(PyExc_TypeError,
                     "attribute name must be string, not '%.200s'",
                     name->ob_type->tp_name);
        return NULL;
    }
    PyErr_Format(PyExc_AttributeError,
                 "'%.50s' object has no attribute '%U'",
                 tp->tp_name, name);
    return nil;
}
func PySequence_GetItem(_ s:PyObject, _ i:Py_ssize_t) -> PyObject?
{

    if (s == nil) {
        return null_error();
    }

    return (s as! Array)[i]
    if (s->ob_type->tp_as_mapping && s->ob_type->tp_as_mapping->mp_subscript) {
        return type_error("%.200s is not a sequence", s);
    }
    return type_error("'%.200s' object does not support indexing", s);
}


/************************************************************************/
/******** Functions to get field objects and specification strings ******/
/************************************************************************/

/* do the equivalent of obj.name */
func getattr(_ obj:PyObject?, _ name:SubString) -> PyObject?
{
    var newobj:PyObject?
    var str:PyObject? = SubString_new_object(name);
    if (str == nil){
        return nil
    }
    newobj = PyObject_GetAttr(obj, str);
    return newobj;
}

/* do the equivalent of obj[idx], where obj is a sequence */
func getitem_sequence(_ obj:PyObject, _ idx:Py_ssize_t) -> PyObject?
{
    return PySequence_GetItem(obj, idx);
}

/* do the equivalent of obj[idx], where obj is not a sequence */
static PyObject *
getitem_idx(PyObject *obj, Py_ssize_t idx)
{
    PyObject *newobj;
    PyObject *idx_obj = PyLong_FromSsize_t(idx);
    if (idx_obj == NULL)
        return NULL;
    newobj = PyObject_GetItem(obj, idx_obj);
    Py_DECREF(idx_obj);
    return newobj;
}

/* do the equivalent of obj[name] */
static PyObject *
getitem_str(PyObject *obj, SubString *name)
{
    PyObject *newobj;
    PyObject *str = SubString_new_object(name);
    if (str == NULL)
        return NULL;
    newobj = PyObject_GetItem(obj, str);
    Py_DECREF(str);
    return newobj;
}

struct FieldNameIterator {
    /* the entire string we're parsing.  we assume that someone else
       is managing its lifetime, and that it will exist for the
       lifetime of the iterator.  can be empty */
    var str:SubString

    /* index to where we are inside field_name */
    var index:Py_ssize_t
    
    init(_ s:PyObject,
         _ start:Py_ssize_t, _ end:Py_ssize_t){
        self.str = .init(s, start, end)
        self.index = start;
    }
}

static int
_FieldNameIterator_attr(FieldNameIterator *self, SubString *name)
{
    var c:Py_UCS4

    name->str = self->str.str;
    name->start = self->index;

    /* return everything until '.' or '[' */
    while (self->index < self->str.end) {
        c = PyUnicode_READ_CHAR(self->str.str, self->index++);
        switch (c) {
        case "[", ".":
            /* backup so that we this character will be seen next time */
            self->index--;
            break;
        default:
            continue;
        }
        break;
    }
    /* end of string is okay */
    name->end = self->index;
    return 1;
}

static int
_FieldNameIterator_item(FieldNameIterator *self, SubString *name)
{
    int bracket_seen = 0;
    Py_UCS4 c;

    name->str = self->str.str;
    name->start = self->index;

    /* return everything until ']' */
    while (self->index < self->str.end) {
        c = PyUnicode_READ_CHAR(self->str.str, self->index++);
        switch (c) {
        case "]":
            bracket_seen = 1;
            break;
        default:
            continue;
        }
        break;
    }
    /* make sure we ended with a ']' */
    if (!bracket_seen) {
        PyErr_SetString(PyExc_ValueError, "Missing ']' in format string");
        return 0;
    }

    /* end of string is okay */
    /* don't include the ']' */
    name->end = self->index-1;
    return 1;
}

/* returns 0 on error, 1 on non-error termination, and 2 if it returns a value */
static int
FieldNameIterator_next(FieldNameIterator *self, int *is_attribute,
                       Py_ssize_t *name_idx, SubString *name)
{
    /* check at end of input */
    if (self->index >= self->str.end)
        return 1;

    switch (PyUnicode_READ_CHAR(self->str.str, self->index++)) {
    case ".":
        *is_attribute = 1;
        if (_FieldNameIterator_attr(self, name) == 0)
            return 0;
        *name_idx = -1;
        break;
    case "[":
        *is_attribute = 0;
        if (_FieldNameIterator_item(self, name) == 0)
            return 0;
        *name_idx = get_integer(name);
        if (*name_idx == -1 && PyErr_Occurred())
            return 0;
        break;
    default:
        /* Invalid character follows ']' */
        PyErr_SetString(PyExc_ValueError, "Only '.' or '[' may "
                        "follow ']' in format field specifier");
        return 0;
    }

    /* empty string is an error */
    if (name->start == name->end) {
        PyErr_SetString(PyExc_ValueError, "Empty attribute in format string");
        return 0;
    }

    return 2;
}


/* input: field_name
   output: 'first' points to the part before the first '[' or '.'
           'first_idx' is -1 if 'first' is not an integer, otherwise
                       it's the value of first converted to an integer
           'rest' is an iterator to return the rest
*/
static int
field_name_split(PyObject *str, Py_ssize_t start, Py_ssize_t end, SubString *first,
                 Py_ssize_t *first_idx, FieldNameIterator *rest,
                 AutoNumber *auto_number)
{
    var c:Py_UCS4
    var i:Py_ssize_t = start;
    int field_name_is_empty;
    int using_numeric_index;

    /* find the part up until the first '.' or '[' */
    while (i < end) {
        switch (c = PyUnicode_READ_CHAR(str, i++)) {
        case "[", ".":
            /* backup so that we this character is available to the
               "rest" iterator */
            i--;
            break;
        default:
            continue;
        }
        break;
    }

    /* set up the return values */
    first = .init(str, start, i)
    rest = .init(str, i, end)

    /* see if "first" is an integer, in which case it's used as an index */
    *first_idx = get_integer(first);
    if (*first_idx == -1 && PyErr_Occurred())
        return 0;

    field_name_is_empty = first->start >= first->end;

    /* If the field name is omitted or if we have a numeric index
       specified, then we're doing numeric indexing into args. */
    using_numeric_index = field_name_is_empty || *first_idx != -1;

    /* We always get here exactly one time for each field we're
       processing. And we get here in field order (counting by left
       braces). So this is the perfect place to handle automatic field
       numbering if the field name is omitted. */

    /* Check if we need to do the auto-numbering. It's not needed if
       we're called from string.Format routines, because it's handled
       in that class by itself. */
    if (auto_number) {
        /* Initialize our auto numbering state if this is the first
           time we're either auto-numbering or manually numbering. */
        if (auto_number.an_state == .ANS_INIT && using_numeric_index)
        {
            auto_number.an_state = field_name_is_empty ? .ANS_AUTO : .ANS_MANUAL;
        }

        /* Make sure our state is consistent with what we're doing
           this time through. Only check if we're using a numeric
           index. */
        if (using_numeric_index){
            if (autonumber_state_error(auto_number->an_state,
                                       field_name_is_empty))
                {return 0;}}
        /* Zero length field means we want to do auto-numbering of the
           fields. */
        if (field_name_is_empty)
            {*first_idx = (auto_number->an_field_number)++;}
    }

    return 1;
}


/*
    get_field_object returns the object inside {}, before the
    format_spec.  It handles getindex and getattr lookups and consumes
    the entire input string.
*/
static PyObject *
get_field_object(SubString *input, PyObject *args, PyObject *kwargs,
                 AutoNumber *auto_number)
{
    PyObject *obj = NULL;
    int ok;
    int is_attribute;
    SubString name;
    SubString first;
    Py_ssize_t index;
    FieldNameIterator rest;

    if (!field_name_split(input->str, input->start, input->end, &first,
                          &index, &rest, auto_number)) {
        goto error;
    }

    if (index == -1) {
        /* look up in kwargs */
        PyObject *key = SubString_new_object(&first);
        if (key == NULL) {
            goto error;
        }
        if (kwargs == NULL) {
            PyErr_SetObject(PyExc_KeyError, key);
            Py_DECREF(key);
            goto error;
        }
        /* Use PyObject_GetItem instead of PyDict_GetItem because this
           code is no longer just used with kwargs. It might be passed
           a non-dict when called through format_map. */
        obj = PyObject_GetItem(kwargs, key);
        Py_DECREF(key);
        if (obj == NULL) {
            goto error;
        }
    }
    else {
        /* If args is NULL, we have a format string with a positional field
           with only kwargs to retrieve it from. This can only happen when
           used with format_map(), where positional arguments are not
           allowed. */
        if (args == NULL) {
            PyErr_SetString(PyExc_ValueError, "Format string contains "
                            "positional fields");
            goto error;
        }

        /* look up in args */
        obj = PySequence_GetItem(args, index);
        if (obj == NULL) {
            PyErr_Format(PyExc_IndexError,
                         "Replacement index %zd out of range for positional "
                         "args tuple",
                         index);
             goto error;
        }
    }

    /* iterate over the rest of the field_name */
    while ((ok = FieldNameIterator_next(&rest, &is_attribute, &index,
                                        &name)) == 2) {
        PyObject *tmp;

        if (is_attribute)
            /* getattr lookup "." */
            tmp = getattr(obj, &name);
        else
            /* getitem lookup "[]" */
            if (index == -1)
                tmp = getitem_str(obj, &name);
            else
                if (PySequence_Check(obj))
                    tmp = getitem_sequence(obj, index);
                else
                    /* not a sequence */
                    tmp = getitem_idx(obj, index);
        if (tmp == NULL)
            goto error;

        /* assign to obj */
        Py_DECREF(obj);
        obj = tmp;
    }
    /* end of iterator, this is the non-error case */
    if (ok == 1)
        return obj;
error:
    Py_XDECREF(obj);
    return NULL;
}

/************************************************************************/
/*****************  Field rendering functions  **************************/
/************************************************************************/

/*
    render_field() is the main function in this section.  It takes the
    field object and field specification string generated by
    get_field_and_spec, and renders the field into the output string.

    render_field calls fieldobj.__format__(format_spec) method, and
    appends to the output.
*/
static int
render_field(PyObject *fieldobj, SubString *format_spec, _PyUnicodeWriter *writer)
{
    int ok = 0;
    PyObject *result = NULL;
    PyObject *format_spec_object = NULL;
    int (*formatter) (_PyUnicodeWriter*, PyObject *, PyObject *, Py_ssize_t, Py_ssize_t) = NULL;
    int err;

    /* If we know the type exactly, skip the lookup of __format__ and just
       call the formatter directly. */
    if (PyUnicode_CheckExact(fieldobj))
        formatter = _PyUnicode_FormatAdvancedWriter;
    else if (PyLong_CheckExact(fieldobj))
        formatter = _PyLong_FormatAdvancedWriter;
    else if (PyFloat_CheckExact(fieldobj))
        formatter = _PyFloat_FormatAdvancedWriter;
    else if (PyComplex_CheckExact(fieldobj))
        formatter = _PyComplex_FormatAdvancedWriter;

    if (formatter) {
        /* we know exactly which formatter will be called when __format__ is
           looked up, so call it directly, instead. */
        err = formatter(writer, fieldobj, format_spec->str,
                        format_spec->start, format_spec->end);
        return (err == 0);
    }
    else {
        /* We need to create an object out of the pointers we have, because
           __format__ takes a string/unicode object for format_spec. */
        if (format_spec->str)
            format_spec_object = PyUnicode_Substring(format_spec->str,
                                                     format_spec->start,
                                                     format_spec->end);
        else
            format_spec_object = PyUnicode_New(0, 0);
        if (format_spec_object == NULL)
            goto done;

        result = PyObject_Format(fieldobj, format_spec_object);
    }
    if (result == NULL)
        goto done;

    if (_PyUnicodeWriter_WriteStr(writer, result) == -1)
        goto done;
    ok = 1;

done:
    Py_XDECREF(format_spec_object);
    Py_XDECREF(result);
    return ok;
}

static int
parse_field(SubString *str, SubString *field_name, SubString *format_spec,
            int *format_spec_needs_expanding, Py_UCS4 *conversion)
{
    /* Note this function works if the field name is zero length,
       which is good.  Zero length field names are handled later, in
       field_name_split. */

    Py_UCS4 c = 0;

    /* initialize these, as they may be empty */
    *conversion = "\0";
    format_spec = .init(nil, 0, 0);

    /* Search for the field name.  it's terminated by the end of
       the string, or a ':' or '!' */
    field_name->str = str->str;
    field_name->start = str->start;
    while (str->start < str->end) {
        switch ((c = PyUnicode_READ_CHAR(str->str, str->start++))) {
        case "{":
            PyErr_SetString(PyExc_ValueError, "unexpected '{' in field name");
            return 0;
        case "[":
            for (; str->start < str->end; str->start++){
                if (PyUnicode_READ_CHAR(str->str, str->start) == "]"){
                    break;
                }
            }
            continue;
        case "}":
        case ":":
        case "!":
            break;
        default:
            continue;
        }
        break;
    }

    field_name->end = str->start - 1;
    if (c == "!" || c == ":") {
        Py_ssize_t; count;
        /* we have a format specifier and/or a conversion */
        /* don't include the last character */

        /* see if there's a conversion specifier */
        if (c == "!") {
            /* there must be another character present */
            if (str->start >= str->end) {
                PyErr_SetString(PyExc_ValueError,
                                "end of string while looking for conversion "
                                "specifier");
                return 0;
            }
            *conversion = PyUnicode_READ_CHAR(str->str, str->start++);

            if (str->start < str->end) {
                c = PyUnicode_READ_CHAR(str->str, str->start++);
                if (c == "}")
                    {return 1;}
                if (c != ":") {
                    PyErr_SetString(PyExc_ValueError,
                                    "expected ':' after conversion specifier");
                    return 0;
                }
            }
        }
        format_spec->str = str->str;
        format_spec->start = str->start;
        count = 1;
        while (str->start < str->end) {
            switch ((c = PyUnicode_READ_CHAR(str->str, str->start++))) {
            case "{":
                *format_spec_needs_expanding = 1;
                count++;
                break;
            case "}":
                count--;
                if (count == 0) {
                    format_spec->end = str->start - 1;
                    return 1;
                }
                break;
            default:
                break;
            }
        }

        PyErr_SetString(PyExc_ValueError, "unmatched '{' in format spec");
        return 0;
    }
    else if (c != '}') {
        PyErr_SetString(PyExc_ValueError, "expected '}' before end of string");
        return 0;
    }

    return 1;
}

/************************************************************************/
/******* Output string allocation and escape-to-markup processing  ******/
/************************************************************************/

/* MarkupIterator breaks the string into pieces of either literal
   text, or things inside {} that need to be marked up.  it is
   designed to make it easy to wrap a Python iterator around it, for
   use with the Formatter class */

struct MarkupIterator {
    var str:SubString
    
    init(_ str:PyObject,
         _ start:Py_ssize_t, _ end:Py_ssize_t){
        self.str = .init(str, start, end)
    }
}

/* returns 0 on error, 1 on non-error termination, and 2 if it got a
   string (or something to be expanded) */
static int
MarkupIterator_next(MarkupIterator *self, SubString *literal,
                    int *field_present, SubString *field_name,
                    SubString *format_spec, Py_UCS4 *conversion,
                    int *format_spec_needs_expanding)
{
    var at_end:int
    var start:Py_ssize_t
    var len:Py_ssize_t
    int markup_follows = 0;

    /* initialize all of the output variables */
    literal = .init(nil, 0, 0)
    field_name = .init(nil, 0, 0)
    format_spec = .init(nil, 0, 0)
    *conversion = "\0";
    *format_spec_needs_expanding = 0;
    *field_present = 0;

    /* No more input, end of iterator.  This is the normal exit
       path. */
    if (self->str.start >= self->str.end){
        return 1;
    }

    start = self->str.start;

    /* First read any literal text. Read until the end of string, an
       escaped '{' or '}', or an unescaped '{'.  In order to never
       allocate memory and so I can just pass pointers around, if
       there's an escaped '{' or '}' then we'll return the literal
       including the brace, but no format object.  The next time
       through, we'll return the rest of the literal, skipping past
       the second consecutive brace. */
    var c:Py_UCS4 = 0
    while (self->str.start < self->str.end) {
        c = PyUnicode_READ_CHAR(self->str.str, self->str.start++)
        switch c {
        case "{", "}":
            markup_follows = 1;
            break;
        default:
            continue;
        }
        break;
    }

    at_end = self->str.start >= self->str.end;
    len = self->str.start - start;

    if ((c == "}") && (at_end ||
                       (c != PyUnicode_READ_CHAR(self->str.str,
                                                 self->str.start)))) {
        PyErr_SetString(PyExc_ValueError, "Single '}' encountered "
                        "in format string");
        return 0;
    }
    if (at_end && c == "{") {
        PyErr_SetString(PyExc_ValueError, "Single '{' encountered "
                        "in format string");
        return 0;
    }
    if (!at_end) {
        if (c == PyUnicode_READ_CHAR(self->str.str, self->str.start)) {
            /* escaped } or {, skip it in the input.  there is no
               markup object following us, just this literal text */
            self->str.start++;
            markup_follows = 0;
        }
        else{
            len--
        }
    }

    /* record the literal text */
    literal->str = self->str.str;
    literal->start = start;
    literal->end = start + len;

    if (!markup_follows){
        return 2;
    }

    /* this is markup; parse the field */
    *field_present = 1;
    if (!parse_field(&self->str, field_name, format_spec,
                     format_spec_needs_expanding, conversion)){
        return 0;
    }
    return 2;
}


/* do the !r or !s conversion on obj */
func
    do_conversion(obj:PyObject?, _ conversion:Py_UCS4) -> String?
{
    /* XXX in pre-3.0, do we need to convert this to unicode, since it
       might have returned a string? */
    switch (conversion) {
    case "r", "s", "a":
        return (obj as? PSFormattable)?.convertField(conversion)
    default:
        if (conversion > 32 && conversion < 127) {
                /* It's the ASCII subrange; casting to char is safe
                   (assuming the execution character set is an ASCII
                   superset). */
                PyErr_Format(PyExc_ValueError,
                     "Unknown conversion specifier %c",
                     (char)conversion);
        } else
                PyErr_Format(PyExc_ValueError,
                     "Unknown conversion specifier \\x%x",
                     (unsigned int)conversion);
        return nil;
    }
}

/* given:

   {field_name!conversion:format_spec}

   compute the result and write it to output.
   format_spec_needs_expanding is an optimization.  if it's false,
   just output the string directly, otherwise recursively expand the
   format_spec string.

   field_name is allowed to be zero length, in which case we
   are doing auto field numbering.
*/

static int
output_markup(SubString *field_name, SubString *format_spec,
              int format_spec_needs_expanding, Py_UCS4 conversion,
              _PyUnicodeWriter *writer, PyObject *args, PyObject *kwargs,
              int recursion_depth, AutoNumber *auto_number)
{
    PyObject *tmp = NULL;
    PyObject *fieldobj = NULL;
    SubString expanded_format_spec;
    SubString *actual_format_spec;
    int result = 0;

    /* convert field_name to an object */
    fieldobj = get_field_object(field_name, args, kwargs, auto_number);
    if (fieldobj == NULL)
        goto done;

    if (conversion != "\0") {
        tmp = do_conversion(fieldobj, conversion);
        if (tmp == NULL || PyUnicode_READY(tmp) == -1)
            goto done;

        /* do the assignment, transferring ownership: fieldobj = tmp */
        Py_DECREF(fieldobj);
        fieldobj = tmp;
        tmp = NULL;
    }

    /* if needed, recurively compute the format_spec */
    if (format_spec_needs_expanding) {
        tmp = build_string(format_spec, args, kwargs, recursion_depth-1,
                           auto_number);
        if (tmp == NULL || PyUnicode_READY(tmp) == -1){
            goto done;
        }

        /* note that in the case we're expanding the format string,
           tmp must be kept around until after the call to
           render_field. */
        expanded_format_spec = .init(tmp, 0, PyUnicode_GET_LENGTH(tmp));
        actual_format_spec = &expanded_format_spec;
    }
    else{
        actual_format_spec = format_spec;
    }
    if (render_field(fieldobj, actual_format_spec, writer) == 0){
        goto done;
    }

    result = 1;

done:
    Py_XDECREF(fieldobj);
    Py_XDECREF(tmp);

    return result;
}

/*
    do_markup is the top-level loop for the format() method.  It
    searches through the format string for escapes to markup codes, and
    calls other functions to move non-markup text to the output,
    and to perform the markup to the output.
*/
static int
do_markup(SubString *input, PyObject *args, PyObject *kwargs,
          _PyUnicodeWriter *writer, int recursion_depth, AutoNumber *auto_number)
{
    MarkupIterator iter;
    int format_spec_needs_expanding;
    int result;
    int field_present;
    SubString literal;
    SubString field_name;
    SubString format_spec;
    Py_UCS4 conversion;

    iter =.init( input->str, input->start, input->end)
    while ((result = MarkupIterator_next(&iter, &literal, &field_present,
                                         &field_name, &format_spec,
                                         &conversion,
                                         &format_spec_needs_expanding)) == 2) {
        if (literal.end != literal.start) {
            if (!field_present && iter.str.start == iter.str.end)
                writer->overallocate = 0;
            if (_PyUnicodeWriter_WriteSubstring(writer, literal.str,
                                                literal.start, literal.end) < 0)
                return 0;
        }

        if (field_present) {
            if (iter.str.start == iter.str.end)
                writer->overallocate = 0;
            if (!output_markup(&field_name, &format_spec,
                               format_spec_needs_expanding, conversion, writer,
                               args, kwargs, recursion_depth, auto_number))
                return 0;
        }
    }
    return result;
}


/*
    build_string allocates the output string and then
    calls do_markup to do the heavy lifting.
*/
func build_string(_ input:SubString, _ args:PyObject, _ kwargs:PyObject,
                  _ recursion_depth:int, _ auto_number: AutoNumber) -> PyObject?
{
    _PyUnicodeWriter writer;

    /* check the recursion level */
    if (recursion_depth <= 0) {
        PyErr_SetString(PyExc_ValueError,
                        "Max string recursion exceeded");
        return nil;
    }

    _PyUnicodeWriter_Init(&writer);
    writer.overallocate = 1;
    writer.min_length = PyUnicode_GET_LENGTH(input.str) + 100;

    if (!do_markup(input, args, kwargs, &writer, recursion_depth,
                   auto_number)) {
        _PyUnicodeWriter_Dealloc(&writer);
        return nil;
    }

    return _PyUnicodeWriter_Finish(&writer);
}

/************************************************************************/
/*********** main routine ***********************************************/
/************************************************************************/

/* this is the main entry point */
func do_string_format(_ self:PyObject, _ args:PyObject, _ kwargs:PyObject) -> PyObject?
{

    /* PEP 3101 says only 2 levels, so that
       "{0:{1}}".format('abc', 's')            # works
       "{0:{1:{2}}}".format('abc', 's', '')    # fails
    */
    var recursion_depth: int = 2

    var auto_number: AutoNumber


    var input:SubString = .init(self, 0, (self as! String).count);
    return build_string(input, args, kwargs, recursion_depth, auto_number);
}


/************************************************************************/
/*********** formatteriterator ******************************************/
/************************************************************************/

/* This is used to implement string.Formatter.vparse().  It exists so
   Formatter can share code with the built in unicode.format() method.
   It's really just a wrapper around MarkupIterator that is callable
   from Python. */

struct formatteriterobject {
    PyObject_HEAD
    PyObject *str;
    MarkupIterator it_markup;
}

static void
formatteriter_dealloc(formatteriterobject *it)
{
    Py_XDECREF(it->str);
    PyObject_FREE(it);
}

/* returns a tuple:
   (literal, field_name, format_spec, conversion)

   literal is any literal text to output.  might be zero length
   field_name is the string before the ':'.  might be None
   format_spec is the string after the ':'.  mibht be None
   conversion is either None, or the string after the '!'
*/
static PyObject *
formatteriter_next(formatteriterobject *it)
{
    SubString literal;
    SubString field_name;
    SubString format_spec;
    Py_UCS4 conversion;
    int format_spec_needs_expanding;
    int field_present;
    int result = MarkupIterator_next(&it->it_markup, &literal, &field_present,
                                     &field_name, &format_spec, &conversion,
                                     &format_spec_needs_expanding);

    /* all of the SubString objects point into it->str, so no
       memory management needs to be done on them */
    assert(0 <= result && result <= 2);
    if (result == 0 || result == 1)
        /* if 0, error has already been set, if 1, iterator is empty */
        return NULL;
    else {
        PyObject *literal_str = NULL;
        PyObject *field_name_str = NULL;
        PyObject *format_spec_str = NULL;
        PyObject *conversion_str = NULL;
        PyObject *tuple = NULL;

        literal_str = SubString_new_object(&literal);
        if (literal_str == NULL)
            goto done;

        field_name_str = SubString_new_object(&field_name);
        if (field_name_str == NULL)
            goto done;

        /* if field_name is non-zero length, return a string for
           format_spec (even if zero length), else return None */
        format_spec_str = (field_present ?
                           SubString_new_object_or_empty :
                           SubString_new_object)(&format_spec);
        if (format_spec_str == NULL)
            goto done;

        /* if the conversion is not specified, return a None,
           otherwise create a one length string with the conversion
           character */
        if (conversion == "\0") {
            conversion_str = Py_None;
            Py_INCREF(conversion_str);
        }
        else
            conversion_str = PyUnicode_FromKindAndData(PyUnicode_4BYTE_KIND,
                                                       &conversion, 1);
        if (conversion_str == NULL)
            goto done;

        tuple = PyTuple_Pack(4, literal_str, field_name_str, format_spec_str,
                             conversion_str);
    done:
        Py_XDECREF(literal_str);
        Py_XDECREF(field_name_str);
        Py_XDECREF(format_spec_str);
        Py_XDECREF(conversion_str);
        return tuple;
    }
}

static PyMethodDef formatteriter_methods[] = {
    {NULL,              NULL}           /* sentinel */
};

static PyTypeObject PyFormatterIter_Type = {
    PyVarObject_HEAD_INIT(&PyType_Type, 0)
    "formatteriterator",                /* tp_name */
    sizeof(formatteriterobject),        /* tp_basicsize */
    0,                                  /* tp_itemsize */
    /* methods */
    (destructor)formatteriter_dealloc,  /* tp_dealloc */
    0,                                  /* tp_vectorcall_offset */
    0,                                  /* tp_getattr */
    0,                                  /* tp_setattr */
    0,                                  /* tp_as_async */
    0,                                  /* tp_repr */
    0,                                  /* tp_as_number */
    0,                                  /* tp_as_sequence */
    0,                                  /* tp_as_mapping */
    0,                                  /* tp_hash */
    0,                                  /* tp_call */
    0,                                  /* tp_str */
    PyObject_GenericGetAttr,            /* tp_getattro */
    0,                                  /* tp_setattro */
    0,                                  /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT,                 /* tp_flags */
    0,                                  /* tp_doc */
    0,                                  /* tp_traverse */
    0,                                  /* tp_clear */
    0,                                  /* tp_richcompare */
    0,                                  /* tp_weaklistoffset */
    PyObject_SelfIter,                  /* tp_iter */
    (iternextfunc)formatteriter_next,   /* tp_iternext */
    formatteriter_methods,              /* tp_methods */
    0,
};

/* unicode_formatter_parser is used to implement
   string.Formatter.vformat.  it parses a string and returns tuples
   describing the parsed elements.  It's a wrapper around
   stringlib/string_format.h's MarkupIterator */
static PyObject *
formatter_parser(PyObject *ignored, PyObject *self)
{
    formatteriterobject *it;

    if (!PyUnicode_Check(self)) {
        PyErr_Format(PyExc_TypeError, "expected str, got %s", Py_TYPE(self)->tp_name);
        return NULL;
    }

    if (PyUnicode_READY(self) == -1)
        return NULL;

    it = PyObject_New(formatteriterobject, &PyFormatterIter_Type);
    if (it == NULL){return nil}

    /* take ownership, give the object to the iterator */
    Py_INCREF(self);
    it->str = self;

    /* initialize the contained MarkupIterator */
    it->it_markup = .init( (PyObject*)self, 0, PyUnicode_GET_LENGTH(self));
    return (PyObject *)it;
}


/************************************************************************/
/*********** fieldnameiterator ******************************************/
/************************************************************************/


/* This is used to implement string.Formatter.vparse().  It parses the
   field name into attribute and item values.  It's a Python-callable
   wrapper around FieldNameIterator */

struct fieldnameiterobject {
    var ob_base:PyObject
    var str:PyObject
    var it_field:FieldNameIterator
}


/* returns a tuple:
   (is_attr, value)
   is_attr is true if we used attribute syntax (e.g., '.foo')
              false if we used index syntax (e.g., '[foo]')
   value is an integer or string
*/
static PyObject *
fieldnameiter_next(fieldnameiterobject *it)
{
    int result;
    int is_attr;
    Py_ssize_t idx;
    SubString name;

    result = FieldNameIterator_next(&it->it_field, &is_attr,
                                    &idx, &name);
    if (result == 0 || result == 1)
        /* if 0, error has already been set, if 1, iterator is empty */
        return NULL;
    else {
        PyObject* result = NULL;
        PyObject* is_attr_obj = NULL;
        PyObject* obj = NULL;

        is_attr_obj = PyBool_FromLong(is_attr);
        if (is_attr_obj == NULL)
            goto done;

        /* either an integer or a string */
        if (idx != -1)
            obj = PyLong_FromSsize_t(idx);
        else
            obj = SubString_new_object(&name);
        if (obj == NULL)
            goto done;

        /* return a tuple of values */
        result = PyTuple_Pack(2, is_attr_obj, obj);

    done:
        Py_XDECREF(is_attr_obj);
        Py_XDECREF(obj);
        return result;
    }
}

static PyMethodDef fieldnameiter_methods[] = {
    {NULL,              NULL}           /* sentinel */
};

static PyTypeObject PyFieldNameIter_Type = {
    PyVarObject_HEAD_INIT(&PyType_Type, 0)
    "fieldnameiterator",                /* tp_name */
    sizeof(fieldnameiterobject),        /* tp_basicsize */
    0,                                  /* tp_itemsize */
    /* methods */
    (destructor)fieldnameiter_dealloc,  /* tp_dealloc */
    0,                                  /* tp_vectorcall_offset */
    0,                                  /* tp_getattr */
    0,                                  /* tp_setattr */
    0,                                  /* tp_as_async */
    0,                                  /* tp_repr */
    0,                                  /* tp_as_number */
    0,                                  /* tp_as_sequence */
    0,                                  /* tp_as_mapping */
    0,                                  /* tp_hash */
    0,                                  /* tp_call */
    0,                                  /* tp_str */
    PyObject_GenericGetAttr,            /* tp_getattro */
    0,                                  /* tp_setattro */
    0,                                  /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT,                 /* tp_flags */
    0,                                  /* tp_doc */
    0,                                  /* tp_traverse */
    0,                                  /* tp_clear */
    0,                                  /* tp_richcompare */
    0,                                  /* tp_weaklistoffset */
    PyObject_SelfIter,                  /* tp_iter */
    (iternextfunc)fieldnameiter_next,   /* tp_iternext */
    fieldnameiter_methods,              /* tp_methods */
    0};

/* unicode_formatter_field_name_split is used to implement
   string.Formatter.vformat.  it takes a PEP 3101 "field name", and
   returns a tuple of (first, rest): "first", the part before the
   first '.' or '['; and "rest", an iterator for the rest of the field
   name.  it's a wrapper around stringlib/string_format.h's
   field_name_split.  The iterator it returns is a
   FieldNameIterator */
static PyObject *
formatter_field_name_split(PyObject *ignored, PyObject *self)
{
    SubString first;
    Py_ssize_t first_idx;
    fieldnameiterobject *it;

    PyObject *first_obj = NULL;
    PyObject *result = NULL;

    if (!PyUnicode_Check(self)) {
        PyErr_Format(PyExc_TypeError, "expected str, got %s", Py_TYPE(self)->tp_name);
        return NULL;
    }

    if (PyUnicode_READY(self) == -1)
        return NULL;

    it = PyObject_New(fieldnameiterobject, &PyFieldNameIter_Type);
    if (it == NULL)
        return NULL;

    /* take ownership, give the object to the iterator.  this is
       just to keep the field_name alive */
    Py_INCREF(self);
    it->str = self;

    /* Pass in auto_number = NULL. We'll return an empty string for
       first_obj in that case. */
    if (!field_name_split((PyObject*)self, 0, PyUnicode_GET_LENGTH(self),
                          &first, &first_idx, &it->it_field, NULL))
        goto done;

    /* first becomes an integer, if possible; else a string */
    if (first_idx != -1)
        first_obj = PyLong_FromSsize_t(first_idx);
    else
        /* convert "first" into a string object */
        first_obj = SubString_new_object(&first);
    if (first_obj == NULL)
        goto done;

    /* return a tuple of values */
    result = PyTuple_Pack(2, first_obj, it);

done:
    Py_XDECREF(it);
    Py_XDECREF(first_obj);
    return result;
}
/* implements the unicode (as opposed to string) version of the
   built-in formatters for string, int, float.  that is, the versions
   of int.__float__, etc., that take and return unicode objects */

#include "Python.h"
#include "pycore_fileutils.h"
#include <locale.h>

/* Raises an exception about an unknown presentation type for this
 * type. */
extension Py_UCS4 {
    var isRegularASCII: Bool {
        let v = self.unicode.value
        return 32 < v && v < 128
    }
}
func unknown_presentation_type(_ presentation_type:Py_UCS4,
                          const char* type_name)
{
    /* %c might be out-of-range, hence the two cases. */
    if (presentation_type.isRegularASCII )
        PyErr_Format(PyExc_ValueError,
                     "Unknown format code '%c' "
                     "for object of type '%.200s'",
                     (char)presentation_type,
                     type_name);
    else
        PyErr_Format(PyExc_ValueError,
                     "Unknown format code '\\x%x' "
                     "for object of type '%.200s'",
                     (unsigned int)presentation_type,
                     type_name);
}

func invalid_thousands_separator_type(_ specifier:Character, _ presentation_type:Py_UCS4)
{
    assert(specifier == "," || specifier == "_");
    if (presentation_type.isRegularASCII){
        PyErr_Format(PyExc_ValueError,
                     "Cannot specify '%c' with '%c'.",
                     specifier, (char)presentation_type);
    }    else {
        PyErr_Format(PyExc_ValueError,
                     "Cannot specify '%c' with '\\x%x'.",
                     specifier, (unsigned int)presentation_type);
    }
}

func invalid_comma_and_underscore()
{
    PyErr_Format(PyExc_ValueError, "Cannot specify both ',' and '_'.");
}

/*
    get_integer consumes 0 or more decimal digit characters from an
    input string, updates *result with the corresponding positive
    integer, and returns the number of digits consumed.

    returns -1 on error.
*/
static int
get_integer(PyObject *str, Py_ssize_t *ppos, Py_ssize_t end,
                  Py_ssize_t *result)
{
    Py_ssize_t accumulator, digitval, pos = *ppos;
    int numdigits;
    int kind = PyUnicode_KIND(str);
    void *data = PyUnicode_DATA(str);

    accumulator = numdigits = 0;
    for (; pos < end; pos++, numdigits++) {
        digitval = Py_UNICODE_TODECIMAL(PyUnicode_READ(kind, data, pos));
        if (digitval < 0)
            break;
        /*
           Detect possible overflow before it happens:

              accumulator * 10 + digitval > PY_SSIZE_T_MAX if and only if
              accumulator > (PY_SSIZE_T_MAX - digitval) / 10.
        */
        if (accumulator > (PY_SSIZE_T_MAX - digitval) / 10) {
            PyErr_Format(PyExc_ValueError,
                         "Too many decimal digits in format string");
            *ppos = pos;
            return -1;
        }
        accumulator = accumulator * 10 + digitval;
    }
    *ppos = pos;
    *result = accumulator;
    return numdigits;
}

/************************************************************************/
/*********** standard format specifier parsing **************************/
/************************************************************************/

/* returns true if this character is a specifier alignment token */
func is_alignment_token(_ c:Py_UCS4) -> int
{
    switch (c) {
    case "<", ">", "=", "^":
        return 1;
    default:
        return 0;
    }
}

extension Int {
    var asBool: Bool{
        return self != 0
    }
}

/* returns true if this character is a sign element */
func is_sign_element(_ c:Py_UCS4) -> int
{
    switch (c) {
    case " ", "+", "-":
        return 1;
    default:
        return 0;
    }
}

/* Locale type codes. LT_NO_LOCALE must be zero. */
enum LocaleType: Character {
    case LT_NO_LOCALE = "\0"
    case LT_DEFAULT_LOCALE = ","
    case LT_UNDERSCORE_LOCALE = "_"
    case LT_UNDER_FOUR_LOCALE = "`"
    case LT_CURRENT_LOCALE = "a"
}

struct InternalFormatSpec {
    var fill_char:Py_UCS4
    var align:Py_UCS4
    var alternate:int
    var sign:Py_UCS4
    var width:Py_ssize_t
    var thousands_separators:LocaleType
    var precision:Py_ssize_t
    var type:Py_UCS4
}
extension InternalFormatSpec: CustomDebugStringConvertible {
    /* Occasionally useful for debugging. Should normally be commented out. */
    var debugDescription: String {
        return String(format:"internal format spec: fill_char %d\n", fill_char) +
        String(format:"internal format spec: align %d\n", align) +
        String(format:"internal format spec: alternate %d\n", alternate) +
        String(format:"internal format spec: sign %d\n", sign) +
        String(format:"internal format spec: width %zd\n", width) +
        String(format:"internal format spec: thousands_separators %d\n",
               thousands_separators) +
        String(format:"internal format spec: precision %zd\n", precision) +
        String(format:"internal format spec: type %c\n", type)
    }
}


/*
  ptr points to the start of the format_spec, end points just past its end.
  fills in format with the parsed information.
  returns 1 on success, 0 on failure.
  if failure, sets the exception
*/
static int
parse_internal_render_format_spec(PyObject *format_spec,
                                  Py_ssize_t start, Py_ssize_t end,
                                  InternalFormatSpec *format,
                                  char default_type,
                                  char default_align)
{
    Py_ssize_t pos = start;
    int kind = PyUnicode_KIND(format_spec);
    void *data = PyUnicode_DATA(format_spec);
    /* end-pos is used throughout this code to specify the length of
       the input string */
#define READ_spec(index) PyUnicode_READ(kind, data, index)

    Py_ssize_t consumed;
    int align_specified = 0;
    int fill_char_specified = 0;

    format->fill_char = " ";
    format->align = default_align;
    format->alternate = 0;
    format->sign = "\0";
    format->width = -1;
    format->thousands_separators = LT_NO_LOCALE;
    format->precision = -1;
    format->type = default_type;

    /* If the second char is an alignment token,
       then parse the fill char */
    if (end-pos >= 2 && is_alignment_token(READ_spec(pos+1))) {
        format->align = READ_spec(pos+1);
        format->fill_char = READ_spec(pos);
        fill_char_specified = 1;
        align_specified = 1;
        pos += 2;
    }
    else if (end-pos >= 1 && is_alignment_token(READ_spec(pos))) {
        format->align = READ_spec(pos);
        align_specified = 1;
        ++pos;
    }

    /* Parse the various sign options */
    if (end-pos >= 1 && is_sign_element(READ_spec(pos))) {
        format->sign = READ_spec(pos);
        ++pos;
    }

    /* If the next character is #, we're in alternate mode.  This only
       applies to integers. */
    if (end-pos >= 1 && READ_spec(pos) == "#") {
        format->alternate = 1;
        ++pos;
    }

    /* The special case for 0-padding (backwards compat) */
    if (!fill_char_specified && end-pos >= 1 && READ_spec(pos) == "0") {
        format->fill_char = "0";
        if (!align_specified) {
            format->align = "=";
        }
        ++pos;
    }

    consumed = get_integer(format_spec, &pos, end, &format->width);
    if (consumed == -1){
        /* Overflow error. Exception already set. */
        return 0;
    }

    /* If consumed is 0, we didn't consume any characters for the
       width. In that case, reset the width to -1, because
       get_integer() will have set it to zero. -1 is how we record
       that the width wasn't specified. */
    if (consumed == 0){
        format->width = -1;
    }

    /* Comma signifies add thousands separators */
    if (end-pos && READ_spec(pos) == ",") {
        format->thousands_separators = LT_DEFAULT_LOCALE;
        ++pos;
    }
    /* Underscore signifies add thousands separators */
    if (end-pos && READ_spec(pos) == "_") {
        if (format->thousands_separators != LT_NO_LOCALE) {
            invalid_comma_and_underscore();
            return 0;
        }
        format->thousands_separators = LT_UNDERSCORE_LOCALE;
        ++pos;
    }
    if (end-pos && READ_spec(pos) == ",") {
        invalid_comma_and_underscore();
        return 0;
    }

    /* Parse field precision */
    if (end-pos && READ_spec(pos) == ".") {
        ++pos;

        consumed = get_integer(format_spec, &pos, end, &format->precision);
        if (consumed == -1){
            /* Overflow error. Exception already set. */
            return 0;}

        /* Not having a precision after a dot is an error. */
        if (consumed == 0) {
            PyErr_Format(PyExc_ValueError,
                         "Format specifier missing precision");
            return 0;
        }

    }

    /* Finally, parse the type field. */

    if (end-pos > 1) {
        /* More than one char remain, invalid format specifier. */
        PyErr_Format(PyExc_ValueError, "Invalid format specifier");
        return 0;
    }

    if (end-pos == 1) {
        format->type = READ_spec(pos);
        ++pos;
    }

    /* Do as much validating as we can, just by looking at the format
       specifier.  Do not take into account what type of formatting
       we're doing (int, float, string). */

    if (format->thousands_separators) {
        switch (format->type) {
        case "d", "e", "f", "g", "E", "G", "%", "F", "\0":
            /* These are allowed. See PEP 378.*/
            break;
        case "b", "o", "x", "X":
            /* Underscores are allowed in bin/oct/hex. See PEP 515. */
            if (format->thousands_separators == LT_UNDERSCORE_LOCALE) {
                /* Every four digits, not every three, in bin/oct/hex. */
                format->thousands_separators = LT_UNDER_FOUR_LOCALE;
                break;
            }
            fallthrough
        default:
            invalid_thousands_separator_type(format->thousands_separators, format->type);
            return 0;
        }
    }

    assert (format->align <= 127);
    assert (format->sign <= 127);
    return 1;
}

/* Calculate the padding needed. */
static void
calc_padding(Py_ssize_t nchars, Py_ssize_t width, Py_UCS4 align,
             Py_ssize_t *n_lpadding, Py_ssize_t *n_rpadding,
             Py_ssize_t *n_total)
{
    if (width >= 0) {
        if (nchars > width){
            *n_total = nchars;
        }
        else{
            *n_total = width;
        }
    }
    else {
        /* not specified, use all of the chars and no more */
        *n_total = nchars;
    }

    /* Figure out how much leading space we need, based on the
       aligning */
    if (align == ">")
        {*n_lpadding = *n_total - nchars}
    else if (align == "^")
       { *n_lpadding = (*n_total - nchars) / 2}
    else if (align == "<" || align == '=')
        {*n_lpadding = 0}
    else {
        /* We should never have an unspecified alignment. */
        Py_UNREACHABLE();
    }

    *n_rpadding = *n_total - nchars - *n_lpadding;
}

/* Do the padding, and return a pointer to where the caller-supplied
   content goes. */
static int
fill_padding(_PyUnicodeWriter *writer,
             Py_ssize_t nchars,
             Py_UCS4 fill_char, Py_ssize_t n_lpadding,
             Py_ssize_t n_rpadding)
{
    Py_ssize_t pos;

    /* Pad on left. */
    if (n_lpadding) {
        pos = writer->pos;
        _PyUnicode_FastFill(writer->buffer, pos, n_lpadding, fill_char);
    }

    /* Pad on right. */
    if (n_rpadding) {
        pos = writer->pos + nchars + n_lpadding;
        _PyUnicode_FastFill(writer->buffer, pos, n_rpadding, fill_char);
    }

    /* Pointer to the user content. */
    writer->pos += n_lpadding;
    return 0;
}

/************************************************************************/
/*********** common routines for numeric formatting *********************/
/************************************************************************/

/* Locale info needed for formatting integers and the part of floats
   before and including the decimal. Note that locales only support
   8-bit chars, not unicode. */
struct LocaleInfo {
    var decimal_point: PyObject?
    var thousands_sep: PyObject?
    const char *grouping;// = 0
    char *grouping_buffer;// = 0
    
    init() {
        decimal_point = nil
        thousands_sep = nil
    }
}

/* describes the layout for an integer, see the comment in
   calc_number_widths() for details */
struct NumberFieldWidths {
    Py_ssize_t n_lpadding;
    Py_ssize_t n_prefix;
    Py_ssize_t n_spadding;
    Py_ssize_t n_rpadding;
    char sign;
    Py_ssize_t n_sign;      /* number of digits needed for sign (0/1) */
    Py_ssize_t n_grouped_digits; /* Space taken up by the digits, including
                                    any grouping chars. */
    Py_ssize_t n_decimal;   /* 0 if only an integer */
    Py_ssize_t n_remainder; /* Digits in decimal and/or exponent part,
                               excluding the decimal itself, if
                               present. */

    /* These 2 are not the widths of fields, but are needed by
       STRINGLIB_GROUPING. */
    Py_ssize_t n_digits;    /* The number of digits before a decimal
                               or exponent. */
    Py_ssize_t n_min_width; /* The min_width we used when we computed
                               the n_grouped_digits width. */
}


/* Given a number of the form:
   digits[remainder]
   where ptr points to the start and end points to the end, find where
    the integer part ends. This could be a decimal, an exponent, both,
    or neither.
   If a decimal point is present, set *has_decimal and increment
    remainder beyond it.
   Results are undefined (but shouldn't crash) for improperly
    formatted strings.
*/
static void
parse_number(PyObject *s, Py_ssize_t pos, Py_ssize_t end,
             Py_ssize_t *n_remainder, int *has_decimal)
{
    Py_ssize_t remainder;
    int kind = PyUnicode_KIND(s);
    void *data = PyUnicode_DATA(s);

    while (pos<end && Py_ISDIGIT(PyUnicode_READ(kind, data, pos)))
        ++pos;
    remainder = pos;

    /* Does remainder start with a decimal point? */
    *has_decimal = pos<end && PyUnicode_READ(kind, data, remainder) == ".";

    /* Skip the decimal point. */
    if (*has_decimal)
        remainder++;

    *n_remainder = end - remainder;
}

/* not all fields of format are used.  for example, precision is
   unused.  should this take discrete params in order to be more clear
   about what it does?  or is passing a single format parameter easier
   and more efficient enough to justify a little obfuscation?
   Return -1 on error. */
static Py_ssize_t
calc_number_widths(NumberFieldWidths *spec, Py_ssize_t n_prefix,
                   Py_UCS4 sign_char, PyObject *number, Py_ssize_t n_start,
                   Py_ssize_t n_end, Py_ssize_t n_remainder,
                   int has_decimal, const LocaleInfo *locale,
                   const InternalFormatSpec *format, Py_UCS4 *maxchar)
{
    Py_ssize_t n_non_digit_non_padding;
    Py_ssize_t n_padding;

    spec->n_digits = n_end - n_start - n_remainder - (has_decimal?1:0);
    spec->n_lpadding = 0;
    spec->n_prefix = n_prefix;
    spec->n_decimal = has_decimal ? PyUnicode_GET_LENGTH(locale->decimal_point) : 0;
    spec->n_remainder = n_remainder;
    spec->n_spadding = 0;
    spec->n_rpadding = 0;
    spec->sign = "\0";
    spec->n_sign = 0;

    /* the output will look like:
       |                                                                                         |
       | <lpadding> <sign> <prefix> <spadding> <grouped_digits> <decimal> <remainder> <rpadding> |
       |                                                                                         |

       sign is computed from format->sign and the actual
       sign of the number

       prefix is given (it's for the '0x' prefix)

       digits is already known

       the total width is either given, or computed from the
       actual digits

       only one of lpadding, spadding, and rpadding can be non-zero,
       and it's calculated from the width and other fields
    */

    /* compute the various parts we're going to write */
    switch (format->sign) {
    case "+":
        /* always put a + or - */
        spec->n_sign = 1;
        spec->sign = (sign_char == "-" ? "-" : "+");
        break;
    case " ":
        spec->n_sign = 1;
        spec->sign = (sign_char == "-" ? "-" : " ");
        break;
    default:
        /* Not specified, or the default (-) */
        if (sign_char == "-") {
            spec->n_sign = 1;
            spec->sign = "-";
        }
    }

    /* The number of chars used for non-digits and non-padding. */
    n_non_digit_non_padding = spec->n_sign + spec->n_prefix + spec->n_decimal +
        spec->n_remainder;

    /* min_width can go negative, that's okay. format->width == -1 means
       we don't care. */
    if (format->fill_char == "0" && format->align == "="){
        spec->n_min_width = format->width - n_non_digit_non_padding;
    }
    else{
        spec->n_min_width = 0;
    }
    if (spec->n_digits == 0){
        /* This case only occurs when using 'c' formatting, we need
           to special case it because the grouping code always wants
           to have at least one character. */
        spec->n_grouped_digits = 0;}
    else {
        Py_UCS4 grouping_maxchar;
        spec->n_grouped_digits = _PyUnicode_InsertThousandsGrouping(
            NULL, 0,
            NULL, 0, spec->n_digits,
            spec->n_min_width,
            locale->grouping, locale->thousands_sep, &grouping_maxchar);
        if (spec->n_grouped_digits == -1) {
            return -1;
        }
        *maxchar = Py_MAX(*maxchar, grouping_maxchar);
    }

    /* Given the desired width and the total of digit and non-digit
       space we consume, see if we need any padding. format->width can
       be negative (meaning no padding), but this code still works in
       that case. */
    n_padding = format->width -
                        (n_non_digit_non_padding + spec->n_grouped_digits);
    if (n_padding > 0) {
        /* Some padding is needed. Determine if it's left, space, or right. */
        switch (format->align) {
        case "<":
            spec->n_rpadding = n_padding;
            break;
        case "^":
            spec->n_lpadding = n_padding / 2;
            spec->n_rpadding = n_padding - spec->n_lpadding;
            break;
        case "=":
            spec->n_spadding = n_padding;
            break;
        case ">":
            spec->n_lpadding = n_padding;
            break;
        default:
            /* Shouldn't get here, but treat it as '>' */
            Py_UNREACHABLE();
        }
    }

    if (spec->n_lpadding || spec->n_spadding || spec->n_rpadding){
        *maxchar = Py_MAX(*maxchar, format->fill_char)
    }

    if (spec->n_decimal){
        *maxchar = Py_MAX(*maxchar, PyUnicode_MAX_CHAR_VALUE(locale->decimal_point))
    }
    return spec->n_lpadding + spec->n_sign + spec->n_prefix +
        spec->n_spadding + spec->n_grouped_digits + spec->n_decimal +
        spec->n_remainder + spec->n_rpadding;
}

/* Fill in the digit parts of a number's string representation,
   as determined in calc_number_widths().
   Return -1 on error, or 0 on success. */
static int
fill_number(_PyUnicodeWriter *writer, const NumberFieldWidths *spec,
            PyObject *digits, Py_ssize_t d_start, Py_ssize_t d_end,
            PyObject *prefix, Py_ssize_t p_start,
            Py_UCS4 fill_char,
            LocaleInfo *locale, int toupper)
{
    /* Used to keep track of digits, decimal, and remainder. */
    Py_ssize_t d_pos = d_start;
    const unsigned int kind = writer->kind;
    const void *data = writer->data;
    Py_ssize_t r;

    if (spec->n_lpadding) {
        _PyUnicode_FastFill(writer->buffer,
                            writer->pos, spec->n_lpadding, fill_char);
        writer->pos += spec->n_lpadding;
    }
    if (spec->n_sign == 1) {
        PyUnicode_WRITE(kind, data, writer->pos, spec->sign);
        writer->pos++;
    }
    if (spec->n_prefix) {
        _PyUnicode_FastCopyCharacters(writer->buffer, writer->pos,
                                      prefix, p_start,
                                      spec->n_prefix);
        if (toupper) {
            Py_ssize_t t;
            for (t = 0; t < spec->n_prefix; t++) {
                Py_UCS4 c = PyUnicode_READ(kind, data, writer->pos + t);
                c = Py_TOUPPER(c);
                assert (c <= 127);
                PyUnicode_WRITE(kind, data, writer->pos + t, c);
            }
        }
        writer->pos += spec->n_prefix;
    }
    if (spec->n_spadding) {
        _PyUnicode_FastFill(writer->buffer,
                            writer->pos, spec->n_spadding, fill_char);
        writer->pos += spec->n_spadding;
    }

    /* Only for type 'c' special case, it has no digits. */
    if (spec->n_digits != 0) {
        /* Fill the digits with InsertThousandsGrouping. */
        r = _PyUnicode_InsertThousandsGrouping(
                writer, spec->n_grouped_digits,
                digits, d_pos, spec->n_digits,
                spec->n_min_width,
                locale->grouping, locale->thousands_sep, NULL);
        if (r == -1){
            return -1;
        }
        assert(r == spec->n_grouped_digits);
        d_pos += spec->n_digits;
    }
    if (toupper) {
        Py_ssize_t t;
        for (t = 0; t < spec->n_grouped_digits; t++) {
            Py_UCS4 c = PyUnicode_READ(kind, data, writer->pos + t);
            c = Py_TOUPPER(c);
            if (c > 127) {
                PyErr_SetString(PyExc_SystemError, "non-ascii grouped digit");
                return -1;
            }
            PyUnicode_WRITE(kind, data, writer->pos + t, c);
        }
    }
    writer->pos += spec->n_grouped_digits;

    if (spec->n_decimal) {
        _PyUnicode_FastCopyCharacters(
            writer->buffer, writer->pos,
            locale->decimal_point, 0, spec->n_decimal);
        writer->pos += spec->n_decimal;
        d_pos += 1;
    }

    if (spec->n_remainder) {
        _PyUnicode_FastCopyCharacters(
            writer->buffer, writer->pos,
            digits, d_pos, spec->n_remainder);
        writer->pos += spec->n_remainder;
        /* d_pos += spec->n_remainder; */
    }

    if (spec->n_rpadding) {
        _PyUnicode_FastFill(writer->buffer,
                            writer->pos, spec->n_rpadding,
                            fill_char);
        writer->pos += spec->n_rpadding;
    }
    return 0;
}

static const char no_grouping[1] = {CHAR_MAX};

/* Find the decimal point character(s?), thousands_separator(s?), and
   grouping description, either for the current locale if type is
   LT_CURRENT_LOCALE, a hard-coded locale if LT_DEFAULT_LOCALE or
   LT_UNDERSCORE_LOCALE/LT_UNDER_FOUR_LOCALE, or none if LT_NO_LOCALE. */
static int
get_locale_info(enum LocaleType type, LocaleInfo *locale_info)
{
    switch (type) {
    case LT_CURRENT_LOCALE: {
        var lc:lconv = localeconv()
        if (_Py_GetLocaleconvNumeric(lc,
                                     &locale_info->decimal_point,
                                     &locale_info->thousands_sep) < 0) {
            return -1;
        }

        /* localeconv() grouping can become a dangling pointer or point
           to a different string if another thread calls localeconv() during
           the string formatting. Copy the string to avoid this risk. */
        locale_info->grouping_buffer = _PyMem_Strdup(lc->grouping);
        if (locale_info->grouping_buffer == NULL) {
            PyErr_NoMemory();
            return -1;
        }
        locale_info->grouping = locale_info->grouping_buffer;
        break;
    }
    case LT_DEFAULT_LOCALE:
    case LT_UNDERSCORE_LOCALE:
    case LT_UNDER_FOUR_LOCALE:
        locale_info->decimal_point = PyUnicode_FromOrdinal(".");
        locale_info->thousands_sep = PyUnicode_FromOrdinal(
            type == LT_DEFAULT_LOCALE ? "," : "_");
        if (!locale_info->decimal_point || !locale_info->thousands_sep)
            {return -1}
        if (type != LT_UNDER_FOUR_LOCALE){
            locale_info->grouping = "\3"; /* Group every 3 characters.  The
                                         (implicit) trailing 0 means repeat
                                         infinitely. */
        }
        else
            {locale_info->grouping = "\4";} /* Bin/oct/hex group every four. */
        break;
    case LT_NO_LOCALE:
        locale_info->decimal_point = PyUnicode_FromOrdinal(".");
        locale_info->thousands_sep = PyUnicode_New(0, 0);
        if (!locale_info->decimal_point || !locale_info->thousands_sep)
            return -1;
        locale_info->grouping = no_grouping;
        break;
    }
    return 0;
}

static void
free_locale_info(LocaleInfo *locale_info)
{
    Py_XDECREF(locale_info->decimal_point);
    Py_XDECREF(locale_info->thousands_sep);
    PyMem_Free(locale_info->grouping_buffer);
}

protocol PSFormattable {
    var str: String { get }
    var repr: String { get }
    var ascii: String { get }
    func convertField(_ conversion:Character) -> String
}
extension PSFormattable {
    var str: String { String(describing: self) }
    var repr:String { String(describing: self) }
    var ascii: String { String(describing: self) }

    func convertField(_ conversion:Character) -> String {
        switch conversion {
        case "s":
            return str
        case "r":
            return repr
        case "a":
            return ascii
        default:
            return String(describing: self)
        }
    }
}
/************************************************************************/
/*********** string formatting ******************************************/
/************************************************************************/

static int
format_string_internal(PyObject *value, const InternalFormatSpec *format,
                       _PyUnicodeWriter *writer)
{
    Py_ssize_t lpad;
    Py_ssize_t rpad;
    Py_ssize_t total;
    Py_ssize_t len;
    int result = -1;
    Py_UCS4 maxchar;

    assert(PyUnicode_IS_READY(value));
    len = PyUnicode_GET_LENGTH(value);

    /* sign is not allowed on strings */
    if (format->sign != "\0") {
        PyErr_SetString(PyExc_ValueError,
                        "Sign not allowed in string format specifier");
        goto done;
    }

    /* alternate is not allowed on strings */
    if (format->alternate) {
        PyErr_SetString(PyExc_ValueError,
                        "Alternate form (#) not allowed in string format "
                        "specifier");
        goto done;
    }

    /* '=' alignment not allowed on strings */
    if (format->align == "=") {
        PyErr_SetString(PyExc_ValueError,
                        "'=' alignment not allowed "
                        "in string format specifier");
        goto done;
    }

    if ((format->width == -1 || format->width <= len)
        && (format->precision == -1 || format->precision >= len)) {
        /* Fast path */
        return _PyUnicodeWriter_WriteStr(writer, value);
    }

    /* if precision is specified, output no more that format.precision
       characters */
    if (format->precision >= 0 && len >= format->precision) {
        len = format->precision;
    }

    calc_padding(len, format->width, format->align, &lpad, &rpad, &total);

    maxchar = writer->maxchar;
    if (lpad != 0 || rpad != 0)
        {maxchar = Py_MAX(maxchar, format->fill_char)}
    if (PyUnicode_MAX_CHAR_VALUE(value) > maxchar) {
        Py_UCS4 valmaxchar = _PyUnicode_FindMaxChar(value, 0, len);
        maxchar = Py_MAX(maxchar, valmaxchar);
    }

    /* allocate the resulting string */
    if (_PyUnicodeWriter_Prepare(writer, total, maxchar) == -1)
        {goto done}

    /* Write into that space. First the padding. */
    result = fill_padding(writer, len, format->fill_char, lpad, rpad);
    if (result == -1)
        {goto done}

    /* Then the source string. */
    if (len) {
        _PyUnicode_FastCopyCharacters(writer->buffer, writer->pos,
                                      value, 0, len);
    }
    writer->pos += (len + rpad);
    result = 0;

done:
    return result;
}


/************************************************************************/
/*********** long formatting ********************************************/
/************************************************************************/

static int
format_long_internal(PyObject *value, const InternalFormatSpec *format,
                     _PyUnicodeWriter *writer)
{
    int result = -1;
    Py_UCS4 maxchar = 127;
    PyObject *tmp = NULL;
    Py_ssize_t inumeric_chars;
    Py_UCS4 sign_char = "\0";
    Py_ssize_t n_digits;       /* count of digits need from the computed
                                  string */
    Py_ssize_t n_remainder = 0; /* Used only for 'c' formatting, which
                                   produces non-digits */
    Py_ssize_t n_prefix = 0;   /* Count of prefix chars, (e.g., '0x') */
    Py_ssize_t n_total;
    Py_ssize_t prefix = 0;
    NumberFieldWidths spec;
    long x;

    /* Locale settings, either from the actual locale or
       from a hard-code pseudo-locale */
    var locale:LocaleInfo = .init()

    /* no precision allowed on integers */
    if (format->precision != -1) {
        PyErr_SetString(PyExc_ValueError,
                        "Precision not allowed in integer format specifier");
        goto done;
    }

    /* special case for character formatting */
    if (format->type == "c") {
        /* error to specify a sign */
        if (format->sign != "\0") {
            PyErr_SetString(PyExc_ValueError,
                            "Sign not allowed with integer"
                            " format specifier 'c'");
            goto done;
        }
        /* error to request alternate format */
        if (format->alternate) {
            PyErr_SetString(PyExc_ValueError,
                            "Alternate form (#) not allowed with integer"
                            " format specifier 'c'");
            goto done;
        }

        /* taken from unicodeobject.c formatchar() */
        /* Integer input truncated to a character */
        x = PyLong_AsLong(value);
        if (x == -1 && PyErr_Occurred())
            goto done;
        if (x < 0 || x > 0x10ffff) {
            PyErr_SetString(PyExc_OverflowError,
                            "%c arg not in range(0x110000)");
            goto done;
        }
        tmp = PyUnicode_FromOrdinal(x);
        inumeric_chars = 0;
        n_digits = 1;
        maxchar = Py_MAX(maxchar, (Py_UCS4)x);

        /* As a sort-of hack, we tell calc_number_widths that we only
           have "remainder" characters. calc_number_widths thinks
           these are characters that don't get formatted, only copied
           into the output string. We do this for 'c' formatting,
           because the characters are likely to be non-digits. */
        n_remainder = 1;
    }
    else {
        int base;
        int leading_chars_to_skip = 0;  /* Number of characters added by
                                           PyNumber_ToBase that we want to
                                           skip over. */

        /* Compute the base and how many characters will be added by
           PyNumber_ToBase */
        switch (format->type) {
        case "b":
            base = 2;
            leading_chars_to_skip = 2; /* 0b */
            break;
        case "o":
            base = 8;
            leading_chars_to_skip = 2; /* 0o */
            break;
        case "x", "X":
            base = 16;
            leading_chars_to_skip = 2; /* 0x */
            break;
        case "d", "n":
            fallthrough
        default:  /* shouldn't be needed, but stops a compiler warning */
            base = 10;
            break;
            
        }

        if (format->sign != "+" && format->sign != " "
            && format->width == -1
            && format->type != "X" && format->type != "n"
            && !format->thousands_separators
            && PyLong_CheckExact(value))
        {
            /* Fast path */
            return _PyLong_FormatWriter(writer, value, base, format->alternate);
        }

        /* The number of prefix chars is the same as the leading
           chars to skip */
        if (format->alternate)
            {n_prefix = leading_chars_to_skip}

        /* Do the hard part, converting to a string in a given base */
        tmp = _PyLong_Format(value, base);
        if (tmp == NULL || PyUnicode_READY(tmp) == -1)
            {goto done}

        inumeric_chars = 0;
        n_digits = PyUnicode_GET_LENGTH(tmp);

        prefix = inumeric_chars;

        /* Is a sign character present in the output?  If so, remember it
           and skip it */
        if (PyUnicode_READ_CHAR(tmp, inumeric_chars) == "-") {
            sign_char = "-"
            ++prefix;
            ++leading_chars_to_skip;
        }

        /* Skip over the leading chars (0x, 0b, etc.) */
        n_digits -= leading_chars_to_skip;
        inumeric_chars += leading_chars_to_skip;
    }

    /* Determine the grouping, separator, and decimal point, if any. */
    if (get_locale_info(format->type == "n" ? LT_CURRENT_LOCALE :
                        format->thousands_separators,
                        &locale) == -1){
        goto done;
}
    /* Calculate how much memory we'll need. */
    n_total = calc_number_widths(&spec, n_prefix, sign_char, tmp, inumeric_chars,
                                 inumeric_chars + n_digits, n_remainder, 0,
                                 &locale, format, &maxchar);
    if (n_total == -1) {
        goto done;
    }

    /* Allocate the memory. */
    if (_PyUnicodeWriter_Prepare(writer, n_total, maxchar) == -1)
        goto done;

    /* Populate the memory. */
    result = fill_number(writer, &spec,
                         tmp, inumeric_chars, inumeric_chars + n_digits,
                         tmp, prefix, format->fill_char,
    &locale, format->type == "X");

done:
    Py_XDECREF(tmp);
    free_locale_info(&locale);
    return result;
}

/************************************************************************/
/*********** float formatting *******************************************/
/************************************************************************/

/* much of this is taken from unicodeobject.c */
static int
format_float_internal(PyObject *value,
                      const InternalFormatSpec *format,
                      _PyUnicodeWriter *writer)
{
    char *buf = NULL;       /* buffer returned from PyOS_double_to_string */
    Py_ssize_t n_digits;
    Py_ssize_t n_remainder;
    Py_ssize_t n_total;
    int has_decimal;
    double val;
    int precision, default_precision = 6;
    Py_UCS4 type = format->type;
    int add_pct = 0;
    Py_ssize_t index;
    NumberFieldWidths spec;
    int flags = 0;
    int result = -1;
    Py_UCS4 maxchar = 127;
    Py_UCS4 sign_char = "\0";
    int float_type; /* Used to see if we have a nan, inf, or regular float. */
    PyObject *unicode_tmp = NULL;

    /* Locale settings, either from the actual locale or
       from a hard-code pseudo-locale */
    var locale:LocaleInfo = .init()

    if (format->precision > INT_MAX) {
        PyErr_SetString(PyExc_ValueError, "precision too big");
        goto done;
    }
    precision = (int)format->precision;

    if (format->alternate){
        flags |= Py_DTSF_ALT;
    }

    if (type == "\0") {
        /* Omitted type specifier.  Behaves in the same way as repr(x)
           and str(x) if no precision is given, else like 'g', but with
           at least one digit after the decimal point. */
        flags |= Py_DTSF_ADD_DOT_0;
        type = "r";
        default_precision = 0;
    }

    if (type == "n"){
        /* 'n' is the same as 'g', except for the locale used to
           format the result. We take care of that later. */
    type = "g";
}
    val = PyFloat_AsDouble(value);
    if (val == -1.0 && PyErr_Occurred())
        {
            goto done;
        }

    if (type == "%") {
        type = "f";
        val *= 100;
        add_pct = 1;
    }

    if (precision < 0)
        precision = default_precision;
    else if (type == "r")
    {type = "g";}

    /* Cast "type", because if we're in unicode we need to pass an
       8-bit char. This is safe, because we've restricted what "type"
       can be. */
    buf = PyOS_double_to_string(val, (char)type, precision, flags,
                                &float_type);
    if (buf == NULL){
        goto done;}
    n_digits = strlen(buf);

    if (add_pct) {
        /* We know that buf has a trailing zero (since we just called
           strlen() on it), and we don't use that fact any more. So we
           can just write over the trailing zero. */
        buf[n_digits] = "%";
        n_digits += 1;
    }

    if (format->sign != "+" && format->sign != " "
        && format->width == -1
        && format->type != "n"
        && !format->thousands_separators)
    {
        /* Fast path */
        result = _PyUnicodeWriter_WriteASCIIString(writer, buf, n_digits);
        PyMem_Free(buf);
        return result;
    }

    /* Since there is no unicode version of PyOS_double_to_string,
       just use the 8 bit version and then convert to unicode. */
    unicode_tmp = _PyUnicode_FromASCII(buf, n_digits);
    PyMem_Free(buf);
    if (unicode_tmp == NULL)
        goto done;

    /* Is a sign character present in the output?  If so, remember it
       and skip it */
    index = 0;
    if (PyUnicode_READ_CHAR(unicode_tmp, index) == "-") {
        sign_char = "-";
        ++index;
        --n_digits;
    }

    /* Determine if we have any "remainder" (after the digits, might include
       decimal or exponent or both (or neither)) */
    parse_number(unicode_tmp, index, index + n_digits, &n_remainder, &has_decimal);

    /* Determine the grouping, separator, and decimal point, if any. */
    if (get_locale_info(format->type == "n" ? LT_CURRENT_LOCALE :
                        format->thousands_separators,
                        &locale) == -1)
        {goto done;}

    /* Calculate how much memory we'll need. */
    n_total = calc_number_widths(&spec, 0, sign_char, unicode_tmp, index,
                                 index + n_digits, n_remainder, has_decimal,
                                 &locale, format, &maxchar);
    if (n_total == -1) {
        goto done;
    }

    /* Allocate the memory. */
    if (_PyUnicodeWriter_Prepare(writer, n_total, maxchar) == -1)
        goto done;

    /* Populate the memory. */
    result = fill_number(writer, &spec,
                         unicode_tmp, index, index + n_digits,
                         NULL, 0, format->fill_char,
                         &locale, 0);

done:
    Py_XDECREF(unicode_tmp);
    free_locale_info(&locale);
    return result;
}

/************************************************************************/
/*********** complex formatting *****************************************/
/************************************************************************/

static int
format_complex_internal(PyObject *value,
                        const InternalFormatSpec *format,
                        _PyUnicodeWriter *writer)
{
    double re;
    double im;
    char *re_buf = NULL;       /* buffer returned from PyOS_double_to_string */
    char *im_buf = NULL;       /* buffer returned from PyOS_double_to_string */

    InternalFormatSpec tmp_format = *format;
    Py_ssize_t n_re_digits;
    Py_ssize_t n_im_digits;
    Py_ssize_t n_re_remainder;
    Py_ssize_t n_im_remainder;
    Py_ssize_t n_re_total;
    Py_ssize_t n_im_total;
    int re_has_decimal;
    int im_has_decimal;
    int precision, default_precision = 6;
    Py_UCS4 type = format->type;
    Py_ssize_t i_re;
    Py_ssize_t i_im;
    NumberFieldWidths re_spec;
    NumberFieldWidths im_spec;
    int flags = 0;
    int result = -1;
    Py_UCS4 maxchar = 127;
    enum PyUnicode_Kind rkind;
    void *rdata;
    Py_UCS4 re_sign_char = "\0";
    Py_UCS4 im_sign_char = "\0";
    int re_float_type; /* Used to see if we have a nan, inf, or regular float. */
    int im_float_type;
    int add_parens = 0;
    int skip_re = 0;
    Py_ssize_t lpad;
    Py_ssize_t rpad;
    Py_ssize_t total;
    PyObject *re_unicode_tmp = NULL;
    PyObject *im_unicode_tmp = NULL;

    /* Locale settings, either from the actual locale or
       from a hard-code pseudo-locale */
    var locale:LocaleInfo = .init()

    if (format->precision > INT_MAX) {
        PyErr_SetString(PyExc_ValueError, "precision too big");
        goto done;
    }
    precision = (int)format->precision;

    /* Zero padding is not allowed. */
    if (format->fill_char == "0") {
        PyErr_SetString(PyExc_ValueError,
                        "Zero padding is not allowed in complex format "
                        "specifier");
        {goto done;}
    }

    /* Neither is '=' alignment . */
    if (format->align == "=") {
        PyErr_SetString(PyExc_ValueError,
                        "'=' alignment flag is not allowed in complex format "
                        "specifier");
        {goto done;}
    }

    re = PyComplex_RealAsDouble(value);
    if (re == -1.0 && PyErr_Occurred()){
        goto done;
    }
    im = PyComplex_ImagAsDouble(value);
    if (im == -1.0 && PyErr_Occurred()){
        goto done;
    }

    if (format->alternate){
        flags |= Py_DTSF_ALT;
    }
    if (type == "\0") {
        /* Omitted type specifier. Should be like str(self). */
        type = "r";
        default_precision = 0;
        if (re == 0.0 && copysign(1.0, re) == 1.0){
            skip_re = 1;}
        else{
            add_parens = 1;}
    }

    if (type == "n"){
        /* 'n' is the same as 'g', except for the locale used to
           format the result. We take care of that later. */
        type = "g";
}
    if (precision < 0){
        precision = default_precision;
    }    else if (type == "r"){
        type = "g";
}
    /* Cast "type", because if we're in unicode we need to pass an
       8-bit char. This is safe, because we've restricted what "type"
       can be. */
    re_buf = PyOS_double_to_string(re, (char)type, precision, flags,
                                   &re_float_type);
    if (re_buf == NULL){
        goto done;}
    im_buf = PyOS_double_to_string(im, (char)type, precision, flags,
                                   &im_float_type);
    if (im_buf == NULL){
        goto done;
}
    n_re_digits = strlen(re_buf);
    n_im_digits = strlen(im_buf);

    /* Since there is no unicode version of PyOS_double_to_string,
       just use the 8 bit version and then convert to unicode. */
    re_unicode_tmp = _PyUnicode_FromASCII(re_buf, n_re_digits);
    if (re_unicode_tmp == NULL){
        goto done;}
    i_re = 0;

    im_unicode_tmp = _PyUnicode_FromASCII(im_buf, n_im_digits);
    if (im_unicode_tmp == NULL){
        goto done;}
    i_im = 0;

    /* Is a sign character present in the output?  If so, remember it
       and skip it */
    if (PyUnicode_READ_CHAR(re_unicode_tmp, i_re) == "-") {
        re_sign_char = "-";
        ++i_re;
        --n_re_digits;
    }
    if (PyUnicode_READ_CHAR(im_unicode_tmp, i_im) == "-") {
        im_sign_char = "-";
        ++i_im;
        --n_im_digits;
    }

    /* Determine if we have any "remainder" (after the digits, might include
       decimal or exponent or both (or neither)) */
    parse_number(re_unicode_tmp, i_re, i_re + n_re_digits,
                 &n_re_remainder, &re_has_decimal);
    parse_number(im_unicode_tmp, i_im, i_im + n_im_digits,
                 &n_im_remainder, &im_has_decimal);

    /* Determine the grouping, separator, and decimal point, if any. */
    if (get_locale_info(format->type == "n" ? LT_CURRENT_LOCALE :
                        format->thousands_separators,
                        &locale) == -1)
        {goto done;}

    /* Turn off any padding. We'll do it later after we've composed
       the numbers without padding. */
    tmp_format.fill_char = "\0";
    tmp_format.align = "<";
    tmp_format.width = -1;

    /* Calculate how much memory we'll need. */
    n_re_total = calc_number_widths(&re_spec, 0, re_sign_char, re_unicode_tmp,
                                    i_re, i_re + n_re_digits, n_re_remainder,
                                    re_has_decimal, &locale, &tmp_format,
                                    &maxchar);
    if (n_re_total == -1) {
        goto done;
    }

    /* Same formatting, but always include a sign, unless the real part is
     * going to be omitted, in which case we use whatever sign convention was
     * requested by the original format. */
    if (!skip_re){
        tmp_format.sign = "+";}
    n_im_total = calc_number_widths(&im_spec, 0, im_sign_char, im_unicode_tmp,
                                    i_im, i_im + n_im_digits, n_im_remainder,
                                    im_has_decimal, &locale, &tmp_format,
                                    &maxchar);
    if (n_im_total == -1) {
        goto done;
    }

    if (skip_re){
        n_re_total = 0;}

    /* Add 1 for the 'j', and optionally 2 for parens. */
    calc_padding(n_re_total + n_im_total + 1 + add_parens * 2,
                 format->width, format->align, &lpad, &rpad, &total);

    if (lpad || rpad){
        maxchar = Py_MAX(maxchar, format->fill_char);
}
    if (_PyUnicodeWriter_Prepare(writer, total, maxchar) == -1){
        goto done;}
    rkind = writer->kind;
    rdata = writer->data;

    /* Populate the memory. First, the padding. */
    result = fill_padding(writer,
                          n_re_total + n_im_total + 1 + add_parens * 2,
                          format->fill_char, lpad, rpad);
    if (result == -1){
        goto done;
    }

    if (add_parens) {
        PyUnicode_WRITE(rkind, rdata, writer->pos, "(");
        writer->pos++;
    }

    if (!skip_re) {
        result = fill_number(writer, &re_spec,
                             re_unicode_tmp, i_re, i_re + n_re_digits,
                             NULL, 0,
                             0,
                             &locale, 0);
        if (result == -1){
            goto done;
        }
    }
    result = fill_number(writer, &im_spec,
                         im_unicode_tmp, i_im, i_im + n_im_digits,
                         NULL, 0,
                         0,
                         &locale, 0);
    if (result == -1){
        goto done;
    }
    PyUnicode_WRITE(rkind, rdata, writer->pos, "j");
    writer->pos++;

    if (add_parens) {
        PyUnicode_WRITE(rkind, rdata, writer->pos, ")");
        writer->pos++;
    }

    writer->pos += rpad;

done:
    PyMem_Free(re_buf);
    PyMem_Free(im_buf);
    Py_XDECREF(re_unicode_tmp);
    Py_XDECREF(im_unicode_tmp);
    free_locale_info(&locale);
    return result;
}

/************************************************************************/
/*********** built in formatters ****************************************/
/************************************************************************/
func format_obj(_ obj:PyObject?, _ writer:_PyUnicodeWriter) -> int
{
    PyObject *str;
    int err;

    str = PyObject_Str(obj);
    if (str == NULL)
        return -1;
    err = _PyUnicodeWriter_WriteStr(writer, str);
    Py_DECREF(str);
    return err;
}

int
_PyUnicode_FormatAdvancedWriter(_PyUnicodeWriter *writer,
                                PyObject *obj,
                                PyObject *format_spec,
                                Py_ssize_t start, Py_ssize_t end)
{
    var format:InternalFormatSpec

    assert(PyUnicode_Check(obj));

    /* check for the special case of zero length format spec, make
       it equivalent to str(obj) */
    if (start == end) {
        if (PyUnicode_CheckExact(obj)){
            return _PyUnicodeWriter_WriteStr(writer, obj);
        }
        else{
            return format_obj(obj, writer);
        }
    }

    /* parse the format_spec */
    if (!parse_internal_render_format_spec(format_spec, start, end,
                                           &format, "s", "<")){
        return -1;
    }

    /* type conversion? */
    switch (format.type) {
    case "s":
        /* no type conversion needed, already a string.  do the formatting */
        return format_string_internal(obj, &format, writer);
    default:
        /* unknown */
        unknown_presentation_type(format.type, obj->ob_type->tp_name);
        return -1;
    }
}

int
_PyLong_FormatAdvancedWriter(_PyUnicodeWriter *writer,
                             PyObject *obj,
                             PyObject *format_spec,
                             Py_ssize_t start, Py_ssize_t end)
{
    PyObject *tmp = NULL, *str = NULL;
    InternalFormatSpec format;
    int result = -1;

    /* check for the special case of zero length format spec, make
       it equivalent to str(obj) */
    if (start == end) {
        if (PyLong_CheckExact(obj))
            return _PyLong_FormatWriter(writer, obj, 10, 0);
        else
            return format_obj(obj, writer);
    }

    /* parse the format_spec */
    if (!parse_internal_render_format_spec(format_spec, start, end,
                                           &format, "d", ">")){
        Py_XDECREF(tmp);
        Py_XDECREF(str);
        return result;

    }

    /* type conversion? */
    switch (format.type) {
    case "b", "c", "d", "o", "x", "X", "n":
        /* no type conversion needed, already an int.  do the formatting */
        result = format_long_internal(obj, &format, writer);
        break;

    case "e", "E", "f", "F", "g", "G", "%":
        /* convert to float */
        tmp = PyNumber_Float(obj);
        if (tmp == NULL){
            Py_XDECREF(tmp);
            Py_XDECREF(str);
            return result;

        }
        result = format_float_internal(tmp, &format, writer);
        break;

    default:
        /* unknown */
        unknown_presentation_type(format.type, obj->ob_type->tp_name);
        Py_XDECREF(tmp);
        Py_XDECREF(str);
        return result;
    }
    return result;
}

int
_PyFloat_FormatAdvancedWriter(_PyUnicodeWriter *writer,
                              PyObject *obj,
                              PyObject *format_spec,
                              Py_ssize_t start, Py_ssize_t end)
{
    var format: InternalFormatSpec

    /* check for the special case of zero length format spec, make
       it equivalent to str(obj) */
    if (start == end){
        return format_obj(obj, writer);
    }
    /* parse the format_spec */
    if (!parse_internal_render_format_spec(format_spec, start, end,
                                           &format, "\0", ">")){
        return -1;}

    /* type conversion? */
    switch (format.type) {
    case "\0", /* No format code: like 'g', but with at least one decimal. */
    "e", "E", "f", "F", "g", "G", "n", "%":
        /* no conversion, already a float.  do the formatting */
        return format_float_internal(obj, &format, writer);

    default:
        /* unknown */
        unknown_presentation_type(format.type, obj->ob_type->tp_name);
        return -1;
    }
}

int
_PyComplex_FormatAdvancedWriter(_PyUnicodeWriter *writer,
                                PyObject *obj,
                                PyObject *format_spec,
                                Py_ssize_t start, Py_ssize_t end)
{
    var format:InternalFormatSpec

    /* check for the special case of zero length format spec, make
       it equivalent to str(obj) */
    if (start == end)
        {return format_obj(obj, writer);}

    /* parse the format_spec */
    if (!parse_internal_render_format_spec(format_spec, start, end,
                                           &format, "\0", ">"))
        {return -1;}

    /* type conversion? */
    switch (format.type) {
    case "\0", /* No format code: like 'g', but with at least one decimal. */
    "e", "E", "f", "F","g", "G", "n":
        /* no conversion, already a complex.  do the formatting */
        return format_complex_internal(obj, &format, writer);

    default:
        /* unknown */
        unknown_presentation_type(format.type, obj->ob_type->tp_name);
        return -1;
    }
}


class _PyUnicodeWriter {
    var buffer:PyObject
    void *data;
    var kind: PyUnicode_Kind = .PyUnicode_WCHAR_KIND
    var maxchar:Py_UCS4
    var size:Py_ssize_t
    var pos:Py_ssize_t

    /* minimum number of allocated characters (default: 0) */
    var min_length:Py_ssize_t

    /* minimum character (default: 127, ASCII) */
    var min_char: Py_UCS4 = Character(127)

    /* If non-zero, overallocate the buffer (default: 0). */
    unsigned char overallocate;

    /* If readonly is 1, buffer is a shared string (cannot be modified)
       and size is set to 0. */
    unsigned char readonly;
}
enum PyUnicode_Kind: Int {
/* String contains only wstr byte characters.  This is only possible
   when the string was created with a legacy API and _PyUnicode_Ready()
   has not been called yet.  */
    case PyUnicode_WCHAR_KIND = 0
/* Return values of the PyUnicode_KIND() macro: */
    case PyUnicode_1BYTE_KIND = 1
    case PyUnicode_2BYTE_KIND = 2
    case PyUnicode_4BYTE_KIND = 4
}

extension String {
    public func format(_ args:Any?..., kwargs:[String:Any?]=[:]) -> String {
        switch do_string_format(self, args, kwargs) {
        case .success(let result):
            return result
        case .failure(let err):
            return String(describing: err)
        }
    }
    
    public func format_map(_ mapping:[String:Any?]) -> String {
        return self.format([], kwargs: mapping)
    }
}
