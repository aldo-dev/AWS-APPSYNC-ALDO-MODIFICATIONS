//
//  MockGraphQLQuery.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-16.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync

final class MockGraphQLQuery: GraphQLQuery {
    static var operationString: String { return "MockGraphQLQuery"}
    
    typealias Data = MockGraphQLSelecitonSet
    
    
}
