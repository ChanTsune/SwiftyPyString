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

extension BinaryInteger {
    @discardableResult
    static prefix func ++ (i: inout Self) -> Self {
        i += 1
        return i
    }
    @discardableResult
    static postfix func ++ (i: inout Self) -> Self {
        let tmp = i
        i += 1
        return tmp
    }
    @discardableResult
    static prefix func -- (i: inout Self) -> Self {
        i -= 1
        return i
    }
    @discardableResult
    static postfix func -- (i: inout Self) -> Self {
        let tmp = i
        i -= 1
        return tmp
    }
}

/*
    unicode_format.h -- implementation of str.format().
*/

/************************************************************************/
/***********   Global data structures and forward declarations  *********/
/************************************************************************/


typealias FormatResult = Result<String, PyException>

enum AutoNumberState {
    case ANS_INIT // 初期状態
    case ANS_AUTO // 自動インクリメントモード
    case ANS_MANUAL // 指定
}   /* Keep track if we're auto-numbering fields */

/* Keeps track of our auto-numbering state, and which number field we're on */
class AutoNumber {
    var an_state: AutoNumberState = .ANS_INIT
    var an_field_number: int = 0
}

func _PyUnicode_FromASCII(_ buffer:String, _ size: Py_ssize_t) -> String
{
    return buffer
}

/* Return 1 if an error has been detected switching between automatic
   field numbering and manual field specification, else return 0. Set
   ValueError on error. */
func autonumber_state_error(_ state:AutoNumberState, _ field_name_is_empty: Bool) -> Result<int,PyException>
{
    if (state == .ANS_MANUAL) {
        if field_name_is_empty {
            return .failure(.ValueError("cannot switch from manual field specification to automatic field numbering"))
        }
    } else {
        if !field_name_is_empty {
            return .failure(.ValueError("cannot switch from automatic field numbering to manual field specification"))
        }
    }
    return .success(0) // 戻り値に特に意味はない
}
func Py_UNICODE_TODECIMAL(_ c:Character) -> Int{
    if c.isdecimal(),let n = c.unicode.properties.numericValue {
        return Int(n)
    }
    return -1
}
func PyUnicode_READ_CHAR(_ str:String,_ index: Int) -> Character{
    return str[index]
}

/************************************************************************/
/***********  Format string parsing -- integers and identifiers *********/
/************************************************************************/

func get_integer(_ str: String) -> Result<Py_ssize_t,PyException>
{
    var accumulator:Py_ssize_t = 0
    var digitval:Py_ssize_t

    /* empty string is an error */
    if str.isEmpty {
        return .success(-1) // error path
    }
    for c in str {
        digitval = Py_UNICODE_TODECIMAL(c);
        if (digitval < 0){
            return .success(-1) // error path
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
    }
    return .success(accumulator)
}

func PyObject_GetAttr(_ v:PyObject, _ name:String) -> Result<PyObject,PyException>
{
    let mirror = Mirror(reflecting: v)
    let c = mirror.children
    var keyMap:[String:Any] = [:]
    for i in c {
        keyMap[i.label!] = i.value
    }
    if let value = keyMap[name] {
        return .success(value)
    }
    return .failure(.AttributeError("'\(typeName(v))' object has no attribute '\(name)'"))
}


/************************************************************************/
/******** Functions to get field objects and specification strings ******/
/************************************************************************/

/* do the equivalent of obj.name */
func getattr(_ obj:PyObject, _ name:String) -> Result<PyObject,PyException>
{
    return PyObject_GetAttr(obj, name)
}
func PyObject_GetItem<D: RandomAccessCollection>(_ obj:D, _ key:D.Index) -> Any? {
    return obj[key]
}
/* do the equivalent of obj[idx], where obj is not a sequence */
func getitem_idx<Seq: RandomAccessCollection>(_ obj:Seq, _ idx:Py_ssize_t) -> PyObject?
{
    return PyObject_GetItem(obj, idx as! Seq.Index);
}

/* do the equivalent of obj[name] */
func getitem_str<Seq: RandomAccessCollection>(_ obj:Seq, _ name:String) -> PyObject?
{
    return PyObject_GetItem(obj, name as! Seq.Index );
}

class FieldNameIterator {
    /* the entire string we're parsing.  we assume that someone else
       is managing its lifetime, and that it will exist for the
       lifetime of the iterator.  can be empty */
    var str:String

    /* index to where we are inside field_name */
    var index:Py_ssize_t
    var end:Int {
        return str.count
    }
    
    init(_ s:String, _ start:Int){
        self.str = s
        self.index = start
    }
}

func _FieldNameIterator_attr(_ self:FieldNameIterator) -> String
{
    var c:Py_UCS4

    let start = self.index

    /* return everything until '.' or '[' */
    while (self.index < self.end) {
        c = PyUnicode_READ_CHAR(self.str, self.index++);
        switch (c) {
        case "[", ".":
            /* backup so that we this character will be seen next time */
            self.index--;
            break;
        default:
            continue;
        }
        break;
    }
    /* end of string is okay */
    let name = self.str[start, self.index]
    return name
}

func _FieldNameIterator_item(_ self:FieldNameIterator) -> Result<String,PyException>
{
    var bracket_seen:Bool = false
    var c:Py_UCS4

    let start = self.index

    /* return everything until ']' */
    while (self.index < self.end) {
        c = PyUnicode_READ_CHAR(self.str, self.index++);
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
        return .failure(.ValueError("Missing ']' in format string"))
    }

    /* end of string is okay */
    /* don't include the ']' */
    let name = self.str[start,self.index-1]
    return .success(name)
}

struct FieldNameIteratorResult {
    var is_attribute: Bool
    var name_idx: Int
    var name: String
}

enum LoopResult<T, U> {
    case success(T)
    case failure(U)
    case finish
}


/* returns 0 on error, 1 on non-error termination, and 2 if it returns a value */
func FieldNameIterator_next(_ self:FieldNameIterator) -> LoopResult<FieldNameIteratorResult, PyException>
{
    /* check at end of input */
    if (self.index >= self.end){
        return .finish
    }
    var is_attribute:Bool = false
    var name_idx:Int = -1
    var name:String = ""

    switch (PyUnicode_READ_CHAR(self.str, self.index++)) {
    case ".":
        is_attribute = true
        name = _FieldNameIterator_attr(self)
        name_idx = -1
        break;
    case "[":
        is_attribute = false
        switch _FieldNameIterator_item(self) {
        case .success(let n):
            name = n
        case .failure(let error):
            return .failure(error)
        }
        switch get_integer(name) {
        case .success(let i):
            name_idx = i
        case .failure(let error):
            return .failure(error)
        }
        break;
    default:
        /* Invalid character follows ']' */
        return .failure(.ValueError("Only '.' or '[' may follow ']' in format field specifier"))
    }

    /* empty string is an error */
    if name.isEmpty {
        return .failure(.ValueError("Empty attribute in format string"))
    }

    return .success(.init(is_attribute: is_attribute, name_idx: name_idx, name: name))
}


/* input: field_name
   output: 'first' points to the part before the first '[' or '.'
           'first_idx' is -1 if 'first' is not an integer, otherwise
                       it's the value of first converted to an integer
           'rest' is an iterator to return the rest
*/
func field_name_split(_ str:String,
                      _ auto_number:AutoNumber) -> Result<(String,Int,FieldNameIterator),PyException>
{
    var c: Py_UCS4
    var i: Py_ssize_t = 0
    let end = str.count
    var field_name_is_empty: Bool
    var using_numeric_index: Bool

    /* find the part up until the first '.' or '[' */
    while (i < end) {
        c = PyUnicode_READ_CHAR(str, i++)
        switch c {
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
    let first = str[nil, i]
    let rest:FieldNameIterator = .init(str[i, end], 0)

    /* see if "first" is an integer, in which case it's used as an index */
    var first_idx:Py_ssize_t = -1
    switch get_integer(first) {
    case .success(let tmp):
        first_idx = tmp
    case .failure(let error):
        return .failure(error)
    }

    field_name_is_empty = first.isEmpty

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
    if (auto_number.an_state == .ANS_INIT && using_numeric_index)
    {
        auto_number.an_state = field_name_is_empty ? .ANS_AUTO : .ANS_MANUAL;
    }

    /* Make sure our state is consistent with what we're doing
       this time through. Only check if we're using a numeric
       index. */
    if (using_numeric_index){
        switch autonumber_state_error(auto_number.an_state, field_name_is_empty) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }
    }
    /* Zero length field means we want to do auto-numbering of the
       fields. */
    if (field_name_is_empty){
        first_idx = (auto_number.an_field_number)++;
    }

    return .success((first,first_idx, rest))
}


/*
    get_field_object returns the object inside {}, before the
    format_spec.  It handles getindex and getattr lookups and consumes
    the entire input string.
*/
func get_field_object(_ input:String, _ args:[Any], _ kwargs:[String:Any],
                      _ auto_number:AutoNumber) -> Result<PyObject,PyException>
{
    var obj:PyObject
    var first: String
    var index:Py_ssize_t
    var rest:FieldNameIterator

    switch field_name_split(input, auto_number) {
    case .success(let tmp):
        (first,index,rest) = tmp
    case .failure(let error):
        return .failure(error)
    }

    if (index == -1) {
        /* look up in kwargs */
        let key:String = first
        if kwargs.isEmpty {
            return .failure(.KeyError(key))
        }
        /* Use PyObject_GetItem instead of PyDict_GetItem because this
           code is no longer just used with kwargs. It might be passed
           a non-dict when called through format_map. */
        guard let v = kwargs[key] else {
            return .failure(.KeyError(key))
        }
        obj = v
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
        if args.count <= index {
            return .failure(.IndexError("Replacement index \(index) out of range for positional args tuple"))
        }
        obj = args[index]
    }

    /* iterate over the rest of the field_name */
    field_name: while true {
        var is_attribute:Bool = .init() // 未初期化防止用
        var index:Int = .init() // 未初期化防止用
        var name:String = .init() // 未初期化防止用

        switch FieldNameIterator_next(rest) {
        case .failure(let error):
            return .failure(error)
        case .finish:
            break field_name
        case .success(let result):
            is_attribute = result.is_attribute
            index = result.name_idx
            name = result.name
        }
        var tmp:PyObject?

        if (is_attribute){
            /* getattr lookup "." */
            tmp = getattr(obj, name);
        } else {
            /* getitem lookup "[]" */
            if (index == -1){
                tmp = getitem_str(obj as! AnyRandomAccessCollection<Any> , name);
            } else {
                tmp = PyObject_GetItem(obj as! AnyRandomAccessCollection<Any>, index as!AnyRandomAccessCollection<Any>.Index)
            }
        }
        if (tmp == nil){
            return .failure(.AttributeError("???"))
        }
        obj = tmp;
    }
    /* end of iterator, this is the non-error case */
    return .success(obj)
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
func render_field(_ fieldobj:PyObject, _ format_spec:String) -> FormatResult
{

    /* If we know the type exactly, skip the lookup of __format__ and just
       call the formatter directly. */
    if fieldobj is PSFormattable {
        return _PyUnicode_FormatAdvancedWriter(fieldobj as! PSFormattable, format_spec)
    }
    else if fieldobj is PSFormattableInteger {
        return _PyLong_FormatAdvancedWriter(fieldobj as! PSFormattableInteger, format_spec)
    }
    else if fieldobj is PSFormattableFloatingPoint {
        return _PyFloat_FormatAdvancedWriter(fieldobj as! PSFormattableFloatingPoint, format_spec)
    }
    else {
        /* We need to create an object out of the pointers we have, because
           __format__ takes a string/unicode object for format_spec. */

        return .success(String(describing: fieldobj))
    }
}
struct ParseResult {
    var field_name: String
    var format_spec: String = ""
    var format_spec_needs_expanding:Bool
    var conversion: Py_UCS4 = "\0"
}

func parse_field(_ str:MarkupIterator) -> Result<ParseResult, PyException>
{
    /* Note this function works if the field name is zero length,
       which is good.  Zero length field names are handled later, in
       field_name_split. */

    var c:Py_UCS4 = "\0"

    /* initialize these, as they may be empty */
    var result = ParseResult(field_name: "", format_spec_needs_expanding: false)

    /* Search for the field name.  it's terminated by the end of
       the string, or a ':' or '!' */
    let start = str.start;
    while (str.start < str.end) {
        c = PyUnicode_READ_CHAR(str.str, str.start++)
        switch c {
        case "{":
            return .failure(.ValueError("unexpected '{' in field name"))
        case "[":
            while str.start < str.end {
                if (PyUnicode_READ_CHAR(str.str, str.start) == "]"){
                    break;
                }
                str.start++
            }
            continue;
        case "}", ":", "!":
            break;
        default:
            continue;
        }
        break;
    }

    result.field_name = str.str[start,str.start - 1] // フィールド名に相当する部分の部分の字列の切り出し
    if (c == "!" || c == ":") {
        var count:Py_ssize_t = 0
        /* we have a format specifier and/or a conversion */
        /* don't include the last character */

        /* see if there's a conversion specifier */
        if (c == "!") {
            /* there must be another character present */
            if (str.start >= str.end) {
                return .failure(.ValueError("end of string while looking for conversion specifier"))
            }
            result.conversion = PyUnicode_READ_CHAR(str.str, str.start++);

            if (str.start < str.end) {
                c = PyUnicode_READ_CHAR(str.str, str.start++);
                if (c == "}"){
                    return .success(result)
                }
                if (c != ":") {
                    return .failure(.ValueError("expected ':' after conversion specifier"))
                }
            }
        }
        let start = str.start
        count = 1;
        while (str.start < str.end) {
            c = PyUnicode_READ_CHAR(str.str, str.start++)
            switch c {
            case "{":
                result.format_spec_needs_expanding = true
                count++;
                break;
            case "}":
                count--;
                if (count == 0) {
                    result.format_spec = str.str[start,str.start - 1] // フォーマット指定子に相当する部分文字列の切り出し
                    return .success(result)
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

    return .success(result)
}

class MarkupIterator {
    let str: String
    var start: Int // 読み取りの開始位置
    var end: Int {
        return str.count
    }
    init(_ str: String, _ start: Int) {
        self.str = str
        self.start = start
    }
}

/* returns 0 on error, 1 on non-error termination, and 2 if it got a
   string (or something to be expanded) */

/* returns a tuple:
   (literal, field_name, format_spec, conversion)

   literal is any literal text to output.  might be zero length
   field_name is the string before the ':'.  might be None
   format_spec is the string after the ':'.  mibht be None
   conversion is either None, or the string after the '!'
*/

struct MarkupIteratorNextResult {
    var format_spec_needs_expanding:Bool
    var field_present:int
    var literal:String
    var field_name:String
    var format_spec:String
    var conversion:Py_UCS4
}

func MarkupIterator_next(_ self:MarkupIterator) -> LoopResult<MarkupIteratorNextResult,PyException>
{
    var at_end: Bool
    var start:Py_ssize_t
    var len:Py_ssize_t
    var markup_follows:Bool = false

    /* initialize all of the output variables */
    var result = MarkupIteratorNextResult(format_spec_needs_expanding: false, field_present: 0, literal: "", field_name: "", format_spec: "", conversion: "\0")

    /* No more input, end of iterator.  This is the normal exit
       path. */
    if (self.start >= self.end){
        return .finish;
    }

    start = self.start;

    /* First read any literal text. Read until the end of string, an
       escaped '{' or '}', or an unescaped '{'.  In order to never
       allocate memory and so I can just pass pointers around, if
       there's an escaped '{' or '}' then we'll return the literal
       including the brace, but no format object.  The next time
       through, we'll return the rest of the literal, skipping past
       the second consecutive brace. */
    var c:Py_UCS4 = "\0"
    for i in self.str[start, nil] {
        c = i
        self.start++
        switch c {
        case "{", "}":
            markup_follows = true
            break;
        default:
            continue;
        }
        break;
    }

    at_end = self.start >= self.end;
    len = self.start - start;

    if ((c == "}") && (at_end ||
        (c != self.str[self.start]))) {
        return .failure(.ValueError("Single '}' encountered in format string"))
    }
    if (at_end && c == "{") {
        return .failure(.ValueError("Single '{' encountered in format string"))
    }
    if (!at_end) {
        if (c == self.str[self.start]) {
            /* escaped } or {, skip it in the input.  there is no
               markup object following us, just this literal text */
            self.start++
            markup_follows = false
        }
        else{
            len--
        }
    }

    /* record the literal text */
    var literal = self.str[start,start + len]

    if (!markup_follows){
        return .success(result)
    }

    /* this is markup; parse the field */
    result.field_present = 1;
    switch parse_field(self) {
    case .success(let r):
        result.conversion = r.conversion
        result.format_spec = r.format_spec
        result.field_name = r.field_name
        result.format_spec_needs_expanding = r.format_spec_needs_expanding
    case .failure(let error):
        return .failure(error)
    }
    return .success(result)
}


/* do the !r or !s conversion on obj */
func do_conversion(_ obj:PyObject, _ conversion:Py_UCS4) -> FormatResult
{
    /* XXX in pre-3.0, do we need to convert this to unicode, since it
       might have returned a string? */
    switch (conversion) {
    case "r", "s", "a":
        if let obj = obj as? PSFormattable {
            return .success(obj.convertField(conversion))
        }
        return .success("nil")
    default:
        if conversion.isRegularASCII {
        /* It's the ASCII subrange; casting to char is safe
           (assuming the execution character set is an ASCII
           superset). */
            return .failure(.ValueError("Unknown conversion specifier \(conversion)"))
        }
        return .failure(.ValueError("Unknown conversion specifier \\x\(hex(conversion.unicode.value,false))"))
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

func output_markup(_ field_name:String,
                   _ format_spec:String,
                   _ format_spec_needs_expanding:Bool,
                   _ conversion:Py_UCS4,
                   _ args:[Any],
                   _ kwargs:[String:Any],
                   _ recursion_depth:int,
                   _ auto_number:AutoNumber) -> FormatResult
{
    var fieldobj:PyObject
    var actual_format_spec:String

    /* convert field_name to an object */
    switch get_field_object(field_name, args, kwargs, auto_number) {
    case .success(let o):
        fieldobj = o
    case .failure(let error):
        return .failure(error)
    }

    if (conversion != "\0") {
        switch do_conversion(fieldobj, conversion) {
        case .success(let s):
            fieldobj = s
        case .failure(let error):
            return .failure(error)
        }
    }

    /* if needed, recurively compute the format_spec */
    if (format_spec_needs_expanding) {
        switch build_string(format_spec, args, kwargs, recursion_depth-1, auto_number) {
        case .success(let expanded_format_spec):
            actual_format_spec = expanded_format_spec
        case .failure(let error):
            return .failure(error)
        }
    }
    else{
        actual_format_spec = format_spec;
    }
    switch render_field(fieldobj, actual_format_spec) {
    case .success(let str):
        return .success(str)
    case .failure(let error):
        return .failure(error)
    }
}

/*
    do_markup is the top-level loop for the format() method.  It
    searches through the format string for escapes to markup codes, and
    calls other functions to move non-markup text to the output,
    and to perform the markup to the output.
*/



func do_markup(_ input:String, _ args:[Any], _ kwargs:[String:Any],
               _ recursion_depth:int, _ auto_number:AutoNumber) -> FormatResult
{
    let iter:MarkupIterator = .init(input, 0)
    var result:MarkupIteratorNextResult
    var markuped:String = ""
    mark_up: while true {
        switch MarkupIterator_next(iter) {
        case .finish:
            break mark_up
        case .failure(let error):
            return .failure(error)
        case .success(let r):
            result = r
            if !result.literal.isEmpty {
                markuped += result.literal
            }

            if (result.field_present.asBool) {
                switch output_markup(result.field_name,
                                     result.format_spec,
                                     result.format_spec_needs_expanding,
                                     result.conversion,
                                     args,
                                     kwargs,
                                     recursion_depth,
                                     auto_number) {
                case .success(let str):
                    markuped += str
                case .failure(let error):
                    return .failure(error)
                }
            }
        }
    }
    return .success(markuped)
}


/*
    build_string allocates the output string and then
    calls do_markup to do the heavy lifting.
*/
func build_string(_ input:String, _ args:[Any], _ kwargs:[String:Any],
                  _ recursion_depth:int, _ auto_number: AutoNumber) -> FormatResult
{
    /* check the recursion level */
    if (recursion_depth <= 0) {
        return .failure(.ValueError("Max string recursion exceeded"))
    }
    return do_markup(input, args, kwargs, recursion_depth, auto_number)
}

/************************************************************************/
/*********** main routine ***********************************************/
/************************************************************************/

/* this is the main entry point */
func do_string_format(_ self:String, _ args:[Any], _ kwargs:[String:Any]) -> String
{

    /* PEP 3101 says only 2 levels, so that
       "{0:{1}}".format('abc', 's')            # works
       "{0:{1:{2}}}".format('abc', 's', '')    # fails
    */
    let recursion_depth: int = 2

    let auto_number: AutoNumber = .init()
    switch build_string(self, args, kwargs, recursion_depth, auto_number) {
    case .success(let s):
        return s
    case .failure(let error):
        return error.localizedDescription
    }
}

/* Raises an exception about an unknown presentation type for this
 * type. */
extension Py_UCS4 {
    var isRegularASCII: Bool {
        let v = self.unicode.value
        return 32 < v && v < 128
    }
}
func unknown_presentation_type(_ presentation_type:Py_UCS4,
                               _ type_name:String) -> PyException
{
    /* %c might be out-of-range, hence the two cases. */
    if (presentation_type.isRegularASCII ){
        return .ValueError("Unknown format code '\(presentation_type)' for object of type '\(type_name)'")
    }
    let hex = String(format: "%x", presentation_type.unicode.value)
    return .ValueError("Unknown format code '\\x\(hex)' for object of type '\(type_name)'")
}

func invalid_thousands_separator_type(_ specifier:Character, _ presentation_type:Py_UCS4) -> PyException
{
    assert(specifier == "," || specifier == "_");
    if (presentation_type.isRegularASCII){
        return .ValueError("Cannot specify '\(specifier)' with '\(presentation_type)'.")
    }
    let hex = String(format:"%x",presentation_type.unicode.value)
    return .ValueError("Cannot specify '\(specifier)' with '\\x\(hex)'.")
}

func invalid_comma_and_underscore() -> PyException
{
    return .ValueError("Cannot specify both ',' and '_'.")
}

/*
    get_integer consumes 0 or more decimal digit characters from an
    input string, updates *result with the corresponding positive
    integer, and returns the number of digits consumed.

    returns -1 on error.
*/
func get_integer(_ str:String,
                 _ ppos:Py_ssize_t) -> Result<(int,int),PyException>
{
    var accumulator:Py_ssize_t = 0
    var numdigits:int = 0
    let end = str.count
    var ppos = ppos
    while ppos < end {
        let digitval = Py_UNICODE_TODECIMAL(str.at(ppos)!);
        if digitval < 0 {
            break;
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
        ppos++
        numdigits++
    }
    return .success((numdigits,accumulator)) // 文字の幅、文字の数値表現
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
    var fill_char:Py_UCS4 = " "
    var align:Py_UCS4
    var alternate:int = 0
    var sign:Py_UCS4 = "\0"
    var width:Py_ssize_t = -1
    var thousands_separators:LocaleType = .LT_NO_LOCALE
    var precision:Py_ssize_t = -1
    var type:Py_UCS4
}
extension InternalFormatSpec: CustomDebugStringConvertible {
    /* Occasionally useful for debugging. Should normally be commented out. */
    var debugDescription: String {
        return String(format:"internal format spec: fill_char \(fill_char))\n") +
        String(format:"internal format spec: align \(align)\n") +
        String(format:"internal format spec: alternate %d\n", alternate) +
        String(format:"internal format spec: sign \(sign)\n") +
        String(format:"internal format spec: width %zd\n", width) +
        String(format:"internal format spec: thousands_separators \(thousands_separators)\n") +
        String(format:"internal format spec: precision %zd\n", precision) +
        String(format:"internal format spec: type \(type)\n")
    }
}


/*
  ptr points to the start of the format_spec, end points just past its end.
  fills in format with the parsed information.
  returns 1 on success, 0 on failure.
  if failure, sets the exception
*/
func parse_internal_render_format_spec(_ format_spec:String,
                                       _ default_format_spec:InternalFormatSpec) -> Result<InternalFormatSpec, PyException>
{
    var format:InternalFormatSpec = .init(align: " ", type: " ")

    var pos = 0
    let end = format_spec.count

    var consumed:Py_ssize_t
    var align_specified:Bool = false
    var fill_char_specified:Bool = false

    /* If the second char is an alignment token,
       then parse the fill char */
    if let align = format_spec.at(pos+1),is_alignment_token(align).asBool {
        // 現在の対象から二文字先にアラインメント指定があればアラインメントの指定に加えて、
        // パディング文字の指定もあることがわかる
        format.align = align
        format.fill_char = format_spec.at(pos)!
        fill_char_specified = true
        align_specified = true
        pos += 2;
    }
    else if let align = format_spec.at(pos), is_alignment_token(align).asBool {
        format.align = align
        align_specified = true
        ++pos;
    }

    /* Parse the various sign options */
    if let element = format_spec.at(pos), is_sign_element(element).asBool {
        format.sign = element
        ++pos;
    }

    /* If the next character is #, we're in alternate mode.  This only
       applies to integers. */
    if let c = format_spec.at(pos), c == "#" {
        format.alternate = 1;
        ++pos;
    }

    /* The special case for 0-padding (backwards compat) */
    if let c = format_spec.at(pos), c == "0", !fill_char_specified {
        format.fill_char = "0"
        if (!align_specified) {
            format.align = "="
        }
        ++pos;
    }

    switch get_integer(format_spec, pos) {
    case .success(let t):
        (consumed,format.width) = t
    case .failure(let error):
        /* Overflow error. Exception already set. */
        return .failure(error)
    }

    /* If consumed is 0, we didn't consume any characters for the
       width. In that case, reset the width to -1, because
       get_integer() will have set it to zero. -1 is how we record
       that the width wasn't specified. */
    if (consumed == 0){
        format.width = -1;
    }

    /* Comma signifies add thousands separators */
    if let c = format_spec.at(pos), c == "," {
        format.thousands_separators = .LT_DEFAULT_LOCALE;
        ++pos;
    }
    /* Underscore signifies add thousands separators */
    if let c = format_spec.at(pos), c == "_" {
        if (format.thousands_separators != .LT_NO_LOCALE) {
            return .failure(invalid_comma_and_underscore())
        }
        format.thousands_separators = .LT_UNDERSCORE_LOCALE;
        ++pos;
    }
    if let c = format_spec.at(pos),c == "," {
        return .failure(invalid_comma_and_underscore())
    }

    /* Parse field precision */
    if let c = format_spec.at(pos), c == "." {
        ++pos;

        switch get_integer(format_spec, pos) {
        case .success(let t):
            (consumed, format.precision) = t
        case .failure(let error):
            /* Overflow error. Exception already set. */
            return .failure(error)
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
        format.type = format_spec.at(pos)!
        ++pos;
    }

    /* Do as much validating as we can, just by looking at the format
       specifier.  Do not take into account what type of formatting
       we're doing (int, float, string). */

    if (format.thousands_separators != .LT_NO_LOCALE) {
        switch (format.type) {
        case "d", "e", "f", "g", "E", "G", "%", "F", "\0":
            /* These are allowed. See PEP 378.*/
            break;
        case "b", "o", "x", "X":
            /* Underscores are allowed in bin/oct/hex. See PEP 515. */
            if (format.thousands_separators == .LT_UNDERSCORE_LOCALE) {
                /* Every four digits, not every three, in bin/oct/hex. */
                format.thousands_separators = .LT_UNDER_FOUR_LOCALE;
                break;
            }
            fallthrough
        default:
            return .failure(invalid_thousands_separator_type(format.thousands_separators.rawValue, format.type))
        }
    }

    return .success(format)
}

/* Calculate the padding needed. */
func calc_padding(Py_ssize_t nchars, Py_ssize_t width, Py_UCS4 align,
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
    else if (align == "<" || align == "=")
        {*n_lpadding = 0}
    else {
        /* We should never have an unspecified alignment. */
        Py_UNREACHABLE();
    }

    *n_rpadding = *n_total - nchars - *n_lpadding;
}
let Py_UNREACHABLE = "Py_FatalError(\"Unreachable C code path reached\")"
/* Do the padding, and return a pointer to where the caller-supplied
   content goes. */
func fill_padding(_ value:String,
                  _ align:Character,
                  _ fill_char:Py_UCS4,
                  _ width:Py_ssize_t) -> String
{
    switch align {
    case ">":
        return value.rjust(width, fillchar: fill_char)
    case "^":
        return value.center(width, fillchar: fill_char)
    case "<", "=":
        return value.ljust(width, fillchar: fill_char)
    default:
        return Py_UNREACHABLE
    }
}

/************************************************************************/
/*********** common routines for numeric formatting *********************/
/************************************************************************/

/* Locale info needed for formatting integers and the part of floats
   before and including the decimal. Note that locales only support
   8-bit chars, not unicode. */
struct LocaleInfo {
    var decimal_point: String = ""
    var thousands_sep: String = ""
    var grouping: [Int8] = []
}
/* _PyUnicode_InsertThousandsGrouping() helper functions */

struct GroupGenerator {
    let grouping:[Int8]
    var previous:Int = .max
    var i:Py_ssize_t = 0 /* Where we're currently pointing in grouping. */
    let max:Int
    init(_ grouping:[Int8]) {
        self.grouping = grouping
        max = Int(CHAR_MAX)
    }
    mutating func next() -> Int {
        /* Note that we don't really do much error checking here. If a
           grouping string contains just CHAR_MAX, for example, then just
           terminate the generator. That shouldn't happen, but at least we
           fail gracefully. */
        if grouping.count > i {
            let ch = Int(self.grouping[self.i])
            switch ch {
            case 0:
                return self.previous;
            case max:
                /* Stop the generator. */
                return 0;
            default:
                self.previous = ch;
                self.i++;
                return ch;
            }
        }
        return previous
    }
}

/* describes the layout for an integer, see the comment in
   calc_number_widths() for details */
struct NumberFieldWidths {
    var need_prefix:Bool
    var sign: Character?
    var need_sign: Bool      /* number of digits needed for sign (0/1) */
    var n_remainder: Py_ssize_t /* Digits in decimal and/or exponent part,
                               excluding the decimal itself, if
                               present. */
    var fill_char:Character = " "
}
/* PyOS_double_to_string's "flags" parameter can be set to 0 or more of: */
enum Py_DTSF:Int{
    case SIGN =  0x01 /* always add the sign */
    case ADD_DOT_0 = 0x02 /* if the result is an integer add ".0" */
    case ALT = 0x04 /* "alternate" formatting. it's format_codespecific */
}

/* PyOS_double_to_string's "type", if non-NULL, will be set to one of: */
enum Py_DTST:Int{
    case FINITE = 0
    case INFINITE = 1
    case NAN = 2
}

func PyOS_double_to_string(_ val:double,
                           _ format_code:Character,
                           _ precision:int,
                           _ flags:int,
                           _ type:int) -> (String, Int)
{
    var format:String
    var buf:String
    var t:Int
    var upper:Bool = false
    // to mutable
    var format_code:Character = format_code
    var precision:int = precision

    /* Validate format_code, and map upper and lower case */
    switch (format_code) {
    case "e",          /* exponent */
         "f",          /* fixed */
         "g":          /* general */
        break;
    case "E":
        upper = true
        format_code = "e";
        break;
    case "F":
        upper = true
        format_code = "f";
        break;
    case "G":
        upper = true
        format_code = "g";
        break;
    case "r":          /* repr format */
        /* Supplied precision is unused, must be 0. */
        if (precision != 0) {
            fatalError("PyErr_BadInternalCall()")
        }
        /* The repr() precision (17 significant decimal digits) is the
           minimal number that is guaranteed to have enough precision
           so that if the number is read back in the exact same binary
           value is recreated.  This is true for IEEE floating point
           by design, and also happens to work for all other modern
           hardware. */
        precision = 17;
        format_code = "g";
        break;
    default:
        fatalError("PyErr_BadInternalCall()")
    }

    /* Here's a quick-and-dirty calculation to figure out how big a buffer
       we need.  In general, for a finite float we need:

         1 byte for each digit of the decimal significand, and

         1 for a possible sign
         1 for a possible decimal point
         2 for a possible [eE][+-]
         1 for each digit of the exponent;  if we allow 19 digits
           total then we're safe up to exponents of 2**63.
         1 for the trailing nul byte

       This gives a total of 24 + the number of digits in the significand,
       and the number of digits in the significand is:

         for 'g' format: at most precision, except possibly
           when precision == 0, when it's 1.
         for 'e' format: precision+1
         for 'f' format: precision digits after the point, at least 1
           before.  To figure out how many digits appear before the point
           we have to examine the size of the number.  If fabs(val) < 1.0
           then there will be only one digit before the point.  If
           fabs(val) >= 1.0, then there are at most

         1+floor(log10(ceiling(fabs(val))))

           digits before the point (where the 'ceiling' allows for the
           possibility that the rounding rounds the integer part of val
           up).  A safe upper bound for the above quantity is
           1+floor(exp/3), where exp is the unique integer such that 0.5
           <= fabs(val)/2**exp < 1.0.  This exp can be obtained from
           frexp.

       So we allow room for precision+1 digits for all formats, plus an
       extra floor(exp/3) digits for 'f' format.

    */

    /* Handle nan and inf. */
    if val.isNaN {
        buf = "nan"
        t = Py_DTST.NAN.rawValue
    } else if val.isInfinite {
        if (copysign(1.0, val) == 1.0){
            buf = "inf"
        }
        else{
            buf = "-inf"
        }
        t = Py_DTST.INFINITE.rawValue
    } else {
        t = Py_DTST.FINITE.rawValue
        if (flags & Py_DTSF.ADD_DOT_0.rawValue).asBool {
            format_code = "Z";
        }
        format = String(format: "%%\((flags & Py_DTSF.ALT.rawValue).asBool ? "#" : "").%i%c", precision, format_code.unicode.value)
        buf = String(format: format, val, precision)
    }

    /* Add sign when requested.  It's convenient (esp. when formatting
     complex numbers) to include a sign even for inf and nan. */
    if ((flags & Py_DTSF.SIGN.rawValue).asBool && buf[0] != "-") {
        buf = "+" + buf
    }
    if (upper) {
        /* Convert to upper case. */
        buf = buf.upper()
    }

    return (buf, t)
}

/**
 * InsertThousandsGrouping:
 * @writer: Unicode writer.
 * @n_buffer: Number of characters in @buffer.
 * @digits: Digits we're reading from. If count is non-NULL, this is unused.
 * @d_pos: Start of digits string.
 * @n_digits: The number of digits in the string, in which we want
 *            to put the grouping chars.
 * @min_width: The minimum width of the digits in the output string.
 *             Output will be zero-padded on the left to fill.
 * @grouping: see definition in localeconv().
 * @thousands_sep: see definition in localeconv().
 *
 * There are 2 modes: counting and filling. If @writer is NULL,
 *  we are in counting mode, else filling mode.
 * If counting, the required buffer size is returned.
 * If filling, we know the buffer will be large enough, so we don't
 *  need to pass in the buffer size.
 * Inserts thousand grouping characters (as defined by grouping and
 *  thousands_sep) into @writer.
 *
 * Return value: -1 on error, number of characters otherwise.
 **/

func _PyUnicode_InsertThousandsGrouping(
    _ digits:String,
    _ grouping:[Int8],
    _ thousands_sep:String) -> String
{
    if thousands_sep.isEmpty || grouping.isEmpty {
        return digits
    }
    var groupgen: GroupGenerator = .init(grouping)

    /* if digits are not grouped, thousands separator
       should be an empty string */
    var buf = ""
    var len = groupgen.next()
    var i = 0
    for ch in digits.reversed() {
        i += 1
        if len != 0 && len == i {
            buf.append(thousands_sep)
            i = 0
            len = groupgen.next()
        }
        buf.append(ch)
    }
    return buf
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
func parse_number(_ s:String) -> (Int, Bool)
{
    let i = s.find(".")
    if i != -1 {
        return (n_remainder: (s.count - i) - 1, has_decimal: true)
    }
    return (n_remainder: 0, has_decimal: false)
}

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
func calc_number_widths(_ n_prefix: Py_ssize_t,
                    _ sign_char:Py_UCS4,
                    _ number:PyObject,
                    _ n_start:Py_ssize_t,
                    _ n_end:Py_ssize_t,
                    _ n_remainder:Py_ssize_t,
                    _ has_decimal:Bool,
                    _ locale:LocaleInfo,
                    _ format:InternalFormatSpec
                    ) -> NumberFieldWidths {
    var spec:NumberFieldWidths = .init(need_prefix: false, sign: "\0", need_sign: false, n_remainder: 0)

    /* compute the various parts we're going to write */
    switch (format.sign) {
    case "+":
        /* always put a + or - */
        spec.sign = (sign_char == "-" ? "-" : "+");
        break;
    case " ":
        spec.sign = (sign_char == "-" ? "-" : " ");
        break;
    default:
        /* Not specified, or the default (-) */
        if (sign_char == "-") {
            spec.sign = "-";
        }
    }

    return spec
}

/* Fill in the digit parts of a number's string representation,
   as determined in calc_number_widths().
   Return -1 on error, or 0 on success. */
func fill_number(_ spec:NumberFieldWidths,
                 _ digits:String,
                 _ format:InternalFormatSpec,
                 _ prefix:String,
                 _ fill_char:Py_UCS4,
                 _ locale:LocaleInfo,
                 _ toupper:Bool) -> FormatResult
{
    var (digits, dot, remine) = digits.partition(locale.decimal_point)
    digits = _PyUnicode_InsertThousandsGrouping(digits, locale.grouping, locale.thousands_sep)
    /* Used to keep track of digits, decimal, and remainder. */
    digits = prefix.upper() + digits + dot + remine

    /* Only for type 'c' special case, it has no digits. */
    if (toupper) {
        digits = digits.upper()
    }
    return .success(digits)
}

func number_just(_ digits:String,_ format:InternalFormatSpec, _ spec:NumberFieldWidths, _ locale:LocaleInfo) -> String {
    /* Some padding is needed. Determine if it's left, space, or right. */
    switch (format.align) {
    case "<":
        return digits.ljust(format.width, fillchar: spec.fill_char)
    case "^":
        return digits.center(format.width, fillchar: spec.fill_char)
    case "=":
        return digits.rjust(format.width, fillchar: "0")
    case ">":
        return digits.rjust(format.width, fillchar: spec.fill_char)
    default:
        /* Shouldn't get here, but treat it as '>' */
        return Py_UNREACHABLE
    }
}

/* Find the decimal point character(s?), thousands_separator(s?), and
   grouping description, either for the current locale if type is
   LT_CURRENT_LOCALE, a hard-coded locale if LT_DEFAULT_LOCALE or
   LT_UNDERSCORE_LOCALE/LT_UNDER_FOUR_LOCALE, or none if LT_NO_LOCALE. */
func get_locale_info(_ type:LocaleType) -> LocaleInfo
{
    var locale_info:LocaleInfo = .init()
    switch (type) {
    case .LT_CURRENT_LOCALE:
        (locale_info.decimal_point,
         locale_info.thousands_sep,
         locale_info.grouping) = getLocalInfo()
    case .LT_DEFAULT_LOCALE,
         .LT_UNDERSCORE_LOCALE,
         .LT_UNDER_FOUR_LOCALE:
        locale_info.decimal_point = "."
        locale_info.thousands_sep = type == .LT_DEFAULT_LOCALE ? "," : "_"
        if (type != .LT_UNDER_FOUR_LOCALE){
            locale_info.grouping = [3] /* Group every 3 characters.  The
                                         (implicit) trailing 0 means repeat
                                         infinitely. */
        } else {
            locale_info.grouping = [4] /* Bin/oct/hex group every four. */
        }
        break;
    case .LT_NO_LOCALE:
        locale_info.decimal_point = "."
        locale_info.thousands_sep = ""
        let no_grouping = [Int8(CHAR_MAX)] // char_max?
        locale_info.grouping = no_grouping;
        break;
    }
    return locale_info
}

func getLocalInfo() -> (String,String,[Int8]) {
    // TODO:remove force unwrap
    // TODO: \0 to ""(empty String)
    if let local = localeconv() {
        let lc = local.pointee
        if let d = lc.decimal_point, let dp = UnicodeScalar(UInt16(d.pointee)) {
            let decimal_point = String(dp)
            if let t = lc.thousands_sep, let ts = UnicodeScalar(UInt32(t.pointee)) {
                let thousands_sep = String(ts)
                var grouping:[Int8] = []
                if let g = lc.grouping {
                    var i = 0
                    while i != CHAR_MAX {
                        let p = g.advanced(by: i)
                        grouping.append(p.pointee)
                        i += 1
                    }
                }
                return (decimal_point, thousands_sep, grouping)
            }
            return (decimal_point, ",", [])
        }
    }
    return (".",",",[])
}


protocol PSFormattable {
    var str: String { get }
    var repr: String { get }
    var ascii: String { get }
    var defaultInternalFormatSpec: InternalFormatSpec { get }
    func convertField(_ conversion: Character) -> String
    func objectFormat(_ format: InternalFormatSpec) -> FormatResult
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

extension String: PSFormattable {
    var defaultInternalFormatSpec: InternalFormatSpec {
        InternalFormatSpec(align: "s", type: "<")
    }
/************************************************************************/
/*********** string formatting ******************************************/
/************************************************************************/
    func objectFormat(_ format: InternalFormatSpec) -> FormatResult {
        let value = self

        var len = value.count

        /* sign is not allowed on strings */
        if (format.sign != "\0") {
            return .failure(.ValueError("Sign not allowed in string format specifier"))
        }

        /* alternate is not allowed on strings */
        if (format.alternate.asBool) {
            return .failure(.ValueError("Alternate form (#) not allowed in string format specifier"))
        }

        /* '=' alignment not allowed on strings */
        if (format.align == "=") {
            return .failure(.ValueError("'=' alignment not allowed in string format specifier"))
        }

        if ((format.width == -1 || format.width <= len)
            && (format.precision == -1 || format.precision >= len)) {
            /* Fast path */
            return .success(value)
        }

        /* if precision is specified, output no more that format.precision
           characters */
        if (format.precision >= 0 && len >= format.precision) {
            len = format.precision;
        }

        /* Write into that space. First the padding. */
        return .success(fill_padding(value, format.align, format.fill_char, format.width))
    }
}

@inlinable
func bin<Subject>(_ i:Subject, _ alternate:Bool=true) -> String where Subject: BinaryInteger {
    return (alternate ? "0b" : "") + String(i, radix: 2, uppercase: false)
}
@inlinable
func oct<Subject>(_ i:Subject, _ alternate:Bool=true) -> String where Subject: BinaryInteger {
    return (alternate ? "0o" : "") + String(i, radix: 8, uppercase: false)
}
@inlinable
func hex<Subject>(_ i:Subject, _ alternate:Bool=true) -> String where Subject: BinaryInteger {
    return (alternate ? "0x" : "") + String(i, radix: 16, uppercase: false)
}
let alternates = [
    2: "0b",
    8: "0o",
    10: "",
    16: "0x",
]
func longFormat<Subject>(_ i:Subject, radix:Int, alternate:Bool=true) -> String where Subject: BinaryInteger {
    return (alternate ? alternates[radix, default: ""] : "") + String(i, radix: radix, uppercase: false)
}

protocol PSFormattableInteger: PSFormattable {
    var formatableInteger: Int { get }
}
extension PSFormattableInteger {
    var defaultInternalFormatSpec: InternalFormatSpec {
        InternalFormatSpec(align: "d", type: ">")
    }
/************************************************************************/
/*********** long formatting ********************************************/
/************************************************************************/

    func objectFormat(_ format: InternalFormatSpec) -> FormatResult {
        let value = self.formatableInteger
        var tmp: String = ""
        var inumeric_chars:Py_ssize_t
        var sign_char:Py_UCS4 = "\0";
        var n_digits:Py_ssize_t       /* count of digits need from the computed string */
        var n_remainder:Py_ssize_t = 0 /* Used only for 'c' formatting, which produces non-digits */
        var n_prefix: Py_ssize_t = 0;   /* Count of prefix chars, (e.g., '0x') */
        var prefix: Py_ssize_t = 0;
        var x:long

        /* no precision allowed on integers */
        if (format.precision != -1) {
            return .failure(.ValueError("Precision not allowed in integer format specifier"))
        }

        /* special case for character formatting */
        if (format.type == "c") {
            /* error to specify a sign */
            if (format.sign != "\0") {
                return .failure(.ValueError("Sign not allowed with integer format specifier 'c'"))
            }
            /* error to request alternate format */
            if (format.alternate.asBool) {
                return .failure(.ValueError("Alternate form (#) not allowed with integer format specifier 'c'"))
            }

            /* taken from unicodeobject.c formatchar() */
            /* Integer input truncated to a character */
            x = value
            if (x < 0 || x > 0x10ffff) {
                return .failure(.OverflowError("%c arg not in range(0x110000)"))
            }
            tmp = String(Py_UCS4(x))
            inumeric_chars = 0;
            n_digits = 1;

            /* As a sort-of hack, we tell calc_number_widths that we only
               have "remainder" characters. calc_number_widths thinks
               these are characters that don't get formatted, only copied
               into the output string. We do this for 'c' formatting,
               because the characters are likely to be non-digits. */
            n_remainder = 1;
        } else {
            let isDefault = (
                format.sign != "+" &&
                format.sign != " " &&
                format.width == -1 &&
                format.type != "X" &&
                format.type != "n" &&
                format.thousands_separators == .LT_NO_LOCALE)
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

            if isDefault {
                /* Fast path */
                return .success(longFormat(value, radix: base, alternate: format.alternate.asBool))
            }

            /* The number of prefix chars is the same as the leading
               chars to skip */
            if (format.alternate.asBool){
                n_prefix = leading_chars_to_skip
            }

            /* Do the hard part, converting to a string in a given base */
            tmp = String(value, radix: base, uppercase: false)

            inumeric_chars = 0;
            n_digits = tmp.count

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
        /* Locale settings, either from the actual locale or
           from a hard-code pseudo-locale */
        let locale:LocaleInfo = get_locale_info(format.type == "n" ? .LT_CURRENT_LOCALE :
            format.thousands_separators)
        /* Calculate how much memory we'll need. */
        let spec: NumberFieldWidths =
        calc_number_widths(n_prefix, sign_char, tmp, inumeric_chars,
                                     inumeric_chars + n_digits, n_remainder, false,
                                     locale, format);

        /* Populate the memory. */
        return fill_number(spec, tmp, format, "prefix(0x,etc)", format.fill_char, locale, format.type == "X")
    }
}

protocol PSFormattableFloatingPoint: PSFormattable {
    var formatableFloatingPoint: Double { get }
}
extension PSFormattableFloatingPoint {
    var defaultInternalFormatSpec: InternalFormatSpec {
        InternalFormatSpec(align: "\0", type: ">")
    }
/************************************************************************/
/*********** float formatting *******************************************/
/************************************************************************/
    func objectFormat(_ format: InternalFormatSpec) -> FormatResult {
        let value = self.formatableFloatingPoint
        var buf:String       /* buffer returned from PyOS_double_to_string */
        var n_digits:Py_ssize_t
        var n_remainder:Py_ssize_t
        var has_decimal:Bool

        var precision:Int
        var default_precision = 6;
        var type:Py_UCS4 = format.type;
        var add_pct:Bool = false
        var index:Py_ssize_t
        var spec:NumberFieldWidths
        var flags:int = 0;
        var sign_char:Py_UCS4 = "\0"
        var float_type:int /* Used to see if we have a nan, inf, or regular float. */ = .init()
        var unicode_tmp:String

        if (format.precision > INT_MAX) {
            return .failure(.ValueError("precision too big"))
        }
        precision = format.precision;

        if (format.alternate.asBool) {
            flags |= Py_DTSF.ALT.rawValue
        }

        if (type == "\0") {
            /* Omitted type specifier.  Behaves in the same way as repr(x)
               and str(x) if no precision is given, else like 'g', but with
               at least one digit after the decimal point. */
            flags |= Py_DTSF.ADD_DOT_0.rawValue
            type = "r";
            default_precision = 0;
        }

        if (type == "n"){
            /* 'n' is the same as 'g', except for the locale used to
               format the result. We take care of that later. */
        type = "g";
        }
        var val = value
        if (type == "%") {
            type = "f";
            val *= 100;
            add_pct = true
        }

        if (precision < 0){
            precision = default_precision;
        }
        else if (type == "r")
        {type = "g";}

        /* Cast "type", because if we're in unicode we need to pass an
           8-bit char. This is safe, because we've restricted what "type"
           can be. */
        (buf,float_type) = PyOS_double_to_string(val, type, precision, flags, float_type)

        n_digits = strlen(buf);

        if (add_pct) {
            /* We know that buf has a trailing zero (since we just called
               strlen() on it), and we don't use that fact any more. So we
               can just write over the trailing zero. */
            buf += "%"
            n_digits += 1;
        }

        if (format.sign != "+" && format.sign != " "
            && format.width == -1
            && format.type != "n"
            && format.thousands_separators == .LT_NO_LOCALE)
        {
            /* Fast path */
            return .success(buf)
        }

        /* Since there is no unicode version of PyOS_double_to_string,
           just use the 8 bit version and then convert to unicode. */
        unicode_tmp = buf

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
        (n_remainder, has_decimal) = parse_number(unicode_tmp)

        /* Determine the grouping, separator, and decimal point, if any. */
        /* Locale settings, either from the actual locale or
           from a hard-code pseudo-locale */
        let locale:LocaleInfo = get_locale_info(format.type == "n" ? .LT_CURRENT_LOCALE : format.thousands_separators)

        /* Calculate how much memory we'll need. */
        spec = calc_number_widths( 0, sign_char, unicode_tmp, index,
                                     index + n_digits, n_remainder, has_decimal,
                                     locale, format);

        /* Populate the memory. */
        return fill_number(spec, unicode_tmp, format,"prefix",format.fill_char, locale, false)
    }
}
protocol PSFormattableComplex: PSFormattable {
    var formatableReal: Double { get }
    var formatableImag: Double { get }
}
extension PSFormattableComplex {
    var defaultInternalFormatSpec: InternalFormatSpec {
        InternalFormatSpec(align: "\0", type: ">")
    }
/************************************************************************/
/*********** complex formatting *****************************************/
/************************************************************************/
    func objectFormat(_ format: InternalFormatSpec) -> FormatResult {
        let re = self.formatableReal
        let im = self.formatableImag

    char *re_buf = NULL;       /* buffer returned from PyOS_double_to_string */
    char *im_buf = NULL;       /* buffer returned from PyOS_double_to_string */

    var tmp_format:InternalFormatSpec = format
    Py_ssize_t n_re_digits;
    Py_ssize_t n_im_digits;
    Py_ssize_t n_re_remainder;
    Py_ssize_t n_im_remainder;
    Py_ssize_t n_re_total;
    Py_ssize_t n_im_total;
    int re_has_decimal;
    int im_has_decimal;
    int precision, default_precision = 6;
        var type:Py_UCS4 = format.type;
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

    re = PyComplex_RealAsDouble(value);
    if (re == -1.0 && PyErr_Occurred()){
        goto done;
    }
    im = PyComplex_ImagAsDouble(value);
    if (im == -1.0 && PyErr_Occurred()){
        goto done;
    }

        if (format.alternate){
        flags |= Py_DTSF.ALT.rawValue
    }
    if (type == "\0") {
        /* Omitted type specifier. Should be like str(self). */
        type = "r";
        default_precision = 0;
        if (re == 0.0 && copysign(1.0, re) == 1.0){
            skip_re = 1;
        } else {
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
    }    else if (type == "r"){
        type = "g";
    }
    /* Cast "type", because if we're in unicode we need to pass an
       8-bit char. This is safe, because we've restricted what "type"
       can be. */
    re_buf = PyOS_double_to_string(re, type, precision, flags,
                                   &re_float_type);
    if (re_buf == NULL){
        goto done;}
    im_buf = PyOS_double_to_string(im, type, precision, flags,
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
    (n_re_remainder, re_has_decimal) = parse_number(re_unicode_tmp)
    (n_im_remainder, im_has_decimal) = parse_number(im_unicode_tmp)

    /* Determine the grouping, separator, and decimal point, if any. */
        locale = get_locale_info(format.type == "n" ? .LT_CURRENT_LOCALE : format.thousands_separators)

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
        tmp_format.sign = "+"
    }
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
    return result;
}
}

/************************************************************************/
/*********** built in formatters ****************************************/
/************************************************************************/
func format_obj(_ obj:PyObject) -> FormatResult
{
    return .success(obj as? String ?? "nil?")
}

func _PyUnicode_FormatAdvancedWriter(
        _ obj:PSFormattable,
        _ format_spec:String) -> FormatResult
{
    var format:InternalFormatSpec

    /* check for the special case of zero length format spec, make
       it equivalent to str(obj) */
    if (format_spec.isEmpty) {
        return .success(obj as! String)
    }

    /* parse the format_spec */
    switch parse_internal_render_format_spec(format_spec,obj.defaultInternalFormatSpec) {
    case .success(let f):
        format = f
        break
    case .failure(let error):
        return .failure(error)
    }

    /* type conversion? */
    switch (format.type) {
    case "s":
        /* no type conversion needed, already a string.  do the formatting */
        return obj.objectFormat(format)
    default:
        /* unknown */
        return .failure(unknown_presentation_type(format.type, typeName(obj)))
    }
}

func _PyLong_FormatAdvancedWriter(
    _ obj:PSFormattableInteger,
    _ format_spec:String) -> FormatResult
{
    var format: InternalFormatSpec

    /* check for the special case of zero length format spec, make
       it equivalent to str(obj) */
    if format_spec.isEmpty {
        return .success(String(obj.formatableInteger))
    }

    /* parse the format_spec */
    switch parse_internal_render_format_spec(format_spec, obj.defaultInternalFormatSpec) {
    case .success(let f):
        format = f
        break
    case .failure(let error):
        return .failure(error)
    }

    /* type conversion? */
    switch (format.type) {
    case "b", "c", "d", "o", "x", "X", "n":
        /* no type conversion needed, already an int.  do the formatting */
        return obj.objectFormat(format)

    case "e", "E", "f", "F", "g", "G", "%":
        /* convert to float */
        return _PyFloat_FormatAdvancedWriter(Double(obj.formatableInteger),format_spec)

    default:
        /* unknown */
        return .failure(unknown_presentation_type(format.type, typeName(obj)))
    }
}

func _PyFloat_FormatAdvancedWriter(
    _ obj:PSFormattableFloatingPoint,
    _ format_spec:String) -> FormatResult
{
    var format: InternalFormatSpec

    /* check for the special case of zero length format spec, make
       it equivalent to str(obj) */
    if format_spec.isEmpty {
        return format_obj(obj);
    }
    /* parse the format_spec */
    switch parse_internal_render_format_spec(format_spec, obj.defaultInternalFormatSpec) {
    case .success(let f):
        format = f
        break
    case .failure(let error):
        return .failure(error)
    }

    /* type conversion? */
    switch (format.type) {
    case "\0", /* No format code: like 'g', but with at least one decimal. */
    "e", "E", "f", "F", "g", "G", "n", "%":
        /* no conversion, already a float.  do the formatting */
        return obj.objectFormat(format)

    default:
        /* unknown */
        return .failure(unknown_presentation_type(format.type,typeName(obj)))
    }
}

func _PyComplex_FormatAdvancedWriter(
    _ obj:PyObject,
    _ format_spec:String) -> FormatResult
{
    var format:InternalFormatSpec

    /* check for the special case of zero length format spec, make
       it equivalent to str(obj) */
    if format_spec.isEmpty {
        return format_obj(obj)
    }

    /* parse the format_spec */
    switch parse_internal_render_format_spec(format_spec, start, end, "\0", ">") {
    case .success(format):
        break
    case .failture(let error):
        return .failture(error)
    }

    /* type conversion? */
    switch (format.type) {
    case "\0", /* No format code: like 'g', but with at least one decimal. */
    "e", "E", "f", "F","g", "G", "n":
        /* no conversion, already a complex.  do the formatting */
        return (obj as! PSFormattableComplex).objectFormat(format)

    default:
        /* unknown */
        return .failure(unknown_presentation_type(format.type, typeName(obj)))
    }
}

func typeName(_ object:Any) -> String {
    return String(describing: type(of: object.self))
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
    public func format(_ args:Any..., kwargs:[String:Any]=[:]) -> String {
        return do_string_format(self, args, kwargs)
    }
    public func format_map(_ mapping:[String:Any]) -> String {
        return self.format([], kwargs: mapping)
    }
}

extension Double: PSFormattableFloatingPoint {
    var formatableFloatingPoint: Double { self }
}
extension Float: PSFormattableFloatingPoint {
    var formatableFloatingPoint: Double { Double(self) }
}
extension Float80: PSFormattableFloatingPoint {
    var formatableFloatingPoint: Double { Double(self) }
}
extension Int: PSFormattableInteger {
    var formatableInteger: Int { self }
}
extension Int8: PSFormattableInteger {
    var formatableInteger: Int { Int(self) }
}
extension Int16: PSFormattableInteger {
    var formatableInteger: Int { Int(self) }
}
extension Int32: PSFormattableInteger {
    var formatableInteger: Int { Int(self) }
}
extension Int64: PSFormattableInteger {
    var formatableInteger: Int { Int(self) }
}
extension UInt8: PSFormattableInteger {
    var formatableInteger: Int { Int(self) }
}
extension UInt16: PSFormattableInteger {
    var formatableInteger: Int { Int(self) }
}
extension UInt32: PSFormattableInteger {
    var formatableInteger: Int { Int(self) }
}
extension UInt64: PSFormattableInteger {
    var formatableInteger: Int { Int(self) }
}
