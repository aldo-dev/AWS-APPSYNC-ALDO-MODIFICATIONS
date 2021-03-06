//
//  SubscriptionRequestingDecoratorTester.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import XCTest
@testable import AWSAppSync
@testable import Reachability


final class ConnectionStatusMockProvider {
    
    var connection: Reachability.Connection = .none
}

final class AWSNetworkTransportDecoratorTester {
    
    let decoratorToTest: AWSNetworkTransportDecorator
    let subscriptionRequestingMock: SubscriptionRequestingMock<MockSubscriptionRequest>
    var receivedResponses: [JSONObject] = []
    var receivedErrors: [Error] = []
    let mockFactory: WorkItemMockFactory
    let maxRetryAttempts = 5
    let connectionStatusProvider = ConnectionStatusMockProvider()
    
    init() {
        subscriptionRequestingMock = SubscriptionRequestingMock<MockSubscriptionRequest>()
        mockFactory = WorkItemMockFactory()
        mockFactory.mockItem.maxRetryTimes = maxRetryAttempts
        let provider = connectionStatusProvider
        decoratorToTest = AWSNetworkTransportDecorator(decorated: subscriptionRequestingMock,
                                                          queueObject: ProcessingQueueObject.serial(withLabel: "SubscriptionRequestingDecoratorTester"),
                                                          factory: mockFactory,
                                                          connectionStateRequest: { return provider.connection })
    }
    
    func setCurrentState(_ state: Reachability.Connection) {
        connectionStatusProvider.connection = state
    }
    
    func emulateNetworkConnectionStatus(_ status: Reachability.Connection) {
        decoratorToTest.hasChanged(to: status)
    }
    
    func setSuccessResponseForDecorated(_ response: JSONObject? = [:]) {
        subscriptionRequestingMock.response = response
    }
    
    func setErrorWithErrorCode(_ code: Int?) {
        subscriptionRequestingMock.error = code.map({ NSError(domain: "TEST", code: $0, userInfo: nil) })
    }
    
    
    func setErrorRetryFlowDecorated(_ error: Error?,
                                    successResponse: JSONObject? = nil,
                                    afterNumberOfRetries retries: Int) {
        
        subscriptionRequestingMock.error = error
        subscriptionRequestingMock.response = successResponse
        subscriptionRequestingMock.retryCount = retries
    }
    
    func sendSubscriptionRequest() {
       let _ =  try! decoratorToTest.sendSubscriptionRequest(operation: MockSubscriptionRequest(),
                                                      completionHandler: { (obj, error) in
                                                        if let obj = obj {
                                                            self.receivedResponses.append(obj)
                                                        }
                                                        
                                                        if let  error = error {
                                                            self.receivedErrors.append(error)
                                                        }
        })
    }
    
    
    func sendDataRequest() {
        decoratorToTest.send(data: Data()) { (obj, error) in
            if let obj = obj {
                self.receivedResponses.append(obj)
            }
            
            if let  error = error {
                self.receivedErrors.append(error)
            }
        }
    }
    
    func sendOperationRequest() {
        let _ = decoratorToTest.send(operation: MockSubscriptionRequest(),
                                     overrideMap: [:]) { (response, error) in
                                        if let response = response?.body {
                                            self.receivedResponses.append(response)
                                        }
                                        
                                        if let  error = error {
                                            self.receivedErrors.append(error)
                                        }
        }
    }
    
    
    func checkDecoratedDataRequestHasBeenCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(numberOfTimes, subscriptionRequestingMock.datas.count, file: file, line: line)
    }
    
    func checkDecoratedSendRequestHasBeenCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(subscriptionRequestingMock.operations.count, numberOfTimes, file: file, line: line)
    }
    
    func checkReceivedSuccessResponse(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(receivedResponses.count, numberOfTimes, file: file, line: line)
    }
    
    func checkReceivedErrorResponse(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
         XCTAssertEqual(receivedErrors.count, numberOfTimes, file: file, line: line)
    }
    
    func checkItemRetryCalledExpectedNumberOfTimes(file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(mockFactory.mockItem.retryCalled, maxRetryAttempts, file: file, line: line)
    }
    
    func checkItemRetryCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(mockFactory.mockItem.retryCalled, numberOfTimes, file: file, line: line)
    }
    
    func checkRetrySendsExpectedNumberOfRequests(file: StaticString = #file, line: UInt = #line) {
        checkDecoratedSendRequestHasBeenCalled(numberOfTimes: maxRetryAttempts + 1, file: file, line: line)
    }
}
