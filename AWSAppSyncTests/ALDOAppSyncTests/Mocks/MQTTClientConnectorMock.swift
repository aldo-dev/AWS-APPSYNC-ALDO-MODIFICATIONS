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
    private(set) var statusCallbacks: [((AWSIoTMQTTStatus) -> Void)] = []
    private(set) var subscribedTopics: [String] = []
    private(set) var extendedCallbacks: [AWSIoTMQTTExtendedNewMessageBlock] = []
    private(set) var unsubscribedTopics: [String] = []
    
    func send(status: AWSIoTMQTTStatus) {
        statusCallbacks.forEach({ $0(status) })
    }
    
    func connect(withClientId: String!, presignedURL: String!, statusCallback: ((AWSIoTMQTTStatus) -> Void)!) -> Bool {
        connectedClients.append(withClientId)
        connectedHosts.append(presignedURL)
        statusCallbacks.append(statusCallback)
        return true
    }
    
    func subscribe(toTopic: String!, qos: UInt8, extendedCallback: AWSIoTMQTTExtendedNewMessageBlock!) {
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
