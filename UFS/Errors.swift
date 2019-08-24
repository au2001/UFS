//
//  Errors.swift
//  UFS
//
//  Created by Aurélien Garnier on 20/08/2019.
//  Copyright © 2019 JustKodding. All rights reserved.
//

import Foundation

enum UFSError: Error {
    
    case unauthorized
    case unmounted
    case closing
    case noData
    
}

enum UFSAuthError: Error {
    
    case unauthorized
    case stateNil
    case docsServiceNil
    case driveServiceNil
    
}

extension NSError {
    convenience init(posixErrorCode err: Int32) {
        self.init(domain: NSPOSIXErrorDomain, code: Int(err), userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(err))])
    }
}

