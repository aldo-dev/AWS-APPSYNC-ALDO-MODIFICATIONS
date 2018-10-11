//
//  ALDOAppSyncSubscriptionCentreReconnectorTester.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import XCTest
import Reachability
@testable import AWSAppSync

final class ALDOAppSyncSubscriptionCentreReconnectorTester {
    
    let subscriptionCentreMock: ALDOAppSyncSubscriptionCentreMock
    let reconnectorToTest: ALDOAppSyncSubscriptionCentreReconnector
    let watcherMock: WatcherMock
    let factory = SubscriptionWatcherInfoBuilder()
    let connectionStatusProvider = ConnectionStatusMockProvider()
    
    init() {
        subscriptionCentreMock = ALDOAppSyncSubscriptionCentreMock()
        let provider = connectionStatusProvider
        reconnectorToTest = ALDOAppSyncSubscriptionCentreReconnector(decorated: subscriptionCentreMock, connectionStateRequest: { provider.connection })
        let info = factory.getInfo(withTopics: ["1"], client: "clien", url: "url")
        watcherMock = WatcherMock(id: 1, expectedResponse: Promise<SubscriptionWatcherInfo>.init(fulfilled: info))
    }
    
    
    func emulateEstablishConnect() {
        subscriptionCentreMock.callConnectionEstablished()
    }
    
    func emulateNetworkStatusChange(_ status: Reachability.Connection) {
        reconnectorToTest.hasChanged(to: status)
    }
    
    func subscribeWatcher() {
        reconnectorToTest.subscribe(watcher: watcherMock)
    }
    
    func emulateCurrentNetworkStatus(_ status: Reachability.Connection) {
        connectionStatusProvider.connection = status
    }
    
    
    func unsubscribeWatcher() {
        reconnectorToTest.unsubscribe(watcher: watcherMock)
    }
    
    func emulateNetworkError(_ error: Error) {
        subscriptionCentreMock.sendError(error: error)
    }

    func checkSubscribeWatcherHasBeenCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(subscriptionCentreMock.subscribedWatchers.count, numberOfTimes, file: file, line: line)
    }
    
    func checkUnsubscribeWatcherHasBeenCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(subscriptionCentreMock.unsubscribedWatchers.count, numberOfTimes, file: file, line: line)
    }
    
}
