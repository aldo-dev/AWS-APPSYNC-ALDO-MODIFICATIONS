//
//  ALDOConnectorTester.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-09-10.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import XCTest
@testable import AWSAppSync

final class ALDOClientFactoryMock: ALDOClientFactory {
    
    var count: Int = 0
    var mock = ALDOMQTTClientConnectorMock()

    var newConnetor: ALDOMQTTClientConnector {
        count += 1
        return mock
    }
}

final class ALDOConnectorTester {
    
    let connecterToTest: ALDOConnector
    let factoryMock = ALDOClientFactoryMock()
    private var receivedStatus: Result<AWSIoTMQTTStatus>?
     private var receivedMessage: Result<MessageData>?
    init() {
        connecterToTest = ALDOConnector(factory: factoryMock)
    
    }
    
    func connect(using info: SubscriptionWatcherInfo) {
        connecterToTest.connect(using: info, statusCallBack: { statusResponse in
            self.receivedStatus = statusResponse.result
        })
    }
    
    func subscribeToTopic(topic: String) {
        connecterToTest.subscribe(toTopic: topic) { (response) in
            self.receivedMessage = response.result
        }
    }
    
    func checkSubscribedTopics(expected: [String],file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(factoryMock.mock.subscribedTopics, expected, file: file, line: line)
    }
    
    func checkConnectedHosts(_ hosts: [String], file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(factoryMock.mock.connectedHosts, hosts, file: file, line: line)
    }
    
    func checkFactoryHasBeenCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line ) {
        XCTAssertEqual(factoryMock.count, numberOfTimes, file: file, line: line)
    }
    
    func testSubscribeResult(_ result: Result<MessageData>,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(result, receivedMessage,file: file, line: line)
    }
    
}
