//
//  DriveHandler.swift
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
private let kGoogleScopes = [OIDScopeOpenID, OIDScopeProfile, OIDScopeEmail, kGTLRAuthScopeDrive, kGTLRAuthScopeDriveMetadata, kGTLRAuthScopeSheetsDrive, kGTLRAuthScopeSheetsSpreadsheets]

class DriveHandler {
    
    private var authorizer: GTMFetcherAuthorizationProtocol?
    private var driveService: GTLRDriveService?
    private var sheetsService: GTLRSheetsService?
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?
    
    public init(withCacheOfSize cacheSize: Int, atPath cachePath: String) {
        self.authorizer = GTMAppAuthFetcherAuthorization(fromKeychainForName: kUFSKeychainName)
        
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

        self.sheetsService = GTLRSheetsService()
        self.sheetsService?.shouldFetchNextPages = true
        self.sheetsService?.isRetryEnabled = true
        self.sheetsService?.authorizer = self.authorizer
        self.sheetsService?.fetcherService.configuration = .default
        self.sheetsService?.fetcherService.configurationBlock = { (fetcher, config) in
            config.urlCache = URLCache(
                memoryCapacity: 0,
                diskCapacity: cacheSize,
                diskPath: cachePath)
            config.requestCachePolicy = .returnCacheDataElseLoad
        }
        self.sheetsService?.setMainBundleIDRestrictionWithAPIKey(kGoogleAPIKey)
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
            
            guard let driveService = self.driveService else {
                callback(UFSAuthError.driveServiceNil)
                return
            }
            
            guard let sheetsService = self.sheetsService else {
                callback(UFSAuthError.sheetsServiceNil)
                return
            }
            
            let authorization = GTMAppAuthFetcherAuthorization(authState: state)
            self.authorizer = authorization
            driveService.authorizer = self.authorizer
            sheetsService.authorizer = self.authorizer
            GTMAppAuthFetcherAuthorization.save(authorization, toKeychainForName: kUFSKeychainName)
            callback(nil)
        })
    }
    
    public func signOut() {
        self.sheetsService?.authorizer = nil
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
    
    public func getDriveService() -> GTLRDriveService? {
        return self.isSignedIn() ? self.driveService : nil
    }
    
    public func getSheetsService() -> GTLRSheetsService? {
        return self.isSignedIn() ? self.sheetsService : nil
    }
    
    public func execute(query: GTLRQuery) throws -> Any? {
        guard self.isSignedIn() else {
            throw UFSAuthError.unauthorized
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var dataOut: Any?
        var errorOut: Error?
        
        _ = DispatchQueue.main.sync {
            return self.driveService?.executeQuery(query) { (ticket, data, error) in
                errorOut = error
                dataOut = data
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        
        if let errorOut = errorOut {
            throw errorOut
        }
        
        return dataOut
    }
    
    public func execute<T>(query: GTLRQuery, withOutputType outputType: T.Type) throws -> T? {
        return try self.execute(query: query) as? T
    }
    
}

