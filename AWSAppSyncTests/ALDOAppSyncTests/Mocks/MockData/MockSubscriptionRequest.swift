//
//  MockSubscriptionRequest.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync

class MockSubscriptionRequest: GraphQLSubscription {
    static var operationString: String = "test"
    
    typealias Data = MockGraphQLSelecitonSet
    
    
}


