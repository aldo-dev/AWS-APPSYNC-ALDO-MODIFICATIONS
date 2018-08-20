//
//  GraphQLDataTransformer.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-07.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

protocol  GraphQLDataTransformer {
    func transform<O: GraphQLOperation,Set>(_ data: Data, for operation: O) ->  Promise<(Set?,RecordSet?)> where Set == O.Data
}

struct AppSyncGraphQLErrorsContainer: Error {
    let errors: [GraphQLError]
}

final class GraphQLDataBasicTransformer: GraphQLDataTransformer {
    
    let parser: GraphQLParser
    let serializer: GraphQLSerializer
    
    init(parser: GraphQLParser, serializer: GraphQLSerializer = GraphQLBasicSerializer()) {
        self.parser = parser
        self.serializer = serializer
    }
    
    func transform<O, Set>(_ data: Data, for operation: O) -> Promise<(Set?,RecordSet?)>  where O : GraphQLOperation, Set == O.Data {
         return serializer.serialize(data, for: operation)
                          .flatMap(parser.parse)
                          .flatMap(extractResult)
        
    }
    
    private func extractResult<D>(from result: GraphQLResult<D>, recordSet: RecordSet?) -> Promise<(D?,RecordSet?)>{
        if let errors = result.errors {
            return Promise(rejected: AppSyncGraphQLErrorsContainer(errors: errors))
        }
        return Promise<(D?,RecordSet?)>.init(fulfilled: (result.data,recordSet))
        
    }
}
