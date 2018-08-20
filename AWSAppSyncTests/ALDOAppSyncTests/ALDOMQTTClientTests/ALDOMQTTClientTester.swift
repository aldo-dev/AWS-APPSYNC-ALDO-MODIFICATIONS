//
//  ALDOMQTTClientTester.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-09.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import XCTest
@testable import AWSAppSync

extension MessageData: Equatable {
    public static func == (lhs: MessageData, rhs: MessageData) -> Bool {
        return lhs.data == rhs.data && lhs.topic == rhs.topic
    }
}
extension Result: Equatable where Value: Equatable {
    public static func == (lhs: Result, rhs: Result) -> Bool {
        switch (lhs,rhs) {
        case let (.success(val1), .success(val2)): return val1 == val2
        case let (.failure(err1),.failure(err2)): return err1.localizedDescription == err2.localizedDescription
        default: return false
        }
    }
}


final class ALDOMQTTClientTester {
    
    private let clientToTest: ALDOMQTTClient
    private let connectorMock: MQTTClientConnectorMock
    private var receivedStatus: Result<MQTTStatus>?
    private var receivedMessage: Result<MessageData>?
    private var queueMock = QueueObjectMock()
    init() {
        connectorMock = MQTTClientConnectorMock()
        queueMock = QueueObjectMock()
        clientToTest = ALDOMQTTClient(client: connectorMock, proccessingQueue: queueMock)
        
    }
    
    func connect(to host: String, with id: String) {
        clientToTest.connect(withClientID: id,
                             host: host,
                             statusCallBack: { self.receivedStatus = $0.result})
    }
    
    func subscribe(to topic: String) {
        clientToTest.subscribe(toTopic: topic,
                               callback: { self.receivedMessage = $0.result })
    }
    
    func emulateStatus(_ status: MQTTStatus) {
        receivedStatus = nil
        connectorMock.send(status: status)
    }
    
    func testSuspendQueueCalled(numberOfTimes: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(queueMock.suspendCalled, numberOfTimes ,file: file, line: line)
    }
    
    func testResumseQueueCalled(numberOfTimes: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(queueMock.resumeCalled, numberOfTimes ,file: file, line: line)
    }
    
    func testExecuteQueueCalled(numberOfTimes: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(queueMock.executeCalled, numberOfTimes ,file: file, line: line)
    }
    
    func testConnectsToExpectedHosts(_ hosts: [String],file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(connectorMock.connectedHosts, hosts ,file: file, line: line)
    }
    
    func testConnectsWithExpectedClients(ids: [String],file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(connectorMock.connectedClients, ids,file: file, line: line)
    }
    
    func testExpectedStatus(_ status: MQTTStatus?,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(status, receivedStatus?.value,file: file, line: line)
    }
    
    func testSubscribeResult(_ result: Result<MessageData>,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(result, receivedMessage,file: file, line: line)
    }
    
    func testSubscribedTo(topics: [String],file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(connectorMock.subscribedTopics, topics,file: file, line: line)
    }
}
