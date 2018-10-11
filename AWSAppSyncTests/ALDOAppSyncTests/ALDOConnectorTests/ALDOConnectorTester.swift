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
    
    func newConnector(for clientID: String) -> ALDOMQTTClientConnector {
        count += 1
        return mock
    }
}

final class ALDOConnectorTester {
    
    let connecterToTest: ALDOConnector
    let factoryMock = ALDOClientFactoryMock()
    private var receivedStatus: [Result<AWSIoTMQTTStatus>] = []
    private var receivedMessage: Result<MessageData>?
    init() {
        connecterToTest = ALDOConnector(factory: factoryMock)
    
    }
    
    func connect(using info: SubscriptionWatcherInfo) {
        connecterToTest.connect(using: info, statusCallBack: { statusResponse in
            self.receivedStatus.append(statusResponse.result!)
        })
    }
    
    func disconnectAll() {
        connecterToTest.disconnectAll()
    }
    
    func disconnectTopic(_ topic: String) {
        connecterToTest.disconnect(topic: topic)
    }
    
    func subscribeToTopic(topic: String) {
        connecterToTest.subscribe(toTopic: topic) { (response) in
            self.receivedMessage = response.result
        }
    }
    
    func sendStatus(_ status: AWSIoTMQTTStatus) {
        factoryMock.mock.sendStatus(status)
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
    
    func testStatusCallbackTriggered(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(receivedStatus.count, numberOfTimes, file: file, line: line)
    }
}
