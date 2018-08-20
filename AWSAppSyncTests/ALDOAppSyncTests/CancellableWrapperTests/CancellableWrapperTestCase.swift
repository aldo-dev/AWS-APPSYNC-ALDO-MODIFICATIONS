//
//  CancellableWrapperTestCase.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import XCTest
@testable import AWSAppSync

class CancellableWrapperTestCase: XCTestCase {
    
    var tester: CancellableWrapperTester!
    override func setUp() {
        super.setUp()
        tester = CancellableWrapperTester()
    }
    
    
    func test_retries_expected_number_of_times() {
        tester.callPerform()
        tester.callRetry()
        wait(timeInterval: .seconds(1))
        tester.checkCanRetry(expected: true)
        tester.callRetry()
        wait(timeInterval: .seconds(4))
        tester.checkCanRetry(expected: false)
        tester.checkRetryCalled(numberOfTimes: 2)
        tester.checkWorkCalled(numberOfTimes: 3)
    }
}
