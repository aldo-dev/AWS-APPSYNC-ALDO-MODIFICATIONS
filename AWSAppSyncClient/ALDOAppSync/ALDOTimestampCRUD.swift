//
//  ALDOTimestampCRUD.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-07.
//

import Foundation
import Dispatch

protocol TimestampSaver {
    func saveCurrentTimestamp(for operationString: String, operationName: String) -> Promise<Date>
}

protocol TimestampReader {
    func getLastSyncTime(operationName: String, operationString: String)-> Promise<Date>
}

enum ALDOTimestampCRUDError: Error  {
    case neverSync
}

final class ALDOTimestampCRUD: TimestampSaver, TimestampReader {
    let metadataCache: AWSSubscriptionMetaDataCache
    
    init(metadataCache: AWSSubscriptionMetaDataCache) {
        self.metadataCache = metadataCache
    }
    
    // MARK: - TimestampSaver implementation
    
    func saveCurrentTimestamp(for operationString: String, operationName: String) -> Promise<Date> {
        
        return Promise.init({ () -> Date in
            let date = Date()
            try self.metadataCache.saveRecord(operationString: operationString,
                                              operationName: operationName,
                                              lastSyncDate: date)
            return date
        })
    }
    
    // MARK: - TimestampReader implementation
    
    func getLastSyncTime(operationName: String, operationString: String) -> Promise<Date> {
        return Promise({ () -> Date in
            guard let syncDate = try self.metadataCache.getLastSyncTime(operationName: operationName,
                                                                    operationString: operationString) else {
                                                                       return Date()
            }
            
            return syncDate
        })
    }
}
