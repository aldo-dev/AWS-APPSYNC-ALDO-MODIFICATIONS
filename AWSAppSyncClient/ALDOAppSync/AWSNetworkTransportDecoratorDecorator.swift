//
//  AWSNetworkTransportDecorator.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-09.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import Reachability

protocol ReachabilityObserver {
    func hasChanged(to: Reachability.Connection)
}

public var NSURLNetworkRequestCancelledCode = -999
public var NSURLNetworkRequestUnauthorizedCode = 401

final class AWSNetworkTransportDecorator: AWSNetworkTransport, ReachabilityObserver, Loggable {
     
    let decorated: AWSNetworkTransport
    var executingItems: [WorkItem] = []
    var currentState: Reachability.Connection = .none
    let serialQueue: QueueObject
    let itemFactory: WorkItemFactory
    fileprivate let logger: AWSLogger?
    
    var canProceedExecution: Bool  {
        return currentState != .none
    }
    
    init(decorated: AWSNetworkTransport,
         queueObject: QueueObject = ProcessingQueueObject.serial(withLabel: "com.SubscriptionRequestingDecorator"),
         factory: WorkItemFactory = CancellableWorkItemFactory.defaultFactory,
         logger: AWSLogger? = nil) {
        self.decorated = decorated
        self.serialQueue = queueObject
        self.itemFactory = factory
        self.logger = logger
    }
    
    // MARK: - ReachabilityObserver Implementation
    
    func hasChanged(to state: Reachability.Connection) {
        logger?.log(message: "Network status has changed to \(state)",
                   filename: #file,
                   line: #line,
                   funcname: #function)
        currentState = state
        if state != .none {
            logger?.log(message: "will continue executing items",
                        filename: #file,
                        line: #line,
                        funcname: #function)
            executingItems.forEach({ $0.perform() })
        } else {
            executingItems.forEach({ $0.cancel() })
            executingItems = []
        }
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
    
    private func performItem(_ item: WorkItem) {
        appendItem(item)
        if canProceedExecution {
            logger?.log(message: "Will perfrom item with id \(item.id)", filename: #file, line: #line, funcname: #function)
            item.perform()
        }
    }
}


// MARK: Private methods
extension AWSNetworkTransportDecorator {
    
    
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
        
        item.setWork { [weak self] () -> Cancellable in
            self?.sendRequest(operation: operation, forItemID: id, completionHandler: completionHandler) ?? EmptyCancellable()
        }
        
        item.setCancelCallback { [weak self] in
            self?.removeItem(with: id)
        }
        
        return item
    }
    
    fileprivate func sendData(_ data: Data,
                              forItemID id: String,
                              completionHandler: @escaping (JSONObject?, Error?) -> Void ) -> Cancellable {
        decorated.send(data: data) {[weak self] (json, error) in
            self?.proccess(responseJSON: json, error: error, for: id, completion: completionHandler)
        }

        return EmptyCancellable()
    
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
    
    fileprivate func processError<Response>(error: Error, forItemID id: String, completion: @escaping (Response?, Error?) -> Void) {
        logger?.log(message: "Received error for item id \(id)", filename: #file, line: #line, funcname: #function)
        logger?.log(error: error, filename: #file, line: #line, funcname: #function)
        guard !shouldPause(forError: error) else  { return }
        
        guard shouldRetry(forError: error) else {
            removeItem(with: id)
            completion(nil,error)
            return
        }
        
        guard let item = executingItems.first(where: { $0.id == id && $0.canRetry }) else {
            removeItem(with: id)
            completion(nil,error)
            return
        }
        
        logger?.log(message: "Retrying item with id \(id)", filename: #file, line: #line, funcname: #function)
        item.retry()
    }
    
    fileprivate func shouldPause(forError error: Error) -> Bool {
        let code = (error as NSError).code
        return code == NSURLErrorNotConnectedToInternet ||
               code == NSURLErrorNetworkConnectionLost
    }
    
    fileprivate func shouldRetry(forError error: Error) -> Bool {
        return (error as? AWSAppSyncClientError).flatMap({ $0.response})
                                                .map({ $0.statusCode != NSURLNetworkRequestUnauthorizedCode }) ?? true
    }
}


protocol SubscriptionRequesting {
    func sendSubscriptionRequest<Operation: GraphQLOperation>(operation: Operation, completionHandler: @escaping (JSONObject?, Error?) -> Void) throws -> Cancellable
}

protocol DataSending {
    func send(data: Data, completionHandler: ((JSONObject?, Error?) -> Void)?)
}

protocol OperationSending {
    func send<Operation>(operation: Operation, overrideMap: [String: String], completionHandler: @escaping (GraphQLResponse<Operation>?, Error?) -> Void) -> Cancellable
}

typealias AWSNetworkTransport = SubscriptionRequesting & DataSending & OperationSending

extension AWSAppSyncHTTPNetworkTransport: AWSNetworkTransport {}
