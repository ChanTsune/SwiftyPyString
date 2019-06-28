
let ALPHA_MASK:UInt16 = 0x01
let DECIMAL_MASK:UInt16 = 0x02
let DIGIT_MASK:UInt16 = 0x04
let LOWER_MASK:UInt16 = 0x08
let LINEBREAK_MASK:UInt16 = 0x10
let SPACE_MASK:UInt16 = 0x20
let TITLE_MASK:UInt16 = 0x40
let UPPER_MASK:UInt16 = 0x80
let XID_START_MASK:UInt16 = 0x100
let XID_CONTINUE_MASK:UInt16 = 0x200
let PRINTABLE_MASK:UInt16 = 0x400
let NUMERIC_MASK:UInt16 = 0x800
let CASE_IGNORABLE_MASK:UInt16 = 0x1000
let CASED_MASK:UInt16 = 0x2000
let EXTENDED_CASE_MASK:UInt16 = 0x4000


func getUnicodeTypeRecord(code:Py_UCS4) -> UnicodeTypeRecord {
    var index:Int
    if code >= 0x110000 {
        index = 0
    }
    else {
        index = Int(index1[Int(code >> SHIFT)])
        index = Int(index2[(index << SHIFT) + Int(code & ((1 << SHIFT) - 1))])
    }
    return UnicodeTypeRecords[index]
}
/* Returns the titlecase Unicode characters corresponding to ch or just
   ch if no titlecase mapping is known. */

func toTitleCase(ch:Py_UCS4) -> Py_UCS4 {
    let typerecord = getUnicodeTypeRecord(code:ch)
    if (typerecord.flags & EXTENDED_CASE_MASK) != 0 {
        return UnicodeExtendedCase[typerecord.title & 0xFFFF]
    }
    return ch + Py_UCS4(typerecord.title)
}
/* Returns 1 for Unicode characters having the category 'Lt', 0
   otherwise. */

func isTitleCase(ch:Py_UCS4) -> Bool {
    let typerecord = getUnicodeTypeRecord(code:ch)
    return typerecord.flags & TITLE_MASK != 0
}
/* Returns 1 for Unicode characters having the XID_Start property, 0
   otherwise. */

func isXidStart(ch:Py_UCS4) -> Bool {
    let ctype = getUnicodeTypeRecord(code:ch);

    return (ctype.flags & XID_START_MASK) != 0;
}

/* Returns 1 for Unicode characters having the XID_Continue property,
   0 otherwise. */

func isXidContinue(ch:Py_UCS4) -> Bool {
    let ctype = getUnicodeTypeRecord(code:ch);

    return (ctype.flags & XID_CONTINUE_MASK) != 0;
}

/* Returns the integer decimal (0-9) for Unicode characters having
   this property, -1 otherwise. */

func toDecimalDigit(ch:Py_UCS4) ->Int {
    let ctype = getUnicodeTypeRecord(code:ch);

    return (ctype.flags & DECIMAL_MASK) != 0 ? ctype.decimal : -1;
}

func isDecimalDigit(ch:Py_UCS4) -> Bool {
    if (toDecimalDigit(ch:ch) < 0){
        return false;
    }
    return true;
}

/* Returns the integer digit (0-9) for Unicode characters having
   this property, -1 otherwise. */

func toDigit(ch:Py_UCS4) -> Int {
    let ctype = getUnicodeTypeRecord(code:ch);

    return (ctype.flags & DIGIT_MASK) != 0 ? ctype.digit : -1;
}

func isDigit(ch:Py_UCS4) -> Bool {
    if (toDigit(ch:ch) < 0){
        return false;
    }
    return true;
}

/* Returns the numeric value as double for Unicode characters having
   this property, -1.0 otherwise. */

func isNumeric(ch:Py_UCS4) -> Bool {
    let ctype = getUnicodeTypeRecord(code:ch);

    return (ctype.flags & NUMERIC_MASK) != 0;
}

/* Returns 1 for Unicode characters to be hex-escaped when repr()ed,
   0 otherwise.
   All characters except those characters defined in the Unicode character
   database as following categories are considered printable.
      * Cc (Other, Control)
      * Cf (Other, Format)
      * Cs (Other, Surrogate)
      * Co (Other, Private Use)
      * Cn (Other, Not Assigned)
      * Zl Separator, Line ('\u2028', LINE SEPARATOR)
      * Zp Separator, Paragraph ('\u2029', PARAGRAPH SEPARATOR)
      * Zs (Separator, Space) other than ASCII space('\x20').
*/
func isPrintable(ch:Py_UCS4) -> Bool {
    let ctype = getUnicodeTypeRecord(code:ch);

    return (ctype.flags & PRINTABLE_MASK) != 0;
}

/* Returns 1 for Unicode characters having the category 'Ll', 0
   otherwise. */

func isLowercase(ch:Py_UCS4) -> Bool {
    let ctype = getUnicodeTypeRecord(code:ch);

    return (ctype.flags & LOWER_MASK) != 0;
}

/* Returns 1 for Unicode characters having the category 'Lu', 0
   otherwise. */

func isUppercase(ch:Py_UCS4) -> Bool {
    let ctype = getUnicodeTypeRecord(code:ch);

    return (ctype.flags & UPPER_MASK) != 0;
}

/* Returns the uppercase Unicode characters corresponding to ch or just
   ch if no uppercase mapping is known. */

func toUppercase(ch:Py_UCS4) -> Py_UCS4 {
    let ctype = getUnicodeTypeRecord(code:ch);

    if (ctype.flags & EXTENDED_CASE_MASK) != 0{
        return UnicodeExtendedCase[ctype.upper & 0xFFFF]
    }
    return ch + Py_UCS4(ctype.upper);
}

/* Returns the lowercase Unicode characters corresponding to ch or just
   ch if no lowercase mapping is known. */

func toLowercase(ch:Py_UCS4) -> Py_UCS4
{
    let ctype = getUnicodeTypeRecord(code:ch);

    if (ctype.flags & EXTENDED_CASE_MASK) != 0{
        return UnicodeExtendedCase[ctype.lower & 0xFFFF];
    }
    return ch + Py_UCS4(ctype.lower);
}
/* TODO:convert C to Swift
int _PyUnicode_ToLowerFull(Py_UCS4 ch, Py_UCS4 *res)
{
    const _PyUnicode_TypeRecord *ctype = getUnicodeTypeRecord(code:ch);

    if (ctype->flags & EXTENDED_CASE_MASK) {
        int index = ctype->lower & 0xFFFF;
        int n = ctype->lower >> 24;
        int i;
        for (i = 0; i < n; i++)
            res[i] = _PyUnicode_ExtendedCase[index + i];
        return n;
    }
    res[0] = ch + ctype->lower;
    return 1;
}

int _PyUnicode_ToTitleFull(Py_UCS4 ch, Py_UCS4 *res)
{
    const _PyUnicode_TypeRecord *ctype = getUnicodeTypeRecord(code:ch);

    if (ctype->flags & EXTENDED_CASE_MASK) {
        int index = ctype->title & 0xFFFF;
        int n = ctype->title >> 24;
        int i;
        for (i = 0; i < n; i++)
            res[i] = _PyUnicode_ExtendedCase[index + i];
        return n;
    }
    res[0] = ch + ctype->title;
    return 1;
}

int _PyUnicode_ToUpperFull(Py_UCS4 ch, Py_UCS4 *res)
{
    const _PyUnicode_TypeRecord *ctype = getUnicodeTypeRecord(code:ch);

    if (ctype->flags & EXTENDED_CASE_MASK) {
        int index = ctype->upper & 0xFFFF;
        int n = ctype->upper >> 24;
        int i;
        for (i = 0; i < n; i++)
            res[i] = _PyUnicode_ExtendedCase[index + i];
        return n;
    }
    res[0] = ch + ctype->upper;
    return 1;
}

int _PyUnicode_ToFoldedFull(Py_UCS4 ch, Py_UCS4 *res)
{
    const _PyUnicode_TypeRecord *ctype = getUnicodeTypeRecord(code:ch);

    if (ctype->flags & EXTENDED_CASE_MASK && (ctype->lower >> 20) & 7) {
        int index = (ctype->lower & 0xFFFF) + (ctype->lower >> 24);
        int n = (ctype->lower >> 20) & 7;
        int i;
        for (i = 0; i < n; i++)
            res[i] = _PyUnicode_ExtendedCase[index + i];
        return n;
    }
    return _PyUnicode_ToLowerFull(ch, res);
}
*/

func isCased(ch:Py_UCS4) -> Bool {
    let ctype = getUnicodeTypeRecord(code:ch);

    return (ctype.flags & CASED_MASK) != 0;
}

func isCaseIgnorable(ch:Py_UCS4) -> Bool {
    let ctype = getUnicodeTypeRecord(code:ch);

    return (ctype.flags & CASE_IGNORABLE_MASK) != 0;
}

/* Returns 1 for Unicode characters having the category 'Ll', 'Lu', 'Lt',
   'Lo' or 'Lm',  0 otherwise. */

func isAlpha(ch:Py_UCS4) -> Bool {
    let ctype = getUnicodeTypeRecord(code:ch);

    return (ctype.flags & ALPHA_MASK) != 0;
}

