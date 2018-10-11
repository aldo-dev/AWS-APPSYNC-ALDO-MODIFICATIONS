//
//  ALDOAppSyncSubscriptionCentreReconnector.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-09.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import Reachability


/** Class-Decorator for SubscriptionCentre

   The class recognizes connection error represented by MQTTStatusError.
   The moment it receives the error of MQTTStatusError it starts reconnect logic on serial queue
   First it put semaphore to block other reconnect requests to happen
   Second sets reconnecting flag to true. This flag will reject other MQTTStatusError comming during reconnection logic
*/

enum SubscriptionCentreConnectionState {
    case connected
    case reconnecting
    case disconnected
}

final class ALDOAppSyncSubscriptionCentreReconnector: SubscriptionCentre, SubscriptionConnectionSubject, Loggable, ReachabilityObserver {
  
    private let decorated: SubscriptionCentre & SubscriptionConnectionSubject
    private var subscribedWatchers: [SubscriptionWatcher] = []
    private var errorCallback: ErrorCallback?
    private var reconnecting: Bool = false
    private var queue: QueueObject = ProcessingQueueObject.serial(withLabel: "com.ALDOAppSyncSubscriptionCentreReconnector")
    private var workItem: DispatchWorkItem?
    private var state: SubscriptionCentreConnectionState = .reconnecting
    private let logger: AWSLogger?
    private let connectionStateRequest: RequestConnectionState
    
    init(decorated: SubscriptionCentre & SubscriptionConnectionSubject,
         logger: AWSLogger? = nil,
         connectionStateRequest: @escaping RequestConnectionState) {
        self.decorated = decorated
        self.logger = logger
        self.connectionStateRequest = connectionStateRequest
        decorated.setConnectionError { [weak self] in self?.proccessError($0) }
        decorated.setEstablishedConnection(callback: {[weak self] in self?.connectionIsEstablished()})
    }
    
    
    // MARK: - SubscriptionCentre Implementation
    
    /// Subscribes a watcher. Will hold in the internal storage
    ///
    /// - Parameter watcher: SubscriptionWatcher
    func subscribe(watcher: SubscriptionWatcher) {
        subscribedWatchers.append(watcher)
        decorated.subscribe(watcher: watcher)
    }
    
    
    /// Unsubscribe a wather. Will try to search in the internal storage by id
    /// Removes from the internal storage and calls decorated object to finish unsubsription
    ///
    /// - Parameter id: Int
    func unsubscribe(watcherWithID id: Int) {
        if let watcher = subscribedWatchers.first(where: { $0.id == id}) {
            unsubscribe(watcher: watcher)
            subscribedWatchers = subscribedWatchers.filter({ $0.id != id })
        } else {
            decorated.unsubscribe(watcherWithID: id)
        }
    }
    
    /// Unsubsribe a wather. Will remove if exists from the internal storage and calls decorated object to finish unsubsription
    ///
    /// - Parameter watcher: SubscriptionWatcher
    func unsubscribe(watcher: SubscriptionWatcher) {
        subscribedWatchers = subscribedWatchers.filter({ $0.id != watcher.id })
        decorated.unsubscribe(watcher: watcher)
    }
    
    /// Sets closure to observe connection error
    ///
    /// - Parameter callback: (Error) -> Void
    func setConnectionError(callback: @escaping ErrorCallback) {
        errorCallback = callback
        decorated.setConnectionError { [weak self] in self?.proccessError($0) }
    }
    
    /// Sets closure to observe when connection is established
    ///
    /// - Parameter callback: @escaping () -> Void
    func setEstablishedConnection(callback: @escaping () -> Void) {
        decorated.setEstablishedConnection { [weak self] in
            self?.connectionIsEstablished()
            callback()
        }
    }
    
    
    // MARK: - ReachabilityObserver Implementation
    
    func hasChanged(to: Reachability.Connection) {
        logger?.log(message: "Network status has changed to \(to)",
                    filename: #file,
                    line: #line,
                    funcname: #function)
        switch to {
        case .wifi, .cellular:
            queue.sync { [weak self] in self?.performWorkItemIfCan() }
            
        default: break
        }
    }
    
    // MARK: - SubscriptionConnectionSubject Implementation
    
    func addObserver(_ observer: SubscriptionConnectionObserver) {
        decorated.addObserver(observer)
    }
    
    func removeObserver(_ observer: SubscriptionConnectionObserver) {
        decorated.removeObserver(observer)
    }
    
    
    private func connectionIsEstablished() {
        state = .connected
        workItem = nil
    }
    
    private func stopReconnectItemIfNeed() {
        logger?.log(message: "Will attempt to stop reconnection for state \(state)", filename: #file, line: #line, funcname: #function)
        queue.sync { [weak self] in
            if self?.state == .reconnecting {
                self?.logger?.log(message: "cancelling reconnection", filename: #file, line: #line, funcname: #function)
                self?.workItem?.cancel()
                self?.workItem = nil
            }
            self?.markDisconnected()
        }
    }
    
    private func markDisconnected() {
        logger?.log(message: "Will attempt to markDisconnected for state \(state)", filename: #file, line: #line, funcname: #function)
        if state != .disconnected {
            state = .disconnected
            logger?.log(message: "Disconnecting", filename: #file, line: #line, funcname: #function)
            self.subscribedWatchers.forEach({ self.decorated.unsubscribe(watcher: $0) })
        }
    }
    
    private func proccessError(_ error: Error) {
        logger?.log(error: error, filename: #file, line: #line, funcname: #function)
        if let _ = error as? MQTTStatusError {
            stopReconnectItemIfNeed()
            startReconnectionLogic()
        } else {
            errorCallback?(error)
        }
    }
    
    private func startReconnectionLogic() {
        queue.sync {[weak self] in
            guard let `self` = self else { return }
            self.logger?.log(message: "Attemt to start reconnection for \(self.state)", filename: #file, line: #line, funcname: #function)
            if self.state == .disconnected {
                self.state = .reconnecting
                self.workItem = self.createReconnectItem()
                self.performWorkItemIfCan()
            }
        }
    }
    
    
    private func performWorkItemIfCan() {
        if canRetry {
            self.logger?.log(message: "will retry work item \(self.state)", filename: #file, line: #line, funcname: #function)
            workItem?.perform()
            workItem = nil
        }
    }
    
    private var canRetry: Bool {
        self.logger?.log(message: "Can retry for  \(connectionStateRequest())", filename: #file, line: #line, funcname: #function)
        return connectionStateRequest() != .none
    }
    
    private func createReconnectItem() -> DispatchWorkItem {
        return DispatchWorkItem(block: { [weak self] in
            guard let `self` = self else { return }
            self.logger?.log(message: "Will subscribe watchers on reconnect", filename: #file, line: #line, funcname: #function)
            self.subscribedWatchers.forEach({ self.decorated.subscribe(watcher: $0) })
        })
    }
}
