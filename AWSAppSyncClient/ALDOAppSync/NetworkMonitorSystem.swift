//
//  NetworkMonitorSystem.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-09-26.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import Reachability



final class NetworkMonitorSystem: ReachabilityObserver {
    
    private var observers: [ReachabilityObserver] = []
    private var lastKnownState: Reachability.Connection = .none
    private let logger: AWSLogger?
    init(logger: AWSLogger? = nil) {
        self.logger = logger
    }
    func addObserver(_ observer: ReachabilityObserver) {

        guard !observers.contains(where: { $0 === observer }) else {
            return
        }
        
        observers.append(observer)
    }
    
    
    func removeObserver(_ observer: ReachabilityObserver) {
        observers = observers.filter({ $0 !== observer })
        
    }

    
    func hasChanged(to: Reachability.Connection) {
        notifyObserversOnChange(to)
    }
    
    private func notifyObserversOnChange(_ state: Reachability.Connection)  {
        logger?.log(message: "Will change status connection from: \(lastKnownState) to \(state)", filename: #file, line: #line, funcname: #function)
        lastKnownState = state
        observers.forEach({ $0.hasChanged(to: state ) })
    }
    
}
