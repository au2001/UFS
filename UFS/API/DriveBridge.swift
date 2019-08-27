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
    var docsService: GTLRDocsService? {
        get {
            return self.driveHandler.getDocsService()
        }
    }
    var driveService: GTLRDriveService? {
        get {
            return self.driveHandler.getDriveService()
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
    
    fileprivate func createRoot() throws -> String {
        let json = GTLRDrive_File(json: [
            "name": "UFS",
            "mimeType": "application/vnd.google-apps.folder",
            "properties": [
                "UFS": "root"
            ],
            "parents": []
        ])
        
        let query = GTLRDriveQuery_FilesCreate.query(withObject: json, uploadParameters: nil)
        query.fields = "id, parents"
        
        let file = try self.driveHandler.execute(query: query, withOutputType: GTLRDrive_File.self)
        
        try self.hide(file: file)
        
        if let identifier = file.identifier {
            return identifier
        } else {
            throw UFSError.noData
        }
    }
    
    public func root() throws -> String {
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "properties has {key='UFS' and value='root'} and trashed=false"
        query.fields = "files(id)"
        query.pageSize = 1000
        
        let fileList = try self.driveHandler.execute(query: query, withOutputType: GTLRDrive_FileList.self)
        
        if let identifier = fileList.files?.first?.identifier {
            return identifier
        } else {
            return try self.createRoot()
        }
    }
    
    public func id(forPath path: String, in parent: String) throws -> String {
        let pathComponents = NSString(string: path).standardizingPath.split(separator: "/")
        
        guard let name = pathComponents.first else {
            return parent
        }
        
        let nextPath = pathComponents.dropFirst().joined(separator: "/")
        
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "name='\(name)' and '\(parent)' in parents and properties has {key='UFS' and value='directory'} and trashed=false"
        query.fields = "files(id)"
        query.pageSize = 1000
        
        let fileList = try self.driveHandler.execute(query: query, withOutputType: GTLRDrive_FileList.self)
        
        if let identifier = fileList.files?.first?.identifier {
            return try self.id(forPath: nextPath, in: identifier)
        } else {
            throw UFSError.noData
        }
    }
    
    public func id(forPath path: String) throws -> String {
        let root = try self.root()

        return try self.id(forPath: path, in: root)
    }
    
    public func propertiesOfItem(atPath path: String) throws -> GTLRDrive_File_Properties {
        let identifier = try self.id(forPath: path)
        
        let query = GTLRDriveQuery_FilesGet.query(withFileId: identifier)
        query.fields = "properties"
        
        let file = try self.driveHandler.execute(query: query, withOutputType: GTLRDrive_File.self)
        
        if let properties = file.properties {
            return properties
        } else {
            throw UFSError.noData
        }
    }
    
    public func contentsOfDirectory(atPath path: String) throws -> [GTLRDrive_File] {
        let identifier = try self.id(forPath: path)
        
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "'\(identifier)' in parents and (properties has {key='UFS' and value='directory'} or properties has {key='UFS' and value='file'}) and trashed=false"
        query.fields = "files(id, name)"
        query.pageSize = 1000
        
        let fileList = try self.driveHandler.execute(query: query, withOutputType: GTLRDrive_FileList.self)
        
        if let files = fileList.files {
            return files
        } else {
            throw UFSError.noData
        }
    }
    
}
