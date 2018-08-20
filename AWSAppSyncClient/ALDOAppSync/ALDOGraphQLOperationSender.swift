//
//  ALDOGraphQLOperationSender.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-14.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

protocol GraphQLOperationSender {
    func send<Operation: GraphQLOperation, Set>(operation: Operation,overrideMap: [String: String]) -> Promise<Set?> where Operation.Data == Set
}




/// Basic operation Sender
/// Provides high-api for sending an operation and publishing to store on success
final class ALDOGraphQLOperationSender: GraphQLOperationSender {
    
    let operationSending: OperationSending
    let cacheKeyForObject: CacheKeyForObject?
    let storePublisher: StorePublisher
    
    
    
    /// Init
    ///
    /// - Parameters:
    ///   - operationSending: Low-api of OperationSending
    ///   - cacheKeyForObject: CacheKeyForObject
    ///   - storePublisher: StorePublisher
    init(operationSending: OperationSending,
         cacheKeyForObject: CacheKeyForObject? = nil,
         storePublisher: StorePublisher) {
        self.operationSending = operationSending
        self.storePublisher = storePublisher
        self.cacheKeyForObject = cacheKeyForObject
    }
    
    
    
    /// Sends an operation
    ///
    /// - Parameters:
    ///   - operation: Operation as GraphQLOperation
    ///   - overrideMap: additional params map
    ///
    ///  - Note: will publish to store upon reveiving success result
    ///
    /// - Returns: Promise<Set?>
    func send<Operation, Set>(operation: Operation, overrideMap: [String : String]) -> Promise<Set?> where Operation : GraphQLOperation, Set == Operation.Data {
        let key = cacheKeyForObject
        return sendOperation(operation: operation, overrideMap: overrideMap)
                    .flatMap({ try $0.parseResult(cacheKeyForObject: key)})
                    .map({($0.0.data, $0.1)})
                    .flatMap({ self.saveToStore(result: $0, for: operation) })
                    .map({ $0.0 })
    }
    
    
    private func sendOperation<Operation>(operation: Operation,overrideMap:  [String : String]) -> Promise<GraphQLResponse<Operation>> where Operation : GraphQLOperation {
        return Promise<GraphQLResponse<Operation>>.init({ [weak self] (fullfilled, rejected) in
            let _ = self?.operationSending.send(operation: operation,
                                                overrideMap: overrideMap,
                                                completionHandler: { (response, error) in
                                                if let error = error {
                                                    rejected(error)
                                                    return
                                                }
                                                if let response = response {
                                                    fullfilled(response)
                                                    return
                                                }
            })
        })
    }
    
    private func saveToStore<O, Set>(result: (Set?, RecordSet?), for operation: O) -> Promise<(Set?,RecordSet?)> where O : GraphQLOperation, Set == O.Data {
        guard let recordSet = result.1 else {
            return Promise(fulfilled: result)
        }
        return self.storePublisher.publish(records: recordSet, context: nil)
                                  .map({ _ in result})
    }
}
