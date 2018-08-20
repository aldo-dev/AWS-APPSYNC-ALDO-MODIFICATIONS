//
//  ALDOAppSyncSubscriptionCentreMock.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync

final class ALDOAppSyncSubscriptionCentreMock: SubscriptionCentre, SubscriptionConnectionSubject {
  

    private(set) var subscribedWatchers: [SubscriptionWatcher] = []
    private(set) var unsubscribedWatchersIDs: [Int] = []
    private(set) var unsubscribedWatchers: [SubscriptionWatcher] = []
    
    private(set) var errorCallback: ErrorCallback?
    private(set) var establishedConnectionCallback: (()->Void)?
    private(set) var connectionObservers: [SubscriptionConnectionObserver] = []
    
    
    func sendError(error: Error) {
        errorCallback?(error)
    }
    
    func callConnectionEstablished() {
        establishedConnectionCallback?()
    }
    
    func subscribe(watcher: SubscriptionWatcher) {
        subscribedWatchers.append(watcher)
    }
    
    func unsubscribe(watcherWithID id: Int) {
        unsubscribedWatchersIDs.append(id)
    }
    
    func unsubscribe(watcher: SubscriptionWatcher) {
        unsubscribedWatchers.append(watcher)
    }
    
    func setConnectionError(callback: @escaping ErrorCallback) {
        errorCallback = callback
    }
    
    func setEstablishedConnection(callback: @escaping () -> Void) {
        establishedConnectionCallback = callback
    }
    
    
    func addObserver(_ observer: SubscriptionConnectionObserver) {
        if !connectionObservers.contains(where: { $0 === observer}) {
            connectionObservers.append(observer)
        }
    }
    
    func removeObserver(_ observer: SubscriptionConnectionObserver) {
        connectionObservers = connectionObservers.filter({ $0 !== observer })
    }
}

