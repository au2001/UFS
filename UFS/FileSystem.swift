//
//  FileSystem.swift
//  UFS
//
//  Created by Aurélien Garnier on 20/08/2019.
//  Copyright © 2019 JustKodding. All rights reserved.
//

import Foundation
import GoogleAPIClientForREST

final class FileSystem: NSObject {
    
    let driveStorage: DriveStorage
    var docsService: GTLRDocsService? {
        get {
            return self.driveStorage.getDocsService()
        }
    }
    var driveService: GTLRDriveService? {
        get {
            return self.driveStorage.getDriveService()
        }
    }
    
    init(withStorage driveStorage: DriveStorage) {
        self.driveStorage = driveStorage
    }

    override func contentsOfDirectory(atPath path: String!) throws -> [Any] {
        let contents = try self.driveStorage.contentsOfDirectory(atPath: path).map { file in
            return Utils.name(ofFile: file)
        }
        
        return contents
    }

    override func attributesOfItem(atPath path: String!, userData: Any!) throws -> [AnyHashable : Any] {
        guard !NSString(string: path).standardizingPath.split(separator: "/").isEmpty else {
            return [FileAttributeKey.type: FileAttributeType.typeDirectory]
        }
        
        var attributes = Utils.attributes(fromProperties: try self.driveStorage.propertiesOfItem(atPath: path))

        if attributes[FileAttributeKey.type] == nil {
            attributes[FileAttributeKey.type] = FileAttributeType.typeRegular
        }

        return attributes
    }

    override func attributesOfFileSystem(forPath path: String!) throws -> [AnyHashable : Any] {
        var attributes: [FileAttributeKey: Any] = [:]
        
        attributes[FileAttributeKey.systemSize] = Int.max
        attributes[FileAttributeKey.systemFreeSize] = Int.max
        attributes[FileAttributeKey.systemNodes] = 0
        attributes[FileAttributeKey.systemFreeNodes] = Int.max
        attributes[FileAttributeKey(rawValue: kGMUserFileSystemVolumeSupportsExtendedDatesKey)] = false
        attributes[FileAttributeKey(rawValue: kGMUserFileSystemVolumeMaxFilenameLengthKey)] = Int.max
        attributes[FileAttributeKey(rawValue: kGMUserFileSystemVolumeSupportsCaseSensitiveNamesKey)] = false
        
        return attributes
    }
    
}

