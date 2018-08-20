//
//  GraphQLOperationSenderMock.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-16.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync

final class GraphQLOperationSenderMock<O, S>: GraphQLOperationSender where O : GraphQLOperation, S == O.Data {
    
    private(set) var operations: [O] = []
    
    var returnedSet: S?
    var error: Error?
    var paused = false {
        didSet {
            if paused {
                dispachQueue.suspend()
            } else {
                dispachQueue.resume()
            }
        }
    }
    
    var dispachQueue = DispatchQueue(label: "GraphQLOperationSenderMock")
    
    func send<Operation, Set>(operation: Operation, overrideMap: [String : String]) -> Promise<Set?> where Operation : GraphQLOperation, Set == Operation.Data {
        operations.append(operation as! O)
        return Promise<Set?>.init({ (fulfilled, rejected) in
            if let error = self.error {
                rejected(error)
            } else {
                fulfilled(self.returnedSet as! Set)
            }
        })
    }
}
