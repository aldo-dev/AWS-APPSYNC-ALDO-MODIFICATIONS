//
//  CredentialsUpdaterMock.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-20.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync

final class CredentialsUpdaterMock: CredentialsUpdater {
    
    private(set) var refreshCalled = 0
    private(set) var completion: ((Promise<Void>) -> Void)?
    func refreshToken(completion: @escaping (Promise<Void>) -> Void) {
        refreshCalled += 1
        self.completion = completion
    }
    
    
}
