//
//  ALDOAppSyncSubscriptionCentreTester.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-09.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import XCTest
@testable import AWSAppSync

final class SubscriptionConnectionObserverMock: SubscriptionConnectionObserver {
    
    private(set) var connectionEstablishedCalled = 0
    private(set) var errors = [Error]()
    func connectionEstablished() {
        connectionEstablishedCalled += 1
    }
    
    func connectionError(_ error: Error) {
        errors.append(error)
    }
}

final class ALDOAppSyncSubscriptionCentreTester {
    
    let centreToTest: ALDOAppSyncSubscriptionCentre
    let connectorMock: ALDOMQTTClientConnectorMock
    let factory = SubscriptionWatcherInfoFactory()
    var watchers: [WatcherMock] = []
    var errors: [Error] = []
    var infos: [SubscriptionWatcherInfo] = []
    var topics = ["test"]
    var clientID = "client"
    var url = "url"
    let connectionObserverMock: SubscriptionConnectionObserverMock
    
    init() {
        connectorMock = ALDOMQTTClientConnectorMock()
        centreToTest = ALDOAppSyncSubscriptionCentre(client: connectorMock)
        connectionObserverMock = SubscriptionConnectionObserverMock()
        centreToTest.setConnectionError(callback: connectionErrorCallback)

    }
    
    func connectWatcher(with id: Int, requestError: Error? = nil) {
        let defaultInfo = factory.getInfo(withTopics: topics, client: clientID, url: url)
        infos.append(defaultInfo)
        let expectedResponse = requestError.map({ Promise<SubscriptionWatcherInfo>.init(rejected: $0) }) ?? Promise.init(fulfilled: defaultInfo)
        let watcher = WatcherMock(id: id, expectedResponse: expectedResponse)
        watchers.append(watcher)
        centreToTest.subscribe(watcher: watcher)
    }
    
    func connectObserver() {
        centreToTest.addObserver(connectionObserverMock)
    }
    
    func emulateStatusChange(newStatus: MQTTStatus) {
        connectorMock.sendStatus(newStatus)
    }
    
    func setTopics(_ topics: [String]) {
        self.topics = topics
    }
    
    func setClientID(_ id: String) {
        self.clientID = id
    }
    
    func unsubscribeWatcher(with id: Int) {
        
        if let w =  watchers.first(where: {$0.id == id }) {
            centreToTest.unsubscribe(watcher: w)
        }
    }
    
    func postData(data: Data, for topic: String) {
        connectorMock.sendData(data, for: topic)
    }
    
    func checkWatcherReceivedData(_ data: [Data], watcherID: Int, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(watchers.first(where: {$0.id == watcherID })!.receivedData, data, file: file, line: line)
    }
    
    func checkRequestSubscriptionHasBeenCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(numberOfTimes, watchers.reduce(0, {$0 + $1.requestSubscriptionRequestCalled}), file: file, line: line)
    }
    
    func checkEstablishConnection(file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(connectorMock.connectedHosts, infos.flatMap({$0.info.map({$0.url})}), file: file)
        XCTAssertEqual(connectorMock.connectedClients, infos.flatMap({$0.info.map({$0.clientId})}), line: line)
    }
    
    
    func checkObserverReceivesEstablishConnection(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line)  {
        XCTAssertEqual(connectionObserverMock.connectionEstablishedCalled, numberOfTimes, file: file, line: line)
    }
    
    func checkObserverReceivesErrorConnection(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(connectionObserverMock.errors.count, numberOfTimes, file: file, line: line)
    }
    
    func checkSubscribingFails(withErrors expectedErrors: [Error],file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(errors.map({$0.localizedDescription}), expectedErrors.map({$0.localizedDescription}), file: file, line: line)
    }
    
    func checkDisconnectTopicCallend(numberOfTimes: Int, topic: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(connectorMock.disconnectedTopics.filter({ $0 == topic }).count,
                       numberOfTimes,
                       file: file,
                       line: line)
    }
    
    func checkDisconnectCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(connectorMock.disconnectAllCount, numberOfTimes, file: file, line: line)
    }
    
    private var connectionErrorCallback: ErrorCallback {
        return { (error) in
            self.errors.append(error)
        }
    }
}
