//
//  AWSNetworkTransportCredentialsUpdateDecoratorTestCase.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-20.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import XCTest

class AWSNetworkTransportCredentialsUpdateDecoratorTestCase: XCTestCase {
    
    var tester: AWSNetworkTransportCredentialsUpdateDecoratorTester!
    
    override func setUp() {
        super.setUp()
        tester = AWSNetworkTransportCredentialsUpdateDecoratorTester()
    }
    
    func test_if_error_401_should_call_credentials_updater() {
        tester.sendQuery()
        tester.emulateQueryResponseWith401Error()
        tester.checkCredentialsUpdaterCalled(numberOfTimes: 1)
    }
    
    func test_if_error_401_should_pause_next_calls() {
        tester.sendQuery()
        tester.emulateQueryResponseWith401Error()
        tester.sendQuery()
        tester.sendQuery()
        tester.checkSendQueryCalled(numberOfTimes: 1)
    }
    
    func test_should_retry_items_after_credantials_updated() {
        tester.sendQuery()
        tester.emulateQueryResponseWith401Error()
        tester.sendQuery()
        tester.sendQuery()
        tester.checkSendQueryCalled(numberOfTimes: 1)
        tester.resetSendQueryCounter()
        tester.emulateCredentialsUpdateWithSuccess()
        tester.checkSendQueryCalled(numberOfTimes: 3)
        
    }
}
