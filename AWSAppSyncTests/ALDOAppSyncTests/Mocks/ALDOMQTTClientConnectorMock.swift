//
//  ALDOMQTTClientConnectorMock.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-09.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync

final class ALDOMQTTClientConnectorMock: ALDOMQTTClientConnector {
    
    private(set) var disconnectedTopics: [String] = []
    private(set) var disconnectAllCount = 0
    private(set) var connectedClients: [String] = []
    private(set) var connectedHosts: [String] = []
    private(set) var statusCallback: ((Promise<MQTTStatus>) -> Void)?
    private(set) var subscribedTopics: [String] = []
    private(set) var extendedCallback: ((Promise<MessageData>) -> Void)?
    
    func connect(withClientID id: String,
                 host: String,
                 statusCallBack: @escaping (Promise<MQTTStatus>) -> Void) {
        connectedClients.append(id)
        connectedHosts.append(host)
        statusCallback = statusCallBack
    }
    
    func subscribe(toTopic topic: String!, callback: @escaping (Promise<MessageData>) -> Void) {
        subscribedTopics.append(topic)
        extendedCallback = callback
    }
    
    func disconnect(topic: String) {
        disconnectedTopics.append(topic)
    }
    
    func disconnectAll() {
        disconnectAllCount += 1
    }
    
    func sendStatus(_ status: MQTTStatus) {
        statusCallback?(Promise(fulfilled: status))
    }
    
    func sendData(_ data: Data, for topic: String) {
        extendedCallback?(Promise(fulfilled: MessageData.init(topic: topic, data: data)))

    }
}
