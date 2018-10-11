//
//  CancellableWrapper.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-10.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

protocol CancellableWorkItem: Cancellable {
    var id: String { get }
    func setWork(_ work: @escaping () -> Cancellable)
    func setCancelCallback(_ block:  @escaping () -> Void)
    func perform()
    
    func cancel()
}

protocol RetriableWorkItem {
    var canRetry: Bool { get }
    func retry()
}

typealias WorkItem = CancellableWorkItem & RetriableWorkItem


/// Class for Cancellable implementation
/// Holds the work and has the ability to controll retry attempts to perform the task

class CancellableWrapper: WorkItem, Loggable {
    
    private var wrapped: Cancellable = EmptyCancellable() {
        willSet { wrapped.cancel() }
    }
    var work: (() -> Cancellable)?
    let id: String
    private(set) var maxRetryTimes: Int
    private(set) var currentRetryAttempt = 0
    
    var cancelCallback: (() -> Void)?
    
    var canRetry: Bool { return currentRetryAttempt <  maxRetryTimes}
    let retryQueue: QueueObject
    
    init(uniqueID: String =  UUID().uuidString,
         retryQueue: QueueObject,
         maxRetryTimes: Int = 10) {
        self.id = uniqueID
        self.maxRetryTimes = maxRetryTimes
        self.retryQueue = retryQueue
    }
    
    func setWork(_ work: @escaping () -> Cancellable) {
        self.work = work
    }
    
    func setCancelCallback(_ block:  @escaping () -> Void) {
        self.cancelCallback = block
    }
    
    func perform() {
        if let block = work {
            wrapped = block()
        }
    }
    
    func retry() {
        log(with: "Retrying in \(currentRetryAttempt * 1) seconds ")
        currentRetryAttempt += 1
        retryQueue.asyncAfter(deadline: .now() + .seconds(currentRetryAttempt * 1)) {[weak self] in
            self?.perform()
        }
    }
    
    func cancel() {
        wrapped.cancel()
        cancelCallback?()
        work = nil
        cancelCallback = nil
    }
}

class EmptyCancellable: Cancellable {
    func cancel() {
        //fake object
    }
}
