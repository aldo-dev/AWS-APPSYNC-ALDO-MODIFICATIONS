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

protocol ALDOMQTTTopicSubscriber {
    func subscribe(toTopic topic: String!, callback: @escaping (Promise<MessageData>) -> Void)
    func disconnect(topic: String)
    func disconnectAll()
}

protocol ALDOMQTTClientConnector: ALDOMQTTTopicSubscriber {
    func connect(withClientID id: String, host: String, statusCallBack: @escaping (Promise<AWSIoTMQTTStatus>) -> Void)
}

enum ALDOMQTTClientError: Error {
    case subscribingIsNotAllowed
}



/// High level api for MQTTClient
/// Allows to establish connection only once
/// Subscribe to the topic is paused until the connection is established
final class ALDOMQTTClient: ALDOMQTTClientConnector, Loggable {

    private var client: MQTTClientConnector
    private var statusProcessor = MQTTStatusProcessor()
    private var semaphore = DispatchSemaphore(value: 1)
    private let proccessingQueue: QueueObject
    private let serialQueue = DispatchQueue(label: "com.ALDOMQTTClient.serial")

    private var currentStatus: AWSIoTMQTTStatus = .unknown
    private let logger: AWSLogger?
    private var subscriptionWorkItems: [DispatchWorkItem] = []
    
    init(client: MQTTClientConnector,
         proccessingQueue: QueueObject = ProcessingQueueObject.serial(withLabel: "com.ALDOMQTTClient.proccessing"),
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
        
        guard currentStatus != .connected && currentStatus != .connecting else {
            callStatusChangedIfNeed(for: currentStatus, { statusCallBack(Promise(fulfilled: currentStatus)) })
            return
        }
        
        logger?.log(message: "Establish connection  for client id: \(id)", filename: #file, line: #line, funcname: #function)
        updateStateOfQueueForNewState(.connecting)
        currentStatus = .connecting
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
            self?.currentStatus = status
        }
    }
    
    private var errorStateForSubscribing: Promise<MessageData>? {
        switch currentStatus {
        case .connected,.connecting: return nil
        default: return Promise<MessageData>.init(rejected: ALDOMQTTClientError.subscribingIsNotAllowed)
        }
    }
    
    private func callStatusChangedIfNeed(for newStatus: AWSIoTMQTTStatus, _ closure: ()->Void ) {
        guard connectionHasChanged(for: newStatus) else { return }
        logger?.log(message: "Will call status callback with \(currentStatus)",
                    filename: #file,
                    line: #line,
                    funcname: #function)
        closure()
    }
    private func connectionHasChanged(for status: AWSIoTMQTTStatus) -> Bool {
        switch (currentStatus, status) {
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
        logger?.log(message: "Will update state from \(currentStatus.rawValue) to \(status.rawValue)",
                    filename: #file,
                    line: #line,
                    funcname: #function)
        switch (currentStatus, status) {
        case (.connecting,.connecting): break
        case (_ , .connecting): proccessingQueue.suspend()
        case (.connecting, .connected):
                    performSubscribeItems()
                    proccessingQueue.resume()
        case (.connecting, _):
            cancelSubscribeItems()
            proccessingQueue.resume()
        default: break
        }
    }
    
    private func startSubscribing(toTopic topic: String!,
                                  callback: @escaping (Promise<MessageData>) -> Void) {
        logger?.log(message: "Pass item to queue subscribing to topic \(topic)", filename: #file, line: #line, funcname: #function)
        
        let item = createSubscribeItem(for: topic, with: callback)
        
        switch currentStatus {
            case .connected: proccessingQueue.async { item.perform() }
            case .unknown, .connecting: subscriptionWorkItems.append(item)
        default:
            logger?.log(message: "Discarding item for \(topic) when current state is \(currentStatus.rawValue)", filename: #file, line: #line, funcname: #function)
        }
    }
    
    
    private func performSubscribeItems() {
        logger?.log(message: "Will perform subscribing items for current state  \(currentStatus.rawValue)", filename: #file, line: #line, funcname: #function)
        subscriptionWorkItems.forEach { (item) in
            proccessingQueue.async {
                item.perform()
            }
        }
    }
    
    private func cancelSubscribeItems() {
           logger?.log(message: "Will cancel subscribing items for current state  \(currentStatus.rawValue)", filename: #file, line: #line, funcname: #function)
        subscriptionWorkItems.forEach({ $0.cancel() })
        subscriptionWorkItems = []
    }
    
    private func createSubscribeItem(for topic: String,
                                     with callback: @escaping (Promise<MessageData>) -> Void) -> DispatchWorkItem {
        return  DispatchWorkItem { [weak self] in
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
        cancelSubscribeItems()
        client.disconnect()
    }
}
