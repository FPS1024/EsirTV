//
//  VodCategory.swift
//  EsirTV
//

import Foundation

struct VodCategory: Identifiable, Hashable {
    let typeId: Int
    let typeName: String

    var id: Int { typeId }

    init(typeId: Int, typeName: String) {
        self.typeId = typeId
        self.typeName = typeName
    }

    init?(dictionary: [String: Any]) {
        typeId = FlexibleJSON.int(from: dictionary["type_id"])
        typeName = FlexibleJSON.string(from: dictionary["type_name"])
        if typeName.isEmpty { return nil }
    }
}
