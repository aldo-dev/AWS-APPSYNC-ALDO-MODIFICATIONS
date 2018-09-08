//
//  QueueObjectMock.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-09.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync


final class ObjectQueueWrapper: QueueObject {
    
    var mockObject = QueueObjectMock()
    var realQueue = DispatchQueue(label: "ObjectQueueWrapper")
    var suspendCalled: Int { return mockObject.suspendCalled }
    var resumeCalled: Int { return mockObject.resumeCalled }
    var executeCalled: Int { return mockObject.executeCalled }
    var syncCalled: Int { return mockObject.syncCalled }
    var asyncAfter: Int { return mockObject.asyncAfter }
    
    func async(execute: @escaping () -> Void) {
        mockObject.async { }
        realQueue.async(execute: execute)
    }
    
    func sync(execute: @escaping () -> Void) {
        mockObject.sync { }
        realQueue.sync(execute: execute)
    }
    
    func asyncAfter(deadline: DispatchTime, execute work: @escaping @convention(block) () -> Void) {
        mockObject.asyncAfter(deadline: deadline, execute: {})
        realQueue.asyncAfter(deadline: deadline, execute: work)
    }
    
    func suspend() {
        mockObject.suspend()
        realQueue.suspend()
    }
    
    func resume() {
        mockObject.resume()
        realQueue.resume()
    }
}


final class QueueObjectMock: QueueObject {

    private(set) var suspendCalled = 0
    private(set) var resumeCalled = 0
    private(set) var executeCalled = 0
    private(set) var syncCalled = 0
    private(set) var asyncAfter = 0
    private(set) var blocks: [() -> Void] = []
    func suspend() {
        suspendCalled += 1
    }
    
    func resume() {
        resumeCalled += 1
        if abs(suspendCalled - resumeCalled) == 0 {
            blocks.forEach({ $0() })
            blocks = []
        }
    }
    
    func async(execute: @escaping () -> Void) {
        executeCalled += 1
        if abs(suspendCalled - resumeCalled) == 0 {
             execute()
        } else {
            blocks.append(execute)
        }
    }
    
    func sync(execute: @escaping () -> Void) {
        syncCalled += 1
        if abs(suspendCalled - resumeCalled) == 0 {
            execute()
        }else {
            blocks.append(execute)
        }
    }
    
    func asyncAfter(deadline: DispatchTime, execute work: @escaping @convention(block) () -> Void) {
        asyncAfter += 1
        if abs(suspendCalled - resumeCalled) == 0 {
            work()
        }
    }
}
