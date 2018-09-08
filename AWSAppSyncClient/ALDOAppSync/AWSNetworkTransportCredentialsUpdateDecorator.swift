//
//  AWSNetworkTransportCredentialsUpdateDecorator.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-19.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import Reachability

public protocol CredentialsUpdater {
    func refreshToken(completion: @escaping (Promise<Void>) -> Void)
}

final class AWSNetworkTransportCredentialsUpdateDecorator: AWSNetworkTransport,ReachabilityObserver {
 
    
    let decorated: AWSNetworkTransport & ReachabilityObserver
    var executingItems: [WorkItem] = []
    let serialQueue: QueueObject
    let itemFactory: WorkItemFactory
    private let credentialsUpdater: CredentialsUpdater
    private let logger: AWSLogger?
    private var waitingForCredentials: Bool = false
    
    init(decorated: AWSNetworkTransport & ReachabilityObserver,
         queueObject: QueueObject = ProcessingQueueObject.serial(withLabel: "com.SubscriptionRequestingDecorator"),
         factory: WorkItemFactory = CancellableWorkItemFactory.defaultFactory,
         credentialsUpdater: CredentialsUpdater,
         logger: AWSLogger? = nil) {
        
        self.decorated = decorated
        self.serialQueue = queueObject
        self.itemFactory = factory
        self.logger = logger
        self.credentialsUpdater = credentialsUpdater
    }
    
    func hasChanged(to: Reachability.Connection) {
        decorated.hasChanged(to: to)
    }
    
    func send(data: Data, completionHandler: ((JSONObject?, Error?) -> Void)?) {
        let item = itemFactory.createItem()
        let id = item.id
        item.setWork { [weak self] () -> Cancellable in
            return self?.sendData(data,
                                  forItemID: id,
                                  completionHandler: { (json, error) in
                                    completionHandler?(json,error)
                                    
            }) ?? EmptyCancellable()
        }
        
        item.setCancelCallback { [weak self] in
            self?.removeItem(with: id)
        }
        performItem(item)
    }
    
    fileprivate func sendData(_ data: Data,
                              forItemID id: String,
                              completionHandler: @escaping (JSONObject?, Error?) -> Void ) -> Cancellable {
        decorated.send(data: data) {[weak self] (json, error) in
            self?.proccess(responseJSON: json, error: error, for: id, completion: completionHandler)
        }
        
        return EmptyCancellable()
        
    }
    
    
    // MARK: - SubscriptionRequesting Implementation
    
    func sendSubscriptionRequest<Operation>(operation: Operation,
                                            completionHandler: @escaping (JSONObject?, Error?) -> Void) throws -> Cancellable where Operation : GraphQLOperation {
        
        let item = getItemFor(operation: operation, completionHandler: completionHandler)
        performItem(item)
        return item
    }
    
    func send<Operation>(operation: Operation,
                         overrideMap: [String : String],
                         completionHandler: @escaping (GraphQLResponse<Operation>?, Error?) -> Void) -> Cancellable where Operation : GraphQLOperation {
        
        let item = getOperationItem(operation: operation,
                                    overrideMap: overrideMap,
                                    completionHandler: completionHandler)
        logger?.log(message: "Create item with id: \(item.id) for operation \(Operation.operationString)",
            filename: #file,
            line: #line,
            funcname: #function)
        performItem(item)
        return item
    }

    
    
    private func performItem(_ item: WorkItem) {
        appendItem(item)
        if !waitingForCredentials {
            logger?.log(message: "Will perfrom item with id \(item.id)", filename: #file, line: #line, funcname: #function)
            item.perform()
        }
    }
    
    fileprivate func getOperationItem<Operation>(operation: Operation,
                                                 overrideMap: [String: String],
                                                 completionHandler: @escaping (GraphQLResponse<Operation>?, Error?) -> Void) -> WorkItem where Operation : GraphQLOperation {
        let item = itemFactory.createItem()
        let id = item.id
        
        item.setWork { [weak self] () -> Cancellable in
            guard let `self` = self else { return EmptyCancellable() }
            
            return self.decorated.send(operation: operation,
                                       overrideMap: overrideMap,
                                       completionHandler: { [weak self] (resonse, error) in
                                        self?.proccess(responseJSON: resonse,
                                                       error: error,
                                                       for: id,
                                                       completion: completionHandler)
            })
        }
        
        item.setCancelCallback { [weak self] in
            self?.removeItem(with: id)
        }
        
        return item
    }
    
    
    fileprivate func getItemFor<Operation>(operation: Operation,
                                           completionHandler: @escaping (JSONObject?, Error?) -> Void) -> WorkItem where Operation : GraphQLOperation {
        let item = itemFactory.createItem()
        let id = item.id
        self.logger?.log(message: "Creating item with id \(id) for operation \(Operation.operationString)", filename: #file, line: #line, funcname: #function)
        item.setWork { [weak self] () -> Cancellable in
            self?.logger?.log(message: "Sending request \(Operation.operationString)", filename: #file, line: #line, funcname: #function)
           return self?.sendRequest(operation: operation, forItemID: id, completionHandler: completionHandler) ?? EmptyCancellable()
        }
        
        item.setCancelCallback { [weak self] in
            self?.removeItem(with: id)
        }
        
        return item
    }
    
    
    fileprivate func sendRequest<Operation>(operation: Operation,
                                            forItemID id: String,
                                            completionHandler: @escaping (JSONObject?, Error?) -> Void ) -> Cancellable where Operation : GraphQLOperation{
        
        let cancellable = try? decorated.sendSubscriptionRequest(operation: operation,
                                                                 completionHandler: { [weak self] (json, error) in
                                                                    
                                                                    self?.proccess(responseJSON: json,
                                                                                   error: error,
                                                                                   for: id,
                                                                                   completion: completionHandler)
                                                                    
        })
        return cancellable ?? EmptyCancellable()
    }
    
    
    fileprivate func proccess<Response>(responseJSON: Response?,
                                        error: Error?,
                                        for id: String,
                                        completion: @escaping (Response?, Error?) -> Void) {
        
        if let error = error {
            processError(error: error, forItemID: id, completion: completion)
        } else {
            logger?.log(message: "Operation request success for item \(id)", filename: #file, line: #line, funcname: #function)
            removeItem(with: id)
            completion(responseJSON,nil)
        }
    }
    
    
    fileprivate func processError<Response>(error: Error,
                                            forItemID id: String,
                                            completion: @escaping (Response?, Error?) -> Void) {
        logger?.log(message: "Received error for item id \(id)", filename: #file, line: #line, funcname: #function)
        logger?.log(error: error, filename: #file, line: #line, funcname: #function)
        
        guard !shouldPause(forError: error) else  {
            requestCredentials()
            return
        }
        
        removeItem(with: id)
        completion(nil,error)
    }
    
    fileprivate func requestCredentials() {
        
        if !waitingForCredentials {
            logger?.log(message: "Requesting credentials", filename: #file, line: #line, funcname: #function)
            waitingForCredentials = true
            credentialsUpdater.refreshToken { [weak self] (result) in
                self?.waitingForCredentials = false
                result.andThen({[ weak self] _ in  self?.performPausedItems() })
                      .andThen({[weak self] _ in self?.logger?.log(message: "Received new token", filename: #file, line: #line, funcname: #function)})
                      .catch({ [weak self] _ in self?.requestCredentials() })
                      .catch({ [weak self] in self?.logger?.log(error: $0, filename: #file, line: #line, funcname: #function)})
            }
        }
    }
    
    fileprivate func performPausedItems() {
        executingItems.forEach({ $0.perform() })
    }
    
    fileprivate func shouldPause(forError error: Error) -> Bool {
       return (error as? AWSAppSyncClientError).flatMap({ $0.response})
                                               .map({ $0.statusCode == 401 }) ?? false
        
    }

    
    fileprivate func removeItem(with id: String) {
        serialQueue.sync { [weak self] in
            guard let `self` = self else { return }
            self.executingItems = self.executingItems.filter({$0.id != id})
        }
    }
    
    fileprivate func appendItem(_ item: WorkItem) {
        serialQueue.sync { [weak self] in
            self?.executingItems.append(item)
        }
    }
    
}
