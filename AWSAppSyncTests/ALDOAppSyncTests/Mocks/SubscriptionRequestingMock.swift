//
//  SubscriptionRequestingMock.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync

final class FakeCancellable: Cancellable {
    func cancel() {
        //Mock
    }
}

final class SubscriptionRequestingMock<T>: AWSNetworkTransport where T : GraphQLOperation {
 
    private(set) var operations: [T] = []
    private(set) var datas: [Data] = []
    
    var response: JSONObject? = nil
    var error: Error? = nil
    
    var retryCount: Int = -1
    
    func sendSubscriptionRequest<Operation>(operation: Operation,
                                            completionHandler: @escaping (JSONObject?, Error?) -> Void) throws -> Cancellable where Operation : GraphQLOperation {
        operations.append(operation as! T)
        if let error = self.error, retryCount < 0 || operations.count < retryCount {
            completionHandler(nil,error)
        } else {
            completionHandler(response,nil)
        }
        
        return FakeCancellable()
    }
    
    func send(data: Data, completionHandler: ((JSONObject?, Error?) -> Void)?) {
        datas.append(data)
        if let error = self.error, retryCount < 0 || datas.count < retryCount {
            completionHandler?(nil,error)
        } else {
            completionHandler?(response,nil)
        }
    }
    
    func send<Operation>(operation: Operation, overrideMap: [String : String], completionHandler: @escaping (GraphQLResponse<Operation>?, Error?) -> Void) -> Cancellable where Operation : GraphQLOperation {
        operations.append(operation as! T)
        if let error = self.error,  retryCount < 0 || operations.count < retryCount {
            completionHandler(nil,error)
        } else {
            completionHandler(GraphQLResponse(operation: operation, body: response!),nil)
        }
        return FakeCancellable()
        
    }
}
