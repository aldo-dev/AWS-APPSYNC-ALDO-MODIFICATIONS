//
//  ALDOSubscriptionWatcher.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-07.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

protocol SubscriptionWatcher: class {
    var id: Int { get }
    var topics: [String] { get }
    func received(_ data: Data)
    func requestSubscriptionRequest() -> Promise<SubscriptionWatcherInfo>
    func cancel()
}

protocol StoreWriter {
    func withinReadWriteTransaction<T>(_ body: @escaping (ApolloStore.ReadWriteTransaction) throws -> T) -> Promise<T>
}

struct SubscriptionWatcherInfo {
    let topics: [String]
    let info: [AWSSubscriptionInfo]
}

public final class ALDOMQTTSubscritionWatcher<S: GraphQLSubscription, Set>: SubscriptionWatcher, Loggable where Set == S.Data {

    public let id: Int
    internal var topics: [String] = []
    let subscription: S
    let requester: SubscriptionRequester
    let parser: GraphQLDataTransformer
    private var cancellation: (() -> Void)?
    var callback: ((Promise<Set?>) -> Void)?
    private let logger: AWSLogger?
    
    init(id: Int = UUID().hashValue,
         subscription: S,
         requester: SubscriptionRequester,
         parser: GraphQLDataTransformer,
         logger: AWSLogger? = nil) {
        self.id = id
        self.parser = parser
        self.subscription = subscription
        self.requester = requester
        self.logger = logger
    }
    
    func received(_ data: Data) {
        logger?.log(message: "Received: \(data)", filename: #file, line: #line, funcname: #function)
        guard let callback = callback else { return }
        let newPromise = self.parser.transform(data, for: subscription)
                                    .map({ $0.0 })
        callback(newPromise)
    }
    
    func requestSubscriptionRequest() -> Promise<SubscriptionWatcherInfo> {
        return requester.sendRequest(for: subscription)
                        .andThen({ [weak self] in self?.topics = $0.topics })                    
    }
    
    func subscribe(_ callback: @escaping (Promise<Set?>) -> Void) {
        self.callback = callback
    }
    
    func setCancellationClosure(_ closure: @escaping () -> Void) {
        cancellation = closure
    }
 
    public func cancel() {
        cancellation?()
    }
    deinit {
        cancel()
    }
}

