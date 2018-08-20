//
//  CancellableWorkItemFactory.swift
//  AWSAppSyncClient
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

protocol WorkItemFactory {
    func createItem() -> WorkItem
}

/// Class for creating WorkItems
/// The major purpose to help in unit testing.

final class CancellableWorkItemFactory: WorkItemFactory {
    
    let retryQueue: QueueObject
    let maxRetryTimes: Int
    
    static var defaultFactory: WorkItemFactory {
        return CancellableWorkItemFactory(retryQueue: ProcessingQueueObject.concurrent(withLabel: "RetriableItem"), maxRetryTimes: 5)
    }
    
    init(retryQueue: QueueObject, maxRetryTimes: Int = 300) {
        self.retryQueue = retryQueue
        self.maxRetryTimes = maxRetryTimes
    }
    
    func createItem() -> WorkItem {
        return CancellableWrapper(retryQueue: retryQueue, maxRetryTimes: maxRetryTimes)
    }
}
