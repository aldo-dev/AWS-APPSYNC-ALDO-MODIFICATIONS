//
//  WorkItemMockFactory.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync


final class WorkItemMock: WorkItem {
    var id: String = "TEST"
    var maxRetryTimes = 1
    private(set) var retryCalled = 0
    private(set) var work: (() -> Cancellable)!
    private(set) var cancelBlock: (() -> Void)!
    
    func setWork(_ work: @escaping () -> Cancellable) {
        self.work = work
    }
    
    func setCancelCallback(_ block: @escaping () -> Void) {
        self.cancelBlock = block
    }
    
    func perform() {
        let _ = work()
    }
    
    func cancel() {
        cancelBlock()
    }
    
    var canRetry: Bool { return retryCalled < maxRetryTimes  }
    
    func retry() {
        retryCalled += 1
        perform()
    }    
}

final class WorkItemMockFactory: WorkItemFactory {
    
    var mockItem = WorkItemMock()
    func createItem() -> WorkItem {
        return mockItem
    }

}
