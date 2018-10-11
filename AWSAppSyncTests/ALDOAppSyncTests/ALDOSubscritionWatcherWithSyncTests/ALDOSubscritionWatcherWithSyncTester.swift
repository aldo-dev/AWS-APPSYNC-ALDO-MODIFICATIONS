//
//  ALDOSubscritionWatcherWithSyncTester.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-16.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import XCTest
@testable import AWSAppSync

enum ALDOSubscritionWatcherWithSyncTesterError: Error {
    case queryFailed
}

final class ALDOSubscritionWatcherWithSyncTester {
    
    let watcherToTest: ALDOSubscritionWatcherWithSync<MockGraphQLQuery, MockGraphQLSelecitonSet>
    let watcherMock: WatcherMock
    let factory = SubscriptionWatcherInfoBuilder()
    private var queueMock = ObjectQueueWrapper()
    var senderMock = GraphQLOperationSenderMock<MockGraphQLQuery,MockGraphQLSelecitonSet>()
    var receivedInfos: [SubscriptionWatcherInfo] = []
    var receivedErrors: [Error] = []
    
    init() {
        let info = factory.getInfo(withTopics: ["1"], client: "clien", url: "url")
        watcherMock = WatcherMock(id: 1, expectedResponse: Promise<SubscriptionWatcherInfo>.init(fulfilled: info))
        senderMock = GraphQLOperationSenderMock<MockGraphQLQuery,MockGraphQLSelecitonSet>()
        senderMock.returnedSet = MockGraphQLSelecitonSet(snapshot: [:])
        watcherToTest = ALDOSubscritionWatcherWithSync(decorated: watcherMock,
                                                       querySender: senderMock,
                                                       outQueue: queueMock,
                                                       query: MockGraphQLQuery())
    }
    
    func setQuerySenderError(_ error: ALDOSubscritionWatcherWithSyncTesterError) {
        senderMock.error = error
    }
    
    func emulateReceiveData() {
        watcherToTest.received(Data())
    }
    
    func emulateEstablishedConnection() {
        watcherToTest.connectionEstablished()
    }
    
    func emulateConnectionFailed() {
        watcherToTest.connectionError(ALDOSubscritionWatcherWithSyncTesterError.queryFailed)
    }
    
    func emulateSendRequest(with error: Error? = nil) {
        if let error = error {
            watcherMock.expectedResponse = Promise(rejected: error)
        }
    
        watcherToTest.requestSubscriptionRequest()
            .andThen { [weak self]  in self?.receivedInfos.append($0)}
            .catch { [weak self]  in self?.receivedErrors.append($0) }
    }
    
    func checkReceivedDataCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(watcherMock.receivedData.count, numberOfTimes,file: file, line: line)
    }
    
    func checkRequestSubscriptionRequestCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(watcherMock.requestSubscriptionRequestCalled, numberOfTimes,file: file, line: line)
    }
    
    func checkSynQuerySent(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(senderMock.operations.count, numberOfTimes,file: file, line: line)
    }
    
    func checkTheQueuePaused(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(queueMock.suspendCalled, numberOfTimes,file: file, line: line)
    }
    
    func checkTheQueueResumed(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(queueMock.resumeCalled, numberOfTimes,file: file, line: line)
    }
}
