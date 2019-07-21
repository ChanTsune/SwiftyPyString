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


typealias Py_ssize_t = Int
typealias PyObject = Any
typealias int = Int
typealias long = Int
typealias double = Double
typealias Py_UCS4 = Character

var PY_SSIZE_T_MAX = Int.max
/*
 unicode_format.h -- implementation of str.format().
 */

/************************************************************************/
/***********   Global data structures and forward declarations  *********/
/************************************************************************/
struct _PyUnicodeWriter {
    var buffer:PyObject = ""
    var data:PyObject = ""
    var size:Py_ssize_t = 0
    var pos:Py_ssize_t = 0
}
/*
 A SubString consists of the characters between two string or
 unicode pointers.
 */

struct SubString {
    var str:PyObject /* borrowed reference */
    var start:Py_ssize_t
    var end:Py_ssize_t

    /* fill in a SubString from a pointer and length */
    init(_ s:PyObject,start:Py_ssize_t,end:Py_ssize_t) {
        self.str = s
        self.start = start
        self.end = end
    }
}

enum AutoNumberState:Int {
    case ANS_INIT = 0
    case ANS_AUTO = 1
    case ANS_MANUAL = 2
}   /* Keep track if we're auto-numbering fields */

/* Keeps track of our auto-numbering state, and which number field we're on */
struct AutoNumber {
    var an_state:AutoNumberState = .ANS_INIT
    var an_field_number:int = 0
}


/* PyOS_double_to_string's "flags" parameter can be set to 0 or more of: */
let Py_DTSF_SIGN =     0x01 /* always add the sign */
let Py_DTSF_ADD_DOT_0 = 0x02 /* if the result is an integer add ".0" */
let Py_DTSF_ALT  =    0x04 /* "alternate" formatting. it's format_code
 specific */

/* PyOS_double_to_string's "type", if non-NULL, will be set to one of: */
let Py_DTST_FINITE = 0
let Py_DTST_INFINITE = 1
let Py_DTST_NAN = 2

/************************************************************************/
/**************************  Utility  functions  ************************/
/************************************************************************/
func PyObject_Str(_ obj:PyObject) -> String {
    return String(describing: obj)
}
let PyObject_Repr = PyObject_Str
let PyObject_ASCII = PyObject_Str

func PyUnicode_GET_LENGTH(_ str:String) -> Int {
    return str.count
}

func PyUnicode_FromOrdinal(_ c:Character) -> String {
    return String(c)
}

func PyUnicode_READ_CHAR(_ str:String,_ index:Int) -> Character {
    return str[index]
}
func PyUnicode_Substring(_ str:PyObject,_ start:Py_ssize_t,_ end:Py_ssize_t) -> String {
    let tmp = str as! String
    return tmp[start,end]
}


/* return a new string.  if str->str is NULL, return None */
func SubString_new_object(_ str:SubString) -> PyObject
{
    if str.str as! String == "" {
        return ""
    }
    return PyUnicode_Substring(str.str, str.start, str.end);
}

func PyUnicode_New(_ params:Any...) -> String {
    return ""
}
/* return a new string.  if str->str is NULL, return a new empty string */
func SubString_new_object_or_empty(_ str:SubString) -> PyObject
{
    if str.str as! String == "" {
        return PyUnicode_New(0, 0)
    }
    return SubString_new_object(str)
}

/* Return 1 if an error has been detected switching between automatic
 field numbering and manual field specification, else return 0. Set
 ValueError on error. */
func autonumber_state_error(_ state:AutoNumberState, _ field_name_is_empty:int) -> Result<int,PyException>
{
    if (state == .ANS_MANUAL) {
        if (field_name_is_empty) {
            return .failure(.ValueError("cannot switch from manual field specification to automatic field numbering"))
        }
    }
    else {
        if (!field_name_is_empty) {
            return .failure(.ValueError("cannot switch from automatic field numbering to manual field specification"))
        }
    }
    return .success(0)
}


/************************************************************************/
/***********  Format string parsing -- integers and identifiers *********/
/************************************************************************/
func Py_UNICODE_TODECIMAL(_ c:Character) -> Int {
    return c.isdecimal() ? Int(c.properties.numericValue!) : -1
}

func get_integer(_ str:SubString) -> Result<Py_ssize_t,PyException>
{
    var accumulator:Py_ssize_t = 0
    var digitval:Py_ssize_t
    var i:Py_ssize_t
    
    /* empty string is an error */
    if (str.start >= str.end){
        return .success(-1)
    }
    i = str.start;
    while ( i < str.end) {
        digitval = Py_UNICODE_TODECIMAL(PyUnicode_READ_CHAR(str.str, i));
        if (digitval < 0){
            return .success(-1)
        }
        /*
         Detect possible overflow before it happens:
         
         accumulator * 10 + digitval > PY_SSIZE_T_MAX if and only if
         accumulator > (PY_SSIZE_T_MAX - digitval) / 10.
         */
        if (accumulator > (PY_SSIZE_T_MAX - digitval) / 10) {
            return .failure(.ValueError("Too many decimal digits in format string"))
        }
        accumulator = accumulator * 10 + digitval;
        
        i += 1
    }
    return .success(accumulator)
}

/************************************************************************/
/******** Functions to get field objects and specification strings ******/
/************************************************************************/

func PyObject_GetAttr(_ obj:PyObject,_ name:String) -> Result<Any?,PyException> {
    let mirror = Mirror(reflecting: obj)
    for i in mirror.children.makeIterator(){
        if let label = i.label, label == name{
            return .success(i.value)
        }
    }
    return .failure(.AttributeError("'\(String(describing: type(of: obj)))' object has no attribute '\(name)'"))
}

/* do the equivalent of obj.name */
func getattr(_ obj:PyObject, name:SubString) -> PyObject
{
    var newobj:PyObject
    var str:PyObject = SubString_new_object(name)
    if (str == NULL){
        return NULL;
    }
    newobj = PyObject_GetAttr(obj, str);
    return newobj;
}

func PySequence_GetItem(_ obj:PyObject,_ idx:Int) -> Result<Any?,PyException> {
    if obj.count <= idx {
        return .failure(.IndexError("\(String(describing: type(of: obj))) index out of range"))
    }
    return .success(obj[idx])
}

/* do the equivalent of obj[idx], where obj is a sequence */
func getitem_sequence(_ obj:PyObject, _ idx:Py_ssize_t) -> PyObject
{
    return PySequence_GetItem(obj, idx);
}
func PyObject_GetItem(_ obj:PyObject,_ idx:Int) -> Result<Any?,PyException> {
    return .success(obj[idx])
}
/* do the equivalent of obj[idx], where obj is not a sequence */
func getitem_idx(_ obj:PyObject, _ idx:Py_ssize_t) -> PyObject
{
    var newobj:PyObject
    newobj = PyObject_GetItem(obj, idx);
    return newobj;
}

/* do the equivalent of obj[name] */
func getitem_str(_ obj:PyObject,  _ name:SubString) -> PyObject
{
    var newobj:PyObject
    var str:PyObject = SubString_new_object(name);
    if (str == NULL){
        return NULL;
    }
    newobj = PyObject_GetItem(obj, str);
    return newobj;
}

struct FieldNameIterator {
    /* the entire string we're parsing.  we assume that someone else
     is managing its lifetime, and that it will exist for the
     lifetime of the iterator.  can be empty */
    var str:SubString
    
    /* index to where we are inside field_name */
    var index:Py_ssize_t
    
    init(_ s:PyObject,start:Py_ssize_t,end:Py_ssize_t) {
        self.str = .init(s,start:start, end:end)
        self.index = start
    }
}


func _FieldNameIterator_attr(_ self:inout FieldNameIterator, _ name:inout SubString) -> int
{
    var c:Py_UCS4
    
    name.str = self.str.str;
    name.start = self.index;
    
    /* return everything until '.' or '[' */
    while (self.index < self.str.end) {
        c = PyUnicode_READ_CHAR(self.str.str as! String, self.index);
        self.index += 1
        switch (c) {
        case "[":
            fallthrough
        case ".":
            /* backup so that we this character will be seen next time */
            self.index -= 1
            break;
        default:
            continue;
        }
        break;
    }
    /* end of string is okay */
    name.end = self.index
    return 1;
}

func _FieldNameIterator_item(_ self:inout FieldNameIterator, name:inout SubString) -> Result<int,PyException>
{
    var bracket_seen:Int = 0;
    var c:Py_UCS4
    
    name.str = self.str.str;
    name.start = self.index;
    
    /* return everything until ']' */
    while (self.index < self.str.end) {
        c = PyUnicode_READ_CHAR(self.str.str as! String, self.index)
        self.index += 1
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
        return.failure(.ValueError("Missing ']' in format string"))
    }
    
    /* end of string is okay */
    /* don't include the ']' */
    name.end = self.index-1;
    return .success(1)
}

/* returns 0 on error, 1 on non-error termination, and 2 if it returns a value */
func FieldNameIterator_next(_ self:inout FieldNameIterator, is_attribute:inout int,
                            name_idx:inout Py_ssize_t, name:inout SubString) -> Result<int,PyException>
{
    /* check at end of input */
    if (self.index >= self.str.end) {
        return .success(1)
    }
    
    var tmp = PyUnicode_READ_CHAR(self.str.str as! String, self.index)
    self.index += 1
    switch (tmp) {
    case ".":
        is_attribute = 1;
        if (_FieldNameIterator_attr(&self, &name) == 0){
            return 0 // おそらくエラーになるはずなんだがエラー要素が見つからない
        }
        name_idx = -1;
        break;
    case "[":
        is_attribute = 0;
        switch _FieldNameIterator_item(&self, name: &name) {
        case .success(_):
            break;
        case .failure(let err):
            return .failure(err)
        }
        switch get_integer(name) {
        case .success(let idx):
            name_idx = idx
        case .failure(let err):
            return .failure(err)
        }
        break;
    default:
        /* Invalid character follows ']' */
        return .failure(.ValueError("Only '.' or '[' may follow ']' in format field specifier"))
    }
    
    /* empty string is an error */
    if (name.start == name.end) {
        return .failure(.ValueError("Empty attribute in format string"))
    }
    
    return .success(2)
}


/* input: field_name
 output: 'first' points to the part before the first '[' or '.'
 'first_idx' is -1 if 'first' is not an integer, otherwise
 it's the value of first converted to an integer
 'rest' is an iterator to return the rest
 */
func field_name_split(_ str:PyObject, start:Py_ssize_t, end:Py_ssize_t, first:inout SubString,
                      first_idx:inout Py_ssize_t, rest:inout FieldNameIterator,auto_number:inout AutoNumber) -> int
{
    var c:Py_UCS4
    var i:Py_ssize_t = start
    var field_name_is_empty:int
    var using_numeric_index:int
    
    /* find the part up until the first '.' or '[' */
    while (i < end) {
        let c = PyUnicode_READ_CHAR(str as! String, i)
        i += 1
        switch c {
        case "[":
            fallthrough
        case ".":
            /* backup so that we this character is available to the
             "rest" iterator */
            i -= 1
            break;
        default:
            continue;
        }
        break;
    }
    
    /* set up the return values */
    first = .init(str,start:start,end:i)
    rest = .init(str, start:i, end:end)
    
    /* see if "first" is an integer, in which case it's used as an index */
    switch get_integer(first) {
    case .success(let idx):
        first_idx = idx
    case .failure(let err):
        return 0;
    }

    field_name_is_empty = first.start >= first.end;
    
    /* If the field name is omitted or if we have a numeric index
     specified, then we're doing numeric indexing into args. */
    using_numeric_index = field_name_is_empty || first_idx != -1;
    
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
        if (auto_number.an_state == .ANS_INIT && using_numeric_index){
            auto_number.an_state = field_name_is_empty ? .ANS_AUTO : .ANS_MANUAL;
        }
        
        /* Make sure our state is consistent with what we're doing
         this time through. Only check if we're using a numeric
         index. */
        if (using_numeric_index){
            if (autonumber_state_error(auto_number.an_state,
                                       field_name_is_empty)){
                return 0;
            }

        }
        /* Zero length field means we want to do auto-numbering of the
         fields. */
        if (field_name_is_empty){
            first_idx = auto_number.an_field_number
            auto_number.an_field_number += 1
        }
    }
    
    return 1;
}


/*
 get_field_object returns the object inside {}, before the
 format_spec.  It handles getindex and getattr lookups and consumes
 the entire input string.
 */
func get_field_object(_ input:SubString, args:[Any], kwargs:[String:Any],
                      auto_number:inout AutoNumber) -> PyObject
{
    var obj:PyObject? = nil
    var ok:int
    var is_attribute:int
    var name:SubString
    var first:SubString
    var index:Py_ssize_t
    var rest:FieldNameIterator
    
    if (!field_name_split(input.str, start: input.start, end: input.end, first: &first,
                          first_idx: &index, rest: &rest, auto_number: &auto_number)) {
        return NULL
    }
    
    if (index == -1) {
        /* look up in kwargs */
        var key:PyObject = SubString_new_object(first);
        if (key == NULL) {
            return NULL;
        }
        if (kwargs == NULL) {
            PyErr_SetObject(PyExc_KeyError, key);
            return NULL;
        }
        /* Use PyObject_GetItem instead of PyDict_GetItem because this
         code is no longer just used with kwargs. It might be passed
         a non-dict when called through format_map. */
        obj = PyObject_GetItem(kwargs, key);
        if (obj == NULL) {
            return NULL;
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
            return NULL;
        }
        
        /* look up in args */
        obj = PySequence_GetItem(args, index);
        if (obj == NULL) {
            PyErr_Format(PyExc_IndexError,
                         "Replacement index %zd out of range for positional "
                "args tuple",
                index);
            return NULL;
        }
    }
    
    /* iterate over the rest of the field_name */
    while ((ok = FieldNameIterator_next(&rest, is_attribute: &is_attribute, name_idx: &index,
                                        name: &name)) == 2) {
            var tmp:PyObject
            
            if (is_attribute){
                /* getattr lookup "." */
                tmp = getattr(obj, &name);
            }
            else{
                /* getitem lookup "[]" */
                if (index == -1){
                    tmp = getitem_str(obj, &name);
                }
                else{
                    if (PySequence_Check(obj)){
                        tmp = getitem_sequence(obj, index);
                    }
                    else{
                        /* not a sequence */
                        tmp = getitem_idx(obj, index);
                    }
                }
            }
            if (tmp == NULL){
                return NULL
            }
            /* assign to obj */
            obj = tmp;
    }
    /* end of iterator, this is the non-error case */
    if (ok == 1){
        return obj
    }
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
func render_field(_ fieldobj:PyObject, _ format_spec:SubString, _ writer:inout _PyUnicodeWriter) -> int
{
    var ok:int = 0
    var result:PyObject = NULL
    var format_spec_object:PyObject = NULL
    var err:int
    
    /* If we know the type exactly, skip the lookup of __format__ and just
     call the formatter directly. */
    if (PyUnicode_CheckExact(fieldobj)){
        err = _PyUnicode_FormatAdvancedWriter(&writer, fieldobj, format_spec.str,
                                                    format_spec.start, format_spec.end);
        return (err == 0);
    }
    else if (PyLong_CheckExact(fieldobj)){
        err = _PyLong_FormatAdvancedWriter(&writer, fieldobj, format_spec.str,
                                                 format_spec.start, format_spec.end);
        return (err == 0);
    }
    else if (PyFloat_CheckExact(fieldobj)){
        err = _PyFloat_FormatAdvancedWriter(&writer, fieldobj, format_spec.str,
                                                  format_spec.start, format_spec.end);
        return (err == 0);
    }
    else if (PyComplex_CheckExact(fieldobj)){
        err = _PyComplex_FormatAdvancedWriter(&writer, fieldobj, format_spec.str,
                                                    format_spec.start, format_spec.end);
        return (err == 0);
    }
    else {
        /* We need to create an object out of the pointers we have, because
         __format__ takes a string/unicode object for format_spec. */
        if (format_spec.str){
            format_spec_object = PyUnicode_Substring(format_spec.str,
                                                     format_spec.start,
                                                     format_spec.end);
        }
        else{
            format_spec_object = PyUnicode_New(0, 0);
        }
        if (format_spec_object == NULL){
            return ok;
        }
        
        result = PyObject_Format(fieldobj, format_spec_object);
    }
    if (result == NULL){
        return ok;
    }
    
    if (_PyUnicodeWriter_WriteStr(writer, result) == -1){
        ok = 1;
    }
    return ok;
}

func parse_field(_ str:inout SubString, _ field_name:inout SubString, _ format_spec:inout SubString,
                 format_spec_needs_expanding:inout int, conversion:inout Py_UCS4) -> int
{
    /* Note this function works if the field name is zero length,
     which is good.  Zero length field names are handled later, in
     field_name_split. */
    
    var c:Py_UCS4
    
    /* initialize these, as they may be empty */
    conversion = "\0"
    format_spec = .init("",start:0,end:0)
    
    /* Search for the field name.  it's terminated by the end of
     the string, or a ':' or '!' */
    field_name.str = str.str
    field_name.start = str.start
    while (str.start < str.end) {
        var c = PyUnicode_READ_CHAR(str.str as! String, str.start)
        str.start += 1
        switch c {
        case "{":
            PyErr_SetString(PyExc_ValueError, "unexpected '{' in field name");
            return 0;
        case "[":
            while str.start < str.end {
                str.start += 1
                if (PyUnicode_READ_CHAR(str.str as! String, str.start) == "]"){
                    break;
                }
            }
            continue;
        case "}":
            fallthrough
        case ":":
            fallthrough
        case "!":
            break;
        default:
            continue;
        }
        break;
    }
    
    field_name.end = str.start - 1;
    if (c == "!" || c == ":") {
        var count:Py_ssize_t
        /* we have a format specifier and/or a conversion */
        /* don't include the last character */
        
        /* see if there's a conversion specifier */
        if (c == "!") {
            /* there must be another character present */
            if (str.start >= str.end) {
                PyErr_SetString(PyExc_ValueError,
                                "end of string while looking for conversion "
                    "specifier");
                return 0;
            }
            conversion = PyUnicode_READ_CHAR(str.str as! String, str.start)
            str.start += 1
            
            if (str.start < str.end) {
                c = PyUnicode_READ_CHAR(str.str as! String, str.start)
                str.start += 1
                if (c == "}"){
                    return 1;
                }
                if (c != ":") {
                    PyErr_SetString(PyExc_ValueError,
                                    "expected ':' after conversion specifier");
                    return 0;
                }
            }
        }
        format_spec.str = str.str;
        format_spec.start = str.start;
        count = 1;
        while (str.start < str.end) {
            c = PyUnicode_READ_CHAR(str.str as! String, str.start)
            str.start += 1
            switch c {
            case "{":
                format_spec_needs_expanding = 1;
                count += 1
                break;
            case "}":
                count -= 1;
                if (count == 0) {
                    format_spec.end = str.start - 1;
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
    else if (c != "}") {
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
    
    init(_ str:PyObject,_ start:Py_ssize_t, _ end:Py_ssize_t) {
        self.str = .init(str, start:start, end:end)
    }
}

/* returns 0 on error, 1 on non-error termination, and 2 if it got a
 string (or something to be expanded) */
func MarkupIterator_next(_ self:inout MarkupIterator, _ literal:inout SubString,
                         _ field_present:inout int, _ field_name:inout SubString,
                         _ format_spec:inout SubString, _ conversion:inout Py_UCS4,
                         _ format_spec_needs_expanding:inout int) -> int
{
    var at_end:int
    var c:Py_UCS4
    var start:Py_ssize_t
    var len:Py_ssize_t
    var markup_follows:int = 0
    
    /* initialize all of the output variables */
    literal = .init("",start:0,end:0)
    field_name = .init("",start:0,end:0)
    format_spec = .init("",start:0,end:0)
    conversion = "\0"
    format_spec_needs_expanding = 0;
    field_present = 0;
    
    /* No more input, end of iterator.  This is the normal exit
     path. */
    if (self.str.start >= self.str.end){
        return 1;
    }
    
    start = self.str.start;
    
    /* First read any literal text. Read until the end of string, an
     escaped '{' or '}', or an unescaped '{'.  In order to never
     allocate memory and so I can just pass pointers around, if
     there's an escaped '{' or '}' then we'll return the literal
     including the brace, but no format object.  The next time
     through, we'll return the rest of the literal, skipping past
     the second consecutive brace. */
    while (self.str.start < self.str.end) {
        c = PyUnicode_READ_CHAR(self.str.str as! String, self.str.start)
        self.str.start += 1
        switch c {
        case "{":
            fallthrough
        case "}":
            markup_follows = 1;
            break;
        default:
            continue;
        }
        break;
    }
    
    at_end = self.str.start >= self.str.end;
    len = self.str.start - start;
    
    if ((c == "}") && (at_end ||
        (c != PyUnicode_READ_CHAR(self.str.str,
                                  self.str.start)))) {
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
        if c == PyUnicode_READ_CHAR(self.str.str, self.str.start) {
            /* escaped } or {, skip it in the input.  there is no
             markup object following us, just this literal text */
            self.str.start += 1
            markup_follows = 0
        }
        else{
            len -= 1;
        }
    }
    
    /* record the literal text */
    literal.str = self.str.str;
    literal.start = start;
    literal.end = start + len;
    
    if (!markup_follows){
        return 2;
    }
    
    /* this is markup; parse the field */
    field_present = 1;
    if (!parse_field(&self.str, &field_name, &format_spec,
                     format_spec_needs_expanding: &format_spec_needs_expanding, conversion: &conversion)){
        return 0;
    }
    return 2;
}


/* do the !r or !s conversion on obj */
func do_conversion(_ obj:PyObject,_ conversion:Py_UCS4) -> PyObject
{
    /* XXX in pre-3.0, do we need to convert this to unicode, since it
     might have returned a string? */
    switch (conversion) {
    case "r":
        return PyObject_Repr(obj);
    case "s":
        return PyObject_Str(obj);
    case "a":
        return PyObject_ASCII(obj);
    default:
        if (conversion > 32 && conversion < 127) {
            /* It's the ASCII subrange; casting to char is safe
             (assuming the execution character set is an ASCII
             superset). */
            PyErr_Format(PyExc_ValueError,
                         "Unknown conversion specifier %c",
                         (char)conversion);
        } else {
            PyErr_Format(PyExc_ValueError,
                         "Unknown conversion specifier \\x%x",
                         (unsigned int)conversion)
        }
        return NULL;
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

func output_markup(_ field_name:SubString, _ format_spec:SubString,
                   _ format_spec_needs_expanding:int, _ conversion:Py_UCS4,
                   _ writer:inout _PyUnicodeWriter, args:[Any], kwargs:[String:Any],
                   _ recursion_depth:int, _ auto_number:inout AutoNumber) -> int
{
    var tmp:PyObject
    var fieldobj:PyObject
    var expanded_format_spec:SubString
    var actual_format_spec:SubString
    var result:int = 0;
    
    /* convert field_name to an object */
    fieldobj = get_field_object(field_name, args: args, kwargs: kwargs, auto_number: &auto_number);
    if (fieldobj == NULL){
        return result;
    }
    
    if (conversion != "\0") {
        tmp = do_conversion(fieldobj, conversion);
        if (tmp == NULL || PyUnicode_READY(tmp) == -1){
            return result;
        }
        
        /* do the assignment, transferring ownership: fieldobj = tmp */
        fieldobj = tmp;
        tmp = NULL;
    }
    
    /* if needed, recurively compute the format_spec */
    if (format_spec_needs_expanding) {
        tmp = build_string(format_spec, args, kwargs, recursion_depth-1,
                           auto_number);
        if (tmp == NULL || PyUnicode_READY(tmp) == -1){
            return result;
        }
        
        /* note that in the case we're expanding the format string,
         tmp must be kept around until after the call to
         render_field. */
        expanded_format_spec = .init(tmp, start:0, end:PyUnicode_GET_LENGTH(tmp))
        actual_format_spec = &expanded_format_spec;
    }
    else{
        actual_format_spec = format_spec;
    }
    
    if (render_field(fieldobj, actual_format_spec, &writer) == 0){
        return result;
    }
    
    result = 1;
    
    return result;
}

/*
 do_markup is the top-level loop for the format() method.  It
 searches through the format string for escapes to markup codes, and
 calls other functions to move non-markup text to the output,
 and to perform the markup to the output.
 */
func do_markup(_ input:SubString, args:[Any], kwargs:[String:Any],
               _ writer:inout _PyUnicodeWriter, _ recursion_depth:int, _ auto_number:AutoNumber) -> int
{
    var iter:MarkupIterator
    var format_spec_needs_expanding:int
    var result:int
    var field_present:int
    var literal:SubString
    var field_name:SubString
    var format_spec:SubString
    var conversion:Py_UCS4
    
    iter = .init( input.str, input.start, input.end);
    while ((result = MarkupIterator_next(&iter, &literal, &field_present,
                                         &field_name, &format_spec,
                                         &conversion,
                                         &format_spec_needs_expanding)) == 2) {
                                            if (literal.end != literal.start) {
                                                if (!field_present && iter.str.start == iter.str.end){
                                                    writer->overallocate = 0;
                                                }
                                                if (_PyUnicodeWriter_WriteSubstring(writer, literal.str,
                                                                                    literal.start, literal.end) < 0){
                                                    return 0;
                                                }
                                            }
                                            
                                            if (field_present) {
                                                if (iter.str.start == iter.str.end){
                                                    writer->overallocate = 0;
                                                }
                                                if (!output_markup(&field_name, &format_spec,
                                                                   format_spec_needs_expanding, conversion, writer,
                                                                   args, kwargs, recursion_depth, auto_number)){
                                                    return 0;
                                                }
                                            }
    }
    return result;
}


/*
 build_string allocates the output string and then
 calls do_markup to do the heavy lifting.
 */
func build_string(_ input:SubString, _ args:[Any], _ kwargs:[String:Any],
                  _ recursion_depth:int, _ auto_number:AutoNumber) -> PyObject
{
    var writer = _PyUnicodeWriter()
    
    /* check the recursion level */
    if (recursion_depth <= 0) {
        PyErr_SetString(PyExc_ValueError,
                        "Max string recursion exceeded");
        return NULL;
    }
    
    writer.overallocate = 1;
    writer.min_length = PyUnicode_GET_LENGTH(input.str) + 100;
    
    if (!do_markup(input, args, kwargs, &writer, recursion_depth,
                   auto_number)) {
        return NULL;
    }
    
    return writer.buffer;
}

/************************************************************************/
/*********** main routine ***********************************************/
/************************************************************************/

/* this is the main entry point */
func do_string_format(_ self:String, args:[Any], kwargs:[String:Any]) -> PyObject
{
    var input:SubString
    
    /* PEP 3101 says only 2 levels, so that
     "{0:{1}}".format('abc', 's')            # works
     "{0:{1:{2}}}".format('abc', 's', '')    # fails
     */
    var recursion_depth:int = 2;
    
    var auto_number = AutoNumber()
    
    
    input = .init(self, start: 0, end: PyUnicode_GET_LENGTH(self))
    return build_string(input, acos, kwargs, recursion_depth, &auto_number);
}




/* implements the unicode (as opposed to string) version of the
 built-in formatters for string, int, float.  that is, the versions
 of int.__float__, etc., that take and return unicode objects */


/* Raises an exception about an unknown presentation type for this
 * type. */

func unknown_presentation_type(presentation_type:Py_UCS4,_ obj:Any) -> Result<Void,PyException>
{
    let type_name = String(describing: obj)
    /* %c might be out-of-range, hence the two cases. */
    if (presentation_type > 32 && presentation_type < 128){
        PyErr_Format(PyExc_ValueError,
                     "Unknown format code '%c' "
            "for object of type '%.200s'",
            (char)presentation_type,
            type_name);
    }
    else{
        PyErr_Format(PyExc_ValueError,
                     "Unknown format code '\\x%x' "
            "for object of type '%.200s'",
            (unsigned int)presentation_type,
            type_name);
    }
}

func invalid_thousands_separator_type(char specifier, Py_UCS4 presentation_type) -> Result<Void,PyException>
{
    assert(specifier == "," || specifier == "_");
    if (presentation_type > 32 && presentation_type < 128){
        return .failure(.ValueError(
                     "Cannot specify '%c' with '%c'.",
                     specifier, (char)presentation_type))
    }
    else{
        return .failure(.ValueError(
                     "Cannot specify '%c' with '\\x%x'.",
                     specifier, (unsigned int)presentation_type))
    }
}

func invalid_comma_and_underscore() -> Result<Void,PyException>
{
    return .failure(.ValueError("Cannot specify both ',' and '_'."))
}

/*
 get_integer consumes 0 or more decimal digit characters from an
 input string, updates *result with the corresponding positive
 integer, and returns the number of digits consumed.
 
 returns -1 on error.
 */
func get_integer(_ str:PyObject, _ ppos:inout Py_ssize_t, _ end:Py_ssize_t, result:inout Py_ssize_t) -> int
{
    var accumulator:Py_ssize_t
    var digitval:Py_ssize_t
    var pos:Py_ssize_t = ppos
    var numdigits:int
    
    accumulator = 0
    numdigits = 0
    while  pos < end {
        digitval = Py_UNICODE_TODECIMAL(PyUnicode_READ(str, pos));
        if (digitval < 0){
            break;
        }
        /*
         Detect possible overflow before it happens:
         
         accumulator * 10 + digitval > PY_SSIZE_T_MAX if and only if
         accumulator > (PY_SSIZE_T_MAX - digitval) / 10.
         */
        if (accumulator > (PY_SSIZE_T_MAX - digitval) / 10) {
            PyErr_Format(PyExc_ValueError,
                         "Too many decimal digits in format string");
            ppos = pos;
            return -1;
        }
        accumulator = accumulator * 10 + digitval;
        numdigits += 1

        pos += 1
    }
    ppos = pos;
    result = accumulator;
    return numdigits;
}

/************************************************************************/
/*********** standard format specifier parsing **************************/
/************************************************************************/

/* returns true if this character is a specifier alignment token */
func is_alignment_token(_ c:Py_UCS4) -> int
{
    if ("<>=^".contains(c)) {
        return 1
    }
    return 0
}

/* returns true if this character is a sign element */
func is_sign_element(_ c:Py_UCS4) -> int
{
    if (" +-".contains(c)) {
        return 1
    }
    return 0
}

/* Locale type codes. LT_NO_LOCALE must be zero. */
enum LocaleType : Character {
    case LT_NO_LOCALE = "\0"
    case LT_DEFAULT_LOCALE = ","
    case LT_UNDERSCORE_LOCALE = "_"
    case LT_UNDER_FOUR_LOCALE = "`"
    case LT_CURRENT_LOCALE = "a"
}

struct InternalFormatSpec{
    var fill_char:Py_UCS4
    var align:Py_UCS4
    var alternate:int
    var sign:Py_UCS4
    var width:Py_ssize_t
    var thousands_separators:LocaleType
    var precision:Py_ssize_t
    var type:Py_UCS4
}

/* Occasionally useful for debugging. Should normally be commented out. */
func DEBUG_PRINT_FORMAT_SPEC(_ format:InternalFormatSpec)
{
    func printf(_ item:Any...){print(item)}
    printf("internal format spec: fill_char %d\n", format.fill_char);
    printf("internal format spec: align %d\n", format.align);
    printf("internal format spec: alternate %d\n", format.alternate);
    printf("internal format spec: sign %d\n", format.sign);
    printf("internal format spec: width %zd\n", format.width);
    printf("internal format spec: thousands_separators %d\n",
           format.thousands_separators);
    printf("internal format spec: precision %zd\n", format.precision);
    printf("internal format spec: type %c\n", format.type);
    printf("\n")
}


/*
 ptr points to the start of the format_spec, end points just past its end.
 fills in format with the parsed information.
 returns 1 on success, 0 on failure.
 if failure, sets the exception
 */
func parse_internal_render_format_spec(_ format_spec:PyObject,
                                       _ start:Py_ssize_t, _ end:Py_ssize_t,
                                       _ format:inout InternalFormatSpec,
                                       _ default_type:Character,_ default_align:Character) -> int
{
    var pos:Py_ssize_t = start;
    /* end-pos is used throughout this code to specify the length of
     the input string */
    
    
    var consumed:Py_ssize_t
    var align_specified:int = 0
    var fill_char_specified:int = 0;
    
    format.fill_char = " ";
    format.align = default_align;
    format.alternate = 0;
    format.sign = "\0";
    format.width = -1;
    format.thousands_separators = .LT_NO_LOCALE;
    format.precision = -1;
    format.type = default_type;
    
    /* If the second char is an alignment token,
     then parse the fill char */
    if (end-pos >= 2 && is_alignment_token(format_spec[pos+1])) {
        format.align = format_spec[pos+1]
        format.fill_char = format_spec[pos]
        fill_char_specified = 1;
        align_specified = 1;
        pos += 2;
    }
    else if (end-pos >= 1 && is_alignment_token(format_spec[pos])) {
        format.align = format_spec[pos]
        align_specified = 1;
        pos += 1
    }
    
    /* Parse the various sign options */
    if (end-pos >= 1 && is_sign_element(format_spec[pos])) {
        format.sign = format_spec[pos];
        pos += 1
    }
    
    /* If the next character is #, we're in alternate mode.  This only
     applies to integers. */
    if (end-pos >= 1 && format_spec[pos] == "#") {
        format.alternate = 1;
        pos += 1
    }
    
    /* The special case for 0-padding (backwards compat) */
    if (!fill_char_specified && end-pos >= 1 && format_spec[pos] == "0") {
        format.fill_char = "0";
        if (!align_specified) {
            format.align = "=";
        }
        pos += 1
    }
    
    consumed = get_integer(format_spec, &pos, end, result: &format.width);
    if (consumed == -1){
        /* Overflow error. Exception already set. */
        return 0;
    }
    
    /* If consumed is 0, we didn't consume any characters for the
     width. In that case, reset the width to -1, because
     get_integer() will have set it to zero. -1 is how we record
     that the width wasn't specified. */
    if (consumed == 0){
        format.width = -1;
    }
    
    /* Comma signifies add thousands separators */
    if (end-pos && format_spec[pos] == ",") {
        format.thousands_separators = .LT_DEFAULT_LOCALE;
        pos += 1
    }
    /* Underscore signifies add thousands separators */
    if (end-pos && format_spec[pos] == "_") {
        if (format.thousands_separators != .LT_NO_LOCALE) {
            invalid_comma_and_underscore();
            return 0;
        }
        format.thousands_separators = .LT_UNDERSCORE_LOCALE;
        pos += 1
    }
    if (end-pos && format_spec[pos] == ",") {
        invalid_comma_and_underscore();
        return 0;
    }
    
    /* Parse field precision */
    if (end-pos && format_spec[pos] == '.') {
        pos += 1
        
        consumed = get_integer(format_spec, &pos, end, result: &format.precision);
        if (consumed == -1){
            /* Overflow error. Exception already set. */
            return 0;
        }
        
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
        format.type = format_spec[pos]
        pos += 1
    }
    
    /* Do as much validating as we can, just by looking at the format
     specifier.  Do not take into account what type of formatting
     we're doing (int, float, string). */
    
    if (format.thousands_separators) {
        switch (format.type) {
        case "d":
            fallthrough
        case "e":
            fallthrough
        case "f":
            fallthrough
        case "g":
            fallthrough
        case "E":
            fallthrough
        case "G":
            fallthrough
        case "%":
            fallthrough
        case "F":
            fallthrough
        case "\0":
            /* These are allowed. See PEP 378.*/
            break;
        case "b":
            fallthrough
        case "o":
            fallthrough
        case "x":
            fallthrough
        case "X":
            /* Underscores are allowed in bin/oct/hex. See PEP 515. */
            if (format.thousands_separators == .LT_UNDERSCORE_LOCALE) {
                /* Every four digits, not every three, in bin/oct/hex. */
                format.thousands_separators = .LT_UNDER_FOUR_LOCALE;
                break;
            }
            /* fall through */
        default:
            invalid_thousands_separator_type(format.thousands_separators, format.type);
            return 0;
        }
    }
    
    assert(format.align <= .init(127))
    assert(format.sign <= .init(127))
    return 1;
}

/* Calculate the padding needed. */
func calc_padding(_ nchars:Py_ssize_t, width:Py_ssize_t, align:Py_UCS4,
                  _ n_lpadding:inout Py_ssize_t, n_rpadding: inout Py_ssize_t,
                  n_total:inout Py_ssize_t) -> Void
{
    if (width >= 0) {
        if (nchars > width){
            n_total = nchars;
        }
        else{
            n_total = width;
        }
    }
    else {
        /* not specified, use all of the chars and no more */
        n_total = nchars;
    }
    
    /* Figure out how much leading space we need, based on the
     aligning */
    if (align == ">"){
        n_lpadding = n_total - nchars;
    }
    else if (align == "^"){
        n_lpadding = (n_total - nchars) / 2;
    }
    else if (align == "<" || align == "="){
        n_lpadding = 0;
    }
    else {
        /* We should never have an unspecified alignment. */
        //Py_UNREACHABLE();// 確実に来ない
    }
    
    n_rpadding = n_total - nchars - n_lpadding;
}

/* Do the padding, and return a pointer to where the caller-supplied
 content goes. */
func fill_padding(_ writer:inout _PyUnicodeWriter,
                  _ nchars:Py_ssize_t,
                  _ fill_char:Py_UCS4, _ n_lpadding:Py_ssize_t,
                  _ n_rpadding:Py_ssize_t) -> int
{
    var pos:Py_ssize_t
    
    /* Pad on left. */
    if (n_lpadding) {
        pos = writer.pos;
        _PyUnicode_FastFill(writer.buffer, pos, n_lpadding, fill_char);
    }
    
    /* Pad on right. */
    if (n_rpadding) {
        pos = writer.pos + nchars + n_lpadding;
        _PyUnicode_FastFill(writer.buffer, pos, n_rpadding, fill_char);
    }
    
    /* Pointer to the user content. */
    writer.pos += n_lpadding;
    return 0;
}

/************************************************************************/
/*********** common routines for numeric formatting *********************/
/************************************************************************/

/* Locale info needed for formatting integers and the part of floats
 before and including the decimal. Note that locales only support
 8-bit chars, not unicode. */
struct LocaleInfo{
    var decimal_point:PyObject = ""
    var thousands_sep:PyObject = ""
    var grouping:String = ""
}


/* describes the layout for an integer, see the comment in
 calc_number_widths() for details */
struct NumberFieldWidths{
    var n_lpadding:Py_ssize_t
    var n_prefix:Py_ssize_t
    var n_spadding:Py_ssize_t
    var n_rpadding:Py_ssize_t
    var sign:Character
    var n_sign:Py_ssize_t      /* number of digits needed for sign (0/1) */
    var n_grouped_digits:Py_ssize_t /* Space taken up by the digits, including
     any grouping chars. */
    var n_decimal:Py_ssize_t   /* 0 if only an integer */
    var n_remainder:Py_ssize_t /* Digits in decimal and/or exponent part,
     excluding the decimal itself, if
     present. */
    
    /* These 2 are not the widths of fields, but are needed by
     STRINGLIB_GROUPING. */
    var n_digits:Py_ssize_t    /* The number of digits before a decimal
     or exponent. */
    var n_min_width:Py_ssize_t /* The min_width we used when we computed
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
func parse_number(_ s:PyObject, _ pos:Py_ssize_t, _ end:Py_ssize_t,
                  _ n_remainder:inout Py_ssize_t,  _ has_decimal:inout int) -> Void
{
    var remainder:Py_ssize_t
    var pos = pos
    
    while (pos<end && Py_ISDIGIT(s[pos])){
        pos += 1
    }
    remainder = pos;
    
    /* Does remainder start with a decimal point? */
    has_decimal = pos<end && s[remainder] == ".";
    
    /* Skip the decimal point. */
    if (has_decimal){
        remainder += 1
    }
    
    n_remainder = end - remainder;
}

/* not all fields of format are used.  for example, precision is
 unused.  should this take discrete params in order to be more clear
 about what it does?  or is passing a single format parameter easier
 and more efficient enough to justify a little obfuscation?
 Return -1 on error. */
func calc_number_widths(_ spec:inout NumberFieldWidths , _ n_prefix:Py_ssize_t,
                        _ sign_char:Py_UCS4, _ number:PyObject, _ n_start:Py_ssize_t,
                        _ n_end:Py_ssize_t, _ n_remainder:Py_ssize_t,
                        _ has_decimal:int, _ locale:LocaleInfo,
    format:InternalFormatSpec, maxchar:Py_UCS4) -> Py_ssize_t
{
    var n_non_digit_non_padding:Py_ssize_t
    var n_padding:Py_ssize_t
    
    spec.n_digits = n_end - n_start - n_remainder - (has_decimal ? 1:0);
    spec.n_lpadding = 0;
    spec.n_prefix = n_prefix;
    spec.n_decimal = has_decimal ? PyUnicode_GET_LENGTH(locale.decimal_point) : 0;
    spec.n_remainder = n_remainder;
    spec.n_spadding = 0;
    spec.n_rpadding = 0;
    spec.sign = "\0"
    spec.n_sign = 0;
    
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
    switch (format.sign) {
    case "+":
        /* always put a + or - */
        spec.n_sign = 1;
        spec.sign = (sign_char == "-" ? "-" : "+");
        break;
    case " ":
        spec.n_sign = 1;
        spec.sign = (sign_char == "-" ? "-" : " ");
        break;
    default:
        /* Not specified, or the default (-) */
        if (sign_char == "-") {
            spec.n_sign = 1;
            spec.sign = "-";
        }
    }
    
    /* The number of chars used for non-digits and non-padding. */
    n_non_digit_non_padding = spec.n_sign + spec.n_prefix + spec.n_decimal +
        spec.n_remainder;
    
    /* min_width can go negative, that's okay. format->width == -1 means
     we don't care. */
    if (format.fill_char == "0" && format.align == "="){
        spec.n_min_width = format.width - n_non_digit_non_padding;
    }
    else{
        spec.n_min_width = 0;
    }
    
    if (spec.n_digits == 0){
        /* This case only occurs when using 'c' formatting, we need
         to special case it because the grouping code always wants
         to have at least one character. */
        spec.n_grouped_digits = 0;
    }
    else {
        var grouping_maxchar:Py_UCS4
        spec.n_grouped_digits = _PyUnicode_InsertThousandsGrouping(
            NULL, 0,
            NULL, 0, spec.n_digits,
            spec.n_min_width,
            locale.grouping, locale.thousands_sep, &grouping_maxchar);
        if (spec.n_grouped_digits == -1) {
            return -1;
        }
        maxchar = Py_MAX(*maxchar, grouping_maxchar);
    }
    
    /* Given the desired width and the total of digit and non-digit
     space we consume, see if we need any padding. format->width can
     be negative (meaning no padding), but this code still works in
     that case. */
    n_padding = format.width -
        (n_non_digit_non_padding + spec.n_grouped_digits);
    if (n_padding > 0) {
        /* Some padding is needed. Determine if it's left, space, or right. */
        switch (format.align) {
        case "<":
            spec.n_rpadding = n_padding;
            break;
        case "^":
            spec.n_lpadding = n_padding / 2;
            spec.n_rpadding = n_padding - spec.n_lpadding;
            break;
        case "=":
            spec.n_spadding = n_padding;
            break;
        case ">":
            spec.n_lpadding = n_padding;
            break;
        default:
            /* Shouldn't get here, but treat it as '>' */
//            Py_UNREACHABLE(); ここには来ない
            break
        }
    }
    
    if (spec.n_lpadding || spec.n_spadding || spec.n_rpadding){
        maxchar = Py_MAX(maxchar, format.fill_char);
    }
    
    if (spec.n_decimal){
        maxchar = Py_MAX(maxchar, PyUnicode_MAX_CHAR_VALUE(locale.decimal_point));
    }
    
    return spec.n_lpadding + spec.n_sign + spec.n_prefix +
        spec.n_spadding + spec.n_grouped_digits + spec.n_decimal +
        spec.n_remainder + spec.n_rpadding;
}

/* Fill in the digit parts of a numbers's string representation,
 as determined in calc_number_widths().
 Return -1 on error, or 0 on success. */
func fill_number(_ writer:inout _PyUnicodeWriter, _ spec:NumberFieldWidths,
                 _ digits:PyObject, _ d_start:Py_ssize_t, _ d_end:Py_ssize_t,
                 _ prefix:PyObject, _ p_start:Py_ssize_t,
                 _ fill_char:Py_UCS4,
                 _ locale:LocaleInfo, _ toupper:int) -> int
{
    /* Used to keep track of digits, decimal, and remainder. */
    var d_pos:Py_ssize_t = d_start
    const unsigned int kind = writer.kind;
    const void *data = writer.data;
    var r:Py_ssize_t
    
    if (spec.n_lpadding) {
        _PyUnicode_FastFill(writer.buffer,
                            writer.pos, spec.n_lpadding, fill_char);
        writer.pos += spec.n_lpadding;
    }
    if (spec.n_sign == 1) {
        PyUnicode_WRITE(kind, data, writer.pos, spec.sign);
        writer.pos += 1
    }
    if (spec.n_prefix) {
        _PyUnicode_FastCopyCharacters(writer.buffer, writer.pos,
                                      prefix, p_start,
                                      spec.n_prefix);
        if (toupper) {
            var t:Py_ssize_t = 0
            while t < spec.n_prefix {
                var c:Py_UCS4 = PyUnicode_READ(kind, data, writer.pos + t);
                c = Py_TOUPPER(c);
                assert (c <= 127);
                PyUnicode_WRITE(kind, data, writer.pos + t, c);
                t += 1
            }
        }
        writer.pos += spec.n_prefix;
    }
    if (spec.n_spadding) {
        _PyUnicode_FastFill(writer.buffer,
                            writer.pos, spec.n_spadding, fill_char);
        writer.pos += spec.n_spadding;
    }
    
    /* Only for type 'c' special case, it has no digits. */
    if (spec.n_digits != 0) {
        /* Fill the digits with InsertThousandsGrouping. */
        r = _PyUnicode_InsertThousandsGrouping(
            writer, spec.n_grouped_digits,
            digits, d_pos, spec.n_digits,
            spec.n_min_width,
            locale.grouping, locale.thousands_sep, NULL);
        if (r == -1){
            return -1;
        }
        assert(r == spec.n_grouped_digits);
        d_pos += spec.n_digits;
    }
    if (toupper) {
        var t:Py_ssize_t = 0
        while t < spec.n_grouped_digits {
            var c:Py_UCS4 = PyUnicode_READ(kind, data, writer.pos + t);
            c = Py_TOUPPER(c);
            if (c > 127) {
                PyErr_SetString(PyExc_SystemError, "non-ascii grouped digit");
                return -1;
            }
            PyUnicode_WRITE(kind, data, writer.pos + t, c);
            t += 1
        }
    }
    writer.pos += spec.n_grouped_digits;
    
    if (spec.n_decimal) {
        _PyUnicode_FastCopyCharacters(
            writer.buffer, writer.pos,
            locale.decimal_point, 0, spec.n_decimal);
        writer.pos += spec.n_decimal;
        d_pos += 1;
    }
    
    if (spec.n_remainder) {
        _PyUnicode_FastCopyCharacters(
            writer.buffer, writer.pos,
            digits, d_pos, spec.n_remainder);
        writer.pos += spec.n_remainder;
        /* d_pos += spec->n_remainder; */
    }
    
    if (spec.n_rpadding) {
        _PyUnicode_FastFill(writer.buffer,
                            writer.pos, spec.n_rpadding,
                            fill_char);
        writer.pos += spec.n_rpadding;
    }
    return 0;
}

let no_grouping = ""

/* Find the decimal point character(s?), thousands_separator(s?), and
 grouping description, either for the current locale if type is
 LT_CURRENT_LOCALE, a hard-coded locale if LT_DEFAULT_LOCALE or
 LT_UNDERSCORE_LOCALE/LT_UNDER_FOUR_LOCALE, or none if LT_NO_LOCALE. */
func _get_local_info() -> (String,String,String) {
    // TODO:remove force unwrap
    // TODO: \0 to ""(empty String)
    if let local = localeconv() {
        let lc = local.pointee
        if let decimal_point = lc.decimal_point {
            let dp = String(UnicodeScalar(UInt32(decimal_point.pointee))!)
            if let thousands_sep = lc.thousands_sep {
                let ts = String(UnicodeScalar(UInt32(thousands_sep.pointee))!)
                if let grouping = lc.grouping {
                    let gp = String(UnicodeScalar(UInt32(grouping.pointee))!)
                    return (dp,ts,gp)
                }
                return (dp,ts,"")
            }
            return (dp,",","")
        }
    }
    return (".",",","")
}
func get_locale_info(_ type:LocaleType, _ locale_info:inout LocaleInfo) -> int
{
    switch (type) {
    case .LT_CURRENT_LOCALE:
        (locale_info.decimal_point,locale_info.thousands_sep,locale_info.grouping) = _get_local_info()
        
        /* localeconv() grouping can become a dangling pointer or point
         to a different string if another thread calls localeconv() during
         the string formatting. Copy the string to avoid this risk. */
        break;
        
    case .LT_DEFAULT_LOCALE:
        fallthrough
    case .LT_UNDERSCORE_LOCALE:
        fallthrough
    case .LT_UNDER_FOUR_LOCALE:
        locale_info.decimal_point = PyUnicode_FromOrdinal(".");
        locale_info.thousands_sep = PyUnicode_FromOrdinal(
            type == .LT_DEFAULT_LOCALE ? "," : "_");
        if (!locale_info.decimal_point || !locale_info.thousands_sep){
            return -1;
        }
        if (type != .LT_UNDER_FOUR_LOCALE){
            locale_info.grouping = "\u{3}"; /* Group every 3 characters.  The
             (implicit) trailing 0 means repeat
             infinitely. */
        }
        else{
            locale_info.grouping = "\u{4}"; /* Bin/oct/hex group every four. */
        }
        break;
    case .LT_NO_LOCALE:
        locale_info.decimal_point = PyUnicode_FromOrdinal(".");
        locale_info.thousands_sep = PyUnicode_New(0, 0);
        if (!locale_info.decimal_point || !locale_info.thousands_sep){
            return -1;
        }
        locale_info.grouping = no_grouping;
        break;
    }
    return 0;
}


/************************************************************************/
/*********** string formatting ******************************************/
/************************************************************************/

func format_string_internal(_ value:PyObject, _ format:InternalFormatSpec,
                            _ writer:inout _PyUnicodeWriter) -> int
{
    var lpad:Py_ssize_t
    var rpad:Py_ssize_t
    var total:Py_ssize_t
    var len:Py_ssize_t
    var result:int = -1
    var maxchar:Py_UCS4
    
    len = PyUnicode_GET_LENGTH(value)
    
    /* sign is not allowed on strings */
    if (format.sign != "\0") {
        PyErr_SetString(PyExc_ValueError,
                        "Sign not allowed in string format specifier");
        return result;
    }
    
    /* alternate is not allowed on strings */
    if (format.alternate) {
        PyErr_SetString(PyExc_ValueError,
                        "Alternate form (#) not allowed in string format "
            "specifier");
        return result;
    }
    
    /* '=' alignment not allowed on strings */
    if (format.align == "=") {
        PyErr_SetString(PyExc_ValueError,
                        "'=' alignment not allowed "
            "in string format specifier");
        return result;
    }
    
    if ((format.width == -1 || format.width <= len)
        && (format.precision == -1 || format.precision >= len)) {
        /* Fast path */
        return _PyUnicodeWriter_WriteStr(writer, value);
    }
    
    /* if precision is specified, output no more that format.precision
     characters */
    if (format.precision >= 0 && len >= format.precision) {
        len = format.precision;
    }
    
    calc_padding(len, format.width, format.align, &lpad, &rpad, &total);
    
    maxchar = writer.maxchar;
    if (lpad != 0 || rpad != 0){
        maxchar = Py_MAX(maxchar, format.fill_char);
    }
    if (PyUnicode_MAX_CHAR_VALUE(value) > maxchar) {
        let valmaxchar:Py_UCS4 = _PyUnicode_FindMaxChar(value, 0, len);
        maxchar = Py_MAX(maxchar, valmaxchar);
    }
    
    /* allocate the resulting string */
    if (_PyUnicodeWriter_Prepare(writer, total, maxchar) == -1){
        return result;
    }
    
    /* Write into that space. First the padding. */
    result = fill_padding(&writer, len, format.fill_char, lpad, rpad);
    if (result == -1){
        return result;
    }
    
    /* Then the source string. */
    if (len) {
        _PyUnicode_FastCopyCharacters(writer.buffer, writer.pos,
                                      value, 0, len);
    }
    writer.pos += (len + rpad);
    result = 0;
    
    return result;
}


/************************************************************************/
/*********** long formatting ********************************************/
/************************************************************************/

func format_long_internal(_ value:PyObject, _ format:InternalFormatSpec,
                          _ writer:inout _PyUnicodeWriter) -> int
{
    var result:int = -1;
    var maxchar:Py_UCS4 = 127;
    var tmp:PyObject = NULL;
    var inumeric_chars:Py_ssize_t
    var sign_char:Py_UCS4 = "\0"
    var n_digits:Py_ssize_t       /* count of digits need from the computed string */
    var n_remainder:Py_ssize_t = 0; /* Used only for 'c' formatting, which produces non-digits */
    var n_prefix:Py_ssize_t = 0;   /* Count of prefix chars, (e.g., '0x') */
    var n_total:Py_ssize_t
    var prefix:Py_ssize_t = 0;
    var spec:NumberFieldWidths
    var x:long
    
    /* Locale settings, either from the actual locale or
     from a hard-code pseudo-locale */
    var locale:LocaleInfo
    
    /* no precision allowed on integers */
    if (format.precision != -1) {
        PyErr_SetString(PyExc_ValueError,
                        "Precision not allowed in integer format specifier");
        return result;
    }
    
    /* special case for character formatting */
    if (format.type == "c") {
        /* error to specify a sign */
        if (format.sign != "\0") {
            PyErr_SetString(PyExc_ValueError,
                            "Sign not allowed with integer"
                " format specifier 'c'");
            return result;
        }
        /* error to request alternate format */
        if (format.alternate) {
            PyErr_SetString(PyExc_ValueError,
                            "Alternate form (#) not allowed with integer"
                " format specifier 'c'");
            return result;
        }
        
        /* taken from unicodeobject.c formatchar() */
        /* Integer input truncated to a character */
        x = PyLong_AsLong(value);
        if (x == -1 && PyErr_Occurred()){
            return result;
        }
        if (x < 0 || x > 0x10ffff) {
            PyErr_SetString(PyExc_OverflowError,
                            "%c arg not in range(0x110000)");
            return result;
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
        var base:int
        var leading_chars_to_skip:int = 0;  /* Number of characters added by
         PyNumber_ToBase that we want to
         skip over. */
        
        /* Compute the base and how many characters will be added by
         PyNumber_ToBase */
        switch (format.type) {
        case "b":
            base = 2;
            leading_chars_to_skip = 2; /* 0b */
            break;
        case "o":
            base = 8;
            leading_chars_to_skip = 2; /* 0o */
            break;
        case "x":
            fallthrough
        case "X":
            base = 16;
            leading_chars_to_skip = 2; /* 0x */
            break;
        case "d":
            fallthrough
        case "n":
            fallthrough
        default:  /* shouldn't be needed, but stops a compiler warning */
            base = 10;
            break;
        }
        
        if (format.sign != "+" && format.sign != " "
            && format.width == -1
            && format.type != "X" && format.type != "n"
            && !format.thousands_separators
            && PyLong_CheckExact(value))
        {
            /* Fast path */
            return _PyLong_FormatWriter(writer, value, base, format.alternate);
        }
        
        /* The number of prefix chars is the same as the leading
         chars to skip */
        if (format.alternate){
            n_prefix = leading_chars_to_skip;
        }
        
        /* Do the hard part, converting to a string in a given base */
        tmp = _PyLong_Format(value, base);
        if (tmp == NULL || PyUnicode_READY(tmp) == -1){
            return result;
        }
        
        inumeric_chars = 0;
        n_digits = PyUnicode_GET_LENGTH(tmp);
        
        prefix = inumeric_chars;
        
        /* Is a sign character present in the output?  If so, remember it
         and skip it */
        if (PyUnicode_READ_CHAR(tmp, inumeric_chars) == "-") {
            sign_char = "-";
            prefix += 1
            leading_chars_to_skip += 1
        }
        
        /* Skip over the leading chars (0x, 0b, etc.) */
        n_digits -= leading_chars_to_skip;
        inumeric_chars += leading_chars_to_skip;
    }
    
    /* Determine the grouping, separator, and decimal point, if any. */
    if (get_locale_info(format->type == "n" ? .LT_CURRENT_LOCALE :
        format.thousands_separators,
                        &locale) == -1){
        return result;
    }
    
    /* Calculate how much memory we'll need. */
    n_total = calc_number_widths(&spec, n_prefix, sign_char, tmp, inumeric_chars,
    inumeric_chars + n_digits, n_remainder, 0,
    &locale, format, &maxchar);
    if (n_total == -1) {
        return result;
    }
    
    /* Allocate the memory. */
    if (_PyUnicodeWriter_Prepare(writer, n_total, maxchar) == -1){
        return result;
    }
    
    /* Populate the memory. */
    result = fill_number(&writer, &spec,
    tmp, inumeric_chars, inumeric_chars + n_digits,
    tmp, prefix, format.fill_char,
    &locale, format.type == "X");
    return result;
}

/************************************************************************/
/*********** float formatting *******************************************/
/************************************************************************/

/* much of this is taken from unicodeobject.c */
func format_float_internal(_ value:PyObject,
                           _ format:InternalFormatSpec,
                           _ writer:inout _PyUnicodeWriter) -> int
{
    var buf:String = NULL;       /* buffer returned from PyOS_double_to_string */
    var n_digits:Py_ssize_t
    var n_remainder:Py_ssize_t
    var n_total:Py_ssize_t
    var has_decimal:int
    var val:double
    var precision:int
    var default_precision:int = 6
    var type:Py_UCS4 = format.type
    var add_pct:int = 0
    var index:Py_ssize_t
    var spec:NumberFieldWidths
    var flags:int = 0
    var result:int = -1
    var maxchar:Py_UCS4 = 127
    var sign_char:Py_UCS4 = "\0"
    var float_type:int /* Used to see if we have a nan, inf, or regular float. */
    var unicode_tmp:PyObject = NULL;
    
    /* Locale settings, either from the actual locale or
     from a hard-code pseudo-locale */
    var locale:LocaleInfo
    
    if (format.precision > INT_MAX) {
        PyErr_SetString(PyExc_ValueError, "precision too big");
        return result;
    }
    precision = format.precision;
    
    if (format.alternate){
        flags |= Py_DTSF_ALT;
    }
    
    if (type == "\0") {
        /* Omitted type specifier.  Behaves in the same way as repr(x)
         and str(x) if no precision is given, else like 'g', but with
         at least one digit after the decimal point. */
        flags |= Py_DTSF_ADD_DOT_0;
        type = "r"
        default_precision = 0;
    }
    
    if (type == "n"){
        /* 'n' is the same as 'g', except for the locale used to
         format the result. We take care of that later. */
        type = "g";
    }
    
    val = PyFloat_AsDouble(value);
    if (val == -1.0 && PyErr_Occurred()){
        return result;
    }
    
    if (type == "%") {
        type = "f"
        val *= 100;
        add_pct = 1;
    }
    
    if (precision < 0){
        precision = default_precision;
    }
    else if (type == "r"){
        type = "g"
    }
    
    /* Cast "type", because if we're in unicode we need to pass an
     8-bit char. This is safe, because we've restricted what "type"
     can be. */
    buf = PyOS_double_to_string(val, type, precision, flags,
    &float_type);
    if (buf == NULL){
        return result;
    }
    n_digits = strlen(buf);
    
    if (add_pct) {
        /* We know that buf has a trailing zero (since we just called
         strlen() on it), and we don't use that fact any more. So we
         can just write over the trailing zero. */
        buf[n_digits] = "%"
        n_digits += 1;
    }
    
    if (format.sign != "+" && format.sign != " "
        && format.width == -1
        && format.type != "n"
        && !format.thousands_separators)
    {
        /* Fast path */
        result = _PyUnicodeWriter_WriteASCIIString(writer, buf, n_digits);
        return result;
    }
    
    /* Since there is no unicode version of PyOS_double_to_string,
     just use the 8 bit version and then convert to unicode. */
    unicode_tmp = _PyUnicode_FromASCII(buf, n_digits);
    if (unicode_tmp == NULL){
        return result;
    }
    
    /* Is a sign character present in the output?  If so, remember it
     and skip it */
    index = 0;
    if (PyUnicode_READ_CHAR(unicode_tmp, index) == "-") {
        sign_char = "-";
        index += 1
        n_digits -= 1
    }
    
    /* Determine if we have any "remainder" (after the digits, might include
     decimal or exponent or both (or neither)) */
    parse_number(unicode_tmp, index, index + n_digits, &n_remainder, &has_decimal);
    
    /* Determine the grouping, separator, and decimal point, if any. */
    if (get_locale_info(format.type == "n" ? .LT_CURRENT_LOCALE :
        format.thousands_separators,
                        &locale) == -1){
        return result;
    }
    
    /* Calculate how much memory we'll need. */
    n_total = calc_number_widths(&spec, 0, sign_char, unicode_tmp, index,
    index + n_digits, n_remainder, has_decimal,
    &locale, format, &maxchar);
    if (n_total == -1) {
        return result;
    }
    
    /* Allocate the memory. */
    if (_PyUnicodeWriter_Prepare(writer, n_total, maxchar) == -1){
        return result;
    }
    
    /* Populate the memory. */
    result = fill_number(&writer, &spec,
    unicode_tmp, index, index + n_digits,
    NULL, 0, format.fill_char,
    &locale, 0);

    return result;
}

/************************************************************************/
/*********** complex formatting *****************************************/
/************************************************************************/

func format_complex_internal(_ value:PyObject,
                             _ format:inout InternalFormatSpec,
                             _ writer:inout _PyUnicodeWriter) -> int
{
    var re:double
    var im:double
    var re_buf:String = NULL;       /* buffer returned from PyOS_double_to_string */
    var im_buf:String = NULL;       /* buffer returned from PyOS_double_to_string */
    
    var tmp_format:InternalFormatSpec = format;
    var n_re_digits:Py_ssize_t
    var n_im_digits:Py_ssize_t
    var n_re_remainder:Py_ssize_t
    var n_im_remainder:Py_ssize_t
    var n_re_total:Py_ssize_t
    var n_im_total:Py_ssize_t
    var re_has_decimal:int
    var im_has_decimal:int
    var precision:int
    var default_precision:int = 6
    var type:Py_UCS4 = format.type
    var i_re:Py_ssize_t
    var i_im:Py_ssize_t
    var re_spec:NumberFieldWidths
    var im_spec:NumberFieldWidths
    var flags:int = 0
    var result:int = -1;
    var maxchar:Py_UCS4 = 127;
    var rkind:PyUnicode_Kind
    void *rdata;
    var re_sign_char:Py_UCS4 = "\0";
    var im_sign_char:Py_UCS4 = "\0";
    var re_float_type:int /* Used to see if we have a nan, inf, or regular float. */
    var im_float_type:int
    var add_parens:int = 0
    var skip_re:int = 0
    var lpad:Py_ssize_t
    var rpad:Py_ssize_t
    var total:Py_ssize_t
    var re_unicode_tmp:PyObject = NULL;
    var im_unicode_tmp:PyObject = NULL;
    
    /* Locale settings, either from the actual locale or
     from a hard-code pseudo-locale */
    var locale:LocaleInfo
    
    if (format.precision > INT_MAX) {
        PyErr_SetString(PyExc_ValueError, "precision too big");
        return result;
    }
    precision = format.precision;
    
    /* Zero padding is not allowed. */
    if (format.fill_char == "0") {
        PyErr_SetString(PyExc_ValueError,
                        "Zero padding is not allowed in complex format "
            "specifier");
        return result;
    }
    
    /* Neither is '=' alignment . */
    if (format.align == "=") {
        PyErr_SetString(PyExc_ValueError,
                        "'=' alignment flag is not allowed in complex format "
            "specifier");
        return result;
    }
    
    re = PyComplex_RealAsDouble(value);
    if (re == -1.0 && PyErr_Occurred()){
        return result;
    }
    im = PyComplex_ImagAsDouble(value);
    if (im == -1.0 && PyErr_Occurred()){
        return result;
    }
    
    if (format.alternate){
        flags |= Py_DTSF_ALT;
    }
    
    if (type == "\0") {
        /* Omitted type specifier. Should be like str(self). */
        type = "r";
        default_precision = 0;
        if (re == 0.0 && copysign(1.0, re) == 1.0){
            skip_re = 1;
        }
        else{
            add_parens = 1;
        }
    }
    
    if (type == "n"){
        /* 'n' is the same as 'g', except for the locale used to
         format the result. We take care of that later. */
        type = "g";
    }
    
    if (precision < 0){
        precision = default_precision;
    }
    else if (type == "r"){
        type = "g";
    }
    
    /* Cast "type", because if we're in unicode we need to pass an
     8-bit char. This is safe, because we've restricted what "type"
     can be. */
    re_buf = PyOS_double_to_string(re, (char)type, precision, flags,
    &re_float_type);
    if (re_buf == NULL){
        return result;
    }
    im_buf = PyOS_double_to_string(im, (char)type, precision, flags,
    &im_float_type);
    if (im_buf == NULL){
        return result;
    }
    
    n_re_digits = strlen(re_buf);
    n_im_digits = strlen(im_buf);
    
    /* Since there is no unicode version of PyOS_double_to_string,
     just use the 8 bit version and then convert to unicode. */
    re_unicode_tmp = _PyUnicode_FromASCII(re_buf, n_re_digits);
    if (re_unicode_tmp == NULL){
        return result;
    }
    i_re = 0;
    
    im_unicode_tmp = _PyUnicode_FromASCII(im_buf, n_im_digits);
    if (im_unicode_tmp == NULL){
        return result;
    }
    i_im = 0;
    
    /* Is a sign character present in the output?  If so, remember it
     and skip it */
    if (PyUnicode_READ_CHAR(re_unicode_tmp, i_re) == "-") {
        re_sign_char = "-"
        i_re += 1
        n_re_digits -= 1
    }
    if (PyUnicode_READ_CHAR(im_unicode_tmp, i_im) == "-") {
        im_sign_char = "-";
        i_im += 1
        n_im_digits -= 1
    }
    
    /* Determine if we have any "remainder" (after the digits, might include
     decimal or exponent or both (or neither)) */
    parse_number(re_unicode_tmp, i_re, i_re + n_re_digits,
                 &n_re_remainder, &re_has_decimal);
    parse_number(im_unicode_tmp, i_im, i_im + n_im_digits,
                 &n_im_remainder, &im_has_decimal);
    
    /* Determine the grouping, separator, and decimal point, if any. */
    if (get_locale_info(format.type == "n" ? .LT_CURRENT_LOCALE :
        format.thousands_separators,
                        &locale) == -1){
        return result;
    }
    
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
        return result;
    }
    
    /* Same formatting, but always include a sign, unless the real part is
     * going to be omitted, in which case we use whatever sign convention was
     * requested by the original format. */
    if (!skip_re){
        tmp_format.sign = "+";
    }
    n_im_total = calc_number_widths(&im_spec, 0, im_sign_char, im_unicode_tmp,
    i_im, i_im + n_im_digits, n_im_remainder,
    im_has_decimal, &locale, &tmp_format,
    &maxchar);
    if (n_im_total == -1) {
        return result;
    }
    
    if (skip_re){
        n_re_total = 0;
    }
    
    /* Add 1 for the 'j', and optionally 2 for parens. */
    calc_padding(n_re_total + n_im_total + 1 + add_parens * 2,
    format.width, format.align, &lpad, &rpad, &total);
    
    if (lpad || rpad){
        maxchar = Py_MAX(maxchar, format.fill_char);
    }
    
    if (_PyUnicodeWriter_Prepare(writer, total, maxchar) == -1){
        return result;
    }
    rkind = writer.kind;
    rdata = writer.data;
    
    /* Populate the memory. First, the padding. */
    result = fill_padding(&writer,
    n_re_total + n_im_total + 1 + add_parens * 2,
    format.fill_char, lpad, rpad);
    if (result == -1){
        return result;
    }
    
    if (add_parens) {
        PyUnicode_WRITE(rkind, rdata, writer.pos, "(");
        writer.pos += 1
    }
    
    if (!skip_re) {
        result = fill_number(&writer, &re_spec,
                             re_unicode_tmp, i_re, i_re + n_re_digits,
                             NULL, 0,
                             0,
                             &locale, 0);
        if (result == -1){
            return result;
        }
    }
    result = fill_number(&writer, &im_spec,
    im_unicode_tmp, i_im, i_im + n_im_digits,
    NULL, 0,
    0,
    &locale, 0);
    if (result == -1){
        return result;
    }
    PyUnicode_WRITE(rkind, rdata, writer.pos, "j");
    writer.pos += 1
    
    if (add_parens) {
        PyUnicode_WRITE(rkind, rdata, writer.pos, ")");
        writer.pos += 1
    }
    
    writer.pos += rpad;
    
    return result;
}

/************************************************************************/
/*********** built in formatters ****************************************/
/************************************************************************/
func format_obj(_ obj:PyObject, _ writer:inout _PyUnicodeWriter) -> int
{
    var str:PyObject
    var err:int
    
    str = PyObject_Str(obj);
    if (str == NULL){
        return -1;
    }
    err = _PyUnicodeWriter_WriteStr(writer, str);
    return err;
}

func _PyUnicode_FormatAdvancedWriter(_ writer:inout _PyUnicodeWriter,
                                     _ obj:PyObject,
                                     _ format_spec:PyObject,
                                     _ start:Py_ssize_t, _ end:Py_ssize_t) -> int
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
            return format_obj(obj, &writer);
        }
    }
    
    /* parse the format_spec */
    if (!parse_internal_render_format_spec(format_spec, start, end,
                                           &format, "s", "<")){
        return -1;
    }
    
    /* type conversion? */
    if format.type = "s" {
        /* no type conversion needed, already a string.  do the formatting */
        return format_string_internal(obj, &format, writer);
    } else {
        /* unknown */
        unknown_presentation_type(format.type, obj);
        return -1;
    }
}

func _PyLong_FormatAdvancedWriter(_ writer:inout _PyUnicodeWriter,
                                  _ obj:PyObject,
                                  _ format_spec:PyObject,
                                  _ start:Py_ssize_t, _ end:Py_ssize_t) -> int
{
    var tmp:PyObject = NULL
    var str:PyObject = NULL;
    var format:InternalFormatSpec
    var result:int = -1;
    
    /* check for the special case of zero length format spec, make
     it equivalent to str(obj) */
    if (start == end) {
        if (PyLong_CheckExact(obj)){
            return _PyLong_FormatWriter(writer, obj, 10, 0);
        }
        else{
            return format_obj(obj, &writer);
        }
    }
    
    /* parse the format_spec */
    if (!parse_internal_render_format_spec(format_spec, start, end,
                                           &format, "d", ">")){
        return result;
    }
    
    /* type conversion? */
    if "bcdoxXn".contains(format.type){
        /* no type conversion needed, already an int.  do the formatting */
        result = format_long_internal(obj, &format, writer);
    } else if "eEfFgG%".contains(format.type){
        /* convert to float */
        tmp = PyNumber_Float(obj);
        if (tmp == NULL){
            return result;
        }
        result = format_float_internal(tmp, &format, writer);
    } else {
        unknown_presentation_type(format.type, obj.ob_type.tp_name);
        return result;
    }
    return result;
}

func _PyFloat_FormatAdvancedWriter(_ writer:inout _PyUnicodeWriter,
                                   _ obj:PyObject,
                                   _ format_spec:PyObject,
    _ start:Py_ssize_t, _ end:Py_ssize_t) -> int
{
    var format:InternalFormatSpec
    
    /* check for the special case of zero length format spec, make
     it equivalent to str(obj) */
    if (start == end){
        return format_obj(obj, &writer);
    }
    
    /* parse the format_spec */
    if (!parse_internal_render_format_spec(format_spec, start, end,
                                           &format, "\0", ">")){
        return -1;
    }
    
    /* type conversion? */
    if "\0eEfFgGn%".contains(format.type){
        /* no conversion, already a float.  do the formatting */
        return format_float_internal(obj, &format, writer);
    } else {
        /* unknown */
        unknown_presentation_type(presentation_type: format.type, obj);
        return  -1
    }
}

func _PyComplex_FormatAdvancedWriter(_ writer:inout _PyUnicodeWriter,
                                     _ obj:PyObject,
    _ format_spec:PyObject,
    _ start:Py_ssize_t, _ end:Py_ssize_t) -> int
{
    var format:InternalFormatSpec
    
    /* check for the special case of zero length format spec, make
     it equivalent to str(obj) */
    if (start == end){
        return format_obj(obj, &writer);
    }
    
    /* parse the format_spec */
    if (!parse_internal_render_format_spec(format_spec, start, end,
                                           &format, "\0", ">")){
        return -1;
    }
    
    /* type conversion? */
    if "\0eEfFgGn".contains(format.type) {
        /* no conversion, already a complex.  do the formatting */
        return format_complex_internal(obj, &format, &writer);

    } else {
        /* unknown */
        unknown_presentation_type(presentation_type: format.type, obj);
        return -1;
    }
}

protocol FormatableNumeric {}
protocol FormatableInteger:FormatableNumeric {}
protocol FormatableFloat:FormatableNumeric {}
extension Int:FormatableInteger {}
extension Int8:FormatableInteger {}
extension Int16:FormatableInteger {}
extension Int32:FormatableInteger {}
extension Int64:FormatableInteger {}
extension UInt:FormatableInteger {}
extension UInt8:FormatableInteger {}
extension UInt16:FormatableInteger {}
extension UInt32:FormatableInteger {}
extension UInt64:FormatableInteger {}
extension Float:FormatableFloat {}
extension Double:FormatableFloat {}
extension Float80:FormatableFloat {}

extension String {
    public func format(_ args:Any..., kwargs:[String:Any]) -> String {
        switch do_string_format(self, args: args, kwargs: kwargs) {
        case .success(let result):
            return result
        case .failure(let err):
            return String(describing: err)
        }
    }
    
    public func format_map(_ mapping:[String:Any]) -> String {
        return self.format([], kwargs: mapping)
    }
}
