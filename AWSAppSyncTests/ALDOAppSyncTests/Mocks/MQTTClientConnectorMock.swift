//
//  MQTTClientConnectorMock.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-09.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync

final class MQTTClientConnectorMock: MQTTClientConnector {
  
    private(set) var disconnectCount = 0
    private(set) var connectedClients: [String] = []
    private(set) var connectedHosts: [String] = []
    private(set) var statusCallbacks: [((MQTTStatus) -> Void)] = []
    private(set) var subscribedTopics: [String] = []
    private(set) var extendedCallbacks: [MQTTExtendedNewMessageBlock] = []
    private(set) var unsubscribedTopics: [String] = []
    
    func send(status: MQTTStatus) {
        statusCallbacks.forEach({ $0(status) })
    }
    
    func connect(withClientId: String!, toHost: String!, statusCallback: ((MQTTStatus) -> Void)!) -> Bool {
        connectedClients.append(withClientId)
        connectedHosts.append(toHost)
        statusCallbacks.append(statusCallback)
        return true
    }
    
    func subscribe(toTopic: String!, qos: UInt8, extendedCallback: MQTTExtendedNewMessageBlock!) {
        subscribedTopics.append(toTopic)
        extendedCallbacks.append(extendedCallback)
    }
    
    func disconnect() {
        disconnectCount += 1
    }
    
    func unsubscribeTopic(_ topic: String!) {
        unsubscribedTopics.append(topic)
    }
    
}
