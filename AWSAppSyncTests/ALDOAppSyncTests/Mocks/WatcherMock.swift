//
//  WatcherMock.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-09.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync

final class WatcherMock: SubscriptionWatcher {
    let id: Int
    var topics: [String] = []
    var receivedData: [Data] = []
    var expectedResponse: Promise<SubscriptionWatcherInfo>
    var requestSubscriptionRequestCalled = 0
    var cancelCalled = 0
    
    init(id: Int = 1, expectedResponse: Promise<SubscriptionWatcherInfo>) {
        self.id = id
        self.expectedResponse = expectedResponse
    }
    
    func received(_ data: Data) {
        receivedData.append(data)
    }
    
    func requestSubscriptionRequest() -> Promise<SubscriptionWatcherInfo> {
        requestSubscriptionRequestCalled += 1
        return expectedResponse
    }
    
    func cancel() {
        cancelCalled += 1
    }
}


final class SubscriptionWatcherInfoBuilder {
    
    private var currentSubscriptionTopics: [String] = []
    private var topicsPerConnection: [String: [String]] = [:]
    private(set) var mockURL = "url"
    
    
    var info: SubscriptionWatcherInfo {
        return SubscriptionWatcherInfo(topics: currentSubscriptionTopics, info: arrayOfConnections)
    }
    
    func setCurrentSubscriptionTopics(_ topics: [String]) {
        currentSubscriptionTopics = topics
    }
    
    func clean() {
        currentSubscriptionTopics = []
        topicsPerConnection = [:]
    }
    
    func setTopics(_ topics: [String], clientID: String) {
        topicsPerConnection[clientID] = topics
    }
    
    func setURL(_ url: String) {
        mockURL = url
    }
    
    
    
    
    func getInfo(withTopics topics: [String], client: String, url: String) -> SubscriptionWatcherInfo {
        return SubscriptionWatcherInfo(topics: topics,
                                        info: [AWSSubscriptionInfo(clientId: client, url: url, topics: topics)])
    }
    
  
    
    private var arrayOfConnections: [AWSSubscriptionInfo] {
        return topicsPerConnection.map({ AWSSubscriptionInfo(clientId: $0.key, url: mockURL, topics: $0.value)  })
    }
}
