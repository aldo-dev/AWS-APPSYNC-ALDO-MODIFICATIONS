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


final class SubscriptionWatcherInfoFactory {
    
    func getInfo(withTopics topics: [String], client: String, url: String) -> SubscriptionWatcherInfo {
        return SubscriptionWatcherInfo(topics: topics,
                                        info: [AWSSubscriptionInfo(clientId: client, url: url, topics: topics)])
    }
}
