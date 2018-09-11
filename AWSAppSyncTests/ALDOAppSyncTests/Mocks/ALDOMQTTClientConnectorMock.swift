//
//  ALDOMQTTClientConnectorMock.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-09.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync

final class ALDOMQTTClientConnectorMock: ALDOMQTTClientConnector, ALDOSubscriptionConnector {
 
    
    private(set) var disconnectedTopics: [String] = []
    private(set) var disconnectAllCount = 0
    private(set) var connectedClients: [String] = []
    private(set) var connectedHosts: [String] = []
    private(set) var statusCallback: ((Promise<AWSIoTMQTTStatus>) -> Void)?
    private(set) var subscribedTopics: [String] = []
    private(set) var extendedCallback: ((Promise<MessageData>) -> Void)?
    
    private(set) var infos: [SubscriptionWatcherInfo] = []
    
    func connect(withClientID id: String,
                 host: String,
                 statusCallBack: @escaping (Promise<AWSIoTMQTTStatus>) -> Void) {
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
    
    func sendStatus(_ status: AWSIoTMQTTStatus) {
        statusCallback?(Promise(fulfilled: status))
    }
    
    func sendData(_ data: Data, for topic: String) {
        extendedCallback?(Promise(fulfilled: MessageData.init(topic: topic, data: data)))

    }
    
    func connect(using info: SubscriptionWatcherInfo,
                 statusCallBack: @escaping (Promise<AWSIoTMQTTStatus>) -> Void) {
        infos.append(info)
        connectedHosts.append(contentsOf: info.info.map({$0.url}))
        connectedClients.append(contentsOf: info.info.map({$0.clientId}))
        statusCallback = statusCallBack
    }
    
    
}
