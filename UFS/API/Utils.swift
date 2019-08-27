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
    
    public static func attributes(fromProperties properties: GTLRDrive_File_Properties) -> [FileAttributeKey: Any] {
        var attributes: [FileAttributeKey: Any] = [:]
        
        properties.additionalProperties().forEach { (key, value) in
            switch(key.lowercased()) {
            case "type":
                switch((value as? String)?.lowercased()) {
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
                attributes[FileAttributeKey.size] = value as? Int
                
            case "modification_date":
                if let timeInterval = value as? TimeInterval {
                    attributes[FileAttributeKey.modificationDate] = Date(timeIntervalSince1970: timeInterval)
                }
                
            case "creation_date":
                if let timeInterval = value as? TimeInterval {
                    attributes[FileAttributeKey.creationDate] = Date(timeIntervalSince1970: timeInterval)
                }

            case "extension_hidden":
                attributes[FileAttributeKey.extensionHidden] = value as? Bool

            default:
                break
            }
        }
        
        return attributes
    }
    
    public static func properties(fromAttributes attributes: [FileAttributeKey: Any]) -> GTLRDrive_File_Properties {
        var properties: [AnyHashable: Any] = [:]
        
        attributes.forEach { (key, value) in
            switch(key) {
            case .type:
                switch(value as? FileAttributeType) {
                case FileAttributeType.typeDirectory:
                    properties["type"] = "directory"
                case FileAttributeType.typeRegular:
                    properties["type"] = "regular"
                case FileAttributeType.typeSymbolicLink:
                    properties["type"] = "symbolic_link"
                case FileAttributeType.typeSocket:
                    properties["type"] = "socket"
                case FileAttributeType.typeCharacterSpecial:
                    properties["type"] = "character_special"
                case FileAttributeType.typeBlockSpecial:
                    properties["type"] = "block_special"
                case FileAttributeType.typeUnknown:
                    properties["type"] = "unknown"
                default:
                    break
                }
                
            case .size:
                properties["size"] = value as? Int
                
            case .modificationDate:
                if let date = value as? Date {
                    properties["modification_date"] = date.timeIntervalSince1970
                }
                
            case .creationDate:
                if let date = value as? Date {
                    properties["creation_date"] = date.timeIntervalSince1970
                }
                
            case .extensionHidden:
                properties["extension_hidden"] = value as? Bool
                
            default:
                break
            }
        }
        
        return GTLRDrive_File_Properties(json: properties)
    }
    
}
