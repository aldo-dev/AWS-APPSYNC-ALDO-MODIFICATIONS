//
//  ALDOGraphQLOperationSenderDecorator.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-14.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation



/// Class-decorator on GraphQLOperationSender
/// the main purpose of the class is to update lastsync time
/// Requests last sync time and then provides as a parram in overrideMap
/// Uppon receiving success result will update lastSyncTime
final class  ALDOGraphQLOperationSenderDecorator: GraphQLOperationSender {
    
    private let decorated: GraphQLOperationSender
    private let timestampCRUD: TimestampSaver & TimestampReader
    
    
    /// Init
    ///
    /// - Parameters:
    ///   - decorated: GraphQLOperationSender
    ///   - timestampCRUD: TimestampSaver & TimestampReader
    init(decorated: GraphQLOperationSender,
         timestampCRUD: TimestampSaver & TimestampReader) {
        self.decorated = decorated
        self.timestampCRUD = timestampCRUD
    }
    
    
    
    /// Sends request for GraphQLOperation
    ///
    /// - Parameters:
    ///   - operation: GraphQLOperation
    ///   - overrideMap: additional params map that will be added in the request
    ///
    ///  - Note: Will request lastsync timestamp and add it into the request
    ///           Upon success will save the current timestamp
    ///
    /// - Returns: Promise<Set?>
    func send<Operation, Set>(operation: Operation,
                              overrideMap: [String : String]) -> Promise<Set?> where Operation : GraphQLOperation, Set == Operation.Data {
        let operationName = "\(Operation.operationString)__\(operation.variables?.jsonObject ?? [:])"
        return timestampCRUD.getLastSyncTime(operationName: operationName, operationString: operationName)
                            .flatMap({ self.sendOperation(operation: operation, timeStamp: $0) })
                            .andThen({ [weak self] _ in  self?.saveCurrentTimeStamp(for: operationName)})
    }
    
    private func sendOperation<Operation, Set>(operation: Operation,
                                               timeStamp: Date) -> Promise<Set?> where Operation : GraphQLOperation, Set == Operation.Data {
        let dictionary = ["SDK_OVERRIDE" :  timeStamp.timeIntervalSince1970.description]
        return self.decorated.send(operation: operation, overrideMap: dictionary)
        
    }
    
    private func saveCurrentTimeStamp(for operationName: String) {
        let currentTimestamp = Date().timeIntervalSince1970.description
        let _ = timestampCRUD.saveCurrentTimestamp(for: currentTimestamp, operationName: operationName)
    }
}
