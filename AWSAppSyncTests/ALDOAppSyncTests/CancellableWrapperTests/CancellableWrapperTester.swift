//
//  CancellableWrapperTester.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import XCTest
@testable import AWSAppSync


final class CancellableWrapperTester {
    var wrapperToTest = CancellableWrapper(retryQueue: ProcessingQueueObject(dispatchQueue: .main),maxRetryTimes: 2)
    private(set) var cancelCallbackCalled = 0
    private(set) var workCalled = 0
    
    init() {
        wrapperToTest = CancellableWrapper(retryQueue: ProcessingQueueObject(dispatchQueue: .main),maxRetryTimes: 2)
        wrapperToTest.setCancelCallback {
            self.cancelCallbackCalled += 1
        }
        
        wrapperToTest.setWork { () -> Cancellable in
            self.workCalled += 1
            return EmptyCancellable()
        }
    }
    
    func callPerform() {
        wrapperToTest.perform()
    }
    
    func callRetry() {
        wrapperToTest.retry()
    }
    
    func checkRetryCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line ) {
        XCTAssertEqual(workCalled - 1, numberOfTimes, file: file, line: line)
    }
    
    func checkWorkCalled(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line ) {
        XCTAssertEqual(workCalled, numberOfTimes, file: file, line: line)
    }
    
    func checkCanRetry(expected: Bool,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(wrapperToTest.canRetry, expected, file: file, line: line)
    }
}
