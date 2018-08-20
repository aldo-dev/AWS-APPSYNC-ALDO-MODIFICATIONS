//
//  GraphQLSerializer.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-07.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

protocol GraphQLSerializer {
    func serialize<Operation: GraphQLOperation>(_ data: Data, for operation: Operation) -> Promise<GraphQLResponse<Operation>>
}

final class GraphQLBasicSerializer: GraphQLSerializer {
    func serialize<Operation>(_ data: Data, for operation: Operation) -> Promise<GraphQLResponse<Operation>> where Operation : GraphQLOperation {
        return Promise<GraphQLResponse<Operation>>({ () -> GraphQLResponse<Operation> in
            guard let datastring = String.init(data: data, encoding: .utf8),
                  let encodedData = datastring.data(using: .utf8),
                  let json = try JSONSerializationFormat.deserialize(data: encodedData) as? JSONObject else {
                throw NSError(domain: "GraphQLBasicSerializer", code: 1, userInfo: ["msg": "Cant convert to string"])
            }
            
            return GraphQLResponse(operation: operation, body: json)
        })
    }
}
