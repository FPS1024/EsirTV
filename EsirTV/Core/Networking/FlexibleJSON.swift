//
//  FlexibleJSON.swift
//  EsirTV
//

import Foundation

enum FlexibleJSON {
    static func string(from value: Any?) -> String {
        switch value {
        case let s as String:
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        case let i as Int:
            return String(i)
        case let d as Double:
            return String(Int(d))
        default:
            return ""
        }
    }

    static func int(from value: Any?, default defaultValue: Int = 0) -> Int {
        switch value {
        case let i as Int:
            return i
        case let s as String:
            return Int(s) ?? defaultValue
        case let d as Double:
            return Int(d)
        default:
            return defaultValue
        }
    }
}

extension JSONDecoder {
    static func decodeJSONObject<T>(_ type: T.Type, from data: Data) throws -> T where T: Any {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let typed = object as? T else {
            throw TVBoxHTTPError.decodeFailed
        }
        return typed
    }
}
