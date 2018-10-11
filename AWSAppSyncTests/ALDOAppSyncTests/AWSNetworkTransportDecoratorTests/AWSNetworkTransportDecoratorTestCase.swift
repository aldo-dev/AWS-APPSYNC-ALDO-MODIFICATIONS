//
//  SubscriptionRequestingDecoratorTestCase.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import XCTest
@testable import AWSAppSync

class AWSNetworkTransportDecoratorTestCase: XCTestCase {
    
    
    var tester: AWSNetworkTransportDecoratorTester!
    
    override func setUp() {
        super.setUp()
        tester = AWSNetworkTransportDecoratorTester()
    }
    
    
    func test_receives_success_as_expected() {
        tester.emulateNetworkConnectionStatus(.cellular)
        tester.setSuccessResponseForDecorated()
        tester.sendSubscriptionRequest()
        tester.checkDecoratedSendRequestHasBeenCalled(numberOfTimes: 1)
        tester.checkReceivedSuccessResponse(numberOfTimes: 1)
        tester.checkReceivedErrorResponse(numberOfTimes: 0)
    }
    
    func test_receives_success_for_send_data_as_expected() {
        tester.emulateNetworkConnectionStatus(.cellular)
        tester.setSuccessResponseForDecorated()
        tester.sendDataRequest()
        tester.checkDecoratedDataRequestHasBeenCalled(numberOfTimes: 1)
        tester.checkReceivedSuccessResponse(numberOfTimes: 1)
        tester.checkReceivedErrorResponse(numberOfTimes: 0)
    }
    
    func test_shouldnot_call_decorated_to_send_requests_if_network_is_not_available() {
        tester.setSuccessResponseForDecorated()
        tester.sendSubscriptionRequest()
        tester.checkDecoratedSendRequestHasBeenCalled(numberOfTimes: 0)
        tester.checkReceivedSuccessResponse(numberOfTimes: 0)
        tester.checkReceivedErrorResponse(numberOfTimes: 0)
    }
    
    func test_shouldnot_call_decorated_to_send_data_requests_if_network_is_not_available() {
        tester.setSuccessResponseForDecorated()
        tester.sendDataRequest()
        tester.checkDecoratedDataRequestHasBeenCalled(numberOfTimes: 0)
        tester.checkReceivedSuccessResponse(numberOfTimes: 0)
        tester.checkReceivedErrorResponse(numberOfTimes: 0)
    }
    
    func test_should_call_decorated_to_send_requests_when_network_becomes_available() {
        tester.setSuccessResponseForDecorated()
        tester.sendSubscriptionRequest()
        tester.emulateNetworkConnectionStatus(.cellular)
        tester.checkDecoratedSendRequestHasBeenCalled(numberOfTimes: 1)
        tester.checkReceivedSuccessResponse(numberOfTimes: 1)
        tester.checkReceivedErrorResponse(numberOfTimes: 0)
    }
    
    func test_should_resend_request_when_network_becomes_available_if_request_ended_up_with_error() {
        // Setting up initial state
        tester.emulateNetworkConnectionStatus(.cellular)
        tester.setCurrentState(.none)
        tester.setErrorWithErrorCode(NSURLErrorNetworkConnectionLost)
        tester.sendSubscriptionRequest()
        
        // prepare respose for the retry
        tester.setErrorWithErrorCode(nil)
        tester.setSuccessResponseForDecorated()
        
        // emulating networkchange
        tester.emulateNetworkConnectionStatus(.cellular)
        
        tester.checkDecoratedSendRequestHasBeenCalled(numberOfTimes: 2)
        tester.checkReceivedSuccessResponse(numberOfTimes: 1)
        tester.checkReceivedErrorResponse(numberOfTimes: 0)
    }
    
    func test_should_resend_data_request_when_network_becomes_available_if_request_ended_up_with_error() {
        // Setting up initial state
        tester.emulateNetworkConnectionStatus(.cellular)
        tester.setCurrentState(.none)
        tester.setErrorWithErrorCode(NSURLErrorNetworkConnectionLost)
        tester.sendDataRequest()
        
        // prepare respose for the retry
        tester.setErrorWithErrorCode(nil)
        tester.setSuccessResponseForDecorated()
        
        // emulating networkchange
        tester.emulateNetworkConnectionStatus(.cellular)
        
        tester.checkDecoratedDataRequestHasBeenCalled(numberOfTimes: 2)
        tester.checkReceivedSuccessResponse(numberOfTimes: 1)
        tester.checkReceivedErrorResponse(numberOfTimes: 0)
    }
    
    
  
    
    func test_all_codes_for_to_retry_logic() {
        let codes = [NSURLErrorNotConnectedToInternet,
                     NSURLErrorNetworkConnectionLost,
                     NSURLNetworkRequestUnauthorizedCode,
                     NSURLErrorDomainNotFound,
                     NSURLSoftwareTaskCancelled,
                     NSURLErrorTimedOut]
        
        codes.forEach { (code) in
            self.setUp()
            self.run_test_routine_retries_to_send_element_for(code: code)
        }
    }
    
    func test_if_network_is_off_and_error_NSURLErrorNetworkConnectionLost_should_pause() {
        tester.emulateNetworkConnectionStatus(.cellular)
        tester.setErrorWithErrorCode(NSURLErrorNetworkConnectionLost)
        tester.setCurrentState(.none)
        tester.sendSubscriptionRequest()
        tester.checkDecoratedSendRequestHasBeenCalled(numberOfTimes: 1)
        tester.checkReceivedSuccessResponse(numberOfTimes: 0)
        tester.checkReceivedErrorResponse(numberOfTimes: 0)
        tester.checkItemRetryCalled(numberOfTimes: 0)
        
    }
    
    
    private func run_test_routine_retries_to_send_element_for(code: Int, file: StaticString = #file, line: UInt = #line) {
        tester.emulateNetworkConnectionStatus(.cellular)
        let error = NSError(domain: "TEST", code: code, userInfo: nil)
        tester.setErrorRetryFlowDecorated(error,
                                          successResponse: [:],
                                          afterNumberOfRetries: 6)
        tester.setCurrentState(.wifi)
        tester.sendSubscriptionRequest()
        tester.checkDecoratedSendRequestHasBeenCalled(numberOfTimes: 6)
        tester.checkItemRetryCalled(numberOfTimes: 5)
        tester.checkReceivedSuccessResponse(numberOfTimes: 1)
        tester.checkReceivedErrorResponse(numberOfTimes: 0)
    }
}
