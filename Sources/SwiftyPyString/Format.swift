//
//  Format.swift
//  SwiftyPyString
//
//  Created by 恒川大輝 on 2019/07/12.
//


class Formatter {
    
    struct replacement_field {
        
    }

    struct field_name {
        
    }
    
    struct arg_name {
        
    }
    
    struct attribute_name {
        
    }
    
    
    struct element_index {
        
    }
    
    struct conversion {
        
    }
    enum LocaleType : String {
        case LT_NO_LOCALE = "\0"
        case LT_DEFAULT_LOCALE = ","
        case LT_UNDERSCORE_LOCALE = "_"
        case LT_UNDER_FOUR_LOCALE
        case LT_CURRENT_LOCALE
    }
    struct FormatSpec {
        var fillChar:Character
        var align:Character
        var alternate:Int
        var sign:Character
        var width:Int
        var thousandsSeparators:LocaleType
        var precision:Int
        var type:Character
    }
    /*
     ptr points to the start of the format_spec, end points just past its end.
     fills in format with the parsed information.
     returns 1 on success, 0 on failure.
     if failure, sets the exception
     */
    private func get_integer(str:String, pos: inout Int,end:Int, result:inout Int) -> Int{
        var accumulator:Int = 0
        var digitval:Int
        var numDigits:Int = 0
        while pos < end {
            digitval = .init(str[pos].properties.numericValue ?? 0)
            if digitval < 0{
                break
            }
            /*
             Detect possible overflow before it happens:
             
             accumulator * 10 + digitval > PY_SSIZE_T_MAX if and only if
             accumulator > (PY_SSIZE_T_MAX - digitval) / 10.
             */
            if accumulator > Int.max - digitval / 10 {
                // PyErr_Format(PyExc_ValueError, "Too many decimal digits in format string");
                return -1
            }
            accumulator = accumulator * 10 + digitval

            pos += 1
            numDigits += 1
        }
        result = accumulator
        return numDigits
        
    }
    private func parseInternalRenderFormatSpec(formatSpec:String, start:Int, end:Int, format: inout FormatSpec, defaultType:Character, defaultalign:Character) -> Int{
        /* end-pos is used throughout this code to specify the length of
         the input string */
        var pos:Int = start
        var consumed:Int
        
        var alignSpecified:Bool = false
        var fillCharSpecified:Bool = false
        
        format.fillChar = " "
        format.align = defaultalign
        format.alternate = 0
        format.sign = "0"
        format.width = -1
        format.thousandsSeparators = .LT_CURRENT_LOCALE
        format.precision = -1
        format.type = defaultType
        /* If the second char is an alignment token,
         then parse the fill char */
        if end - pos >= 2 && self.isAlignmentToken(formatSpec[pos+1]){
            format.align = formatSpec[pos+1]
            format.fillChar = formatSpec[pos]
            fillCharSpecified = true
            alignSpecified = true
            pos += 2
        }else if end - pos >= 1 && isAlignmentToken(formatSpec[pos]){
            format.align = formatSpec[pos]
            alignSpecified = true
            pos += 1
        }
        /* Parse the various sign options */
        if (end - pos) >= 1 && self.isSignElement(formatSpec[pos]){
            format.sign = formatSpec[pos]
            pos += 1
        }
        /* If the next character is #, we're in alternate mode.  This only
         applies to integers. */
        if end - pos >= 1 && formatSpec[pos] == "#" {
            format.alternate = 1
            pos += 1
        }
        
        /* The special case for 0-padding (backwards compat) */
        if !fillCharSpecified && end - pos >= 1 && formatSpec[pos] == "0" {
            format.fillChar = "0"
            if !alignSpecified {
                format.align = "="
            }
            pos += 1
        }
        consumed = get_integer(str: formatSpec, pos: &pos, end: end, result: &format.width)// TODO:Impl
        
        if consumed == -1 {
            /* Overflow error. Exception already set. */
            return 0
        }
        /* If consumed is 0, we didn't consume any characters for the
         width. In that case, reset the width to -1, because
         get_integer() will have set it to zero. -1 is how we record
         that the width wasn't specified. */
        if consumed == 0{
            format.width = -1
        }
        /* Comma signifies add thousands separators */
        if (end - pos) != 0 && formatSpec[pos] == ","{
            format.thousandsSeparators = .LT_DEFAULT_LOCALE
            pos += 1
        }
        /* Underscore signifies add thousands separators */
        if (end - pos) != 0 && formatSpec[pos] == "_" {
            if format.thousandsSeparators != .LT_NO_LOCALE {
                // invalid_comma_and_underscore() // TODO:Impl
                return 0
            }
            format.thousandsSeparators = .LT_UNDERSCORE_LOCALE
            pos += 1
        }
        if (end - pos) != 0 && formatSpec[pos] == "," {
            // invalid_comma_and_underscore() // TODO:Impl
            return 0
        }
        /* Parse field precision */
        if (end - pos) != 0 && formatSpec[pos] == "." {
            pos += 1
            
            consumed = get_integer(str: formatSpec, pos: &pos, end: end, result: &format.precision) // TODO:Imple
            if consumed == -1{
                /* Overflow error. Exception already set. */
                return 0
            }
            
            /* Not having a precision after a dot is an error. */
            if consumed == 0 {
                // PyErr_Format(PyExc_ValueError, "Format specifier missing precision")
                return 0
            }
            
        }
        /* Finally, parse the type field. */
        
        if end-pos > 1 {
            /* More than one char remain, invalid format specifier. */
            // PyErr_Format(PyExc_ValueError, "Invalid format specifier")
            return 0
        }
        
        if end-pos == 1 {
            format.type = formatSpec[pos]
            pos += 1
        }
        /* Do as much validating as we can, just by looking at the format
         specifier.  Do not take into account what type of formatting
         we're doing (int, float, string). */
        
        if format.thousandsSeparators != .LT_NO_LOCALE {
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
                if format.thousandsSeparators == .LT_UNDERSCORE_LOCALE {
                    /* Every four digits, not every three, in bin/oct/hex. */
                    format.thousandsSeparators = .LT_UNDER_FOUR_LOCALE
                    break;
                }
                /* fall through */
            default:
                // invalid_thousands_separator_type(format->thousands_separators, format->type);
                return 0;
            }
        }
        
        assert(format.align <= Character(127));
        assert(format.sign  <= Character(127));
        return 1;
        
        
        
    }
    
    struct fill {
        
    }
    
    
    struct align {
        
    }
    
    
    struct sign {
        
    }
    
    struct width {
    
        
    }

    struct grouping_option {
    
        
    }

    struct precision {
    
        
    }

    struct type {
        
        enum t : String {
            case a
        }
        
        
    }
    func isAlignmentToken(_ c:Character) -> Bool{
        switch c {
        case "<":
            return true
        case ">":
            return true
        case "=":
            return true
        case "^":
            return true
        default:
            return false
        }
    }
    func isSignElement(_ c:Character) -> Bool{
        switch (c) {
        case " ":
            return true
        case "+":
            return true
        case "-":
            return true
        default:
            return false
        }
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
extension Float:FormatableFloat{}
extension Double:FormatableFloat{}
extension Float80:FormatableFloat{}

extension String {
    public func format(_ args:Any..., kwargs:[String:Any]) -> String {
        // TODO:Impl
        for item in args {
            var str = ""
            var type = ""
            if item is FormatableInteger {
                
            }
            else if item is FormatableFloat {
                
            }
            else {
                
            }
        }
        return self
    }
    
    public func format_map(_ mapping:[String:Any]) -> String {
        // TODO:Impl
        return self
    }

}
