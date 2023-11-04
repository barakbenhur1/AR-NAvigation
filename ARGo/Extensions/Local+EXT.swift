//
//  Local+EXT.swift
//  ARGo
//
//  Created by ברק בן חור on 04/11/2023.
//

import Foundation

extension Locale {
    static func getDescription(id: String) -> String? {
        let current = Locale.current.language.languageCode?.identifier
        let language = NSLocale.init(localeIdentifier: current!)
        return language.displayName(forKey: NSLocale.Key.identifier, value: id)?.description
    }
}
