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
    
    let driveBridge: DriveBridge
    
    init(withBridge driveBridge: DriveBridge) {
        self.driveBridge = driveBridge
    }

    override func contentsOfDirectory(atPath path: String!) throws -> [Any] {
        do {
            let contents = try self.driveBridge.contentsOfDirectory(atPath: path).map { file in
                return Utils.name(ofFile: file)
            }

            return contents
        } catch let e {
            print("Error: contentsOfDirectory(atPath: \"\(path!)\") -> \(e)")
            throw e
        }
    }

    override func attributesOfItem(atPath path: String!, userData: Any!) throws -> [AnyHashable: Any] {
        guard !NSString(string: path).standardizingPath.split(separator: "/").isEmpty else {
            return [FileAttributeKey.type: FileAttributeType.typeDirectory]
        }

        do {
            var attributes = Utils.attributes(fromProperties: try self.driveBridge.propertiesOfItem(atPath: path))

            if attributes[FileAttributeKey.type] == nil {
                attributes[FileAttributeKey.type] = FileAttributeType.typeRegular
            }

            return attributes
        } catch let e {
            print("Error: attributesOfItem(atPath: \"\(path!)\") -> \(e)")
            throw e
        }
    }

    override func attributesOfFileSystem(forPath path: String!) throws -> [AnyHashable: Any] {
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
    
    override func setAttributes(_ attributes: [AnyHashable : Any]!, ofItemAtPath path: String!, userData: Any!) throws {
//        *   <li>NSFileSize
//        *   <li>NSFileModificationDate
//        *   <li>NSFileCreationDate                  (if supports extended dates)
//        *   <li>kGMUserFileSystemFileBackupDateKey  (if supports extended dates)
//        *   <li>kGMUserFileSystemFileChangeDateKey
//        *   <li>kGMUserFileSystemFileAccessDateKey
//        *   <li>kGMUserFileSystemFileFlagsKey
    }
    
}

