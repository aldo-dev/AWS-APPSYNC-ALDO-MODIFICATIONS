//
//  AWSNetworkTransportMock.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-20.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import Reachability
@testable import AWSAppSync

final class AWSNetworkTransportMock<T>: AWSNetworkTransport,ReachabilityObserver  where T : GraphQLOperation {
   
    
    private(set) var operations: [T] = []
    private(set) var subscriptionOperations: [T] = []
    private(set) var datas: [Data] = []
    
    private(set) var jsonCompletionHandler: ((JSONObject?, Error?) -> Void)?
    private(set) var sendOperationCompletion: ((GraphQLResponse<T>?, Error?) -> Void)?
    
    func send(data: Data, completionHandler: ((JSONObject?, Error?) -> Void)?) {
        datas.append(data)
        jsonCompletionHandler = completionHandler
    }
    
    func send<Operation>(operation: Operation,
                         overrideMap: [String : String],
                         completionHandler: @escaping (GraphQLResponse<Operation>?, Error?) -> Void) -> Cancellable where Operation : GraphQLOperation {
        operations.append(operation as! T)
        sendOperationCompletion = completionHandler as! ((GraphQLResponse<T>?, Error?) -> Void)
        return FakeCancellable()
    }
    
    func sendSubscriptionRequest<Operation>(operation: Operation,
                                            completionHandler: @escaping (JSONObject?, Error?) -> Void) throws -> Cancellable where Operation : GraphQLOperation {
        subscriptionOperations.append(operation as! T)
        jsonCompletionHandler = completionHandler
        return FakeCancellable()
    }
    
    func clear() {
        operations = []
        datas = []
    }
    
    func hasChanged(to: Reachability.Connection) {
        
    }
    
}
