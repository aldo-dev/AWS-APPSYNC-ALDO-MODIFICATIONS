//
//  ALDOConnection.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-09-10.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

final class ALDOConnection {
    let client: ALDOMQTTClientConnector
    var connectedTopics: [String] = []
    let allowedTopics: [String]
    
    init(client: ALDOMQTTClientConnector,
         allowedTopics: [String]) {
        self.client = client
        self.allowedTopics = allowedTopics.sorted()
    }
    
    var isEmpty: Bool {
        return connectedTopics.isEmpty
    }
    
    func canSubscribe(toTopic topic: String) -> Bool {
        return allowedTopics.contains(topic)
    }
    func accepts(topics: [String]) -> Bool {
        return allowedTopics == topics.sorted()
    }
    
    func subscribed(toTopics topic: String) -> Bool {
        return connectedTopics.contains(topic)
    }
    
    func subscribe(toTopic topic: String!, callback: @escaping (Promise<MessageData>) -> Void) {
        connectedTopics.append(topic)
        client.subscribe(toTopic: topic, callback: callback)
    }
    
    func disconnect(topic: String) {
        if let topic = connectedTopics.first(where: { $0 == topic}) {
            client.disconnect(topic: topic)
            connectedTopics = connectedTopics.filter({ $0 != topic })
        }
    }
    
    func disconnectAll() {
        client.disconnectAll()
    }
    
}
