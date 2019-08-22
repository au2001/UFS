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
private let kGoogleClientId = "164202260323-0t8fmdo5mohv4dbgfc5odt5oui6ggert.apps.googleusercontent.com"
private let kGoogleClientSecret = "b1tKeHkH-uSucMzNBks2LBh7"
private let kGoogleRedirectURI = URL(string: "com.googleusercontent.apps.164202260323-0t8fmdo5mohv4dbgfc5odt5oui6ggert:/oauthredirect")!

class DriveStorage {
    
    private var docsService: GTLRDocsService?
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?
    
    public init() {
        self.docsService = GTLRDocsService()
        self.docsService?.shouldFetchNextPages = true
        self.docsService?.isRetryEnabled = true
        self.docsService?.authorizer = GTMAppAuthFetcherAuthorization(fromKeychainForName: kUFSKeychainName)
    }
    
    func handle(url: URL) -> Bool {
        return self.currentAuthorizationFlow?.resumeExternalUserAgentFlow(with: url) ?? false
    }
    
    public func signIn(callback: @escaping (Error?) -> ()) {
        if self.isSignedIn() {
            return
        }
        
        let configuration = GTMAppAuthFetcherAuthorization.configurationForGoogle()
        let scopes = [OIDScopeOpenID, OIDScopeProfile, OIDScopeEmail] // kGTLRAuthScopeDocsDocuments?
        let request = OIDAuthorizationRequest(configuration: configuration, clientId: kGoogleClientId, clientSecret: kGoogleClientSecret, scopes: scopes, redirectURL: kGoogleRedirectURI, responseType: OIDResponseTypeCode, additionalParameters: nil)
        
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
                callback(UFSAuthError.serviceNil)
                return
            }
            
            let authorization = GTMAppAuthFetcherAuthorization(authState: state)
            docsService.authorizer = authorization
            GTMAppAuthFetcherAuthorization.save(authorization, toKeychainForName: kUFSKeychainName)
            callback(nil)
        })
    }
    
    public func signOut() {
        GTMAppAuthFetcherAuthorization.removeFromKeychain(forName: kUFSKeychainName)
        self.docsService?.authorizer = nil
    }
    
    public func isSignedIn() -> Bool {
        return self.docsService?.authorizer?.canAuthorize ?? false
    }
    
    public func getUserEmail() -> String? {
        return self.docsService?.authorizer?.userEmail
    }
    
}

enum UFSAuthError: Error {
    
    case stateNil
    case serviceNil
    
}

