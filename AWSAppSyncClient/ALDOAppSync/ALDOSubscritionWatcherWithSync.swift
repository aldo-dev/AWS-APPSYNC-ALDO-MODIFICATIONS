//
//  ALDOSubscritionWatcherWithSync.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

protocol SubscriptionConnectionObserver: AnyObject {
    func connectionEstablished()
    func connectionError(_ error: Error)
}


enum ALDOSubscritionWatcherOutQueueState {
    case paused
    case active
}

public final class ALDOSubscritionWatcherWithSync<Q: GraphQLQuery, Set>: SubscriptionWatcher,SubscriptionConnectionObserver, Loggable where Set == Q.Data {

    var id: Int {  return decorated.id }
    var topics: [String] { return decorated.topics }
    var query: Q
    var callback: ((Promise<Set?>) -> Void)?
    
    private let decorated: SubscriptionWatcher
    private let outQueue: QueueObject
    private let proccessingQueue = DispatchQueue(label: "ALDOSubscritionWatcherWithSync.proccessing")
    private let querySender: GraphQLOperationSender
    private var syncWorkItem: DispatchWorkItem?
    private var cancellation: (() -> Void)?
    private let logger: AWSLogger?
    
    private var queuestate: ALDOSubscritionWatcherOutQueueState = .active {
        didSet {
            switch queuestate {
            case .active: outQueue.resume()
            case .paused: outQueue.suspend()
            }
        }
    }

    init(decorated: SubscriptionWatcher,
         querySender: GraphQLOperationSender,
         outQueue: QueueObject = ProcessingQueueObject.serial(withLabel: "ALDOSubscritionWatcherWithSync"),
         query: Q,
         logger: AWSLogger? = nil) {
        self.decorated = decorated
        self.query = query
        self.outQueue = outQueue
        self.querySender = querySender
        self.logger = logger
    }

    func requestSubscriptionRequest() -> Promise<SubscriptionWatcherInfo> {
        cancelSyncing()
        pauseQueueIfNeed()
        return decorated.requestSubscriptionRequest()
    }
    
    func subscribe(_ callback: @escaping (Promise<Set?>) -> Void) {
        self.callback = callback
    }
    
    func setCancellationClosure(_ closure: @escaping () -> Void) {
        cancellation = closure
    }
    
    func cancel() {
        cancelSyncing()
        decorated.cancel()
        cancellation?()
    }
    
    func received(_ data: Data) {
        logger?.log(message: "Received: \(data)", filename: #file, line: #line, funcname: #function)
        outQueue.async { [weak self] in
            self?.logger?.log(message: "Passing data to Decorated object", filename: #file, line: #line, funcname: #function)
            self?.decorated.received(data)
        }
    }
    
    func connectionEstablished() {
        logger?.log(message: "Received connection established", filename: #file, line: #line, funcname: #function)
        proccessingQueue.async {[weak self] in
            self?.sync()
        }
    }
    
    func connectionError(_ error: Error) {
        logger?.log(error: error, filename: #file, line: #line, funcname: #function)
        cancelSyncing()
    }
    
    func pauseQueueIfNeed() {
        guard queuestate == .active else { return }
        logger?.log(message: "PAUSING QUEUE", filename: #file, line: #line, funcname: #function)
        queuestate = .paused
    }
    
    func resumeIfNeed() {
        guard queuestate == .paused else { return }
        logger?.log(message: "RESUMING QUEUE", filename: #file, line: #line, funcname: #function)
        queuestate = .active
    }
    
    func sync() {
        syncWorkItem?.cancel()
        syncWorkItem = createWorkItem()
        logger?.log(message: "Start syncing", filename: #file, line: #line, funcname: #function)
        syncWorkItem?.perform()
    }
   
    private func createWorkItem() -> DispatchWorkItem {
        return DispatchWorkItem(block: {[weak self] in
            guard let `self` = self else { return }
             self.logger?.log(message: "Sending sync query", filename: #file, line: #line, funcname: #function)
             self.querySender.send(operation: self.query, overrideMap: [:])
                             .catch({ [weak self] in self?.procceesErrorSync($0) })
                             .andThen({ [weak self] in self?.procceedSyncSuccess(result: $0) })
        })
    }
    
    private func procceedSyncSuccess(result: Set?) {
        finishSyncing()
        callback?(Promise(fulfilled: result))
    }
    
    private func procceesErrorSync(_ error: Error) {
        logger?.log(error: error, filename: #file, line: #line, funcname: #function)
        cancelSyncing()
        callback?(Promise(rejected: error))
    }
    
    private func cancelSyncing() {
        logger?.log(message: "Will cancel syncing", filename: #file, line: #line, funcname: #function)
        proccessingQueue.async {[weak self] in
            if let workItem =  self?.syncWorkItem {
                workItem.cancel()
                self?.finishSyncing()
            }
        }
    }
    
    private func finishSyncing() {
        logger?.log(message: "Finish syncing with success", filename: #file, line: #line, funcname: #function)
        resumeIfNeed()
        syncWorkItem = nil
    }
    
}
