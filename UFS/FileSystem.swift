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
    
    let rootPath = "/" // TODO
    
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
    
    // MARK: - Moving an Item
    override func moveItem(atPath source: String!, toPath destination: String!) throws {
        let sourcePath = (self.rootPath.appending(source) as NSString).utf8String!
        let destinationPath = (self.rootPath.appending(destination) as NSString).utf8String!
        
        let returnValue = rename(sourcePath, destinationPath)
        if returnValue < 0 {
            throw NSError(posixErrorCode: errno)
        }
    }
    
    // MARK: - Removing an Item
    override func removeDirectory(atPath path: String!) throws {
        // We need to special-case directories here and use the bsd API since
        // NSFileManager will happily do a recursive remove :-(
        let originalPath = (self.rootPath.appending(path) as NSString).utf8String!
        
        let returnValue = rmdir(originalPath)
        if returnValue < 0 {
            throw NSError(posixErrorCode: errno)
        }
    }
    
    override func removeItem(atPath path: String!) throws {
        let originalPath = self.rootPath.appending(path)
        
        return try FileManager.default.removeItem(atPath: originalPath)
    }
    
    // MARK: - Creating an Item
    override func createDirectory(atPath path: String!, attributes: [AnyHashable : Any]! = [:]) throws {
        guard let attributes = attributes as? [FileAttributeKey: Any] else { throw NSError(posixErrorCode: EPERM) }
        
        let originalPath = self.rootPath.appending(path)
        
        try FileManager.default.createDirectory(atPath: originalPath, withIntermediateDirectories: false, attributes: attributes)
    }
    
    override func createFile(atPath path: String!, attributes: [AnyHashable : Any]! = [:], flags: Int32, userData: AutoreleasingUnsafeMutablePointer<AnyObject?>!) throws {
        
        guard let mode = attributes[FileAttributeKey.posixPermissions] as? mode_t else {
            throw NSError(posixErrorCode: EPERM)
        }
        
        let originalPath = self.rootPath.appending(path)
        
        let fileDescriptor = open((originalPath as NSString).utf8String!, flags, mode)
        
        if fileDescriptor < 0 {
            throw NSError(posixErrorCode: errno)
        }
        
        userData.pointee = NSNumber(value: fileDescriptor)
    }
    
    // MARK: - Linking an Item
    override func linkItem(atPath path: String!, toPath otherPath: String!) throws {
        let originalPath = (self.rootPath.appending(path) as NSString).utf8String!
        let originalOtherPath = (self.rootPath.appending(otherPath) as NSString).utf8String!
        
        // We use link rather than the NSFileManager equivalent because it will copy
        // the file rather than hard link if part of the root path is a symlink.
        if link(originalPath, originalOtherPath) < 0 {
            throw NSError(posixErrorCode: errno)
        }
    }
    
    // MARK: - Symbolic Links
    override func createSymbolicLink(atPath path: String!, withDestinationPath otherPath: String!) throws {
        let sourcePath = self.rootPath.appending(path)
        try FileManager.default.createSymbolicLink(atPath: sourcePath, withDestinationPath: otherPath)
    }
    
    override func destinationOfSymbolicLink(atPath path: String!) throws -> String {
        let sourcePath = self.rootPath.appending(path)
        return try FileManager.default.destinationOfSymbolicLink(atPath: sourcePath)
    }
    
    // MARK: - File Contents
    override func openFile(atPath path: String!, mode: Int32, userData: AutoreleasingUnsafeMutablePointer<AnyObject?>!) throws {
        let originalPath = (self.rootPath.appending(path) as NSString).utf8String!
        
        let fileDescriptor = open(originalPath, mode)
        
        if fileDescriptor < 0 {
            throw NSError(posixErrorCode: errno)
        }
        
        userData.pointee = NSNumber(value: fileDescriptor)
    }
    
    override func releaseFile(atPath path: String!, userData: Any!) {
        guard let num = userData as? NSNumber else {
            return
        }
        
        let fileDescriptor = num.int32Value
        close(fileDescriptor)
    }
    
    override func readFile(atPath path: String!, userData: Any!, buffer: UnsafeMutablePointer<Int8>!, size: Int, offset: off_t, error: NSErrorPointer) -> Int32 {
        guard let num = userData as? NSNumber else {
            error?.pointee = NSError(posixErrorCode: EBADF)
            return -1
        }
        
        let fileDescriptor = num.int32Value
        let returnValue = Int32(pread(fileDescriptor, buffer, size, offset))
        
        if returnValue < 0 {
            error?.pointee = NSError(posixErrorCode: errno)
            return -1
        }
        return returnValue
    }
    
    override func writeFile(atPath path: String!, userData: Any!, buffer: UnsafePointer<Int8>!, size: Int, offset: off_t, error: NSErrorPointer) -> Int32 {
        guard let num = userData as? NSNumber else {
            error?.pointee = NSError(posixErrorCode: EBADF)
            return -1
        }
        
        let fileDescriptor = num.int32Value
        
        let returnValue = pwrite(fileDescriptor, buffer, size, offset)
        if returnValue < 0 {
            error?.pointee = NSError(posixErrorCode: errno)
        }
        return Int32(returnValue)
    }
    
    override func preallocateFile(atPath path: String!, userData: Any!, options: Int32, offset: off_t, length: off_t) throws {
        guard let num = userData as? NSNumber else {
            throw NSError(posixErrorCode: EBADF)
        }
        
        let fileDescriptor = num.int32Value
        
        var fstore = fstore_t()
        if options & ALLOCATECONTIG == 1 {
            fstore.fst_flags = UInt32(F_ALLOCATECONTIG)
        }
        if options & ALLOCATEALL == 1 {
            fstore.fst_flags = fstore.fst_flags & UInt32(ALLOCATEALL)
        }
        if options & ALLOCATEFROMPEOF == 1 {
            fstore.fst_posmode = F_PEOFPOSMODE
        } else if options & ALLOCATEFROMVOL == 1 {
            fstore.fst_posmode = F_VOLPOSMODE
        }
        fstore.fst_offset = offset
        fstore.fst_length = length
        if fcntl(fileDescriptor, F_PREALLOCATE, &fstore) == -1 {
            throw NSError(posixErrorCode: errno)
        }
    }
    
    public override func exchangeDataOfItem(atPath path1: String!, withItemAtPath path2: String!) throws {
        let sourcePath = (self.rootPath.appending(path1) as NSString).utf8String!
        let destinationPath = (self.rootPath.appending(path2) as NSString).utf8String!
        
        let returnValue = exchangedata(sourcePath, destinationPath, 0)
        if returnValue < 0 {
            throw NSError(posixErrorCode: errno)
        }
    }
    
    // MARK: - Directory Contents
    override func contentsOfDirectory(atPath path: String!) throws -> [Any] {
        let originalPath = self.rootPath.appending(path)
        return try FileManager.default.contentsOfDirectory(atPath: originalPath)
    }
    
    // MARK: - Getting and Setting Attributes
    override func attributesOfItem(atPath path: String!, userData: Any!) throws -> [AnyHashable : Any] {
        let originalPath = self.rootPath.appending(path)
        return try FileManager.default.attributesOfItem(atPath: originalPath)
    }
    
    override func attributesOfFileSystem(forPath path: String!) throws -> [AnyHashable : Any] {
        let originalPath = self.rootPath.appending(path)
        
        var attributes = try FileManager.default.attributesOfFileSystem(forPath: originalPath)
        attributes[FileAttributeKey(rawValue: kGMUserFileSystemVolumeSupportsExtendedDatesKey)] = true
        
        let originalUrl = URL(fileURLWithPath: originalPath, isDirectory: true)
        
        let volumeSupportsCaseSensitiveNames = try originalUrl.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]).volumeSupportsCaseSensitiveNames ?? true
        attributes[FileAttributeKey(rawValue: kGMUserFileSystemVolumeSupportsCaseSensitiveNamesKey)] = volumeSupportsCaseSensitiveNames
        
        return attributes
    }
    
    override func setAttributes(_ attributes: [AnyHashable : Any]!, ofItemAtPath path: String!, userData: Any!) throws {
        guard let attribs = attributes as? [FileAttributeKey: Any] else { throw NSError(posixErrorCode: EINVAL) }
        
        let originalPath = self.rootPath.appending(path)
        
        if let pathPointer = (originalPath as NSString).utf8String {
            if let offset = attributes[FileAttributeKey.size.rawValue] as? Int64 {
                let ret = truncate(pathPointer, offset)
                if ret < 0 {
                    throw NSError(posixErrorCode: errno)
                }
            }
            
            if let flags = attributes[kGMUserFileSystemFileFlagsKey] as? Int32 {
                let rc = chflags(pathPointer, UInt32(flags))
                if rc < 0 {
                    throw NSError(posixErrorCode: errno)
                }
            }
        }
        
        try FileManager.default.setAttributes(attribs, ofItemAtPath: originalPath)
    }
    
}

