//
//  AWSNetworkTransportCredentialsUpdateDecoratorTester.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-20.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import XCTest
@testable import AWSAppSync

final class AWSNetworkTransportCredentialsUpdateDecoratorTester {
    
    let decoratorToTest: AWSNetworkTransportCredentialsUpdateDecorator
    let networkTransportMock: AWSNetworkTransportMock<MockGraphQLQuery>
    let credentialsUpdaterMock: CredentialsUpdaterMock
    var responses: [GraphQLResponse<MockGraphQLQuery>] = []
    var errors: [Error] = []
    
    init() {
        credentialsUpdaterMock = CredentialsUpdaterMock()
        networkTransportMock = AWSNetworkTransportMock<MockGraphQLQuery>()
        decoratorToTest = AWSNetworkTransportCredentialsUpdateDecorator(decorated: networkTransportMock,
                                                                        credentialsUpdater: credentialsUpdaterMock)
    }
    
    func sendQuery() {
        let _ = decoratorToTest.send(operation: MockGraphQLQuery(),
                                     overrideMap: [:]) {[weak self] (response, error) in
                                        if let response = response {
                                            self?.responses.append(response)
                                        }
                                        if let error = error {
                                            self?.errors.append(error)
                                        }
        }
    }
    
    func emulateCredentialsUpdateWithSuccess() {
        credentialsUpdaterMock.completion?(Promise(fulfilled: ()))
    }
    
    func emulateQueryResponseWithSuccess() {
        networkTransportMock.sendOperationCompletion?(GraphQLResponse(operation: MockGraphQLQuery(), body: [:]), nil)
    }
    
    func resetSendQueryCounter() {
        networkTransportMock.clear()
    }
    
    func emulateQueryResponseWith401Error() {
        let urlResposne = HTTPURLResponse(url: URL(fileURLWithPath: "Empty"), statusCode: 401, httpVersion: nil, headerFields: nil)
        let error = AWSAppSyncClientError(body: nil, response: urlResposne, isInternalError: false, additionalInfo: nil)
        networkTransportMock.sendOperationCompletion?(nil, error)
    }

    func checkCredentialsUpdaterCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(numberOfTimes, credentialsUpdaterMock.refreshCalled,file: file, line: line)
    }
    
    func checkSendQueryCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(numberOfTimes, networkTransportMock.operations.count,file: file, line: line)
    }
}
