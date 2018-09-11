//
//  ALDOConnector.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-09-10.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

protocol ALDOSubscriptionConnector: ALDOMQTTTopicSubscriber {
    func connect(using info: SubscriptionWatcherInfo, statusCallBack: @escaping (Promise<AWSIoTMQTTStatus>) -> Void)
}

protocol ALDOClientFactory {
    var newConnetor: ALDOMQTTClientConnector { get }
}

final class ALDOMQTTClientFactory: ALDOClientFactory {
    let logger: AWSLogger?
    
    init(logger: AWSLogger? = nil) {
        self.logger = logger
    }
    
    var newConnetor: ALDOMQTTClientConnector {
        return ALDOMQTTClient(client: AWSIoTMQTTClient<AnyObject, AnyObject>(), logger: logger)
    }
}

final class ALDOConnector: ALDOSubscriptionConnector {
    
    let factory: ALDOClientFactory
    var connections: [ALDOConnection] = []
    let logger: AWSLogger?
    var statusCallbacks: [String: (Promise<AWSIoTMQTTStatus>) -> Void] = [:]
    var messageCallbacks: [String:  (Promise<MessageData>) -> Void] = [:]
    var lastStatus: AWSIoTMQTTStatus = .unknown
    
    init(factory: ALDOClientFactory, logger: AWSLogger? = nil) {
        self.factory = factory
        self.logger = logger
    }
    
    func connect(using info: SubscriptionWatcherInfo,
                 statusCallBack: @escaping (Promise<AWSIoTMQTTStatus>) -> Void) {
        extractInfoThatContainsCurrentTopics(from: info).forEach({ connect(using: $0, statusCallBack: statusCallBack) })
    }
    
    
    private func connect(using info: AWSSubscriptionInfo, statusCallBack: @escaping (Promise<AWSIoTMQTTStatus>) -> Void) {
        logger?.log(message: "Will attempt to connect", filename: #file, line: #line, funcname: #function)
        statusCallbacks[info.clientId] = statusCallBack
        
        let connection: ALDOConnection
    
        if let existedConnection = connections.first(where: { $0.accepts(topics: info.topics) }) {
            logger?.log(message: "Found connection for topics: \(info.topics)", filename: #file, line: #line, funcname: #function)
            connection = existedConnection
        } else {
            logger?.log(message: "Could not found connection for topics: \(info.topics). Will Create a new one", filename: #file, line: #line, funcname: #function)
            
            connection =  ALDOConnection(client: factory.newConnetor, allowedTopics: info.topics)
            connections.append(connection)
            
            connection.client.connect(withClientID: info.clientId, host: info.url,
                                      statusCallBack: { [weak self] in self?.processStatus($0, for: info.clientId) })
        }
    }
    
    func subscribe(toTopic topic: String!, callback: @escaping (Promise<MessageData>) -> Void) {
        
        guard let connection = connection(for: topic) else {
            logger?.log(message: "Can't Subscribe because could not found connection for topic: \(topic)", filename: #file, line: #line, funcname: #function)
            callback(Promise(rejected: ALDOMQTTClientError.subscribingIsNotAllowed))
            return
        }
        
        guard !connection.subscribed(toTopics: topic) else {
            logger?.log(message: "Already subscribed to the topic: \(topic)", filename: #file, line: #line, funcname: #function)
            return
        }
        
        connection.client.subscribe(toTopic: topic, callback: callback)
    }
    
    
    func disconnect(topic: String) {
        connections.filter({ $0.subscribed(toTopics: topic) })
                   .forEach({ $0.disconnect(topic: topic) })
        
        connections.filter({ $0.isEmpty }).forEach({ $0.disconnectAll() })
        
        connections = connections.filter({!$0.isEmpty})

    }
    
    func disconnectAll() {
        connections.forEach({ $0.client.disconnectAll() })
        statusCallbacks = [:]
    }
    
    private func processStatus(_ statusResult: Promise<AWSIoTMQTTStatus>, for clientID: String) {
        statusCallbacks[clientID]?(statusResult)
    }
    
    private func connection(for topic: String) -> ALDOConnection? {
        return connections.first(where: { $0.canSubscribe(toTopic: topic) })
    }
    
    private func extractInfoThatContainsCurrentTopics(from subscriptionInfo: SubscriptionWatcherInfo) -> [AWSSubscriptionInfo] {
        return subscriptionInfo.info.filter({ Set($0.topics).isSuperset(of: subscriptionInfo.topics) })
    }
    
}
