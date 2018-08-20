//
//  GraphQLDataTransformerWriteDecorator.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-14.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

protocol StorePublisher {
    func publish(records: RecordSet, context: UnsafeMutableRawPointer?) -> Promise<Void>
}

extension ApolloStore: StorePublisher {}

final class GraphQLDataTransformerWriteDecorator: GraphQLDataTransformer {
    
    let decorated: GraphQLDataTransformer
    let storePublisher: StorePublisher
    
    init(decorated: GraphQLDataTransformer,
         storePublisher: StorePublisher) {
        self.decorated = decorated
        self.storePublisher = storePublisher
    }
    
    func transform<O, Set>(_ data: Data, for operation: O) -> Promise<(Set?, RecordSet?)> where O : GraphQLOperation, Set == O.Data {
        return decorated.transform(data, for: operation)
                        .flatMap({ self.saveToStore(result: $0, for: operation) })
    }
    
    
    private func saveToStore<O, Set>(result: (Set?, RecordSet?), for operation: O) -> Promise<(Set?,RecordSet?)> where O : GraphQLOperation, Set == O.Data {
        
        guard let recordSet = result.1 else {
            return Promise(fulfilled: result)
        }
        
       return self.storePublisher.publish(records: recordSet, context: nil)
                                 .map({ _ in result})
    }
}
