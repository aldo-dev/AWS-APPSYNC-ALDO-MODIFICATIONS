//
//  GraphQLParser.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-07.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

protocol GraphQLParser {
    func parse<Operation: GraphQLOperation>(_ response: GraphQLResponse<Operation>) -> Promise<(GraphQLResult<Operation.Data>, RecordSet?)>
}

final class GraphQLBasicParser: GraphQLParser {
    let cacheKeyForObject: CacheKeyForObject?
    
    init(cacheKeyForObject: CacheKeyForObject?) {
        self.cacheKeyForObject = cacheKeyForObject
    }
    
    func parse<Operation: GraphQLOperation>(_ response: GraphQLResponse<Operation>) -> Promise<(GraphQLResult<Operation.Data>, RecordSet?)> {
        do {
            return try response.parseResult(cacheKeyForObject: self.cacheKeyForObject)
        } catch {
            return Promise(rejected: error)
        }
    }
}
