//
//  ALDOAppSyncSubscriptionCentre.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-07.
//

import Foundation

protocol MQTTClientConnector: class {
    func connect(withClientId: String!, presignedURL: String!, statusCallback: ((AWSIoTMQTTStatus) -> Void)!) -> Bool
    func subscribe(toTopic: String!, qos: UInt8, extendedCallback: AWSIoTMQTTExtendedNewMessageBlock!)
    func unsubscribeTopic(_ topic: String!)
    func disconnect()
}

extension AWSIoTMQTTClient: MQTTClientConnector {}

protocol SubscriptionCentre {
    func subscribe(watcher: SubscriptionWatcher)
    func unsubscribe(watcherWithID id: Int)
    func unsubscribe(watcher: SubscriptionWatcher)
    func setConnectionError(callback: @escaping ErrorCallback)
    func setEstablishedConnection(callback: @escaping () -> Void)
}

typealias ErrorCallback = (Error) -> Void


protocol SubscriptionConnectionSubject {
    func addObserver(_ observer: SubscriptionConnectionObserver)
    func removeObserver(_ observer: SubscriptionConnectionObserver)
}

enum ALDOAppSyncSubscriptionCentreState: Equatable {
    static func == (lhs: ALDOAppSyncSubscriptionCentreState, rhs: ALDOAppSyncSubscriptionCentreState) -> Bool {
        switch (lhs, rhs) {
        case (.connected, .connected),
             (.error,.error),
             (.closed,.closed): return true
        default: return false
        }
    }
    
    case closed
    case connected
    case error(Error)
    
}

/// Subscription centre mangages wathers subscribing/unsubscribing
final class ALDOAppSyncSubscriptionCentre: SubscriptionCentre, SubscriptionConnectionSubject, Loggable {
    
    private var source = WatcherSource<String>()
    private let client: ALDOSubscriptionConnector
    private let statusProccessor = MQTTStatusProcessor()
    private var connectedTopics: [String] = []
    private var connectionErrorCallback: ErrorCallback?
    private var establishedConnection: (() -> Void)?
    private var connectionObservers: [SubscriptionConnectionObserver] = []
    private var state: ALDOAppSyncSubscriptionCentreState = .closed
    private let logger: AWSLogger?
    
    init(client: ALDOSubscriptionConnector,
         logger: AWSLogger? = nil) {
        self.client = client
        self.logger = logger
    }
    
    /// Subscribes a Watcher
    /// - sends request to obtain token and topic info
    /// - sends request to establish the connection
    /// - sends request to connect to topics
    ///
    /// - Parameter watcher: SubscriptionWatcher
    func subscribe(watcher: SubscriptionWatcher) {
        logger?.log(message: "Subscribing watcher", filename: #file, line: #line, funcname: #function)
        requestConnectionInfo(for: watcher)
            .andThen({[weak self] in self?.logger?.log(message: "Received new topics: \($0.topics)", filename: #file, line: #line, funcname: #function) })
            .andThen({[weak self] in self?.logger?.log(message: "Received  info: \($0.info.map({ "\($0.clientId) with topics: \($0.topics)" }))", filename: #file, line: #line, funcname: #function) })
            .andThen({ [weak self] in self?.establishConnection(with: $0)})
            .andThen({ [weak self] in self?.connect(to: $0.topics) })
            .catch({ [weak self] in self?.connectionErrorCallback?($0) })
    }
    
    
    /// Sets closure to observe connection error
    ///
    /// - Parameter callback: (Error) -> Void
    func setConnectionError(callback: @escaping (Error) -> Void) {
        connectionErrorCallback = callback
    }
    
    /// Sets closure to observe when connection is established
    ///
    /// - Parameter callback: @escaping () -> Void
    func setEstablishedConnection(callback: @escaping () -> Void) {
        establishedConnection = callback
    }
    
    
    /// Unsubscribe watcher based on id.
    /// - NOTE: Unsubscribes only if internal source contains watcher with the id
    /// - Parameter id: Int
    func unsubscribe(watcherWithID id: Int) {
        if let watcher = source.watcher(with: id) {
            unsubscribe(watcher: watcher)
        }
    }
    
    /// Unsubscribes a watcher
    ///
    /// - NOTE:
    ///    - Will disconnect a topic if this is the last wather that listens it
    ///    - Will close the connection if it is the last watcher
    ///
    /// - Parameter watcher: SubscriptionWatcher
    func unsubscribe(watcher: SubscriptionWatcher) {
        source.topics(for: watcher).forEach { (topic) in
            self.disconnectTopicIfNeed(topic)
            self.source.remove(watcher: watcher, for: topic)
            self.closeConnectionIfNeed()
        }
    }
    
    /// Add observer to listen connection status
    ///
    /// - Parameter observer: SubscriptionConnectionObserver
    func addObserver(_ observer: SubscriptionConnectionObserver) {
        if !connectionObservers.contains(where: { $0 === observer}) {
            connectionObservers.append(observer)
            notifyObserverAboutLastState(observer)
        }
    }
    
    
    /// Remove observer from listening connection status
    ///
    /// - Parameter observer: SubscriptionConnectionObserver
    func removeObserver(_ observer: SubscriptionConnectionObserver) {
        connectionObservers = connectionObservers.filter({ $0 !== observer })
    }
    
    private func disconnectTopicIfNeed(_ topic: String) {
        guard !source.watchers(for: topic).isEmpty else { return }
        logger?.log(message: "Disconnecting from topic \(topic)",
                    filename: #file,
                    line: #line,
                    funcname: #function)
        self.client.disconnect(topic: topic)
        connectedTopics = connectedTopics.filter({ $0 != topic})
    }
    
    private func requestConnectionInfo(for watcher: SubscriptionWatcher) -> Promise<SubscriptionWatcherInfo> {
        return watcher.requestSubscriptionRequest()
                      .andThen({ [weak self] in self?.appendWatcher(watcher, for: $0.topics) })
    }

    private func appendWatcher(_ watcher: SubscriptionWatcher, for topics: [String]) {
        topics.forEach({ source.append(watcher: watcher, for: $0) })
    }
    
    private func connect(to topics: [String]) {
        topics.forEach({ self.connect(to: $0) })
    }
    
    private func connect(to topic: String) {
        guard !connectedTopics.contains(topic) else { return }
        connectedTopics.append(topic)
        
        logger?.log(message: "Start subscribing to topic: \(topic)",
                    filename: #file,
                    line: #line,
                    funcname: #function)
        client.subscribe(toTopic: topic) { [weak self] (result) in
            
            result.andThen({[weak self] _ in self?.logger?.log(message: "Received data for topic \(topic)",
                                                               filename: #file,
                                                               line: #line,
                                                               funcname: #function)})
                  .andThen({[weak self] in self?.proccessReceived(message: $0) })
        }
    }
    
    private func proccessReceived(message: MessageData) {
        source.watchers(for: message.topic).forEach({ $0.received(message.data) })
    }
    
    private func establishConnection(with info: SubscriptionWatcherInfo) {
        client.connect(using: info, statusCallBack: { [weak self] in self?.monitor(status: $0) })
    }
    
    
    private func closeConnectionIfNeed() {
        if self.source.isEmpty {
            
            self.logger?.log(message: "Closing connection",
                             filename: #file,
                             line: #line,
                             funcname: #function)
            
            state = .closed
            self.client.disconnectAll()
        }
    }
    
    private func monitor(status: Promise<AWSIoTMQTTStatus>) {
        
        status.flatMap(statusProccessor.proccessStatus)
              .andThen({ [weak self] _ in self?.connectionEstablished() })
              .catch({ [weak self] in self?.connectionError($0) })
    }
    
    private func notifyObserverAboutLastState(_ observer: SubscriptionConnectionObserver) {
        switch state {
        case .connected: observer.connectionEstablished()
        case let .error(error): observer.connectionError(error)
        default: break
        }
    }
    
    private func connectionEstablished() {
        guard state != .connected else { return }
        logger?.log(message: "Connection Established with success",
                    filename: #file,
                    line: #line,
                    funcname: #function)
        
        establishedConnection?()
        state = .connected
        notifyObserversConnectionEstablished()
    }
    
    private func notifyObserversConnectionEstablished() {
        connectionObservers.forEach({ $0.connectionEstablished() })
    }
    
    private func connectionError(_ error: Error) {
        guard state != .error(error) else { return }
        logger?.log(error: error,
                    filename: #file,
                    line: #line,
                    funcname: #function)
        
        connectionErrorCallback?(error)
        state = .error(error)
    }
    
    private func notifyObserversConnectionError(_ error: Error) {
        connectionObservers.forEach({ $0.connectionError(error) })
    }
}
