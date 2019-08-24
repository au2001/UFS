//
//  DriveStorage.swift
//  UFS
//
//  Created by Aurélien Garnier on 22/08/2019.
//  Copyright © 2019 JustKodding. All rights reserved.
//

import Foundation
import GTMAppAuth
import GoogleAPIClientForREST

private let kUFSKeychainName = "UFS Google Drive Authorization"
private let kGoogleAPIKey = "AIzaSyDWfRc2r7HsGC_GmeQpv6sqeZCAF6_Bw24"
private let kGoogleClientId = "164202260323-0t8fmdo5mohv4dbgfc5odt5oui6ggert.apps.googleusercontent.com"
private let kGoogleClientSecret = "b1tKeHkH-uSucMzNBks2LBh7"
private let kGoogleRedirectURI = URL(string: "com.googleusercontent.apps.164202260323-0t8fmdo5mohv4dbgfc5odt5oui6ggert:/oauthredirect")!
private let kGoogleScopes = [OIDScopeOpenID, OIDScopeProfile, OIDScopeEmail, kGTLRAuthScopeDocsDocuments, kGTLRAuthScopeDocsDrive, kGTLRAuthScopeDrive, kGTLRAuthScopeDriveMetadata]

class DriveStorage {
    
    private var authorizer: GTMFetcherAuthorizationProtocol?
    private var docsService: GTLRDocsService?
    private var driveService: GTLRDriveService?
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?
    
    public init(withCacheOfSize cacheSize: Int, atPath cachePath: String) {
        self.authorizer = GTMAppAuthFetcherAuthorization(fromKeychainForName: kUFSKeychainName)
        
        self.docsService = GTLRDocsService()
        self.docsService?.shouldFetchNextPages = true
        self.docsService?.isRetryEnabled = true
        self.docsService?.authorizer = self.authorizer
        self.docsService?.fetcherService.configuration = .default
        self.docsService?.fetcherService.configurationBlock = { (fetcher, config) in
            config.urlCache = URLCache(
                memoryCapacity: 0,
                diskCapacity: cacheSize,
                diskPath: cachePath)
            config.requestCachePolicy = .returnCacheDataElseLoad
        }
        self.docsService?.setMainBundleIDRestrictionWithAPIKey(kGoogleAPIKey)
        
        self.driveService = GTLRDriveService()
        self.driveService?.shouldFetchNextPages = true
        self.driveService?.isRetryEnabled = true
        self.driveService?.authorizer = self.authorizer
        self.driveService?.fetcherService.configuration = .default
        self.driveService?.fetcherService.configurationBlock = { (fetcher, config) in
            config.urlCache = URLCache(
                memoryCapacity: 0,
                diskCapacity: cacheSize,
                diskPath: cachePath)
            config.requestCachePolicy = .returnCacheDataElseLoad
        }
        self.driveService?.setMainBundleIDRestrictionWithAPIKey(kGoogleAPIKey)
    }
    
    func handle(url: URL) -> Bool {
        return self.currentAuthorizationFlow?.resumeExternalUserAgentFlow(with: url) ?? false
    }
    
    public func signIn(callback: @escaping (Error?) -> ()) {
        if self.isSignedIn() {
            callback(nil)
            return
        }
        
        let configuration = GTMAppAuthFetcherAuthorization.configurationForGoogle()
        let request = OIDAuthorizationRequest(configuration: configuration, clientId: kGoogleClientId, clientSecret: kGoogleClientSecret, scopes: kGoogleScopes, redirectURL: kGoogleRedirectURI, responseType: OIDResponseTypeCode, additionalParameters: nil)
        
        self.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, callback: { (state, error) in
            if error != nil {
                callback(error)
                return
            }
            
            guard let state = state else {
                callback(UFSAuthError.stateNil)
                return
            }
            
            guard let docsService = self.docsService else {
                callback(UFSAuthError.docsServiceNil)
                return
            }
            
            guard let driveService = self.driveService else {
                callback(UFSAuthError.driveServiceNil)
                return
            }
            
            let authorization = GTMAppAuthFetcherAuthorization(authState: state)
            self.authorizer = authorization
            docsService.authorizer = self.authorizer
            driveService.authorizer = self.authorizer
            GTMAppAuthFetcherAuthorization.save(authorization, toKeychainForName: kUFSKeychainName)
            callback(nil)
        })
    }
    
    public func signOut() {
        self.docsService?.authorizer = nil
        self.driveService?.authorizer = nil
        self.authorizer?.stopAuthorization()
        self.authorizer = nil
        GTMAppAuthFetcherAuthorization.removeFromKeychain(forName: kUFSKeychainName)
    }
    
    public func isSignedIn() -> Bool {
        return self.authorizer?.canAuthorize ?? false
    }
    
    public func getUserEmail() -> String? {
        return self.authorizer?.userEmail
    }
    
    public func getDocsService() -> GTLRDocsService? {
        return self.isSignedIn() ? self.docsService : nil
    }
    
    public func getDriveService() -> GTLRDriveService? {
        return self.isSignedIn() ? self.driveService : nil
    }
    
    fileprivate func createRoot() throws -> String {
        guard self.isSignedIn() else {
            print("Unauthorized")
            throw UFSAuthError.unauthorized
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var dataOut: String?
        var errorOut: Error?
        
        let file = GTLRDrive_File(json: [
            "name": "UFS",
            "mimeType": "application/vnd.google-apps.folder",
            "properties": [
                "UFS_Root": "true"
            ],
            "parents": []
        ])
        
        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: nil)
        query.fields = "id"
        
        _ = DispatchQueue.main.sync {
            return self.driveService?.executeQuery(query) { (ticket, data, error) in
                if let error = error {
                    errorOut = error
                    semaphore.signal()
                    return
                }
                
                guard let file = data as? GTLRDrive_File else {
                    print("Unable to decode data")
                    semaphore.signal()
                    return
                }
                
                dataOut = file.identifier
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        
        if let errorOut = errorOut {
            print(errorOut)
            throw errorOut
        }
        
        if let dataOut = dataOut {
            return dataOut
        } else {
            print("Unable to create root")
            throw UFSError.noData
        }
    }
    
    public func root() throws -> String {
        guard self.isSignedIn() else {
            print("Unauthorized")
            throw UFSAuthError.unauthorized
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var dataOut: String?
        var errorOut: Error?
        
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "properties has {key='UFS_Root' and value='true'} and trashed=false"
        query.fields = "files(id)"
        query.pageSize = 1000
        
        _ = DispatchQueue.main.sync {
            return self.driveService?.executeQuery(query) { (ticket, data, error) in
                if let error = error {
                    errorOut = error
                    semaphore.signal()
                    return
                }
                
                guard let data = data as? GTLRDrive_FileList, let files = data.files else {
                    print("Unable to decode data")
                    semaphore.signal()
                    return
                }
                
                dataOut = files.first?.identifier
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        
        if let errorOut = errorOut {
            print(errorOut)
            throw errorOut
        }
        
        if let dataOut = dataOut {
            return dataOut
        } else {
            return try self.createRoot()
        }
    }
    
    public func id(forPath path: String) throws -> String {
        return try self.id(forPath: path, in: self.root())
    }
    
    public func id(forPath path: String, in parent: String) throws -> String {
        guard self.isSignedIn() else {
            print("Unauthorized")
            throw UFSAuthError.unauthorized
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var dataOut: String?
        var errorOut: Error?

        let pathComponents = NSString(string: path).standardizingPath.split(separator: "/")

        guard let name = pathComponents.first else {
            return parent
        }
        
        let nextPath = pathComponents.dropFirst().joined(separator: "/")
        
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "name='\(name)' and '\(parent)' in parents and trashed=false"
        query.fields = "files(id)"
        query.pageSize = 1000
        
        _ = DispatchQueue.main.sync {
            return self.driveService?.executeQuery(query) { (ticket, data, error) in
                if let error = error {
                    errorOut = error
                    semaphore.signal()
                    return
                }
                
                guard let data = data as? GTLRDrive_FileList, let files = data.files else {
                    print("Unable to decode data")
                    semaphore.signal()
                    return
                }
                
                dataOut = files.first?.identifier
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        
        if let errorOut = errorOut {
            print(errorOut)
            throw errorOut
        }
        
        if let dataOut = dataOut {
            return try self.id(forPath: nextPath, in: dataOut)
        } else {
            return try self.createRoot()
        }
    }
    
    public func propertiesOfItem(atPath path: String) throws -> [String: String] {
        return [:] // TODO
    }
    
    public func contentsOfDirectory(atPath path: String) throws -> [GTLRDrive_File] {
        guard self.isSignedIn() else {
            print("Unauthorized")
            throw UFSAuthError.unauthorized
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var dataOut: [GTLRDrive_File]?
        var errorOut: Error?
        
        let parent = try self.id(forPath: path)
        
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "'\(parent)' in parents and trashed=false"
        query.fields = "files(id, name)"
        query.pageSize = 1000
        
        _ = DispatchQueue.main.sync {
            return self.driveService?.executeQuery(query) { (ticket, data, error) in
                if let error = error {
                    errorOut = error
                    semaphore.signal()
                    return
                }

                guard let data = data as? GTLRDrive_FileList, let files = data.files else {
                    print("Unable to decode data")
                    semaphore.signal()
                    return
                }

                dataOut = files
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        
        if let errorOut = errorOut {
            print(errorOut)
            throw errorOut
        }

        if let dataOut = dataOut {
            return dataOut
        } else {
            print("Unable to find directory \(path)")
            throw UFSError.noData
        }
    }
    
}

