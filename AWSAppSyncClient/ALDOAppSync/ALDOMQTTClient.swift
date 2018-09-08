//
//  ALDOMQTTClient.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-07.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

struct MessageData {
    let topic: String
    let data: Data
}

protocol ALDOMQTTClientConnector {
    func connect(withClientID id: String, host: String, statusCallBack: @escaping (Promise<AWSIoTMQTTStatus>) -> Void)
    func subscribe(toTopic topic: String!, callback: @escaping (Promise<MessageData>) -> Void)
    func disconnect(topic: String)
    func disconnectAll()
}


enum ALDOMQTTClientError: Error {
    case subscribingIsNotAllowed
}



/// High level api for MQTTClient
/// Allows to establish connection only once
/// Subscribe to the topic is paused until the connection is established
final class ALDOMQTTClient: ALDOMQTTClientConnector, Loggable {
    
    private static let proccessingQueue: QueueObject = ProcessingQueueObject.serial(withLabel: "com.ALDOMQTTClient.proccessing")
    private var client: MQTTClientConnector
    private var statusProcessor = MQTTStatusProcessor()
    private var semaphore = DispatchSemaphore(value: 1)
    private let proccessingQueue: QueueObject
    private let serialQueue = DispatchQueue(label: "com.ALDOMQTTClient.serial")

    private var currentState: AWSIoTMQTTStatus = .unknown
    private let logger: AWSLogger?
    
    init(client: MQTTClientConnector,
         proccessingQueue: QueueObject = ALDOMQTTClient.proccessingQueue,
         logger: AWSLogger? = nil) {
        self.client = client
        self.logger = logger
        self.proccessingQueue = proccessingQueue
    }
    
    
    /// Establishes web-socket connection
    ///
    /// - Parameters:
    ///   - id: client id
    ///   - host: host
    ///   - statusCallBack: @escaping (Promise<AWSIoTMQTTStatus>) -> Void
    func connect(withClientID id: String,
                 host: String,
                 statusCallBack: @escaping (Promise<AWSIoTMQTTStatus>) -> Void) {
        
        guard currentState != .connected && currentState != .connecting else {
            callStatusChangedIfNeed(for: currentState, { statusCallBack(Promise(fulfilled: currentState)) })
            return
        }
        
        logger?.log(message: "Establish connection  for client id: \(id)", filename: #file, line: #line, funcname: #function)
        updateStateOfQueueForNewState(.connecting)
        currentState = .connecting
        let _ = self.client.connect(withClientId: id,
                            presignedURL: host,
                            statusCallback: {[weak self] (status) in
                               self?.processNewStatus(status, statusCallBack: statusCallBack)
                                
        })
    }
    
    
    func subscribe(toTopic topic: String!,
                   callback: @escaping (Promise<MessageData>) -> Void) {
        
        if let errorState = errorStateForSubscribing {
            callback(errorState)
            return
        }
        startSubscribing(toTopic: topic, callback: callback)
    }
    
    
    private func processNewStatus(_ status: AWSIoTMQTTStatus, statusCallBack: @escaping (Promise<AWSIoTMQTTStatus>) -> Void ) {
        serialQueue.sync { [weak self] in
            self?.updateStateOfQueueForNewState(status)
            self?.callStatusChangedIfNeed(for: status, { statusCallBack(Promise(fulfilled: status)) })
            self?.currentState = status
        }
    }
    
    private var errorStateForSubscribing: Promise<MessageData>? {
        switch currentState {
        case .connected,.connecting: return nil
        default: return Promise<MessageData>.init(rejected: ALDOMQTTClientError.subscribingIsNotAllowed)
        }
    }
    
    private func callStatusChangedIfNeed(for newStatus: AWSIoTMQTTStatus, _ closure: ()->Void ) {
        guard connectionHasChanged(for: newStatus) else { return }
        logger?.log(message: "Will call status callback with \(currentState)",
                    filename: #file,
                    line: #line,
                    funcname: #function)
        closure()
    }
    private func connectionHasChanged(for status: AWSIoTMQTTStatus) -> Bool {
        switch (currentState, status) {
        case (.connecting,.connected),
             (.connected,.disconnected),
             (.connected,.connectionRefused),
             (.connected,.connectionError),
             (.connected,.protocolError),
             (.connecting,.disconnected),
             (.connecting,.connectionRefused),
             (.connecting,.connectionError),
             (.connecting,.protocolError):
             return true
        default: return false
        }
    }
    
    private func updateStateOfQueueForNewState(_ status: AWSIoTMQTTStatus) {
        logger?.log(message: "Will update state from \(currentState.rawValue) to \(status.rawValue)",
                    filename: #file,
                    line: #line,
                    funcname: #function)
        switch (currentState, status) {
        case (.connecting,.connecting): break
        case (_ , .connecting): proccessingQueue.suspend()
        case (.connecting, _): proccessingQueue.resume()
        default: break
        }
    }
    
    private func startSubscribing(toTopic topic: String!,
                                  callback: @escaping (Promise<MessageData>) -> Void) {
        logger?.log(message: "Pass item to queue subscribing to topic \(topic)", filename: #file, line: #line, funcname: #function)
        proccessingQueue.async { [weak self] in
            guard self?.currentState == .connected else {
                self?.logger?.log(message: "State is not connected, discarding: \(topic)", filename: #file, line: #line, funcname: #function)
                return
                
            }
            self?.logger?.log(message: "Start subscribing to topic \(topic)", filename: #file, line: #line, funcname: #function)
            self?.client.subscribe(toTopic: topic, qos: 1, extendedCallback: { (_, _, data) in
                self?.proccessResponse(forTopic: topic, data: data, using: callback)
            })
        }
    }
    
    private func proccessResponse(forTopic topic: String,
                                  data: Data?,
                                  using callback: @escaping (Promise<MessageData>) -> Void) {
        logger?.log(message: "Received Data for topic: \(topic)", filename: #file, line: #line, funcname: #function)
        if let data = data {
            callback(Promise(fulfilled: MessageData(topic: topic, data: data)))
        }
    }
    
    func disconnect(topic: String) {
        logger?.log(message: "Diconnecting from topic: \(topic)", filename: #file, line: #line, funcname: #function)
        client.unsubscribeTopic(topic)
    }
    
    func disconnectAll() {
        logger?.log(message: "Closing connection", filename: #file, line: #line, funcname: #function)
        client.disconnect()
    }
}
