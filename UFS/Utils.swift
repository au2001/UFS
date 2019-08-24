//
//  Utils.swift
//  UFS
//
//  Created by Aurélien Garnier on 24/08/2019.
//  Copyright © 2019 JustKodding. All rights reserved.
//

import Foundation
import GoogleAPIClientForREST

class Utils {
    
    fileprivate init() {}
    
    public static func name(ofFile file: GTLRDrive_File) -> String {
        var name = file.name ?? ""
        
        name = String(name.prefix(255))
        name = name.replacingOccurrences(of: ":", with: "-")
        name = name.replacingOccurrences(of: "/", with: ":")
        
        return name
    }
    
    public static func attributes(fromProperties properties: [String: String]) -> [FileAttributeKey: Any] {
        var attributes: [FileAttributeKey: Any] = [:]
        
        properties.forEach { (key, value) in
            switch(key.lowercased()) {
            case "type":
                switch(value.lowercased()) {
                case "directory":
                    attributes[FileAttributeKey.type] = FileAttributeType.typeDirectory
                case "regular":
                    attributes[FileAttributeKey.type] = FileAttributeType.typeRegular
                case "symbolic_link":
                    attributes[FileAttributeKey.type] = FileAttributeType.typeSymbolicLink
                case "socket":
                    attributes[FileAttributeKey.type] = FileAttributeType.typeSocket
                case "character_special":
                    attributes[FileAttributeKey.type] = FileAttributeType.typeCharacterSpecial
                case "block_special":
                    attributes[FileAttributeKey.type] = FileAttributeType.typeBlockSpecial
                case "unknown":
                    attributes[FileAttributeKey.type] = FileAttributeType.typeUnknown
                default:
                    break
                }

            case "size":
                attributes[FileAttributeKey.size] = Int(value)
                
            case "modification_date":
                if let timeInterval = TimeInterval(value) {
                    attributes[FileAttributeKey.modificationDate] = Date(timeIntervalSince1970: timeInterval)
                }
                
            case "creation_date":
                if let timeInterval = TimeInterval(value) {
                    attributes[FileAttributeKey.creationDate] = Date(timeIntervalSince1970: timeInterval)
                }

            case "extension_hidden":
                attributes[FileAttributeKey.extensionHidden] = Bool(value)

            default:
                break
            }
        }
        
        return attributes
    }
    
}
