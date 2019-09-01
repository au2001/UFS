//
//  DriveBridge.swift
//  UFS
//
//  Created by Aurélien Garnier on 26/08/2019.
//  Copyright © 2019 JustKodding. All rights reserved.
//

import Foundation
import GoogleAPIClientForREST

class DriveBridge {
    
    let driveHandler: DriveHandler
    var driveService: GTLRDriveService? {
        get {
            return self.driveHandler.getDriveService()
        }
    }
    var sheetsService: GTLRSheetsService? {
        get {
            return self.driveHandler.getSheetsService()
        }
    }
    
    init(forDriveHandler driveHandler: DriveHandler) {
        self.driveHandler = driveHandler
    }
    
    fileprivate func hide(file: GTLRDrive_File) throws {
        guard let parents = file.parents?.joined(separator: ","), !parents.isEmpty else {
            return
        }
        
        let identifier = file.identifier!
        let json = GTLRDrive_File(json: [:])
        
        let query = GTLRDriveQuery_FilesUpdate.query(withObject: json, fileId: identifier, uploadParameters: nil)
        query.removeParents = parents
        
        _ = try self.driveHandler.execute(query: query)
    }
    
    fileprivate func createRoot() throws -> GTLRDrive_File {
        let json = GTLRDrive_File(json: [:])
        json.name = "UFS"
        json.mimeType = "application/vnd.google-apps.folder"
        json.properties = GTLRDrive_File_Properties(json: [
            "UFS": "root"
        ])
        
        let query = GTLRDriveQuery_FilesCreate.query(withObject: json, uploadParameters: nil)
        query.fields = "id, parents"
        
        let file = try self.driveHandler.execute(query: query, withOutputType: GTLRDrive_File.self)
        
        if let file = file {
            try self.hide(file: file)
            return file
        } else {
            throw NSError(posixErrorCode: EAGAIN)
        }
    }
    
    public func rootFile() throws -> GTLRDrive_File {
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "properties has {key='UFS' and value='root'} and trashed=false"
        query.fields = "files(id)"
        query.pageSize = 1000
        
        let fileList = try self.driveHandler.execute(query: query, withOutputType: GTLRDrive_FileList.self)
        
        if let file = fileList?.files?.first {
            return file
        } else {
            return try self.createRoot()
        }
    }
    
    public func root() throws -> String { // TODO: Cache
        if let identifier = try self.rootFile().identifier {
            return identifier
        } else {
            throw NSError(posixErrorCode: EAGAIN)
        }
    }
    
    public func file(atPath path: String, in parent: GTLRDrive_File) throws -> GTLRDrive_File { // TODO: Cache
        let pathComponents = NSString(string: path).standardizingPath.split(separator: "/")
        
        guard let name = pathComponents.first else {
            return parent
        }
        
        let nextPath = pathComponents.dropFirst().joined(separator: "/")
        
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "name='\(name)' and '\(parent.identifier ?? "")' in parents and (properties has {key='UFS' and value='directory'} or properties has {key='UFS' and value='file'}) and trashed=false"
        query.fields = "files(id, name)"
        query.pageSize = 1000
        
        let fileList = try self.driveHandler.execute(query: query, withOutputType: GTLRDrive_FileList.self)
        
        if let file = fileList?.files?.first {
            return try self.file(atPath: nextPath, in: file)
        } else {
            throw NSError(posixErrorCode: ENOENT)
        }
    }
    
    public func file(atPath path: String) throws -> GTLRDrive_File {
        let root = try self.rootFile()
        
        return try self.file(atPath: path, in: root)
    }
    
    public func id(forPath path: String) throws -> String {
        if let identifier = try self.file(atPath: path).identifier {
            return identifier
        } else {
            throw NSError(posixErrorCode: EAGAIN)
        }
    }
    
    public func propertiesOfFile(atPath path: String) throws -> GTLRDrive_File_Properties { // TODO: Cache & Hard links
        let identifier = try self.id(forPath: path)
        
        let query = GTLRDriveQuery_FilesGet.query(withFileId: identifier)
        query.fields = "properties"
        
        let file = try self.driveHandler.execute(query: query, withOutputType: GTLRDrive_File.self)
        
        if let properties = file?.properties {
            return properties
        } else {
            throw NSError(posixErrorCode: ENOENT)
        }
    }
    
    public func contentsOfDirectory(atPath path: String) throws -> [GTLRDrive_File] { // TODO: Cache & Hard links
        let identifier = try self.id(forPath: path)
        
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "'\(identifier)' in parents and (properties has {key='UFS' and value='directory'} or properties has {key='UFS' and value='file'}) and trashed=false"
        query.fields = "files(id, name)"
        query.pageSize = 1000
        
        let fileList = try self.driveHandler.execute(query: query, withOutputType: GTLRDrive_FileList.self)
        
        if let files = fileList?.files {
            return files
        } else {
            throw NSError(posixErrorCode: EAGAIN)
        }
    }
    
    public func setProperties(_ properties: GTLRDrive_File_Properties, ofFileAtPath path: String) throws {
        let identifier = try self.id(forPath: path)
        let json = GTLRDrive_File(json: [:])
        json.properties = properties
        
        let query = GTLRDriveQuery_FilesUpdate.query(withObject: json, fileId: identifier, uploadParameters: nil)
        
        _ = try self.driveHandler.execute(query: query)
    }
    
    public func createDirectory(atPath path: String, properties: GTLRDrive_File_Properties) throws -> String { // TODO: Already exists
        let parent = try self.id(forPath: NSString(string: path).deletingLastPathComponent)
        
        properties.json?["UFS"] = "directory"

        let json = GTLRDrive_File(json: [:])
        json.name = NSString(string: path).lastPathComponent
        json.properties = properties
        json.mimeType = "application/vnd.google-apps.folder"
        json.parents = [parent]
        
        let query = GTLRDriveQuery_FilesCreate.query(withObject: json, uploadParameters: nil)
        query.fields = "id"
        
        let file = try self.driveHandler.execute(query: query, withOutputType: GTLRDrive_File.self)
        
        if let identifier = file?.identifier {
            return identifier
        } else {
            throw NSError(posixErrorCode: EAGAIN)
        }
    }
    
    public func createFile(atPath path: String, properties: GTLRDrive_File_Properties) throws -> String { // TODO: Already exists
        let parent = try self.id(forPath: NSString(string: path).deletingLastPathComponent)
        
        properties.json?["UFS"] = "file"
        
        let json = GTLRDrive_File(json: [:])
        json.name = NSString(string: path).lastPathComponent
        json.properties = properties
        json.mimeType = "application/vnd.google-apps.spreadsheet"
        json.parents = [parent]
        
        let query = GTLRDriveQuery_FilesCreate.query(withObject: json, uploadParameters: nil)
        query.fields = "id"
        
        let file = try self.driveHandler.execute(query: query, withOutputType: GTLRDrive_File.self)
        
        if let identifier = file?.identifier {
            return identifier
        } else {
            throw NSError(posixErrorCode: EAGAIN)
        }
    }
    
    public func moveFile(atPath source: String, toPath destination: String) throws { // TODO: Already exists
        let identifier = try self.id(forPath: source)
        let parent = try self.id(forPath: NSString(string: destination).deletingLastPathComponent)
        
        let query1 = GTLRDriveQuery_FilesGet.query(withFileId: identifier)
        query1.fields = "parents"
        
        let file = try self.driveHandler.execute(query: query1, withOutputType: GTLRDrive_File.self)
        
        guard let parents = file?.parents?.filter({ identifier -> Bool in
            return identifier != parent
        }) else {
            return
        }
        
        let json = GTLRDrive_File(json: [:])
        json.name = NSString(string: destination).lastPathComponent
        
        let query2 = GTLRDriveQuery_FilesUpdate.query(withObject: json, fileId: identifier, uploadParameters: nil)
        if !parents.isEmpty {
            query2.removeParents = parents.joined(separator: ",")
        }
        if !parents.contains(parent) {
            query2.addParents = parent
        }
        
        _ = try self.driveHandler.execute(query: query2)
    }
    
    func removeFile(atPath path: String!) throws {
        let identifier = try self.id(forPath: path)
        
        let query = GTLRDriveQuery_FilesDelete.query(withFileId: identifier)
        
        _ = try self.driveHandler.execute(query: query)
    }
    
}

