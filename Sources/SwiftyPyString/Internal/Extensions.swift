//
//  Extensions.swift
//  SwiftyPyString
//

import Foundation

extension StringProtocol {
    func adjustIndex(_ s: Int?, _ e: Int?) -> (Int, Int) {
        var start = s ?? 0
        var end = e ?? count
        if (end > count) {
            end = count
        } else if (end < 0) {
            end += count
            end = Swift.max(end, 0)
        }
        if (start < 0) {
            start += count
            start = Swift.max(start, 0)
        }
        return (start, end)
    }
    func slice(start: Int?, end: Int?) -> SubSequence {
        let (s, e) = adjustIndex(start, end)
        return dropLast(count - e).dropFirst(s)
    }
}

extension StringProtocol {
    func dropLast(while predicate: (Self.Element) throws -> Bool) rethrows -> SubSequence {
        var s = dropLast(0)
        while let l = s.last, try predicate(l) {
            s = s.dropLast()
        }
        return s
    }
}
