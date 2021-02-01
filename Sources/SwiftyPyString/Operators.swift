//
//  Operators.swift
//  SwiftyPyString
//
//

import Foundation

@inlinable
public func *<T:StringProtocol> (str: T, n: Int) -> String {
    return repeatElement(str, count: n > 0 ? n : 0).joined()
}

@inlinable
public func *<T:StringProtocol> (n: Int, str: T) -> String {
    return str * n
}

@inlinable
public func * (str: String, n: Int) -> String {
    return String(repeating: str, count: n > 0 ? n : 0)
}

@inlinable
public func * (n: Int, str: String) -> String {
    return str * n
}

@inlinable
public func * (char: Character, n: Int) -> String {
    return String(repeating: char, count: n > 0 ? n : 0)
}

@inlinable
public func * (n: Int, char: Character) -> String {
    return char * n
}

@inlinable
public func *= (str: inout String, n: Int) {
    str = str * n
}
