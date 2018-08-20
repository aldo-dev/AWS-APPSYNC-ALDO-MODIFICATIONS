//
//  XCTestCaseExtension.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import XCTest


extension XCTestCase {
    func wait(timeInterval: DispatchTimeInterval) {
        let exp = expectation(description: UUID().uuidString)
        DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeInterval.timeInterval * 2)
        
    }
}
