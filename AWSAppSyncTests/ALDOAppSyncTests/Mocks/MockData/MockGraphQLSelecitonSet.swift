//
//  MockGraphQLSelecitonSet.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync

class MockGraphQLSelecitonSet: GraphQLSelectionSet {
    required init(snapshot: Snapshot) {
        self.snapshot = snapshot
    }
    
    static var selections: [GraphQLSelection] = [GraphQLField("test",
                                                              alias: nil,
                                                              arguments: nil,
                                                              type: GraphQLOutputType.scalar(String.self))]
    
    var snapshot: Snapshot = [:]
    
    
}
