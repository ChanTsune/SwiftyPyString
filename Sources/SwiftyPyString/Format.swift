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

enum AutoNumberState:Int {
    case ANS_INIT = 0
    case ANS_AUTO = 1
    case ANS_MANUAL = 2
}   /* Keep track if we're auto-numbering fields */

/* Keeps track of our auto-numbering state, and which number field we're on */
class AutoNumber {
    var an_state:AutoNumberState = .ANS_INIT
    var an_field_number:Int = 0
    
    func increment() -> Int {
        self.an_field_number += 1
        return self.an_field_number
    }
}


/************************************************************************/
/**************************  Utility  functions  ************************/
/************************************************************************/
func autonumber_state_error(_ state:AutoNumberState, _ field_name_is_empty:Bool) -> Result<Void,PyException>
{
    if (state == .ANS_MANUAL) {
        if field_name_is_empty {
            return .failure(.ValueError("cannot switch from manual field specification to automatic field numbering"))
        }
    }
    else {
        if !field_name_is_empty {
            return .failure(.ValueError("cannot switch from automatic field numbering to manual field specification"))
        }
    }
    return .success(Void())
}

func UNICODE_TODECIMAL(_ c:Character) -> Int {
    return c.isdecimal() ? Int(c.properties.numericValue!) : -1
}

/************************************************************************/
/***********  Format string parsing -- integers and identifiers *********/
/************************************************************************/

func get_integer(_ str:String) -> Result<Int,PyException>
{
    /* empty string is an error */
    if str.isEmpty {
        return .success(-1) // error on top level
    }
    var accumulator:Int = 0
    var digitval:Int = 0

    for c in str {
        digitval = UNICODE_TODECIMAL(c)
        if digitval < 0 {
            return .success(-1) // error on top level
        }
        /*
         Detect possible overflow before it happens:
         
         accumulator * 10 + digitval > PY_SSIZE_T_MAX if and only if
         accumulator > (PY_SSIZE_T_MAX - digitval) / 10.
         */
        if (accumulator > (Int.max - digitval) / 10) {
            return .failure(.ValueError("Too many decimal digits in format string"))
        }
        accumulator = accumulator * 10 + digitval

    }
    return .success(accumulator)
}

/************************************************************************/
/******** Functions to get field objects and specification strings ******/
/************************************************************************/

/* do the equivalent of obj.name */
func getattr(_ obj:Any, name:String) -> Any?
{
    let mirror = Mirror(reflecting: obj)
    for i in mirror.children.makeIterator(){
        if let label = i.label, label == name{
            return i.value
        }
    }
    return nil;
}

/* do the equivalent of obj[idx], where obj is a sequence */
func getitem_sequence(_ obj:Any, idx:Int) -> Any?
{
    let sequence = obj as! [Any]
    return sequence[idx]
}

/* do the equivalent of obj[idx], where obj is not a sequence */
func getitem_idx(obj:Any, idx:Int)-> Any?
{
    let object = obj as! [Int:Any]
    return object[idx]
}

/* do the equivalent of obj[name] */
func getitem_str(obj:Any, name:String) -> Any?
{
    let object = obj as! [String:Any]
    return object[name]
}


var PyObject_GetItem = getitem_str
var PySequence_GetItem = getitem_sequence



class FieldName : Sequence {
    typealias Iterator = FieldNameIterator
    /* the entire string we're parsing.  we assume that someone else
     is managing its lifetime, and that it will exist for the
     lifetime of the iterator.  can be empty */
    var str:String
    
    /* index to where we are inside field_name */
    var index:Int
    
    var err:PyException? = nil
    
    init(_ s:String ,start:Int=0){
        self.str = s
        self.index = start
    }
    func makeIterator() -> FieldNameIterator {
        return Iterator(self)
    }
    func getNext() -> (Bool,Int,String)? {
        var is_attribute:Bool = false
        var name:String = ""
        var name_idx:Int = -1
        /* check at end of input */
        if (self.index >= self.str.count){
            return nil
        }
        let c = self.str[self.index]
        self.index += 1
        switch (c) {
        case ".":
            is_attribute = true
            
            var c:Character
            
            let start = self.index
            
            /* return everything until '.' or '[' */
            while (self.index < self.str.count) {
                c = self.str[self.index]
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
            name = self.str[start,self.index]
            
            name_idx = -1
            break;
        case "[":
            is_attribute = false
            
            var bracket_seen:Bool = false
            var c:Character
            
            let start = self.index
            
            /* return everything until ']' */
            while (self.index < self.str.count) {
                c = self.str[self.index]
                self.index += 1
                switch (c) {
                case "]":
                    bracket_seen = true;
                    break;
                default:
                    continue;
                }
                break;
            }
            /* make sure we ended with a ']' */
            if (!bracket_seen) {
                self.err = .ValueError("Missing ']' in format string")
                return nil
            }
            
            /* end of string is okay */
            /* don't include the ']' */
            name = self.str[start,self.index-1]
            switch get_integer(name) {
                case .success(let idx):
                    name_idx = idx
                    break;
                case .failure(let error):
                    self.err = error
                    return nil;
            }
            break;
        default:
            /* Invalid character follows ']' */
            self.err = .ValueError("Only '.' or '[' may follow ']' in format field specifier")
            return nil
        }
        
        /* empty string is an error */
        if name.isEmpty {
            self.err = .ValueError("Empty attribute in format string")
            return nil
        }
        
        return (is_attribute, name_idx, name)

    }

}

class FieldNameIterator : IteratorProtocol {
    typealias Element = (Bool,Int,String)
    private let fieldName:FieldName
    
    init(_ fieldName:FieldName){
        self.fieldName = fieldName
    }
    
    func next() -> (Bool, Int, String)? {
        return self.fieldName.getNext()
    }
}

/* input: field_name
 output: 'first' points to the part before the first '[' or '.'
 'first_idx' is -1 if 'first' is not an integer, otherwise
 it's the value of first converted to an integer
 'rest' is an iterator to return the rest
 */
func field_name_split(_ str:String, auto_number:AutoNumber) -> Result<(String,Int,FieldName),PyException>
{
    var c:Character
    var i:Int = 0
    let end = str.count
    
    /* find the part up until the first '.' or '[' */
    while (i < end) {
        c = str[i]
        i += 1
        switch (c) {
        case "[":
            fallthrough
        case ".":
            /* backup so that we this character is available to the
             "rest" iterator */
            i -= 1;
            break;
        default:
            continue;
        }
        break;
    }
    
    /* set up the return values */
    var first = str[nil,i]

    var rest = FieldName(str, start:i)

    /* see if "first" is an integer, in which case it's used as an index */
    var first_idx:Int
    switch get_integer(first) {
    case .success(let idx):
        if idx == -1 {
            return .failure(.Exception("Unknown error\(#function)\(#line)"))
        }
        first_idx = idx
        break;
    case .failure(let err):
        return .failure(err)
    }
    
    let field_name_is_empty = first.isEmpty
    
    /* If the field name is omitted or if we have a numeric index
     specified, then we're doing numeric indexing into args. */
    let using_numeric_index = field_name_is_empty || first_idx != -1
    
    /* We always get here exactly one time for each field we're
     processing. And we get here in field order (counting by left
     braces). So this is the perfect place to handle automatic field
     numbering if the field name is omitted. */
    
    /* Check if we need to do the auto-numbering. It's not needed if
     we're called from string.Format routines, because it's handled
     in that class by itself. */

    /* Initialize our auto numbering state if this is the first
     time we're either auto-numbering or manually numbering. */
    if auto_number.an_state == .ANS_INIT && using_numeric_index {
        auto_number.an_state = field_name_is_empty ? .ANS_AUTO : .ANS_MANUAL;
    }
    
    /* Make sure our state is consistent with what we're doing
     this time through. Only check if we're using a numeric
     index. */
    if using_numeric_index {
        switch autonumber_state_error(auto_number.an_state,
                                      field_name_is_empty){
        case .success:
            break;
        case .failure(let err):
            return .failure(err)
        }
    }
    /* Zero length field means we want to do auto-numbering of the
     fields. */
    if field_name_is_empty {
        first_idx = auto_number.an_field_number
        auto_number.an_field_number += 1
    }
    return .success((first,first_idx,rest))
}

/*
 get_field_object returns the object inside {}, before the
 format_spec.  It handles getindex and getattr lookups and consumes
 the entire input string.
 */
func get_field_object(_ field_name:String,args:[Any],kwargs:[String:Any],auto_number:AutoNumber) -> Result<Any?,PyException> {
    var obj:Any?
    var first:String = ""
    var index:Int = 0 // TODO: un initt
    var rest:FieldName
    
    switch field_name_split(field_name, auto_number: auto_number) {
    case .success(let (f,i,r)):
        first = f
        index = i
        rest = r
        break;
    case .failure(let err):
        return .failure(err)
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
        obj = PyObject_GetItem(kwargs, key);
        if obj == nil {
            return .success(nil)
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
        obj = PySequence_GetItem(args, index);
        if (obj == nil) {
            return .failure(.IndexError("Replacement index %zd out of range for positional args tuple \(index)"))
        }
    }
    /* iterate over the rest of the field_name */
    for (is_attribute,index,name) in rest {
        
        var tmp:Any?
        
        if is_attribute {
            /* getattr lookup "." */
            tmp = getattr(obj, name: name);
        } else {
            /* getitem lookup "[]" */
            if (index == -1){
                tmp = getitem_str(obj: obj, name: name);
            }
            else{
                if obj is Array<Any> {// []添字演算子アクセス可能なオブジェクトの場合
                    tmp = getitem_sequence(obj, idx: index);
                }
                else{
                    /* not a sequence */
                    tmp = getitem_idx(obj: obj, idx: index);
                }
            }
        }
        if (tmp == nil){
            return .success(nil)
        }
        obj = tmp
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

func PyObject_Format(_ obj:Any?,_ format_spec:String) -> String {
    if format_spec.isEmpty {
        return String(describing: obj)
    }
    return String(describing: obj)
}

func render_field(_ fieldobj:Any?, format_spec:String) -> Result<String,PyException>
{
    /* If we know the type exactly, skip the lookup of __format__ and just
     call the formatter directly. */
    if fieldobj is String {
        return _PyUnicode_FormatAdvancedWriter(obj: fieldobj as! String, format_spec: format_spec)
    }
    else if fieldobj is FormatableInteger {
        return _PyLong_FormatAdvancedWriter(obj: fieldobj!, format_spec: format_spec)
    }
    else if fieldobj is FormatableFloat {
        return _PyFloat_FormatAdvancedWriter(obj: fieldobj!, format_spec: format_spec)
    }
    //    else if (PyComplex_CheckExact(fieldobj)){
    //        formatter = _PyComplex_FormatAdvancedWriter;
    //        err = formatter(writer, fieldobj, format_spec.str,
    //                        format_spec.start, format_spec.end);
    //        return (err == 0)
    //    }
    /* We need to create an object out of the pointers we have, because
     __format__ takes a string/unicode object for format_spec. */
    // どのプロトコルにも属さなかった場合、オブジェクトの__format__メソッドの呼び出し
    // TODO:各プロトコルのformat関数作成、当面はただの文字列化で済ませる予定
    return .success(PyObject_Format(fieldobj, format_spec))  // nilもfieldobjに入っている予定
}
func parse_field(str:String) -> Result<(String, String, Bool, Character),PyException>
{
    /* Note this function works if the field name is zero length,
     which is good.  Zero length field names are handled later, in
     field_name_split. */
    
    var c:Character = "\0";
    
    /* initialize these, as they may be empty */
    var conversion:Character = "\0";
    
    var format_spec = ""
    /* Search for the field name.  it's terminated by the end of
     the string, or a ':' or '!' */
    var field_name = ""
    var format_spec_needs_expanding:Bool = false
    
    var len = 0
    while len < str.count {
        c = str[len]
        len += 1
        switch (c) {
        case "{":
            return .failure(.ValueError("unexpected '{' in field name"))
        case "[":
            while len < str.count {
                if (str[len] == "]"){
                    break;
                }
                len += 1
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
    
    field_name = str[nil,len]
    if (c == "!" || c == ":") {
        var count:Int;
        /* we have a format specifier and/or a conversion */
        /* don't include the last character */
        
        /* see if there's a conversion specifier */
        if (c == "!") {
            /* there must be another character present */
            if len >= str.count {
                return .failure(.ValueError("end of string while looking for conversion specifier"))
            }
            conversion = str[len]
            len += 1
            if len < str.count {
                c = str[len]
                len += 1
                if (c == "}"){
                    return .success((field_name,format_spec,format_spec_needs_expanding,conversion))
                }
                if (c != ":") {
                    return .failure(.ValueError("expected ':' after conversion specifier"))
                }
            }
        }
        let tmp_len = len
        count = 1;
        while len < str.count {
            c = str[len]
            len += 1
            switch (c) {
            case "{":
                format_spec_needs_expanding = true;
                count += 1;
                break;
            case "}":
                count -= 1;
                if (count == 0) {
                    format_spec = str[tmp_len,len - 1]
                    return .success((field_name,format_spec,format_spec_needs_expanding,conversion))
                }
                break;
            default:
                break;
            }
        }
        
        return .failure(.ValueError("unmatched '{' in format spec"))
    }
    else if c != "}" {
        return .failure(.ValueError("expected '}' before end of string"))
    }
    
    return .success((field_name,format_spec,format_spec_needs_expanding,conversion))
}

/************************************************************************/
/******* Output string allocation and escape-to-markup processing  ******/
/************************************************************************/

/* MarkupIterator breaks the string into pieces of either literal
 text, or things inside {} that need to be marked up.  it is
 designed to make it easy to wrap a Python iterator around it, for
 use with the Formatter class */

class Markup : Sequence {
    typealias Iterator = MarkupIterator
    var str:String
    var index:Int
    init(_ str:String,start:Int=0){
        self.str = str
        self.index = start
    }
    func makeIterator() -> Markup.Iterator {
        return Iterator(self)
    }
    func MarkupNext() -> Result<(String,Bool,String,String,Character,Bool),PyException>? {
        var at_end:Bool;
        var c:Character = "\0";
        var start:Int;
        var len:Int;
        var markup_follows:Bool = false;
        
        /* initialize all of the output variables */
        var literal:String = ""
        let field_name = ""
        let format_spec = ""
        
        let conversion:Character = "\0"
        let format_spec_needs_expanding = false
        var field_present = false
        
        /* No more input, end of iterator.  This is the normal exit
         path. */
        if (self.index >= self.str.count){
            return nil
        }
        
        start = self.index
        
        /* First read any literal text. Read until the end of string, an
         escaped '{' or '}', or an unescaped '{'.  In order to never
         allocate memory and so I can just pass pointers around, if
         there's an escaped '{' or '}' then we'll return the literal
         including the brace, but no format object.  The next time
         through, we'll return the rest of the literal, skipping past
         the second consecutive brace. */
        while self.index < self.str.count {
            c = self.str[self.index]
            self.index += 1
            switch (c) {
            case "{":
                fallthrough
            case "}":
                markup_follows = true;
                break;
            default:
                continue;
            }
            break;
        }
        
        at_end = self.index >= self.str.count
        len = self.index - start;
        
        if (c == "}") && (at_end ||
            (c != self.str[self.index])) {
            return .failure(.ValueError("Single '}' encountered in format string"))
        }
        if (at_end && c == "{") {
            return .failure(.ValueError("Single '{' encountered in format string"))
        }
        if (!at_end) {
            if (c == self.str[self.index]) {
                /* escaped } or {, skip it in the input.  there is no
                 markup object following us, just this literal text */
                self.index += 1;
                markup_follows = false;
            }
            else{
                len -= 1;
            }
        }
        
        /* record the literal text */
        literal = self.str[start,start+len]
        
        if (!markup_follows){
            return .success((literal,field_present,field_name,format_spec,conversion,format_spec_needs_expanding))
        }
        
        /* this is markup; parse the field */
        field_present = true
        switch parse_field(str: self.str) {
        case .success((field_name,format_spec,format_spec_needs_expanding,conversion)):
            break;
        case .failure(let err):
            return .failure(err)
        }
        return .success((literal,field_present,field_name,format_spec,conversion,format_spec_needs_expanding))
    }
}
/* do the !r or !s conversion on obj */
func do_conversion(_ obj:Any?,conversion:Character) -> Result<String?,PyException> {
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
            if (conversion > Character(32) && conversion < Character(127)) {
                /* It's the ASCII subrange; casting to char is safe
                 (assuming the execution character set is an ASCII
                 superset). */
                return .failure(.ValueError("Unknown conversion specifier \(conversion)"))
            } else {
                return .failure(.ValueError("Unknown conversion specifier \\x\(conversion)"))
            }
        }
    }
    return .success(nil)
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
func output_markup(field_name:String, format_spec:String,
                   format_spec_needs_expanding:Bool, conversion:Character,
                   args:[Any], kwargs:[String:Any],
                   recursion_depth:Int, auto_number:AutoNumber) -> Result<String,PyException>
{
    
    var actual_format_spec:String = ""
    
    /* convert field_name to an object */
    var fieldobj:Any? = get_field_object(field_name, args: args, kwargs: kwargs, auto_number: auto_number)
    
    if (conversion != "\0") {
        switch do_conversion(fieldobj, conversion: conversion) {
        case .success(let result):
            fieldobj = result
            break;
        case .failure(let err):
            return .failure(err)
        }
        /* do the assignment, transferring ownership: fieldobj = tmp */
    }
    
    /* if needed, recurively compute the format_spec */
    if format_spec_needs_expanding {
        /* note that in the case we're expanding the format string,
         tmp must be kept around until after the call to
         render_field. */
        switch build_string(format_spec, args: args, kwargs: kwargs, recursion_depth: recursion_depth-1, auto_number: auto_number) {
        case .success(let expanded_format_spec):
            actual_format_spec = expanded_format_spec
            break;
        case .failure(let err):
            return .failure(err)
        }
    } else {
        actual_format_spec = format_spec
    }
    
    return render_field(fieldobj, format_spec: actual_format_spec)
}


class MarkupIterator : IteratorProtocol {
    typealias Element = Result<(String,Bool,String,String,Character,Bool),PyException>
    private let markup:Markup
    init(_ markup:Markup){
        self.markup = markup
    }
    func next() -> MarkupIterator.Element? {
        return self.markup.MarkupNext()
    }
}
/*
 do_markup is the top-level loop for the format() method.  It
 searches through the format string for escapes to markup codes, and
 calls other functions to move non-markup text to the output,
 and to perform the markup to the output.
 */
func do_markup(_ str:String,args:[Any],kwargs:[String:Any],recursion_depth:Int,auto_number:AutoNumber) -> Result<String,PyException> {
    var buffer:String = ""
    let iter:Markup = .init(str)
    for result in iter {
        switch result {
        case .success(let (literal,field_present,field_name,format_spec,conversion,format_spec_needs_expanding)):
            if literal.isEmpty {
                buffer.append(literal)
            }
            if (field_present) {
                switch output_markup(field_name: field_name, format_spec: format_spec,
                                     format_spec_needs_expanding: format_spec_needs_expanding, conversion: conversion,
                                     args: args, kwargs: kwargs, recursion_depth: recursion_depth, auto_number: auto_number){
                case .success(let tmp):
                    buffer.append(tmp)
                    break;
                case .failure(let err):
                    return .failure(err)
                }
            }
        case .failure(let err):
            return .failure(err)
        }
        
    }
    return .success(buffer)
}


/*
 build_string allocates the output string and then
 calls do_markup to do the heavy lifting.
 */
func build_string(_ str:String, args:[Any],kwargs:[String:Any],recursion_depth:Int,auto_number:AutoNumber) -> Result<String,PyException> {
    /* check the recursion level */
    if recursion_depth <= 0 {
        return .failure(.ValueError("Max string recursion exceeded"))
    }
    return do_markup(str, args: args, kwargs: kwargs, recursion_depth: recursion_depth, auto_number: auto_number)
}

func PyObject_Repr(_ obj:Any) -> String {
    return String(describing: obj)
}
func PyObject_Str(_ obj:Any) -> String {
    return String(describing: obj)
}
func PyObject_ASCII(_ obj:Any) -> String {
    return String(describing: obj)
}

/* Raises an exception about an unknown presentation type for this
 * type. */

func unknown_presentation_type(presentation_type:Character, type_name:String) -> Result<Void,PyException> {
    /* %c might be out-of-range, hence the two cases. */
    if (presentation_type > Character(32) && presentation_type < Character(128)){
        return .failure(.ValueError("Unknown format code '\(presentation_type)' for object of type '\(type_name)'"))

    }
    else{
        return .failure(.ValueError("Unknown format code '\\x\(presentation_type)' for object of type '\(type_name)'"))
    }
}

func invalid_thousands_separator_type(specifier:Character, presentation_type:Character) -> Result<Void,PyException>
{
    assert(specifier == "," || specifier == "_");
    if (presentation_type > Character(32) && presentation_type < Character(128)){
        return .failure(.ValueError("Cannot specify '\(specifier)' with '\(presentation_type)'."))
    }
    else{
        return .failure(.ValueError("Cannot specify '\(specifier)' with '\\x\(presentation_type)'."))
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
func get_integer(str:String, ppos:inout Int, end:Int,result:inout Int) -> Result<Int,PyException>
{
    var accumulator:Int = 0
    var digitval:Int = 0
    var pos:Int = ppos;
    var numdigits:Int = 0
    
    while (pos < end) {
        digitval = UNICODE_TODECIMAL(str[pos])
        if digitval < 0 {
            break
        }
        /*
         Detect possible overflow before it happens:
         
         accumulator * 10 + digitval > PY_SSIZE_T_MAX if and only if
         accumulator > (PY_SSIZE_T_MAX - digitval) / 10.
         */
        if (accumulator > (Int.max - digitval) / 10) {
            ppos = pos;
            return .failure(.ValueError("Too many decimal digits in format string"))
        }
        accumulator = accumulator * 10 + digitval
        pos += 1
        numdigits += 1
    }
    ppos = pos;
    result = accumulator;
    return .success(numdigits)
}

/************************************************************************/
/*********** standard format specifier parsing **************************/
/************************************************************************/

/* returns true if this character is a specifier alignment token */
func is_alignment_token(_ c:Character) -> Bool
{
    return "<>+^".contains(c)
}

/* returns true if this character is a sign element */
func is_sign_element(_ c:Character) -> Bool
{
    return " +-".contains(c)
}

/* Locale type codes. LT_NO_LOCALE must be zero. */
enum LocaleType : Character {
    typealias RawValue = Character
    
    case LT_NO_LOCALE = "\0"
    case LT_DEFAULT_LOCALE = ","
    case LT_UNDERSCORE_LOCALE = "_"
    case LT_UNDER_FOUR_LOCALE = "`"// py origin Number
    case LT_CURRENT_LOCALE = "a"// py origin Number
};

struct InternalFormatSpec{
    var fill_char:Character = " "
    var align:Character
    var alternate:Int = 0
    var sign:Character = "\0"
    var width:Int = -1
    var thousands_separators:LocaleType = .LT_NO_LOCALE
    var precision:Int = -1
    var type:Character
    
    init(align:Character,type:Character){
        self.align = align
        self.type = type
    }
    static func from(_ str:String,defaultAline:Character=" ",defaultType:Character=" ") -> InternalFormatSpec {
        var spec = InternalFormatSpec(align: defaultType, type: defaultType)
        spec.fill_char = " "
        return spec
    }
}

/* Occasionally useful for debugging. Should normally be commented out. */
func DEBUG_PRINT_FORMAT_SPEC(_ format:InternalFormatSpec)
{
    func printf(_ items:Any...){
        print(items)
    }
    printf("internal format spec: fill_char %d\n", format.fill_char);
    printf("internal format spec: align %d\n", format.align);
    printf("internal format spec: alternate %d\n", format.alternate);
    printf("internal format spec: sign %d\n", format.sign);
    printf("internal format spec: width %zd\n", format.width);
    printf("internal format spec: thousands_separators %d\n",
           format.thousands_separators);
    printf("internal format spec: precision %zd\n", format.precision);
    printf("internal format spec: type %c\n", format.type);
    printf("\n");
}


/*
 ptr points to the start of the format_spec, end points just past its end.
 fills in format with the parsed information.
 returns 1 on success, 0 on failure.
 if failure, sets the exception
 */
func parse_internal_render_format_spec(format_spec:String,
                                    default_type:Character,
                                    default_align:Character) -> Result<InternalFormatSpec,PyException>
{
    var pos:Int = 0
    let end:Int = format_spec.count
    /* end-pos is used throughout this code to specify the length of
     the input string */
    
    var consumed:Int
    var align_specified:Bool = false
    var fill_char_specified:Bool = false
    var format:InternalFormatSpec = .init(align: default_align, type: default_type)
    
    /* If the second char is an alignment token,
     then parse the fill char */
    if (end-pos >= 2 && is_alignment_token(format_spec[pos+1])) {
        format.align = format_spec[pos+1]
        format.fill_char = format_spec[pos]
        fill_char_specified = true;
        align_specified = true;
        pos += 2;
    }
    else if (end-pos >= 1 && is_alignment_token(format_spec[pos])) {
        format.align = format_spec[pos]
        align_specified = true;
        pos += 1
    }
    
    /* Parse the various sign options */
    if (end-pos >= 1 && is_sign_element(format_spec[pos])) {
        format.sign = format_spec[pos]
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
            format.align = "="
        }
        pos += 1
    }
    switch get_integer(str: format_spec, ppos: &pos, end: end, result: &format.width) {
    case .success(let i):
        consumed = i
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
    if (end-pos != 0 && format_spec[pos] == ",") {
        format.thousands_separators = .LT_DEFAULT_LOCALE;
        pos += 1
    }
    /* Underscore signifies add thousands separators */
    if (end-pos != 0 && format_spec[pos] == "_") {
        if (format.thousands_separators != .LT_NO_LOCALE) {
            switch invalid_comma_and_underscore() {
            case .failure(let err):
                return .failure(err)
            default:
                break;
            }
        }
        format.thousands_separators = .LT_UNDERSCORE_LOCALE;
        pos += 1;
    }
    if (end-pos != 0 && format_spec[pos] == ",") {
        switch invalid_comma_and_underscore() {
        case .failure(let err):
            return .failure(err)
        default:
            break
        }
    }
    
    /* Parse field precision */
    if (end-pos != 0 && format_spec[pos] == ".") {
        pos += 1
        switch get_integer(str: format_spec, ppos: &pos, end: end, result: &format.precision) {
        case .success(let i):
            /* Not having a precision after a dot is an error. */
            if (i == 0) {
                return .failure(.ValueError("Format specifier missing precision"))
            }
            consumed = 0
            break;
        case .failure(let err):
            /* Overflow error. Exception already set. */
            return .failure(err)
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
    
    if (format.thousands_separators != .LT_NO_LOCALE) {
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
            switch invalid_thousands_separator_type(specifier: format.thousands_separators.rawValue, presentation_type: format.type) {
            case .failure(let err):
                return .failure(err)
            default:
                break;
            }
        }
    }
    
    assert(format.align <= Character(127));
    assert(format.sign <= Character(127));
    return .success(format)
}

/* Calculate the padding needed. */
func
    calc_padding(nchars:Int, width:Int, align:Character,
                 n_lpadding:inout Int,  n_rpadding:inout Int,
                 n_total:inout Int)
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
    }
    
    n_rpadding = n_total - nchars - n_lpadding;
}


/************************************************************************/
/*********** common routines for numeric formatting *********************/
/************************************************************************/

/* Locale info needed for formatting integers and the part of floats
 before and including the decimal. Note that locales only support
 8-bit chars, not unicode. */
struct LocaleInfo{
    var decimal_point:String = "";
    var thousands_sep:String = "";
    var grouping:String = "";
}


/* describes the layout for an integer, see the comment in
 calc_number_widths() for details */
struct NumberFieldWidths{
    var n_lpadding:Int = 0
    var n_prefix:Int = 0
    var n_spadding:Int = 0
    var n_rpadding:Int = 0
    var sign:Character = .init(0)
    var n_sign:Int = 0      /* number of digits needed for sign (0/1) */
    var n_grouped_digits:Int = 0  /* Space taken up by the digits, including
     any grouping chars. */
    var n_decimal:Int = 0   /* 0 if only an integer */
    var n_remainder:Int = 0 /* Digits in decimal and/or exponent part,
     excluding the decimal itself, if
     present. */
    
    /* These 2 are not the widths of fields, but are needed by
     STRINGLIB_GROUPING. */
    var n_digits:Int = 0    /* The number of digits before a decimal
     or exponent. */
    var n_min_width:Int = 0 /* The min_width we used when we computed
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
func
    parse_number(s:String, pos:Int, end:Int,
                 n_remainder:inout Int, has_decimal:inout Bool)
{
    var pos = pos
    var remainder:Int
    
    while (pos<end && s[pos].isdigit() ){
        pos += 1;
    }
    remainder = pos;
    
    /* Does remainder start with a decimal point? */
    has_decimal = pos<end && s[remainder] == ".";
    
    /* Skip the decimal point. */
    if (has_decimal){
        remainder += 1;
    }
    
    n_remainder = end - remainder;
}

/* not all fields of format are used.  for example, precision is
 unused.  should this take discrete params in order to be more clear
 about what it does?  or is passing a single format parameter easier
 and more efficient enough to justify a little obfuscation?
 Return -1 on error. */
func calc_number_widths(spec:inout NumberFieldWidths, n_prefix:Int,
                       sign_char:Character, number:Any, n_start:Int,
                       n_end:Int, n_remainder:Int,
                       has_decimal:Bool, locale:LocaleInfo,
                       format:InternalFormatSpec) -> Int
{
    var n_non_digit_non_padding:Int
    var n_padding:Int
    
    spec.n_digits = n_end - n_start - n_remainder - (has_decimal ? 1 : 0);
    spec.n_lpadding = 0;
    spec.n_prefix = n_prefix;
    spec.n_decimal = has_decimal ? locale.decimal_point.count : 0;
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
        spec.sign = (sign_char == "-" ? "-" : "+")
        break;
    case " ":
        spec.n_sign = 1;
        spec.sign = (sign_char == "-" ? "-" : " ")
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
        spec.n_grouped_digits = 0 ;_PyUnicode_InsertThousandsGrouping(
            nil, 0,
            nil, 0, spec.n_digits,
            spec.n_min_width,
            locale.grouping, locale.thousands_sep);
        if (spec.n_grouped_digits == -1) {
            return -1;
        }
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
            break
        }
    }
    
    return spec.n_lpadding + spec.n_sign + spec.n_prefix +
        spec.n_spadding + spec.n_grouped_digits + spec.n_decimal +
        spec.n_remainder + spec.n_rpadding;
}


func _PyUnicode_InsertThousandsGrouping(_ i:Any?...) -> String{
    return ""
}


/* Fill in the digit parts of a numbers's string representation,
 as determined in calc_number_widths().
 Return -1 on error, or 0 on success. */
func fill_number(spec:NumberFieldWidths,
                digits:String, d_start:Int, d_end:Int,
                prefix:String, p_start:Int,fill_char:Character,
                locale:LocaleInfo, toupper:Bool) -> Result<String,PyException>
{
    /* Used to keep track of digits, decimal, and remainder. */
    var buffer:String = ""
    var d_pos:Int = d_start;

    var r:Int;
    
    if (spec.n_lpadding != 0) {
        
        buffer.append(String(repeating: fill_char,count: spec.n_lpadding))
    }
    if (spec.n_sign != 0) {
        buffer.append(spec.sign)
    }
    if (spec.n_prefix != 0) {
        let tmp_prefix = String(repeating: prefix, count: spec.n_prefix)
        if (toupper) {
            buffer.append(tmp_prefix.upper())
        }
        else {
            buffer.append(tmp_prefix)
        }
    }
    if (spec.n_spadding != 0) {
        buffer.append(String(repeating: fill_char, count: spec.n_spadding))
    }
    
    /* Only for type 'c' special case, it has no digits. */
    if (spec.n_digits != 0) {
        /* Fill the digits with InsertThousandsGrouping. */
        buffer = _PyUnicode_InsertThousandsGrouping(
             spec.n_grouped_digits,
            digits, d_pos, spec.n_digits,
            spec.n_min_width,
            locale.grouping, locale.thousands_sep, nil);
//        assert(r == spec.n_grouped_digits);
        d_pos += spec.n_digits;
    }
    if (toupper) {
        var t:Int = 0;
        while(t < spec.n_grouped_digits) {
            var c:Character = buffer[t]
            c = c.toUpper()
            //tmp TODO:remove commentout //            if (c > 127) {
//                SystemError("non-ascii grouped digit")
//                return -1;
//            }
        //tmp TODO:remove commnetout//            PyUnicode_WRITE(kind, writer.data, writer.pos + t, c);
            t += 1
        }
    }
    
    if (spec.n_decimal != 0) {
        // TODO:remove commentout
//        _PyUnicode_FastCopyCharacters(
//            writer.buffer, writer.pos,
//            locale.decimal_point, 0, spec.n_decimal);
//        writer.pos += spec.n_decimal;
        d_pos += 1;
    }
    
    if (spec.n_remainder != 0) {
        // TODO:remove commentout
//        _PyUnicode_FastCopyCharacters(
//            writer.buffer, writer.pos,
//            digits, d_pos, spec.n_remainder);
//        writer.pos += spec.n_remainder;
    }
    
    if (spec.n_rpadding != 0) {
        // TODO:remove commentout
//        _PyUnicode_FastFill(writer.buffer,
//                            writer.pos, spec.n_rpadding,
//                            fill_char);
//        writer.pos += spec.n_rpadding;
    }
    return .success(buffer)
}

var no_grouping:[Character] = [Character(255)]

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

func get_locale_info(type:LocaleType) -> Result<LocaleInfo,PyException>
{
    var locale_info: LocaleInfo = .init()
    switch (type) {
    case .LT_CURRENT_LOCALE:
        (locale_info.decimal_point , locale_info.thousands_sep, locale_info.grouping) = _get_local_info()

        /* localeconv() grouping can become a dangling pointer or point
         to a different string if another thread calls localeconv() during
         the string formatting. Copy the string to avoid this risk. */
        break;

    case .LT_DEFAULT_LOCALE:
        fallthrough
    case .LT_UNDERSCORE_LOCALE:
        fallthrough
    case .LT_UNDER_FOUR_LOCALE:
        locale_info.decimal_point = "."
        locale_info.thousands_sep = type == .LT_DEFAULT_LOCALE ? "," : "_"
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
        locale_info.decimal_point = "."
        locale_info.thousands_sep = ""
        locale_info.grouping = "\0"
        break;
    }
    return .success(locale_info)
}


/************************************************************************/
/*********** string formatting ******************************************/
/************************************************************************/

func format_string_internal(value:String, format:InternalFormatSpec) -> Result<String,PyException>
{
    var len:Int
    var padStr:String = ""
    
    len = value.count
    
    /* sign is not allowed on strings */
    if (format.sign != "\0") {
        return .failure(.ValueError("Sign not allowed in string format specifier"))
    }
    
    /* alternate is not allowed on strings */
    if (format.alternate != 0) {
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
    
    if format.align == ">" {
        padStr = value.rjust(format.width, fillchar: format.fill_char)
    } else if format.align == "^" {
        padStr = value.center(format.width, fillchar: format.fill_char)
    } else if format.align == "<" || format.align == "=" {
        padStr = value.ljust(format.width, fillchar: format.fill_char)
    }

    /* Write into that space. First the padding. */
    
    /* Then the source string. */
    return .success(padStr)
}


/************************************************************************/
/*********** long formatting ********************************************/
/************************************************************************/

func format_long_internal(value:Any, format:InternalFormatSpec) -> Result<String,PyException>
{
    var tmp:String = ""
    var inumeric_chars:Int
    var sign_char:Character = "\0"
    var n_digits:Int;       /* count of digits need from the computed string */
    var n_remainder:Int = 0; /* Used only for 'c' formatting, which
     produces non-digits */
    var n_prefix:Int = 0;   /* Count of prefix chars, (e.g., '0x') */
    var n_total:Int;
    var prefix:Int = 0;
    var spec:NumberFieldWidths = .init()
    var x:Int
    
    /* Locale settings, either from the actual locale or
     from a hard-code pseudo-locale */
    var locale:LocaleInfo
    
    /* no precision allowed on integers */
    if (format.precision != -1) {
        return.failure(.ValueError("Precision not allowed in integer format specifier"))
    }
    
    /* special case for character formatting */
    if (format.type == "c") {
        /* error to specify a sign */
        if (format.sign != "\0") {
            return .failure(.ValueError("Sign not allowed with integer format specifier 'c'"))
        }
        /* error to request alternate format */
        if (format.alternate != 0) {
            return .failure(.ValueError("Alternate form (#) not allowed with integer format specifier 'c'"))
        }
        
        /* taken from unicodeobject.c formatchar() */
        /* Integer input truncated to a character */
        x = value as! Int // できるだけ精度が高い方が望ましい

        if (x < 0 || x > 0x10ffff) {
            return .failure(.OverflowError("\(value) arg not in range(0x110000)"))
        }
        tmp = String(Character(x)) // <- Unicode 文字
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
        var base:Int;
        var leading_chars_to_skip:Int = 0;  /* Number of characters added by
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
            && format.thousands_separators != .LT_NO_LOCALE)
        {
            /* Fast path */
            return .success("") //TODO removecommentout _PyLong_FormatWriter(writer, value, base, format.alternate);
        }
        
        /* The number of prefix chars is the same as the leading
         chars to skip */
        if (format.alternate != 0){
            n_prefix = leading_chars_to_skip;
        }
        
        /* Do the hard part, converting to a string in a given base */
        tmp = String(value as! Int64  , radix: base)

        inumeric_chars = 0;
        n_digits = tmp.count
        
        prefix = inumeric_chars;
        
        /* Is a sign character present in the output?  If so, remember it
         and skip it */
        if (tmp[inumeric_chars] == "-") {
            sign_char = "-";
            prefix += 1;
            leading_chars_to_skip += 1
        }
        
        /* Skip over the leading chars (0x, 0b, etc.) */
        n_digits -= leading_chars_to_skip;
        inumeric_chars += leading_chars_to_skip;
    }
    
    /* Determine the grouping, separator, and decimal point, if any. */
    switch get_locale_info(type: format.type == "n" ? .LT_CURRENT_LOCALE :
        format.thousands_separators) {
    case .success(let l):
        locale = l
        break
    case .failure(let err):
        return .failure(err)
    }
    
    /* Calculate how much memory we'll need. */
    n_total = calc_number_widths(spec: &spec, n_prefix: n_prefix, sign_char: sign_char, number: tmp, n_start: inumeric_chars,
                                 n_end: inumeric_chars + n_digits, n_remainder: n_remainder, has_decimal: false,
                                 locale: locale, format: format);
    if (n_total == -1) {
        return .failure(.Exception("Unknown Error"))
    }
    
    /* Populate the memory. */
    return fill_number(spec: spec,
                         digits: tmp, d_start: inumeric_chars, d_end: inumeric_chars + n_digits,
                         prefix: tmp, p_start: prefix, fill_char: format.fill_char,
                         locale: locale, toupper: format.type == "X");
}

/************************************************************************/
/*********** float formatting *******************************************/
/************************************************************************/

/* PyOS_double_to_string's "flags" parameter can be set to 0 or more of: */
let Py_DTSF_SIGN = 0x01 /* always add the sign */
let Py_DTSF_ADD_DOT_0 = 0x02 /* if the result is an integer add ".0" */
let Py_DTSF_ALT = 0x04 /* "alternate" formatting. it's format_code
 specific */

/* PyOS_double_to_string's "type", if non-NULL, will be set to one of: */
let Py_DTST_FINITE = 0
let Py_DTST_INFINITE = 1
let Py_DTST_NAN = 2

/* much of this is taken from unicodeobject.c */
func format_float_internal(value:Any,
                          format:InternalFormatSpec) -> Result<String,PyException>
{
    var buf:String = ""      /* buffer returned from PyOS_double_to_string */
    var n_digits:Int
    var n_remainder:Int = 0
    var n_total:Int
    var has_decimal:Bool = false
    var val:Double // big float
    var precision:Int = 0
    var default_precision:Int = 6;
    var type:Character = format.type;
    var add_pct:Bool = false;
    var index:Int = 0
    var spec:NumberFieldWidths = .init()
    var flags:Int = 0;
    var sign_char:Character = "\0";
    var float_type:Int /* Used to see if we have a nan, inf, or regular float. */
    var unicode_tmp:String
    
    /* Locale settings, either from the actual locale or
     from a hard-code pseudo-locale */
    var locale:LocaleInfo = .init()
    
    if (format.precision > Int.max) {
        return .failure(.ValueError("precision too big"))
    }
    precision = format.precision;
    
    if (format.alternate != 0){
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
    
    val = value as! Double
    
    if (type == "%") {
        type = "f";
        val *= 100;
        add_pct = true;
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
// TODO remove commnetout    buf = PyOS_double_to_string(val, type, precision, flags, &float_type);
    n_digits = buf.count;
    
    if (add_pct) {
        /* We know that buf has a trailing zero (since we just called
         strlen() on it), and we don't use that fact any more. So we
         can just write over the trailing zero. */
        buf.append("%") // 一番後ろに％をつけるフォーマッティング
        n_digits += 1;
    }
    
    if (format.sign != "+" && format.sign != " "
        && format.width == -1
        && format.type != "n"
        && format.thousands_separators != .LT_NO_LOCALE)
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
    if (unicode_tmp[index] == "-") {
        sign_char = "-";
        index += 1;
        n_digits -= 1;
    }
    
    /* Determine if we have any "remainder" (after the digits, might include
     decimal or exponent or both (or neither)) */
    parse_number(s: unicode_tmp, pos: index, end: index + n_digits, n_remainder: &n_remainder, has_decimal: &has_decimal);
    
    /* Determine the grouping, separator, and decimal point, if any. */
    switch get_locale_info(type: format.type == "n" ? .LT_CURRENT_LOCALE :
        format.thousands_separators) {
    case .success(let l):
        locale = l
        break;
    case .failure(let err):
        return .failure(err)
    }
    
    /* Calculate how much memory we'll need. */
    n_total = calc_number_widths(spec: &spec, n_prefix: 0, sign_char: sign_char, number: unicode_tmp, n_start: index,
                                 n_end: index + n_digits, n_remainder: n_remainder, has_decimal: has_decimal,
                                 locale: locale, format: format)
    if (n_total == -1) {
        return .failure(.Exception("Unknown Error"))
    }
    
    
    /* Populate the memory. */
    return fill_number(spec: spec,
                         digits: unicode_tmp, d_start: index, d_end: index + n_digits,
                         prefix: "", p_start: 0, fill_char: format.fill_char,
                         locale: locale, toupper: false)
}

/************************************************************************/
/*********** complex formatting *****************************************/
/************************************************************************/
//
//static int
//format_complex_internal(PyObject *value,
//const InternalFormatSpec *format,
//_PyUnicodeWriter *writer)
//{
//    double re;
//    double im;
//    char *re_buf = NULL;       /* buffer returned from PyOS_double_to_string */
//    char *im_buf = NULL;       /* buffer returned from PyOS_double_to_string */
//
//    InternalFormatSpec tmp_format = *format;
//    Py_ssize_t n_re_digits;
//    Py_ssize_t n_im_digits;
//    Py_ssize_t n_re_remainder;
//    Py_ssize_t n_im_remainder;
//    Py_ssize_t n_re_total;
//    Py_ssize_t n_im_total;
//    int re_has_decimal;
//    int im_has_decimal;
//    int precision, default_precision = 6;
//    Py_UCS4 type = format->type;
//    Py_ssize_t i_re;
//    Py_ssize_t i_im;
//    NumberFieldWidths re_spec;
//    NumberFieldWidths im_spec;
//    int flags = 0;
//    int result = -1;
//    Py_UCS4 maxchar = 127;
//    enum PyUnicode_Kind rkind;
//    void *rdata;
//    Py_UCS4 re_sign_char = '\0';
//    Py_UCS4 im_sign_char = '\0';
//    int re_float_type; /* Used to see if we have a nan, inf, or regular float. */
//    int im_float_type;
//    int add_parens = 0;
//    int skip_re = 0;
//    Py_ssize_t lpad;
//    Py_ssize_t rpad;
//    Py_ssize_t total;
//    PyObject *re_unicode_tmp = NULL;
//    PyObject *im_unicode_tmp = NULL;
//
//    /* Locale settings, either from the actual locale or
//     from a hard-code pseudo-locale */
//    LocaleInfo locale
//
//    if (format->precision > INT_MAX) {
//        PyErr_SetString(PyExc_ValueError, "precision too big");
//        goto done;
//    }
//    precision = (int)format->precision;
//
//    /* Zero padding is not allowed. */
//    if (format->fill_char == '0') {
//        PyErr_SetString(PyExc_ValueError,
//                        "Zero padding is not allowed in complex format "
//            "specifier");
//        goto done;
//    }
//
//    /* Neither is '=' alignment . */
//    if (format->align == '=') {
//        PyErr_SetString(PyExc_ValueError,
//                        "'=' alignment flag is not allowed in complex format "
//            "specifier");
//        goto done;
//    }
//
//    re = PyComplex_RealAsDouble(value);
//    if (re == -1.0 && PyErr_Occurred())
//    goto done;
//    im = PyComplex_ImagAsDouble(value);
//    if (im == -1.0 && PyErr_Occurred())
//    goto done;
//
//    if (format->alternate)
//    flags |= Py_DTSF_ALT;
//
//    if (type == '\0') {
//        /* Omitted type specifier. Should be like str(self). */
//        type = 'r';
//        default_precision = 0;
//        if (re == 0.0 && copysign(1.0, re) == 1.0)
//        skip_re = 1;
//        else
//        add_parens = 1;
//    }
//
//    if (type == 'n')
//    /* 'n' is the same as 'g', except for the locale used to
//     format the result. We take care of that later. */
//    type = 'g';
//
//    if (precision < 0)
//    precision = default_precision;
//    else if (type == 'r')
//    type = 'g';
//
//    /* Cast "type", because if we're in unicode we need to pass an
//     8-bit char. This is safe, because we've restricted what "type"
//     can be. */
//    re_buf = PyOS_double_to_string(re, (char)type, precision, flags,
//    &re_float_type);
//    if (re_buf == NULL)
//    goto done;
//    im_buf = PyOS_double_to_string(im, (char)type, precision, flags,
//    &im_float_type);
//    if (im_buf == NULL)
//    goto done;
//
//    n_re_digits = strlen(re_buf);
//    n_im_digits = strlen(im_buf);
//
//    /* Since there is no unicode version of PyOS_double_to_string,
//     just use the 8 bit version and then convert to unicode. */
//    re_unicode_tmp = _PyUnicode_FromASCII(re_buf, n_re_digits);
//    if (re_unicode_tmp == NULL)
//    goto done;
//    i_re = 0;
//
//    im_unicode_tmp = _PyUnicode_FromASCII(im_buf, n_im_digits);
//    if (im_unicode_tmp == NULL)
//    goto done;
//    i_im = 0;
//
//    /* Is a sign character present in the output?  If so, remember it
//     and skip it */
//    if (PyUnicode_READ_CHAR(re_unicode_tmp, i_re) == '-') {
//        re_sign_char = '-';
//        ++i_re;
//        --n_re_digits;
//    }
//    if (PyUnicode_READ_CHAR(im_unicode_tmp, i_im) == '-') {
//        im_sign_char = '-';
//        ++i_im;
//        --n_im_digits;
//    }
//
//    /* Determine if we have any "remainder" (after the digits, might include
//     decimal or exponent or both (or neither)) */
//    parse_number(re_unicode_tmp, i_re, i_re + n_re_digits,
//                 &n_re_remainder, &re_has_decimal);
//    parse_number(im_unicode_tmp, i_im, i_im + n_im_digits,
//                 &n_im_remainder, &im_has_decimal);
//
//    /* Determine the grouping, separator, and decimal point, if any. */
//    if (get_locale_info(format->type == 'n' ? LT_CURRENT_LOCALE :
//        format->thousands_separators,
//                        &locale) == -1)
//    goto done;
//
//    /* Turn off any padding. We'll do it later after we've composed
//     the numbers without padding. */
//    tmp_format.fill_char = '\0';
//    tmp_format.align = '<';
//    tmp_format.width = -1;
//
//    /* Calculate how much memory we'll need. */
//    n_re_total = calc_number_widths(&re_spec, 0, re_sign_char, re_unicode_tmp,
//    i_re, i_re + n_re_digits, n_re_remainder,
//    re_has_decimal, &locale, &tmp_format,
//    &maxchar);
//    if (n_re_total == -1) {
//        goto done;
//    }
//
//    /* Same formatting, but always include a sign, unless the real part is
//     * going to be omitted, in which case we use whatever sign convention was
//     * requested by the original format. */
//    if (!skip_re)
//    tmp_format.sign = '+';
//    n_im_total = calc_number_widths(&im_spec, 0, im_sign_char, im_unicode_tmp,
//    i_im, i_im + n_im_digits, n_im_remainder,
//    im_has_decimal, &locale, &tmp_format,
//    &maxchar);
//    if (n_im_total == -1) {
//        goto done;
//    }
//
//    if (skip_re)
//    n_re_total = 0;
//
//    /* Add 1 for the 'j', and optionally 2 for parens. */
//    calc_padding(n_re_total + n_im_total + 1 + add_parens * 2,
//    format->width, format->align, &lpad, &rpad, &total);
//
//    if (lpad || rpad)
//    maxchar = Py_MAX(maxchar, format->fill_char);
//
//    if (_PyUnicodeWriter_Prepare(writer, total, maxchar) == -1)
//    goto done;
//    rkind = writer->kind;
//    rdata = writer->data;
//
//    /* Populate the memory. First, the padding. */
//    result = fill_padding(writer,
//    n_re_total + n_im_total + 1 + add_parens * 2,
//    format->fill_char, lpad, rpad);
//    if (result == -1)
//    goto done;
//
//    if (add_parens) {
//        PyUnicode_WRITE(rkind, rdata, writer->pos, '(');
//        writer->pos++;
//    }
//
//    if (!skip_re) {
//        result = fill_number(writer, &re_spec,
//                             re_unicode_tmp, i_re, i_re + n_re_digits,
//                             NULL, 0,
//                             0,
//                             &locale, 0);
//        if (result == -1)
//        goto done;
//    }
//    result = fill_number(writer, &im_spec,
//    im_unicode_tmp, i_im, i_im + n_im_digits,
//    NULL, 0,
//    0,
//    &locale, 0);
//    if (result == -1)
//    goto done;
//    PyUnicode_WRITE(rkind, rdata, writer->pos, 'j');
//    writer->pos++;
//
//    if (add_parens) {
//        PyUnicode_WRITE(rkind, rdata, writer->pos, ')');
//        writer->pos++;
//    }
//
//    writer->pos += rpad;
//
//    done:
//    PyMem_Free(re_buf);
//    PyMem_Free(im_buf);
//    Py_XDECREF(re_unicode_tmp);
//    Py_XDECREF(im_unicode_tmp);
//    return result;
//}
//
/************************************************************************/
/*********** built in formatters ****************************************/
/************************************************************************/
func format_obj(obj:Any) -> String
{
    return .init(describing: obj)
}

func _PyUnicode_FormatAdvancedWriter(obj:String,format_spec:String) -> Result<String,PyException>
{
    var format:InternalFormatSpec = .init(align: "\0", type: "\0") // TODO: un init
    
    /* check for the special case of zero length format spec, make
     it equivalent to str(obj) */
    if format_spec.isEmpty {
        return .success(obj)
    }
    
    /* parse the format_spec */
    switch parse_internal_render_format_spec(format_spec: format_spec, default_type: "s", default_align: "<") {
    case .success(let fmt):
        format = fmt
    case .failure(let err):
        return .failure(err)
    }
    
    /* type conversion? */
    switch (format.type) {
    case "s":
        /* no type conversion needed, already a string.  do the formatting */
        return format_string_internal(value: obj, format: format)
    default:
        /* unknown */
        switch unknown_presentation_type(presentation_type: format.type, type_name: String(describing:type(of:obj))) {
        case .failure(let err):
            return .failure(err)
        default:
            return .success("Unknown Error")
        }
    }
}

func _PyLong_FormatAdvancedWriter(obj:Any,
                                 format_spec:String) -> Result<String,PyException>
{
    var tmp:Any? = nil
    var str:String
    var format:InternalFormatSpec = .init(align: "\0", type: "\0")
    
    /* check for the special case of zero length format spec, make
     it equivalent to str(obj) */
    if format_spec.isEmpty {
        if obj is FormatableInteger {
            return .success("") //TODO remove commentout  _PyLong_FormatWriter(writer, obj, 10, 0);
        }
        else{
            return .success(format_obj(obj: obj))
        }
    }
    
    /* parse the format_spec */
    switch parse_internal_render_format_spec(format_spec: format_spec,
                                             default_type: "d", default_align: ">") {
    case .success(let fmt):
        format = fmt
        break;
    case .failure(let err):
        return .failure(err)
    }
    
    /* type conversion? */
    switch (format.type) {
    case "b":
        fallthrough
    case "c":
        fallthrough
    case "d":
        fallthrough
    case "o":
        fallthrough
    case "x":
        fallthrough
    case "X":
        fallthrough
    case "n":
        /* no type conversion needed, already an int.  do the formatting */
        return format_long_internal(value: obj, format: format)
        
    case "e":
        fallthrough
    case "E":
        fallthrough
    case "f":
        fallthrough
    case "F":
        fallthrough
    case "g":
        fallthrough
    case "G":
        fallthrough
    case "%":
        /* convert to float */
        tmp = Float(obj as! Int)
        return format_float_internal(value: tmp, format: format)
        
    default:
        /* unknown */
        switch unknown_presentation_type(presentation_type: format.type, type_name: String(describing: type(of: obj))) {
        case .failure(let err):
            return .failure(err)
        default:
            return .success("Unknown Error")
        }
    }
}

func _PyFloat_FormatAdvancedWriter(obj:Any,format_spec:String) -> Result<String,PyException>
{
    var format:InternalFormatSpec = .init(align: "\0", type: "\0")
    
    /* check for the special case of zero length format spec, make
     it equivalent to str(obj) */
    if format_spec.isEmpty {
        return .success(format_obj(obj: obj))
    }
    
    /* parse the format_spec */
    
    switch parse_internal_render_format_spec(format_spec: format_spec,
                                             default_type: "\0", default_align: ">") {
    case .success(let fmt):
        format = fmt
        break;
    case .failure(let err):
        return .failure(err)
    }
    
    /* type conversion? */
    switch (format.type) {
    case "\0": /* No format code: like 'g', but with at least one decimal. */
        fallthrough
    case "e":
        fallthrough
    case "E":
        fallthrough
    case "f":
        fallthrough
    case "F":
        fallthrough
    case "g":
        fallthrough
    case "G":
        fallthrough
    case "n":
        fallthrough
    case "%":
        /* no conversion, already a float.  do the formatting */
        return format_float_internal(value: obj, format: format)
    default:
        /* unknown */
        switch unknown_presentation_type(presentation_type: format.type, type_name: String(describing: type(of: obj))) {
        case .failure(let err):
            return .failure(err)
        default:
            return .success("Unknown Error")
        }
    }
}

//func
//    _PyComplex_FormatAdvancedWriter(writer:_PyUnicodeWriter,
//                                    obj:Any,
//                                    format_spec:String,
//                                    start:Int, end:Int) -> Int
//{
//    var format:InternalFormatSpec
//
//    /* check for the special case of zero length format spec, make
//     it equivalent to str(obj) */
//    if (start == end){
//        return format_obj(obj, writer);
//    }
//
//    /* parse the format_spec */
//    if (!parse_internal_render_format_spec(format_spec: format_spec, start: start, end: end,
//                                           format: &format, default_type: "\0", default_align: ">")){
//        return -1;
//    }
//
//    /* type conversion? */
//    switch (format.type) {
//    case "\0": /* No format code: like 'g', but with at least one decimal. */
//        fallthrough
//    case "e":
//        fallthrough
//    case "E":
//        fallthrough
//    case "f":
//        fallthrough
//    case "F":
//        fallthrough
//    case "g":
//        fallthrough
//    case "G":
//        fallthrough
//    case "n":
//        /* no conversion, already a complex.  do the formatting */
//        return format_complex_internal(obj, &format, writer);
//
//    default:
//        /* unknown */
//        unknown_presentation_type(presentation_type: format.type, type_name: String(describing: type(of: obj)));
//        return -1;
//    }
//}
//






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





    /************************************************************************/
    /*********** main routine ***********************************************/
    /************************************************************************/

    /* this is the main entry point */
    func _format(target:String,args:[Any],kwargs:[String:Any]) -> Result<String,PyException> {
        /* PEP 3101 says only 2 levels, so that
         "{0:{1}}".format('abc', 's')            # works
         "{0:{1:{2}}}".format('abc', 's', '')    # fails
         */
        let recursion_depth:Int = 2
        let auto_number:AutoNumber = .init()
        if target.isEmpty {
            return .success(target)
        }
        return build_string(target,args:args,kwargs: kwargs,recursion_depth: recursion_depth,auto_number: auto_number)
    }

extension String {
    public func format(_ args:Any..., kwargs:[String:Any]) -> String {
        switch _format(target: self,args: args,kwargs: kwargs) {
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
