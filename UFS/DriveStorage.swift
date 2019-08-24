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
    
    
}

