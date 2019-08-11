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
struct _PyUnicodeWriter {
    var buffer:String = ""
    var size:Py_ssize_t = 0
    var pos:Py_ssize_t = 0
}
func _PyUnicode_FastCopyCharacters(
    _ to:inout String, _ to_start:Py_ssize_t,
    _ from:String, _ from_start:Py_ssize_t, _ how_many:Py_ssize_t)
{
    for i in 0..<how_many {
        if to.count > to_start + i {
            to[to_start + i] = from[from_start + i]
        }
        else {
            to.append(from[from_start + i])
        }
    }
}

func _PyUnicode_FastFill(_ unicode:inout String, _ start:Py_ssize_t, _ length:Py_ssize_t,
                         _ fill_char:Py_UCS4)
{
    unicode_fill(&unicode, fill_char, start, length)
}


func unicode_fill(_ data:inout String, _ value:Py_UCS4,
                  _ start:Py_ssize_t, _ length:Py_ssize_t)
{

    let s = String(repeating: value,count: length)
    let i = data.index(data.startIndex, offsetBy: start)
    let j = data.index(data.startIndex, offsetBy: start + length)
    data.replaceSubrange(i..<j, with: s)
}

func _PyUnicodeWriter_WriteStr(_ writer:inout _PyUnicodeWriter, _ str:String) ->Result<int,PyException>
{
    var len:Py_ssize_t
    
    len = PyUnicode_GET_LENGTH(str);
    if (len == 0){
        return .success(0)
    }
    _PyUnicode_FastCopyCharacters(&writer.buffer, writer.pos,str, 0, len);
    writer.pos += len;
    return .success(0)
}
func PyUnicode_WRITE(_ str:inout String ,_ pos:Int,_ c:Character) {
    str[pos] = c
}

func _PyUnicodeWriter_WriteSubstring(_ writer:inout _PyUnicodeWriter, _ str:String,
                                     _ start:Py_ssize_t, _ end:Py_ssize_t) -> Result<int,PyException>
{
    var len:Py_ssize_t
    
    
    assert(0 <= start);
    assert(end <= PyUnicode_GET_LENGTH(str));
    assert(start <= end);
    
    if (end == 0){
        return .success(0)
    }
    
    if (start == 0 && end == PyUnicode_GET_LENGTH(str)){
        return _PyUnicodeWriter_WriteStr(&writer, str);
    }
    
    len = end - start;
    
    
    _PyUnicode_FastCopyCharacters(&writer.buffer, writer.pos,
                                  str, start, len);
    writer.pos += len;
    return .success(0)
}
func _PyUnicodeWriter_WriteASCIIString(_ writer:inout _PyUnicodeWriter,
                                       _ ascii:String, _ len:Py_ssize_t) -> Result<int,PyException> {
    var len = len
    if len == -1 {
        len = ascii.count
    }
    writer.buffer.append(ascii[nil,len])
    writer.pos += len
    return .success(0)
}
func _PyUnicode_FromASCII(_ str:String,_ size:Int) -> String {
    return str[nil,size]
}
func _PyLong_FormatWriter(_ writer:inout _PyUnicodeWriter,
                          _ obj:Int64,
                          _ base:int, _ alternate:Bool) -> Result<int,PyException>// alternate:0x 0b 0o
{
    let alternat = [16:"0x",8:"0o",2:"0b"]
    var tmp = String(obj ,radix:10)
    if alternate {
        tmp = alternat[base,default: ""] + tmp
    }
    writer.buffer += tmp
    writer.pos += tmp.count
    
    return .success(1)
}

extension String {
    private func _splitCountFront(_ length:Int) -> [String] {
        var tmp:[String] = []
        var i = 0
        while self.count > i {
            tmp.append(self[i,i+length])
            i += length
        }
        return tmp
    }
    private func _splitCountBack(_ length:Int) -> [String] {
        var tmp:[String] = []
        var i = self.count
        while i >= 0 {
            let t = i-length
            tmp.insert((self[t < 0 ? 0 : t, i]), at: 0)
            i -= length
        }
        return tmp
    }
    public func splitCount(_ length:Int, back:Bool=false) -> [String] {
        if back {
            return self._splitCountBack(length)
        }
        return self._splitCountFront(length)
    }
}

func _PyUnicode_InsertThousandsGrouping(
    _ writer: inout _PyUnicodeWriter,
    _ n_buffer:Py_ssize_t,
    _ digits:String,
    _ d_pos:Py_ssize_t,
    _ n_digits:Py_ssize_t,
    _ min_width:Py_ssize_t,
    _ grouping:String,
    _ thousands_sep:String) -> Result<Py_ssize_t,PyException>
{
    let sep_len = 3
    let tmp_digits = digits.splitCount(sep_len)
    
    let inserted = thousands_sep.join(tmp_digits)
    
    writer.buffer.append(inserted)
    writer.pos += inserted.count
    return .success(inserted.count)
}
/*
 A SubString consists of the characters between two string or
 unicode pointers.
 */

struct SubString {
    var str:String /* borrowed reference */
    var start:Py_ssize_t
    var end:Py_ssize_t

    /* fill in a SubString from a pointer and length */
    init(_ s:String,start:Py_ssize_t,end:Py_ssize_t) {
        self.str = s
        self.start = start
        self.end = end
    }
}
enum FormatState {
    case SPEC
    case LITERAL
    case ERROR
}

enum AutoNumberState:Int {
    case ANS_INIT = 0
    case ANS_AUTO = 1
    case ANS_MANUAL = 2
}   /* Keep track if we're auto-numbering fields */

/* Keeps track of our auto-numbering state, and which number field we're on */
class AutoNumber {
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
let PyUnicode_READ = PyUnicode_READ_CHAR

func PyUnicode_Substring(_ str:String,_ start:Py_ssize_t,_ end:Py_ssize_t) -> String {
    return str[start,end]
}

func PyObject_Format(_ obj:Any?,_ format_spec:String) -> String {
    return String(describing: obj)
}

/* return a new string.  if str->str is NULL, return None */
func SubString_new_object(_ str:SubString) -> String
{
    if str.str.isEmpty {
        return ""
    }
    return PyUnicode_Substring(str.str, str.start, str.end);
}

func PyUnicode_New(_ params:Any...) -> String {
    return ""
}


/* Return 1 if an error has been detected switching between automatic
 field numbering and manual field specification, else return 0. Set
 ValueError on error. */
func autonumber_state_error(_ state:AutoNumberState, _ field_name_is_empty:Bool) -> Result<int,PyException>
{
    if state == .ANS_MANUAL && field_name_is_empty {
        return .failure(.ValueError("cannot switch from manual field specification to automatic field numbering"))
    }
    else if !field_name_is_empty {
        return .failure(.ValueError("cannot switch from automatic field numbering to manual field specification"))
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

func PyObject_GetAttr(_ obj:PyObject?,_ name:String) -> Result<Any?,PyException> {
    if let obj = obj{
        let mirror = Mirror(reflecting: obj)
        for i in mirror.children.makeIterator(){
            if let label = i.label, label == name{
                return .success(i.value)
            }
        }
        return .failure(.AttributeError("'\(String(describing: type(of: obj)))' object has no attribute '\(name)'"))
    }
    return .failure(.AttributeError("'nil' object has no attribute '\(name)'"))
}

/* do the equivalent of obj.name */
func getattr(_ obj:PyObject?, _ name:SubString) -> Result<PyObject?,PyException>
{
    let str = SubString_new_object(name)
    let newobj = PyObject_GetAttr(obj, str);
    return newobj;
}


/* do the equivalent of obj[idx], where obj is a sequence */
func getitem_sequence(_ obj:[Any], _ idx:Py_ssize_t) -> Result<PyObject,PyException>
{
    if obj.count <= idx {
        return .failure(.IndexError("\(String(describing: type(of: obj))) index out of range"))
    }
    return .success(obj[idx])
}
/* do the equivalent of obj[idx], where obj is not a sequence */
func getitem_idx(_ obj:[Int:Any], _ idx:Py_ssize_t) -> Result<Any,PyException>
{
    if let newobj = obj[idx] {
        return .success(newobj)
    }
    return .failure(.KeyError(String(idx)))
}

/* do the equivalent of obj[name] */
func getitem_str(_ obj:[String:Any?],  _ name:SubString) -> Result<Any?,PyException>
{
    let str = SubString_new_object(name)
    return getitem_str(obj, str)
}
func getitem_str(_ obj:[String:Any?],  _ name:String) -> Result<Any?,PyException>
{
    if let newobj = obj[name] {
        return .success(newobj)
    }
    return .failure(.KeyError(name))
}


struct FieldNameIterator {
    /* the entire string we're parsing.  we assume that someone else
     is managing its lifetime, and that it will exist for the
     lifetime of the iterator.  can be empty */
    var str:SubString
    
    /* index to where we are inside field_name */
    var index:Py_ssize_t
    
    init(_ s:String,start:Py_ssize_t,end:Py_ssize_t) {
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
        c = PyUnicode_READ_CHAR(self.str.str , self.index);
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
    var bracket_seen = false
    var c:Py_UCS4
    
    name.str = self.str.str;
    name.start = self.index;
    
    /* return everything until ']' */
    while (self.index < self.str.end) {
        c = PyUnicode_READ_CHAR(self.str.str , self.index)
        self.index += 1
        switch (c) {
        case "]":
            bracket_seen = true
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
    
    let tmp = PyUnicode_READ_CHAR(self.str.str , self.index)
    self.index += 1
    switch (tmp) {
    case ".":
        is_attribute = 1;
        if (_FieldNameIterator_attr(&self, &name) == 0){
            return .failure(.Exception("Unknown Error")) // おそらくエラーになるはずなんだがエラー要素が見つからない
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
func field_name_split(_ str:String, start:Py_ssize_t, end:Py_ssize_t, first:inout SubString,
                      first_idx:inout Py_ssize_t, rest:inout FieldNameIterator,auto_number:AutoNumber) -> Result<int,PyException>
{
    var i:Py_ssize_t = start
    var field_name_is_empty:Bool
    var using_numeric_index:Bool
    
    /* find the part up until the first '.' or '[' */
    while (i < end) {
        let c = PyUnicode_READ_CHAR(str, i)
        i += 1
        switch c {
        case "[", ".":
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
        return .failure(err)
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

        /* Initialize our auto numbering state if this is the first
         time we're either auto-numbering or manually numbering. */
        if (auto_number.an_state == .ANS_INIT && using_numeric_index){
            auto_number.an_state = field_name_is_empty ? .ANS_AUTO : .ANS_MANUAL;
        }
        
        /* Make sure our state is consistent with what we're doing
         this time through. Only check if we're using a numeric
         index. */
        if (using_numeric_index){
            switch autonumber_state_error(auto_number.an_state, field_name_is_empty){
            case .success(_):
                break
            case .failure(let err):
                return .failure(err)
            }

        }
        /* Zero length field means we want to do auto-numbering of the
         fields. */
        if (field_name_is_empty){
            first_idx = auto_number.an_field_number
            auto_number.an_field_number += 1
        }

    
    return .success(1)
}


/*
 get_field_object returns the object inside {}, before the
 format_spec.  It handles getindex and getattr lookups and consumes
 the entire input string.
 */
func get_field_object(_ input:SubString, args:[Any?], kwargs:[String:Any?],
                      auto_number:AutoNumber) -> Result<PyObject?,PyException>
{
    var obj:PyObject? = nil
    var ok:int = 0
    var is_attribute:int = 0
    var name:SubString = .init("", start: 0, end: 0)
    var first:SubString = .init("", start: 0, end: 0) // uninit
    var index:Py_ssize_t = 0 //
    var rest:FieldNameIterator = .init("", start: 0, end: 0) //
    
    switch field_name_split(input.str, start: input.start, end: input.end, first: &first,
                            first_idx: &index, rest: &rest, auto_number: auto_number) {
    case .success(_):
        break;
    case .failure(let err):
        return .failure(err)
    }
    
    
    if (index == -1) {
        /* look up in kwargs */
        let key = SubString_new_object(first);

        if kwargs.isEmpty {
            return .failure(.KeyError(key))
        }
        /* Use PyObject_GetItem instead of PyDict_GetItem because this
         code is no longer just used with kwargs. It might be passed
         a non-dict when called through format_map. */
        switch getitem_str(kwargs, key) {
        case .success(let o):
            obj = o
            break;
        case .failure(let err):
            return .failure(err)
        }
    }
    else {
        /* If args is NULL, we have a format string with a positional field
         with only kwargs to retrieve it from. This can only happen when
         used with format_map(), where positional arguments are not
         allowed. */
        if args.isEmpty {
            return .failure(.ValueError("Format string contains positional fields"))
        }
        
        /* look up in args */
        if index >= args.count {
            return .failure(.IndexError("Replacement index \(index) out of range for positional args tuple"))
        }
        obj = args[index]
    }
    
    /* iterate over the rest of the field_name */
    while true {
        switch FieldNameIterator_next(&rest, is_attribute: &is_attribute, name_idx: &index, name: &name) {
        case .success(let o):
            ok = o
            break;
        case .failure(let err):
            return .failure(err)
        }
        if ok != 2 {
            break;
        }
        /* assign to obj */
        if (is_attribute != 0){
            /* getattr lookup "." */
            switch getattr(obj, name) {
            case .success(let o):
                obj = o
                break;
            case .failure(let err):
                return .failure(err)
            }
        }
        else{
            /* getitem lookup "[]" */
            if (index == -1){
                switch getitem_str(obj as! [String : Any], name) {
                case .success(let o):
                    obj = o
                    break;
                case .failure(let err):
                    return .failure(err)
                }
            }
            else{
                if let aobj = obj as? [Any] {
                    switch getitem_sequence(aobj, index) {
                    case .success(let o):
                        obj = o
                        break;
                    case .failure(let err):
                        return .failure(err)
                    }
                }
                else{
                    /* not a sequence */
                    switch getitem_idx(obj as! [Int : Any], index) {
                    case .success(let o):
                        obj = o
                        break;
                    case .failure(let err):
                        return .failure(err)
                    }
                }
            }
        }

    }
    /* end of iterator, this is the non-error case */
    if (ok == 1){
        return .success(obj)
    }
    return .failure(.Exception("Unkonw Error"));
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
func render_field(_ fieldobj:PyObject?, _ format_spec:SubString, _ writer:inout _PyUnicodeWriter) -> Result<int,PyException>
{
    var result:String = ""
    var format_spec_object:String = ""
    
    /* If we know the type exactly, skip the lookup of __format__ and just
     call the formatter directly. */
    switch fieldobj {
    case let str as String:
        return _PyUnicode_FormatAdvancedWriter(&writer, str, format_spec.str,
                                               format_spec.start, format_spec.end);
    case let i as FormatableSignedInteger:
        return _PyLong_FormatAdvancedWriter(&writer, i.toInt64(), format_spec.str,
                                            format_spec.start, format_spec.end);
    case let i as FormatableUnSignedInteger:
        return _PyLong_FormatAdvancedWriter(&writer, Int64(i.toUInt64()), format_spec.str,
                                            format_spec.start, format_spec.end);
    case let f as FormatableFloat:
        return _PyFloat_FormatAdvancedWriter(&writer, f.toDouble(), format_spec.str,
                                             format_spec.start, format_spec.end);
    case let cx as (Double,Double):
        return _PyComplex_FormatAdvancedWriter(&writer, cx, format_spec.str,
                                               format_spec.start, format_spec.end);
    default:
        /* We need to create an object out of the pointers we have, because
         __format__ takes a string/unicode object for format_spec. */
        if !format_spec.str.isEmpty {
            format_spec_object = SubString_new_object(format_spec)
        }
        else{
            format_spec_object = PyUnicode_New(0, 0);
        }
        result = PyObject_Format(fieldobj, format_spec_object);
    }
    
    return _PyUnicodeWriter_WriteStr(&writer, result)
}

func parse_field(_ str:inout SubString, _ field_name:inout SubString, _ format_spec:inout SubString,
                 format_spec_needs_expanding:inout int, conversion:inout Py_UCS4) -> Result<int,PyException>
{
    /* Note this function works if the field name is zero length,
     which is good.  Zero length field names are handled later, in
     field_name_split. */
    
    var c:Py_UCS4 = " "
    
    /* initialize these, as they may be empty */
    conversion = "\0"
    format_spec = .init("",start:0,end:0)
    
    /* Search for the field name.  it's terminated by the end of
     the string, or a ':' or '!' */
    field_name.str = str.str
    field_name.start = str.start
    while (str.start < str.end) {
        c = PyUnicode_READ_CHAR(str.str , str.start)
        str.start += 1
        switch c {
        case "{":
            return .failure(.ValueError("unexpected '{' in field name"))
        case "[":
            while str.start < str.end {
                str.start += 1
                if (PyUnicode_READ_CHAR(str.str , str.start) == "]"){
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
                return .failure(.ValueError("end of string while looking for conversion specifier"))
            }
            conversion = PyUnicode_READ_CHAR(str.str , str.start)
            str.start += 1
            
            if (str.start < str.end) {
                c = PyUnicode_READ_CHAR(str.str , str.start)
                str.start += 1
                if (c == "}"){
                    return .success(1)
                }
                if (c != ":") {
                    return .failure(.ValueError("expected ':' after conversion specifier"))
                }
            }
        }
        format_spec.str = str.str;
        format_spec.start = str.start;
        count = 1;
        while (str.start < str.end) {
            c = PyUnicode_READ_CHAR(str.str , str.start)
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
                    return .success(1)
                }
                break;
            default:
                break;
            }
        }
        
        return .failure(.ValueError("unmatched '{' in format spec"))
    }
    else if (c != "}") {
        return .failure(.ValueError("expected '}' before end of string"))
    }
    
    return .success(1)
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
    
    init(_ str:String,_ start:Py_ssize_t, _ end:Py_ssize_t) {
        self.str = .init(str, start:start, end:end)
    }
}

/* returns 0 on error, 1 on non-error termination, and 2 if it got a
 string (or something to be expanded) */
func MarkupIterator_next(_ self:inout MarkupIterator, _ literal:inout SubString,
                         _ field_present:inout int, _ field_name:inout SubString,
                         _ format_spec:inout SubString, _ conversion:inout Py_UCS4,
                         _ format_spec_needs_expanding:inout int) -> Result<int,PyException>
{
    var at_end:Bool = false
    var c:Py_UCS4 = " "
    var start:Py_ssize_t
    var len:Py_ssize_t
    var markup_follows:Bool = false
    
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
        return .success(1)
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
        c = PyUnicode_READ_CHAR(self.str.str , self.str.start)
        self.str.start += 1
        switch c {
        case "{":
            fallthrough
        case "}":
            markup_follows = true
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
        return .failure(.ValueError("Single '}' encountered in format string"))
    }
    if (at_end && c == "{") {
        return .failure(.ValueError("Single '{' encountered in format string"))
    }
    if (!at_end) {
        if c == PyUnicode_READ_CHAR(self.str.str, self.str.start) {
            /* escaped } or {, skip it in the input.  there is no
             markup object following us, just this literal text */
            self.str.start += 1
            markup_follows = false
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
        return .success(2)
    }
    
    /* this is markup; parse the field */
    field_present = 1;
    switch parse_field(&self.str, &field_name, &format_spec,
                       format_spec_needs_expanding: &format_spec_needs_expanding, conversion: &conversion) {
    case .success(_):
        break
    case .failure(let err):
        return .failure(err)
    }
    return .success(2)
}


/* do the !r or !s conversion on obj */
func do_conversion(_ obj:PyObject?,_ conversion:Py_UCS4) -> Result<String,PyException>
{
    /* XXX in pre-3.0, do we need to convert this to unicode, since it
     might have returned a string? */
    if let obj = obj {
        switch (conversion) {
        case "r":
            return .success(PyObject_Repr(obj))
        case "s":
            return .success(PyObject_Str(obj))
        case "a":
            return .success(PyObject_ASCII(obj))
        default:
            if (conversion > .init(32)  && conversion < .init(127)) {
                /* It's the ASCII subrange; casting to char is safe
                 (assuming the execution character set is an ASCII
                 superset). */
                return .failure(.ValueError("Unknown conversion specifier \(conversion)"))
            } else {
                return .failure(.ValueError("Unknown conversion specifier \\x\(conversion)"))
            }
        }
    }
    return .success("nil")
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
                   _ writer:inout _PyUnicodeWriter, _ args:[Any?], _ kwargs:[String:Any?],
                   _ recursion_depth:int, _ auto_number:AutoNumber) -> Result<int,PyException>
{
    var tmp:String
    var fieldobj:PyObject?
    var actual_format_spec:SubString
    
    /* convert field_name to an object */
    switch get_field_object(field_name, args: args, kwargs: kwargs, auto_number: auto_number) {
    case .success(let o):
        fieldobj = o
        break;
    case .failure(let err):
        return .failure(err)
    }
    
    if (conversion != "\0") {
        switch do_conversion(fieldobj, conversion) {
        case .success(let t):
            tmp = t
            break
        case .failure(let err):
            return .failure(err)
        }
        
        /* do the assignment, transferring ownership: fieldobj = tmp */
        fieldobj = tmp;
    }
    
    /* if needed, recurively compute the format_spec */
    if (format_spec_needs_expanding != 0) {
        switch build_string(format_spec, args, kwargs, recursion_depth-1,auto_number){
        case .success(let t):
            tmp = t
            break;
        case .failure(let err):
            return .failure(err)
        }
        
        /* note that in the case we're expanding the format string,
         tmp must be kept around until after the call to
         render_field. */
        var expanded_format_spec:SubString = .init(tmp, start:0, end:PyUnicode_GET_LENGTH(tmp))
        actual_format_spec = expanded_format_spec;
    }
    else{
        actual_format_spec = format_spec;
    }
    switch render_field(fieldobj, actual_format_spec, &writer) {
    case .success(_):
        break
    case .failure(let err):
        return .failure(err)
    }
    
    return .success(1)
}

/*
 do_markup is the top-level loop for the format() method.  It
 searches through the format string for escapes to markup codes, and
 calls other functions to move non-markup text to the output,
 and to perform the markup to the output.
 */
func do_markup(_ input:SubString, _ args:[Any?], _ kwargs:[String:Any?],
               _ writer:inout _PyUnicodeWriter, _ recursion_depth:int, _ auto_number:AutoNumber) -> Result<int,PyException>
{
    var iter:MarkupIterator = .init( input.str, input.start, input.end)
    var format_spec_needs_expanding:int = 0
    var result:int = 0
    var field_present:int = 0
    var literal:SubString = .init("", start: 0, end: 0)
    var field_name:SubString = .init("", start: 0, end: 0)
    var format_spec:SubString = .init("", start: 0, end: 0)
    var conversion:Py_UCS4 = "\0"
    
    while true {
        switch MarkupIterator_next(&iter, &literal, &field_present,
                                   &field_name, &format_spec,
                                   &conversion,
                                   &format_spec_needs_expanding){
        case .success(let r):
            result = r
            break;
        case .failure(let err):
            return .failure(err)
        }
        
        if result != 2 {
            break;
        }
        
        
        if (literal.end != literal.start) {
            switch _PyUnicodeWriter_WriteSubstring(&writer, literal.str,
                                                   literal.start, literal.end) {
            case .success(_):
                break;
            case .failure(let err):
                return .failure(err)
            }
        }
        
        if (field_present != 0) {
            switch output_markup(field_name, format_spec,
                                 format_spec_needs_expanding, conversion, &writer,
                                 args, kwargs, recursion_depth, auto_number) {
            case .success(_):
                break;
            case .failure(let err):
                return .failure(err)
            }
        }
        
    }
    return .success(result);// 戻り値が1の時は正常終了
}


/*
 build_string allocates the output string and then
 calls do_markup to do the heavy lifting.
 */
func build_string(_ input:SubString, _ args:[Any?], _ kwargs:[String:Any?],
                  _ recursion_depth:int, _ auto_number:AutoNumber) -> Result<String,PyException>
{
    var writer = _PyUnicodeWriter()
    
    /* check the recursion level */
    if (recursion_depth <= 0) {
        return .failure(.ValueError("Max string recursion exceeded"))
    }
    

    switch do_markup(input, args, kwargs, &writer, recursion_depth, auto_number) {
    case .success(_):
        break
    case .failure(let err):
        return .failure(err)
    }
    
    return .success(writer.buffer)
}

/************************************************************************/
/*********** main routine ***********************************************/
/************************************************************************/

/* this is the main entry point */
func do_string_format(_ self:String, args:[Any?], kwargs:[String:Any?]) -> Result<String,PyException>
{
    
    /* PEP 3101 says only 2 levels, so that
     "{0:{1}}".format('abc', 's')            # works
     "{0:{1:{2}}}".format('abc', 's', '')    # fails
     */
    let recursion_depth:int = 2
    
    var auto_number = AutoNumber()

    let input:SubString = .init(self, start: 0, end: PyUnicode_GET_LENGTH(self))
    return build_string(input, args, kwargs, recursion_depth, auto_number)
}




/* implements the unicode (as opposed to string) version of the
 built-in formatters for string, int, float.  that is, the versions
 of int.__float__, etc., that take and return unicode objects */


/* Raises an exception about an unknown presentation type for this
 * type. */

func unknown_presentation_type(_ presentation_type:Py_UCS4,_ obj:Any) -> Result<int,PyException>
{
    let type_name = String(describing: obj)
    /* %c might be out-of-range, hence the two cases. */
    if (presentation_type > .init(32) && presentation_type < .init(128)){
        return .failure(.ValueError("Unknown format code '\(presentation_type)' for object of type '\(type_name)'"))
    }
    else{
        return .failure(.ValueError("Unknown format code '\\x\(presentation_type)' for object of type '\(type_name)'"))
    }
}

func invalid_thousands_separator_type(_ specifier:Character, _ presentation_type:Py_UCS4) -> Result<int,PyException>
{
    // assert(specifier == "," || specifier == "_");
    if (presentation_type > .init(32) && presentation_type < .init(128)){
        return .failure(.ValueError("Cannot specify '\(specifier)' with '\(presentation_type)'."))
    } else {
        return .failure(.ValueError("Cannot specify '\(specifier)' with '\\x\(presentation_type)'."))
    }
}

func invalid_comma_and_underscore() -> Result<int,PyException>
{
    return .failure(.ValueError("Cannot specify both ',' and '_'."))
}

/*
 get_integer consumes 0 or more decimal digit characters from an
 input string, updates *result with the corresponding positive
 integer, and returns the number of digits consumed.
 
 returns -1 on error.
 */
func get_integer(_ str:String, _ ppos:inout Py_ssize_t, _ end:Py_ssize_t, result:inout Py_ssize_t) -> Result<int,PyException>
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
            ppos = pos;
            return .failure(.ValueError("Too many decimal digits in format string"))
        }
        accumulator = accumulator * 10 + digitval;
        numdigits += 1

        pos += 1
    }
    ppos = pos;
    result = accumulator;
    return .success(numdigits)
}

/************************************************************************/
/*********** standard format specifier parsing **************************/
/************************************************************************/

/* returns true if this character is a specifier alignment token */
func is_alignment_token(_ c:Py_UCS4) -> Bool
{
    return "<>=^".contains(c)
}

/* returns true if this character is a sign element */
func is_sign_element(_ c:Py_UCS4) -> Bool
{
    return " +-".contains(c)
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
    var fill_char:Py_UCS4 = " "
    var align:Py_UCS4
    var alternate:Bool = false
    var sign:Py_UCS4 = "\0"
    var width:Py_ssize_t = -1
    var thousands_separators:LocaleType = .LT_NO_LOCALE
    var precision:Py_ssize_t = -1
    var type:Py_UCS4
    
    init(_ align:Py_UCS4="\0",type:Py_UCS4="\0") {
        self.align = align
        self.type = type
    }
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
func parse_internal_render_format_spec(_ format_spec:String,
                                       _ start:Py_ssize_t, _ end:Py_ssize_t,
                                       _ format:inout InternalFormatSpec,
                                       _ default_type:Character,_ default_align:Character) -> Result<int,PyException>
{
    var pos:Py_ssize_t = start
    /* end-pos is used throughout this code to specify the length of
     the input string */
    
    
    var consumed:Py_ssize_t
    var align_specified = false
    var fill_char_specified = false
    
    format.align = default_align;
    format.type = default_type;
    
    /* If the second char is an alignment token,
     then parse the fill char */
    if (end-pos >= 2 && is_alignment_token(format_spec[pos+1])) {
        format.align = format_spec[pos+1]
        format.fill_char = format_spec[pos]
        fill_char_specified = true
        align_specified = true
        pos += 2;
    }
    else if (end-pos >= 1 && is_alignment_token(format_spec[pos])) {
        format.align = format_spec[pos]
        align_specified = true
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
        format.alternate = true
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
    switch get_integer(format_spec, &pos, end, result: &format.width) {
    case .success(let t):
        consumed = t
        break
    case .failure(let err):
        /* Overflow error. Exception already set. */
        return .failure(err)
    }
    
    /* If consumed is 0, we didn't consume any characters for the
     width. In that case, reset the width to -1, because
     get_integer() will have set it to zero. -1 is how we record
     that the width wasn't specified. */
    if (consumed == 0){
        format.width = -1;
    }
    
    /* Comma signifies add thousands separators */
    if  (end-pos) != 0 && format_spec[pos] == "," {
        format.thousands_separators = .LT_DEFAULT_LOCALE;
        pos += 1
    }
    /* Underscore signifies add thousands separators */
    if (end-pos) != 0 && format_spec[pos] == "_" {
        if (format.thousands_separators != .LT_NO_LOCALE) {
            return invalid_comma_and_underscore()
        }
        format.thousands_separators = .LT_UNDERSCORE_LOCALE;
        pos += 1
    }
    if (end-pos) != 0 && format_spec[pos] == "," {
        return invalid_comma_and_underscore()
    }
    
    /* Parse field precision */
    if (end-pos) != 0 && format_spec[pos] == "." {
        pos += 1
        
        switch get_integer(format_spec, &pos, end, result: &format.precision) {
        case .success(let t):
            consumed = t
            break
        case .failure(let err):
            /* Overflow error. Exception already set. */
            return .failure(err)
        }
        
        /* Not having a precision after a dot is an error. */
        if (consumed == 0) {
            return .failure(.ValueError("Format specifier missing precision"))
        }
        
    }
    
    /* Finally, parse the type field. */
    
    if (end-pos > 1) {
        /* More than one char remain, invalid format specifier. */
        return .failure(.ValueError("Invalid format specifier"))
    }
    
    if (end-pos == 1) {
        format.type = format_spec[pos]
        pos += 1
    }
    
    /* Do as much validating as we can, just by looking at the format
     specifier.  Do not take into account what type of formatting
     we're doing (int, float, string). */
    
    switch format.type {
    case "d", "e", "f", "g", "E", "G", "%", "F", "\0":
        /* These are allowed. See PEP 378.*/
        break;
    case "b", "o", "x", "X":
        /* Underscores are allowed in bin/oct/hex. See PEP 515. */
        if format.thousands_separators == .LT_UNDERSCORE_LOCALE {
            /* Every four digits, not every three, in bin/oct/hex. */
            format.thousands_separators = .LT_UNDER_FOUR_LOCALE
            break;
        }
        /* fall through */
        fallthrough
    default:
        return invalid_thousands_separator_type(format.thousands_separators.rawValue, format.type)
    }
    
    
    assert(format.align <= .init(127))
    assert(format.sign <= .init(127))
    return .success(1)
}

/* Calculate the padding needed. */
func calc_padding(_ nchars:Py_ssize_t, _ width:Py_ssize_t, _ align:Py_UCS4,
                  _ n_lpadding:inout Py_ssize_t, _ n_rpadding: inout Py_ssize_t,
                  _ n_total:inout Py_ssize_t) -> Void
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
    if (n_lpadding != 0) {
        pos = writer.pos;
        _PyUnicode_FastFill(&writer.buffer, pos, n_lpadding, fill_char);
    }
    
    /* Pad on right. */
    if (n_rpadding != 0) {
        pos = writer.pos + nchars + n_lpadding;
        _PyUnicode_FastFill(&writer.buffer, pos, n_rpadding, fill_char);
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
    var decimal_point:String = ""
    var thousands_sep:String = ""
    var grouping:String = ""
}


/* describes the layout for an integer, see the comment in
 calc_number_widths() for details */
struct NumberFieldWidths{
    var n_lpadding:Py_ssize_t = 0
    var n_prefix:Py_ssize_t = 0
    var n_spadding:Py_ssize_t = 0
    var n_rpadding:Py_ssize_t = 0
    var sign:Character = "\0"
    var n_sign:Py_ssize_t = 0      /* number of digits needed for sign (0/1) */
    var n_grouped_digits:Py_ssize_t = 0 /* Space taken up by the digits, including
     any grouping chars. */
    var n_decimal:Py_ssize_t = 0   /* 0 if only an integer */
    var n_remainder:Py_ssize_t = 0 /* Digits in decimal and/or exponent part,
     excluding the decimal itself, if
     present. */
    
    /* These 2 are not the widths of fields, but are needed by
     STRINGLIB_GROUPING. */
    var n_digits:Py_ssize_t = 0    /* The number of digits before a decimal
     or exponent. */
    var n_min_width:Py_ssize_t = 0 /* The min_width we used when we computed
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
func parse_number(_ s:String, _ pos:Py_ssize_t, _ end:Py_ssize_t,
                  _ n_remainder:inout Py_ssize_t,  _ has_decimal:inout Bool) -> Void
{
    var remainder:Py_ssize_t
    var pos = pos
    
    while (pos<end && s[pos].isdigit() ){
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
                        _ has_decimal:Bool, _ locale:LocaleInfo,
    _ format:InternalFormatSpec) -> Py_ssize_t
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
        spec.n_grouped_digits = 0
//        spec.n_grouped_digits = _PyUnicode_InsertThousandsGrouping(
//            NULL, 0,
//            NULL, 0, spec.n_digits,
//            spec.n_min_width,
//            locale.grouping, locale.thousands_sep);
        if (spec.n_grouped_digits == -1) {
            return -1;
        }

    }
    
    /* Given the desired width and the total of digit and non-digit
     space we consume, see if we need any padding. format->width can
     be negative (meaning no padding), but this code still works in
     that case. */
    n_padding = format.width - (n_non_digit_non_padding + spec.n_grouped_digits);
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
    
    
    
    return spec.n_lpadding + spec.n_sign + spec.n_prefix +
        spec.n_spadding + spec.n_grouped_digits + spec.n_decimal +
        spec.n_remainder + spec.n_rpadding;
}

/* Fill in the digit parts of a numbers's string representation,
 as determined in calc_number_widths().
 Return -1 on error, or 0 on success. */
func fill_number(_ writer:inout _PyUnicodeWriter, _ spec:NumberFieldWidths,
                 _ digits:String, _ d_start:Py_ssize_t, _ d_end:Py_ssize_t,
                 _ prefix:String, _ p_start:Py_ssize_t,
                 _ fill_char:Py_UCS4,
                 _ locale:LocaleInfo, _ toupper:Bool) -> Result<int,PyException>
{
    /* Used to keep track of digits, decimal, and remainder. */
    var d_pos:Py_ssize_t = d_start
    
    if (spec.n_lpadding != 0) {
        _PyUnicode_FastFill(&writer.buffer,
                            writer.pos, spec.n_lpadding, fill_char);
        writer.pos += spec.n_lpadding;
    }
    if (spec.n_sign == 1) {
        PyUnicode_WRITE(&writer.buffer, writer.pos, spec.sign);
        writer.pos += 1
    }
    if (spec.n_prefix != 0) {
        _PyUnicode_FastCopyCharacters(&writer.buffer, writer.pos,
                                      prefix, p_start,
                                      spec.n_prefix);
        if (toupper) {
            var t:Py_ssize_t = 0
            while t < spec.n_prefix {
                var c:Py_UCS4 = PyUnicode_READ(writer.buffer, writer.pos + t);
                c = c.toUpper()
                assert(c <= .init( 127 ));
                PyUnicode_WRITE(&writer.buffer, writer.pos + t, c);
                t += 1
            }
        }
        writer.pos += spec.n_prefix;
    }
    if (spec.n_spadding != 0) {
        _PyUnicode_FastFill(&writer.buffer,
                            writer.pos, spec.n_spadding, fill_char);
        writer.pos += spec.n_spadding;
    }
    
    /* Only for type 'c' special case, it has no digits. */
    if (spec.n_digits != 0) {
        /* Fill the digits with InsertThousandsGrouping. */
        _ = _PyUnicode_InsertThousandsGrouping(
            &writer, spec.n_grouped_digits,
            digits, d_pos, spec.n_digits,
            spec.n_min_width,
            locale.grouping, locale.thousands_sep)

        d_pos += spec.n_digits;
    }
    if (toupper) {
        var t:Py_ssize_t = 0
        while t < spec.n_grouped_digits {
            var c:Py_UCS4 = PyUnicode_READ(writer.buffer, writer.pos + t);
            c = c.toUpper()
            if (c > .init(127)) {
                return .failure(.SystemError("non-ascii grouped digit"))
            }
            PyUnicode_WRITE(&writer.buffer, writer.pos + t, c);
            t += 1
        }
    }
    writer.pos += spec.n_grouped_digits;
    
    if (spec.n_decimal != 0) {
        _PyUnicode_FastCopyCharacters(
            &writer.buffer, writer.pos,
            locale.decimal_point, 0, spec.n_decimal);
        writer.pos += spec.n_decimal;
        d_pos += 1;
    }
    
    if (spec.n_remainder != 0) {
        _PyUnicode_FastCopyCharacters(
            &writer.buffer, writer.pos,
            digits, d_pos, spec.n_remainder);
        writer.pos += spec.n_remainder;
        /* d_pos += spec->n_remainder; */
    }
    
    if (spec.n_rpadding != 0) {
        _PyUnicode_FastFill(&writer.buffer,
                            writer.pos, spec.n_rpadding,
                            fill_char);
        writer.pos += spec.n_rpadding;
    }
    return .success(0)
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

class GroupingGenerator {
    var i:Int = 0
    var grouping:String
    var previous:Int = 0
    init (_ grouping:String){self.grouping = grouping}
    public subscript(_ index:Int) -> Int {
        if grouping.count <= i {
            return self.previous
        }
        let v = Int(self.grouping[self.i].unicode.value)
        switch v {
        case 0:
            return self.previous
        case 255:
            return 0
        default:
            self.previous = v
            self.i += 1
            return v
        }
    }
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
            type == .LT_DEFAULT_LOCALE ? "," : "_")
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
        locale_info.grouping = no_grouping;
        break;
    }
    return 0;
}


/* _Py_dg_dtoa is available. */

/* I'm using a lookup table here so that I don't have to invent a non-locale
 specific way to convert to uppercase */
let OFS_INF = 0
let OFS_NAN = 1
let OFS_E = 2

/* The lengths of these are known to the code below, so don't change them */
let lc_float_strings:[String] = [
    "inf",
    "nan",
    "e",
]
let uc_float_strings:[String] = [
    "INF",
    "NAN",
    "E",
]

class FloatFormatter {

    static func SpecifiedGeneralNumberFormat(_ formatNumber:Double,accuracy:Int,sharp:Bool=false) -> String {
        // g
        return String(format: "%.\(accuracy)g", formatNumber)
    }
    static func NonSpecifiedGeneralNumberFormat(_ formatNumber:Double,accuracy:Int,sharp:Bool=false) -> String {
        // z
        var tmp = SpecifiedGeneralNumberFormat(formatNumber,accuracy: accuracy)
        if !tmp.contains("."){
            tmp += ".0"
        }
        return tmp
    }
    static func SpecifiedFloatNumberFormat(_ f:Double,accuracy:Int,sharp:Bool=false) -> String {
        // f
        var tmp = String(f.nround(accuracy))
        if let dicimalPointIndex = tmp.firstIndex(of: ".") {
            let i = tmp.distance(from: tmp.startIndex, to: dicimalPointIndex) + 1
            if i + accuracy < tmp.count {
                tmp = String(tmp.prefix(i+accuracy))
            }
            if let last = tmp.last, last == "." {
                _ = tmp.popLast()
            }
        }
        return tmp
    }
    static func SpecifiedExpNumberFormat(_ f:Double,accuracy:Int,sharp:Bool=false) -> String {
        // e
        return String(format: "%.\(accuracy)e", f)
    }
}


func PyOS_snprintf(_ str:String, _ size:size_t, _ format:String,_ items:CVarArg...) -> String
{
    return String(format: format, arguments: items)
}
/* Given a string that may have a decimal point in the current
 locale, change it back to a dot.  Since the string cannot get
 longer, no need for a maximum buffer size parameter. */
func change_decimal_from_locale_to_dot(_ buffer:String) -> String
{
    let (decimal_point,_,_) = _get_local_info()
    return buffer.replace(decimal_point, new: ".")
}


/* From the C99 standard, section 7.19.6:
 The exponent always contains at least two digits, and only as many more digits
 as necessary to represent the exponent.
 */
let MIN_EXPONENT_DIGITS = 2

/* Ensure that any exponent, if present, is at least MIN_EXPONENT_DIGITS
 in length. */
func ensure_minimum_exponent_length(_ buffer:inout String, _ buf_size:size_t)
{
    let stringIndex = buffer.firstIndex(where: {(c) -> Bool in
        return c == "e" || c == "E"
    })
    if stringIndex == nil {
        return ;
    }
    var index = Int(buffer.distance(from: buffer.startIndex, to: stringIndex!))
    if (index != 0 && (buffer[index+1] == "-" || buffer[index+1] == "+")) {
        var start = index + 2
        var exponent_digit_cnt:int = 0
        var leading_zero_cnt:int = 0
        var in_leading_zeros:int = 1
        var significant_digit_cnt:int
        
        /* Skip over the exponent and the sign. */
        index += 2;
        
        /* Find the end of the exponent, keeping track of leading
         zeros. */
        while (buffer.count > index && buffer[index].isdigit()) {
            if (in_leading_zeros != 0 && buffer[index] == "0"){
                leading_zero_cnt += 1
            }
            if (buffer[index] != "0"){
                in_leading_zeros = 0;
            }
            index += 1
            exponent_digit_cnt += 1
        }
        
        significant_digit_cnt = exponent_digit_cnt - leading_zero_cnt;
        if (exponent_digit_cnt == MIN_EXPONENT_DIGITS) {
            /* If there are 2 exactly digits, we're done,
             regardless of what they contain */
        }
        else if (exponent_digit_cnt > MIN_EXPONENT_DIGITS) {
            var extra_zeros_cnt:int
            
            /* There are more than 2 digits in the exponent.  See
             if we can delete some of the leading zeros */
            if (significant_digit_cnt < MIN_EXPONENT_DIGITS) {
                significant_digit_cnt = MIN_EXPONENT_DIGITS
            }
            extra_zeros_cnt = exponent_digit_cnt - significant_digit_cnt;
            
            /* Delete extra_zeros_cnt worth of characters from the
             front of the exponent */
            assert(extra_zeros_cnt >= 0);
            
            /* Add one to significant_digit_cnt to copy the
             trailing 0 byte, thus setting the length */
//            memmove(start,
//            start + extra_zeros_cnt,
//            significant_digit_cnt + 1)
        }
        else {
            /* If there are fewer than 2 digits, add zeros
             until there are 2, if there's enough room */
            var zeros:int = MIN_EXPONENT_DIGITS - exponent_digit_cnt;
            if (start + zeros + exponent_digit_cnt + 1
                < buf_size) {
                buffer = "0" * zeros + buffer
            }
        }
    }
}

/* Remove trailing zeros after the decimal point from a numeric string; also
 remove the decimal point if all digits following it are zero.  The numeric
 string must end in '\0', and should not have any leading or trailing
 whitespace.  Assumes that the decimal point is '.'. */
func remove_trailing_zeros(_ buffer:String) -> String
{
    var tmp = buffer
    while tmp.last == "0" {
        _ = tmp.popLast()
    }
    if buffer.last == "." {
        _ = tmp.popLast()
    }
    return tmp
}

/* Ensure that buffer has a decimal point in it.  The decimal point will not
 be in the current locale, it will always be '.'. Don't add a decimal point
 if an exponent is present.  Also, convert to exponential notation where
 adding a '.0' would produce too many significant digits (see issue 5864).
 
 Returns a pointer to the fixed buffer, or NULL on failure.
 */
func ensure_decimal_point(_ buffer:String, _ buf_size:size_t, _ precision:int) -> String
{
    var buffer = buffer
    var digit_count:int
    var insert_count:int = 0
    var convert_to_exp:int = 0
    var chars_to_insert:String = ""
    var digits_start:int
    
    /* search for the first non-digit character */
    var index = 0
    var p:String = buffer;
    if (p[index] == "-" || p[index] == "+"){
        /* Skip leading sign, if present.  I think this could only
         ever be '-', but it can't hurt to check for both. */
        index += 1
    }
    digits_start = index
    while p[index].isdigit() {
        index += 1
    }
    digit_count = index - digits_start
    
    if (p[index] == ".") {
        if p[index+1].isdigit() {
            /* Nothing to do, we already have a decimal
             point and a digit after it */
        }
        else {
            /* We have a decimal point, but no following
             digit.  Insert a zero after the decimal. */
            /* can't ever get here via PyOS_double_to_string */
            assert(precision == -1);
            index += 1
            chars_to_insert = "0";
            insert_count = 1;
        }
    }
    else if !(p[index] == "e" || p[index] == "E") {
        /* Don't add ".0" if we have an exponent. */
        if (digit_count == precision) {
            /* issue 5864: don't add a trailing .0 in the case
             where the '%g'-formatted result already has as many
             significant digits as were requested.  Switch to
             exponential notation instead. */
            convert_to_exp = 1;
            /* no exponent, no point, and we shouldn't land here
             for infs and nans, so we must be at the end of the
             string. */
            assert(p[index] == "\0");
        }
        else {
            assert(precision == -1 || digit_count < precision);
            chars_to_insert = ".0";
            insert_count = 2;
        }
    }
    if insert_count != 0 {
        var buf_len:size_t = buffer.count
        if (buf_len + insert_count + 1 >= buf_size) {
            /* If there is not enough room in the buffer
             for the additional text, just skip it.  It's
             not worth generating an error over. */
        }
        else {
            buffer = chars_to_insert + buffer
        }
    }
    if convert_to_exp != 0 {
        var buf_avail:size_t = 1//TODO:Remove
        index = digits_start;
        /* insert decimal point */
        assert(digit_count >= 1);
        p[1] = "."
        index += digit_count+1;
        if (buf_avail == 0){
            return "NULL"
        }
        /* Add exponent.  It's okay to use lower case 'e': we only
         arrive here as a result of using the empty format code or
         repr/str builtins and those never want an upper case 'E' */
        buffer = PyOS_snprintf(p[index,nil], buf_avail, "e%+.02d", digit_count-1);
        buffer = remove_trailing_zeros(buffer)
    }
    return buffer;
}

/* see FORMATBUFLEN in unicodeobject.c */
let FLOAT_FORMATBUFLEN = 120

/**
 * _PyOS_ascii_formatd:
 * @buffer: A buffer to place the resulting string in
 * @buf_size: The length of the buffer.
 * @format: The printf()-style format to use for the
 *          code to use for converting.
 * @d: The #gdouble to convert
 * @precision: The precision to use when formatting.
 *
 * Converts a #gdouble to a string, using the '.' as
 * decimal point. To format the number you pass in
 * a printf()-style format string. Allowed conversion
 * specifiers are 'e', 'E', 'f', 'F', 'g', 'G', and 'Z'.
 *
 * 'Z' is the same as 'g', except it always has a decimal and
 *     at least one digit after the decimal.
 *
 * Return value: The pointer to the buffer with the converted string.
 * On failure returns NULL but does not set any Python exception.
 **/
func _PyOS_ascii_formatd(_ buffer:String,
                         _ buf_size:Int,
                         _ format:String,
                         _ d:double,
                         _ precision:int) -> String
{
    var buffer = buffer
    var format = format
    var format_char:Character
    var format_len:Int = format.count
    
    /* Issue 2264: code 'Z' requires copying the format.  'Z' is 'g', but
     also with at least one character past the decimal. */
    var tmp_format:String
    
    /* The last character in the format string must be the format char */
    format_char = format[format_len - 1];
    
    if (format[0] != "%") {
        return "NULL"
    }
    
    /* I'm not sure why this test is here.  It's ensuring that the format
     string after the first character doesn't have a single quote, a
     lowercase l, or a percent. This is the reverse of the commented-out
     test about 10 lines ago. */
    let _f = format[1,nil]
    if _f.contains("'") || _f.contains("l") || _f.contains("%") {
        return "NULL"
    }
    
    /* Also curious about this function is that it accepts format strings
     like "%xg", which are invalid for floats.  In general, the
     interface to this function is not very good, but changing it is
     difficult because it's a public API. */
    
    if  !"eEfFgGZ".contains(format_char) {
        return "NULL"
    }
    
    /* Map 'Z' format_char to 'g', by copying the format string and
     replacing the final char with a 'g' */
    if (format_char == "Z") {
        tmp_format = format
        tmp_format[format_len - 1] = "g"
        format = tmp_format
    }
    
    
    /* Have PyOS_snprintf do the hard work */
    buffer = PyOS_snprintf(buffer, buf_size, format, d)
    
    /* Do various fixups on the return string */
    
    /* Get the current locale, and find the decimal point string.
     Convert that string back to a dot. */
    buffer = change_decimal_from_locale_to_dot(buffer)
    
    /* If an exponent exists, ensure that the exponent is at least
     MIN_EXPONENT_DIGITS digits, providing the buffer is large enough
     for the extra zeros.  Also, if there are more than
     MIN_EXPONENT_DIGITS, remove as many zeros as possible until we get
     back to MIN_EXPONENT_DIGITS */
    ensure_minimum_exponent_length(&buffer, buf_size);
    
    /* If format_char is 'Z', make sure we have at least one character
     after the decimal point (and make sure we have a decimal point);
     also switch to exponential notation in some edge cases where the
     extra character would produce more significant digits that we
     really want. */
    if (format_char == "Z") {
        buffer = ensure_decimal_point(buffer, buf_size, precision);
    }
    
    return buffer;
}

/* The fallback code to use if _Py_dg_dtoa is not available. */

func PyOS_double_to_string(_ val:Double,
                           _ format_code:Character,
                           _ precision:int,
                           _ flags:int,
                           _ type: inout int) -> String
{
    var format_code = format_code
    var precision = precision
    
    var buf:String = ""
    var upper:Bool = false
    
    /* Validate format_code, and map upper and lower case */
    switch (format_code) {
    case "e"/* exponent */, "f"/* fixed */,"g":          /* general */
        break;
    case "E","F","G":
        upper = true
        format_code = format_code.lowercased()[0]
        break;
    case "r":          /* repr format */
        /* Supplied precision is unused, must be 0. */
        if (precision != 0) {
//            PyErr_BadInternalCall();
//            return NULL;
        }
        /* The repr() precision (17 significant decimal digits) is the
         minimal number that is guaranteed to have enough precision
         so that if the number is read back in the exact same binary
         value is recreated.  This is true for IEEE floating point
         by design, and also happens to work for all other modern
         hardware. */
        precision = 17;
        format_code = "g"
        break;
    default:
        break;
//        PyErr_BadInternalCall();
//        return NULL;
    }

    /* Handle nan and inf. */
    if val.isNaN {
        buf += "nan"
        type = Py_DTST_NAN;
    } else if val.isInfinite {
        if val > 0 {
            buf += "inf"
        }
        else{
            buf += "-inf"
        }
        type = Py_DTST_INFINITE;
    } else {
        type = Py_DTST_FINITE;
        if (flags & Py_DTSF_ADD_DOT_0) != 0 {
            format_code = "Z"
        }
        switch format_code {
        case "e":
            buf = FloatFormatter.SpecifiedExpNumberFormat(val, accuracy: precision, sharp: (flags & Py_DTSF_ALT) != 0)
            break
        case "f":
            buf = FloatFormatter.SpecifiedFloatNumberFormat(val, accuracy: precision, sharp: (flags & Py_DTSF_ALT) != 0)
            break
        case "g":
            buf = FloatFormatter.SpecifiedGeneralNumberFormat(val, accuracy: precision, sharp: (flags & Py_DTSF_ALT) != 0)
            break
        case "z","Z":
            buf = FloatFormatter.NonSpecifiedGeneralNumberFormat(val, accuracy: precision, sharp: (flags & Py_DTSF_ALT) != 0)
            break
        case "%":
            buf = FloatFormatter.SpecifiedFloatNumberFormat(val*100, accuracy: precision, sharp: (flags & Py_DTSF_ALT) != 0) + "%"
        default:
            break
        }
    }
    
    /* Add sign when requested.  It's convenient (esp. when formatting
     complex numbers) to include a sign even for inf and nan. */
    if (flags & Py_DTSF_SIGN) != 0 && buf[0] != "-" {
        /* the bufsize calculations above should ensure that we've got
         space to add a sign */
        buf = "+" + buf
    }
    if (upper) {
        /* Convert to upper case. */
        buf = buf.upper()
    }
    return buf
}




/************************************************************************/
/*********** string formatting ******************************************/
/************************************************************************/

func format_string_internal(_ value:String, _ format:InternalFormatSpec,
                            _ writer:inout _PyUnicodeWriter) -> Result<int,PyException>
{
    /* sign is not allowed on strings */
    if (format.sign != "\0") {
        return .failure(.ValueError("Sign not allowed in string format specifier"))
    }
    
    /* alternate is not allowed on strings */
    if (format.alternate) {
        return .failure(.ValueError("Alternate form (#) not allowed in string format specifier"))
    }
    
    /* '=' alignment not allowed on strings */
    if (format.align == "=") {
        return .failure(.ValueError("'=' alignment not allowed in string format specifier"))
    }
    var value = value
    
    var len = value.count

    if ((format.width == -1 || format.width <= len)
        && (format.precision == -1 || format.precision >= len)) {
        /* Fast path */
        return _PyUnicodeWriter_WriteStr(&writer, value);
    }
    
    /* if precision is specified, output no more that format.precision
     characters */
    if (format.precision >= 0 && len >= format.precision) {
        len = format.precision;
    }

    switch format.align {
    case ">":
        value = value.rjust(format.width, fillchar: format.fill_char)
        break
    case "<":
        value = value.ljust(format.width, fillchar: format.fill_char)
        break
    case "=","^":
        value = value.center(format.width, fillchar: format.fill_char)
        break
    default:
        break;
    }
    
    /* Then the source string. */
    writer.buffer.append(value)
    writer.pos += value.count
    
    return .success(0)
}


/************************************************************************/
/*********** long formatting ********************************************/
/************************************************************************/

func format_long_internal(_ value:Int64, _ format:InternalFormatSpec,
                          _ writer:inout _PyUnicodeWriter) -> Result<int,PyException>
{
    var tmp:String = ""
    var inumeric_chars:Py_ssize_t
    var sign_char:Py_UCS4 = "\0"
    var n_digits:Py_ssize_t       /* count of digits need from the computed string */
    var n_remainder:Py_ssize_t = 0; /* Used only for 'c' formatting, which produces non-digits */
    var n_prefix:Py_ssize_t = 0;   /* Count of prefix chars, (e.g., '0x') */
    var n_total:Py_ssize_t
    var prefix:Py_ssize_t = 0;
    var spec:NumberFieldWidths = .init()
    
    /* Locale settings, either from the actual locale or
     from a hard-code pseudo-locale */
    var locale:LocaleInfo = .init()
    
    /* no precision allowed on integers */
    if (format.precision != -1) {
        return .failure(.ValueError("Precision not allowed in integer format specifier"))
    }
    
    /* special case for character formatting */
    if (format.type == "c") { // 数値を文字として扱う場合
        /* error to specify a sign */
        if (format.sign != "\0") {
            return .failure(.ValueError("Sign not allowed with integer format specifier 'c'"))
        }
        /* error to request alternate format */
        if (format.alternate) {
            return .failure(.ValueError("Alternate form (#) not allowed with integer format specifier 'c'"))
        }
        
        /* taken from unicodeobject.c formatchar() */
        /* Integer input truncated to a character */

        if (value < 0 || value > 0x10ffff) {
            return .failure(.OverflowError("%c arg not in range(0x110000)"))
        }
        tmp = PyUnicode_FromOrdinal(.init( Int(value) ));
        inumeric_chars = 0;
        n_digits = 1;
        
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
            && format.thousands_separators == .LT_NO_LOCALE)
        {
            /* Fast path */
            return _PyLong_FormatWriter(&writer, value, base, format.alternate);
        }
        
        /* The number of prefix chars is the same as the leading
         chars to skip */
        if (format.alternate){
            n_prefix = leading_chars_to_skip;
        }
        
        /* Do the hard part, converting to a string in a given base */
        tmp = String(value,radix: base)
        
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
    _ = get_locale_info(format.type == "n" ? .LT_CURRENT_LOCALE :
        format.thousands_separators, &locale)
    
    /* Calculate how much memory we'll need. */
    n_total = calc_number_widths(&spec, n_prefix, sign_char, tmp, inumeric_chars,
    inumeric_chars + n_digits, n_remainder, false, locale, format);
    
    
    /* Populate the memory. */
    return fill_number(&writer, spec,
    tmp, inumeric_chars, inumeric_chars + n_digits,
    tmp, prefix, format.fill_char,
    locale, format.type == "X");
}

/************************************************************************/
/*********** float formatting *******************************************/
/************************************************************************/

/* much of this is taken from unicodeobject.c */
func format_float_internal(_ value:Double,
                           _ format:InternalFormatSpec,
                           _ writer:inout _PyUnicodeWriter) -> Result<int,PyException>
{
    var buf:String = ""      /* buffer returned from PyOS_double_to_string */
    var n_digits:Py_ssize_t = 0
    var n_remainder:Py_ssize_t = 0
    var has_decimal:Bool = false
    var val:double = 0
    var default_precision:int = 6
    var type:Py_UCS4 = format.type
    var index:Py_ssize_t = 0
    var spec:NumberFieldWidths = .init()
    var flags:int = 0
    var sign_char:Py_UCS4 = "\0"
    var float_type:int  = 0 /* Used to see if we have a nan, inf, or regular float. */
    var unicode_tmp:String = ""
    
    /* Locale settings, either from the actual locale or
     from a hard-code pseudo-locale */
    var locale:LocaleInfo = .init()
    
    if (format.precision > INT_MAX) {
        return .failure(.ValueError("precision too big"))
    }
    var precision:int = format.precision;

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
    
    val = value
    
    if (precision < 0){
        precision = default_precision;
    }
    else if (type == "r"){
        type = "g"
    }

    /* Cast "type", because if we're in unicode we need to pass an
     8-bit char. This is safe, because we've restricted what "type"
     can be. */
    buf = PyOS_double_to_string(val, type, precision, flags, &float_type);

    n_digits = buf.count
    

    
    if (format.sign != "+" && format.sign != " "
        && format.width == -1
        && format.type != "n"
        && format.thousands_separators == .LT_NO_LOCALE)
    {
        /* Fast path */
        return _PyUnicodeWriter_WriteASCIIString(&writer, buf, n_digits);
    }
    
    /* Since there is no unicode version of PyOS_double_to_string,
     just use the 8 bit version and then convert to unicode. */
    unicode_tmp = _PyUnicode_FromASCII(buf, n_digits);
    
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
    parse_number(unicode_tmp, index, index + n_digits, &n_remainder, &has_decimal)
    
    /* Determine the grouping, separator, and decimal point, if any. */
    _ = get_locale_info(format.type == "n" ? .LT_CURRENT_LOCALE :
        format.thousands_separators,
                        &locale)
    
    /* Calculate how much memory we'll need. */
    _ = calc_number_widths(&spec, 0, sign_char, unicode_tmp, index,
    index + n_digits, n_remainder, has_decimal,
    locale, format)
    
    
    /* Populate the memory. */
    return fill_number(&writer, spec,
    unicode_tmp, index, index + n_digits,
    "", 0, format.fill_char,
    locale, false)
}

/************************************************************************/
/*********** complex formatting *****************************************/
/************************************************************************/

func format_complex_internal(_ value:PyObject,
                             _ format:inout InternalFormatSpec,
                             _ writer:inout _PyUnicodeWriter) -> Result<int,PyException>
{
    var re:double = 0
    var im:double = 0
    var re_buf:String = ""      /* buffer returned from PyOS_double_to_string */
    var im_buf:String = ""      /* buffer returned from PyOS_double_to_string */
    
    var tmp_format:InternalFormatSpec = format;
    var n_re_digits:Py_ssize_t = 0
    var n_im_digits:Py_ssize_t = 0
    var n_re_remainder:Py_ssize_t = 0
    var n_im_remainder:Py_ssize_t = 0
    var n_re_total:Py_ssize_t = 0
    var n_im_total:Py_ssize_t = 0
    var re_has_decimal:Bool = false
    var im_has_decimal:Bool = false
    var precision:int = 0
    var default_precision:int = 6
    var type:Py_UCS4 = format.type
    var i_re:Py_ssize_t = 0
    var i_im:Py_ssize_t = 0
    var re_spec:NumberFieldWidths = .init()
    var im_spec:NumberFieldWidths = .init()
    var flags:int = 0
    var result:int = -1;
    var re_sign_char:Py_UCS4 = "\0";
    var im_sign_char:Py_UCS4 = "\0";
    var re_float_type:int = 0 /* Used to see if we have a nan, inf, or regular float. */
    var im_float_type:int = 0
    var add_parens:Bool = false
    var skip_re:Bool = false
    var lpad:Py_ssize_t = 0
    var rpad:Py_ssize_t = 0
    var total:Py_ssize_t = 0
    var re_unicode_tmp:String = ""
    var im_unicode_tmp:String = ""
    
    /* Locale settings, either from the actual locale or
     from a hard-code pseudo-locale */
    var locale:LocaleInfo = .init()
    
    if (format.precision > INT_MAX) {
        return .failure(.ValueError("precision too big"))
    }
    precision = format.precision;
    
    /* Zero padding is not allowed. */
    if (format.fill_char == "0") {
        return .failure(.ValueError("Zero padding is not allowed in complex format specifier"))
    }
    
    /* Neither is '=' alignment . */
    if (format.align == "=") {
        return .failure(.ValueError("'=' alignment flag is not allowed in complex format specifier"))
    }
    
    (re,im) = value as! (Double,Double)
    
    if (format.alternate){
        flags |= Py_DTSF_ALT;
    }
    
    if (type == "\0") {
        /* Omitted type specifier. Should be like str(self). */
        type = "r";
        default_precision = 0;
        if (re == 0.0 && copysign(1.0, re) == 1.0){
            skip_re = true
        }
        else{
            add_parens = true
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
    re_buf = PyOS_double_to_string(re, type, precision, flags,
    &re_float_type);

    im_buf = PyOS_double_to_string(im, type, precision, flags,
    &im_float_type);
    
    n_re_digits = strlen(re_buf);
    n_im_digits = strlen(im_buf);
    
    /* Since there is no unicode version of PyOS_double_to_string,
     just use the 8 bit version and then convert to unicode. */
    re_unicode_tmp = _PyUnicode_FromASCII(re_buf, n_re_digits);
    i_re = 0;
    
    im_unicode_tmp = _PyUnicode_FromASCII(im_buf, n_im_digits);
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
    _ = get_locale_info(format.type == "n" ? .LT_CURRENT_LOCALE :
        format.thousands_separators,
                        &locale)
    
    /* Turn off any padding. We'll do it later after we've composed
     the numbers without padding. */
    tmp_format.fill_char = "\0";
    tmp_format.align = "<";
    tmp_format.width = -1;
    
    /* Calculate how much memory we'll need. */
    n_re_total = calc_number_widths(&re_spec, 0, re_sign_char, re_unicode_tmp,
    i_re, i_re + n_re_digits, n_re_remainder,
    re_has_decimal, locale, tmp_format)
    
    /* Same formatting, but always include a sign, unless the real part is
     * going to be omitted, in which case we use whatever sign convention was
     * requested by the original format. */
    if (!skip_re){
        tmp_format.sign = "+";
    }
    n_im_total = calc_number_widths(&im_spec, 0, im_sign_char, im_unicode_tmp,
    i_im, i_im + n_im_digits, n_im_remainder,
    im_has_decimal, locale, tmp_format)
    
    if (skip_re){
        n_re_total = 0;
    }
    
    /* Add 1 for the 'j', and optionally 2 for parens. */
    calc_padding(n_re_total + n_im_total + 1 + (add_parens ? 1:0) * 2,
    format.width, format.align, &lpad, &rpad, &total);
    
    
    
    /* Populate the memory. First, the padding. */
    result = fill_padding(&writer,
    n_re_total + n_im_total + 1 + (add_parens ? 1:0) * 2,
    format.fill_char, lpad, rpad)
    
    if (add_parens) {
        PyUnicode_WRITE(&writer.buffer, writer.pos, "(");
        writer.pos += 1
    }
    
    if (!skip_re) {
        switch fill_number(&writer, re_spec,
                             re_unicode_tmp, i_re, i_re + n_re_digits,
                             "", 0, "\0",
                             locale, false) {
        case .success(let r):
            result = r
            break;
        case .failure(let err):
            return .failure(err)
        }
    }
    switch fill_number(&writer, im_spec,
    im_unicode_tmp, i_im, i_im + n_im_digits,
    "", 0,"\0", locale, false){
    case .success(let r):
        result = r
        break;
    case .failure(let err):
        return .failure(err)
    }

    PyUnicode_WRITE(&writer.buffer, writer.pos, "j");
    writer.pos += 1
    
    if (add_parens) {
        PyUnicode_WRITE(&writer.buffer, writer.pos, ")");
        writer.pos += 1
    }
    
    writer.pos += rpad;
    
    return .success(result)
}

/************************************************************************/
/*********** built in formatters ****************************************/
/************************************************************************/
func format_obj(_ obj:PyObject, _ writer:inout _PyUnicodeWriter) -> Result<int,PyException>
{
    let str:String = PyObject_Str(obj)
    return _PyUnicodeWriter_WriteStr(&writer, str);
}

func _PyUnicode_FormatAdvancedWriter(_ writer:inout _PyUnicodeWriter,
                                     _ obj:String,
                                     _ format_spec:String,
                                     _ start:Py_ssize_t, _ end:Py_ssize_t) -> Result<int,PyException>
{
    var format:InternalFormatSpec = .init()
    
    
    /* check for the special case of zero length format spec, make
     it equivalent to str(obj) */
    if (start == end) {
        return _PyUnicodeWriter_WriteStr(&writer, obj)
    }
    
    /* parse the format_spec */
    switch parse_internal_render_format_spec(format_spec, start, end,
                                             &format, "s", "<") {
    case .success(_):
        break
    case .failure(let err):
        return .failure(err)
    }
    
    /* type conversion? */
    if format.type == "s" {
        /* no type conversion needed, already a string.  do the formatting */
        return format_string_internal(obj, format, &writer);
    } else {
        /* unknown */
        return unknown_presentation_type(format.type, obj);
    }
}

func _PyLong_FormatAdvancedWriter(_ writer:inout _PyUnicodeWriter,
                                  _ obj:Int64,
                                  _ format_spec:String,
                                  _ start:Py_ssize_t, _ end:Py_ssize_t) -> Result<int,PyException>
{
    var format:InternalFormatSpec = .init()
    
    /* check for the special case of zero length format spec, make
     it equivalent to str(obj) */
    if (start == end) {
        return _PyLong_FormatWriter(&writer, obj, 10, false);
    }
    
    /* parse the format_spec */
    switch parse_internal_render_format_spec(format_spec, start, end,
                                             &format, "d", ">") {
    case .success(_):
        break
    case .failure(let err):
        return .failure(err)
    }

    
    /* type conversion? */
    if "bcdoxXn".contains(format.type){
        /* no type conversion needed, already an int.  do the formatting */
        return format_long_internal(obj, format, &writer)
    } else if "eEfFgG%".contains(format.type){
        /* convert to float */
        
        let tmp = Double(obj) // 精度の高い少数型へ変換

        return format_float_internal(tmp, format, &writer)
    } else {
        return unknown_presentation_type(format.type, obj)
    }
    return .success(0)
}

func _PyFloat_FormatAdvancedWriter(_ writer:inout _PyUnicodeWriter,
                                   _ obj:Double,
                                   _ format_spec:String,
    _ start:Py_ssize_t, _ end:Py_ssize_t) -> Result<int,PyException>
{
    var format:InternalFormatSpec = .init()
    
    /* check for the special case of zero length format spec, make
     it equivalent to str(obj) */
    if (start == end){
        return format_obj(obj, &writer);
    }
    
    /* parse the format_spec */
    switch parse_internal_render_format_spec(format_spec, start, end,
                                             &format, "\0", ">") {
    case .success(_):
        break
    case .failure(let err):
        return .failure(err)
    }

    /* type conversion? */
    if "\0eEfFgGn%".contains(format.type){
        /* no conversion, already a float.  do the formatting */
        return format_float_internal(obj, format, &writer);
    } else {
        /* unknown */
        return unknown_presentation_type(format.type, obj);
    }
}

func _PyComplex_FormatAdvancedWriter(_ writer:inout _PyUnicodeWriter,
                                     _ obj:PyObject,
    _ format_spec:String,
    _ start:Py_ssize_t, _ end:Py_ssize_t) -> Result<int,PyException>
{
    var format:InternalFormatSpec = .init()
    
    /* check for the special case of zero length format spec, make
     it equivalent to str(obj) */
    if (start == end){
        return format_obj(obj, &writer);
    }
    
    /* parse the format_spec */
    switch parse_internal_render_format_spec(format_spec, start, end,
                                             &format, "\0", ">") {
    case .success(_):
        break
    case .failure(let err):
        return .failure(err)
    }
    
    /* type conversion? */
    if "\0eEfFgGn".contains(format.type) {
        /* no conversion, already a complex.  do the formatting */
        return format_complex_internal(obj, &format, &writer);

    } else {
        /* unknown */
        return unknown_presentation_type(format.type, obj);
    }
}

protocol FormatableNumeric {}
protocol FormatableSignedInteger:FormatableNumeric {
    func toInt64() -> Int64;
}
protocol FormatableUnSignedInteger:FormatableNumeric {
    func toUInt64() -> UInt64;
}
protocol FormatableFloat:FormatableNumeric {
    func toDouble() -> Double;
    func nround(_ ndigits:Int) -> Double;
}
extension FormatableFloat {
    func nround(_ ndigits:Int=0) -> Double {
        let ndigits = Double(ndigits)
        let n = pow(10,ndigits)
        return round(self.toDouble() * n) / n
    }
}
extension Int:FormatableSignedInteger {
    func toInt64() -> Int64 {
        return Int64(self)
    }
}
extension Int8:FormatableSignedInteger {
    func toInt64() -> Int64 {
        return Int64(self)
    }
}
extension Int16:FormatableSignedInteger {
    func toInt64() -> Int64 {
        return Int64(self)
    }
}
extension Int32:FormatableSignedInteger {
    func toInt64() -> Int64 {
        return Int64(self)
    }
}
extension Int64:FormatableSignedInteger {
    func toInt64() -> Int64 {
        return Int64(self)
    }
}
extension UInt:FormatableUnSignedInteger {
    func toUInt64() -> UInt64 {
        return UInt64(self)
    }
}
extension UInt8:FormatableUnSignedInteger {
    func toUInt64() -> UInt64 {
        return UInt64(self)
    }
}
extension UInt16:FormatableUnSignedInteger {
    func toUInt64() -> UInt64 {
        return UInt64(self)
    }
}
extension UInt32:FormatableUnSignedInteger {
    func toUInt64() -> UInt64 {
        return UInt64(self)
    }
}
extension UInt64:FormatableUnSignedInteger {
    func toUInt64() -> UInt64 {
        return UInt64(self)
    }
}
extension Float:FormatableFloat {
    func toDouble() -> Double {
        return Double(self)
    }
}
extension Double:FormatableFloat {
    func toDouble() -> Double {
        return Double(self)
    }
}
extension Float80:FormatableFloat {
    func toDouble() -> Double {
        return Double(self)
    }
}

extension String {
    public func format(_ args:Any?..., kwargs:[String:Any?]=[:]) -> String {
        switch do_string_format(self, args: args, kwargs: kwargs) {
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
