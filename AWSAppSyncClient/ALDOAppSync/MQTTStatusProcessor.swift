//
//  MQTTStatusProcessor.swift
//  AHFuture
//
//  Created by Alex Hmelevski on 2018-08-08.
//

import Foundation

struct MQTTStatusError: Error {
    var localizedDescription: String = "Could Not establish the connection"
}

final class MQTTStatusProcessor: Loggable {
    
   func proccessStatus(_ status: AWSIoTMQTTStatus) -> Promise<AWSIoTMQTTStatus> {

        switch status {
        case .connecting,
             .connected: return Promise(fulfilled: status)
        case .connectionError,
             .connectionRefused,
             .protocolError,
             .disconnected,
             .unknown:  return Promise(rejected: MQTTStatusError())
        }
        
    }
}
