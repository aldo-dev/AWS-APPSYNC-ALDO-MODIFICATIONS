//
//  SubscriptionIntegrationTester.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-16.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
@testable import AWSAppSync
import XCTest

final class ALDOMQTTClientFactoryMock: ALDOClientFactory {
    

    let connectorMock = MQTTClientConnectorMock()
    let clientMock: ALDOMQTTClient
    private(set) var newConnectorCalledCount = 0
    init() {
        clientMock = ALDOMQTTClient(client: connectorMock)
    }
    
    var newConnetor: ALDOMQTTClientConnector {
        newConnectorCalledCount += 1
        return clientMock
    }
    
    
}


final class StoreMock: StorePublisher {
    var publishedCalledCount = 0
    
    var cacheKeyForObject: CacheKeyForObject? = nil
    
    func publish(records: RecordSet, context: UnsafeMutableRawPointer?) -> Promise<Void> {
        publishedCalledCount += 1
        return Promise.init(fulfilled: ())
    }
}


final class TimeCRUDMock: TimestampSaver, TimestampReader {
    
    
    var saveCurrentTimestampCount = 0
    var getLastSyncTimeCount = 0
    
    func saveCurrentTimestamp(for operationString: String, operationName: String) -> Promise<Date> {
        saveCurrentTimestampCount += 1
        return Promise.init(fulfilled: Date())
    }
    
    func getLastSyncTime(operationName: String, operationString: String) -> Promise<Date> {
        getLastSyncTimeCount += 1
        return Promise.init(fulfilled: Date())
    }
    
}

final class SubscriptionResponseParserMock: SubscriptionResponseParser {
    
    
    static var result: Result<SubscriptionWatcherInfo>!
    init(body: JSONObject) {
        
    }
    
    func parseResult() throws -> AWSGraphQLSubscriptionResponse {
        if let info = SubscriptionResponseParserMock.result.value {
            return AWSGraphQLSubscriptionResponse(errors: nil, newTopics: info.topics, subscrptionInfo: info.info)
        } else {
           return AWSGraphQLSubscriptionResponse(errors: [GraphQLError("Error")], newTopics: nil, subscrptionInfo: nil)
        }
        
    }
}




final class SubscriptionIntegrationTester {
    
    let credentialsUpdater = CredentialsUpdaterMock()
    let clientFactoryMock = ALDOMQTTClientFactoryMock()
    let networkTransportMock = AWSNetworkTransportMock<MockGraphQLQuery>()
    let subscriptionTransportMock = AWSNetworkTransportMock<MockSubscriptionRequest>()
    let subcriptiontransportReachabilityObserver: AWSNetworkTransportDecorator
    let queryReachabilityObserver: AWSNetworkTransportDecorator
    let subscriptionTransport: AWSNetworkTransportCredentialsUpdateDecorator
    let queryTransport: AWSNetworkTransportCredentialsUpdateDecorator
    let decoratedCentre: ALDOAppSyncSubscriptionCentreReconnector
    var parserMock: GraphQLDataTransformer!
    let storeMock = StoreMock()
    let timeStampCRUDMock = TimeCRUDMock()
    var watcherResult: Result<MockSubscriptionRequest.Data?>?
    var syncWatcherResult: Result<MockGraphQLQuery.Data?>?
 
    init() {
        let centre  = ALDOAppSyncSubscriptionCentre(client: ALDOConnector(factory: clientFactoryMock))
        decoratedCentre = ALDOAppSyncSubscriptionCentreReconnector(decorated: centre)
        subcriptiontransportReachabilityObserver = AWSNetworkTransportDecorator(decorated: subscriptionTransportMock)
        queryReachabilityObserver = AWSNetworkTransportDecorator(decorated: networkTransportMock)
        subscriptionTransport = AWSNetworkTransportCredentialsUpdateDecorator(decorated: subcriptiontransportReachabilityObserver,
                                                                              credentialsUpdater: credentialsUpdater)
        
        queryTransport = AWSNetworkTransportCredentialsUpdateDecorator(decorated: queryReachabilityObserver,
                                                                       credentialsUpdater: credentialsUpdater)
        
    }
    
    
    
    func subscribeWatcher(withExpectedResponse response: Promise<SubscriptionWatcherInfo>) {
        SubscriptionResponseParserMock.result = response.result!
        let parser = GraphQLDataBasicTransformer(parser: GraphQLBasicParser(cacheKeyForObject: storeMock.cacheKeyForObject))
        let requester = ALDOSubscriptionRequester(httpLevelRequesting: subscriptionTransport,
                                                  parserType: SubscriptionResponseParserMock.self)
        let watcher = ALDOMQTTSubscritionWatcher(subscription: MockSubscriptionRequest(),
                                                 requester: requester,
                                                 parser: parser)
        
    
        let operationSender = ALDOGraphQLOperationSender(operationSending: queryTransport,
                                                         cacheKeyForObject: storeMock.cacheKeyForObject,
                                                         storePublisher: storeMock)
        

        let operationSenderWithSaving = ALDOGraphQLOperationSenderDecorator(decorated: operationSender,
                                                                            timestampCRUD: timeStampCRUDMock)

        watcher.subscribe { (result) in
            
            self.watcherResult = result.result
        }
        
        let syncWatcher = ALDOSubscritionWatcherWithSync(decorated: watcher,
                                                         querySender: operationSenderWithSaving,
                                                         query: MockGraphQLQuery())
        
        syncWatcher.subscribe { (result) in
            self.syncWatcherResult = result.result
        }

        decoratedCentre.addObserver(syncWatcher)
        
        decoratedCentre.subscribe(watcher: syncWatcher)
    }
    
    
    func emulateConnectionOn() {
        decoratedCentre.hasChanged(to: .wifi)
        subcriptiontransportReachabilityObserver.hasChanged(to: .wifi)
        queryReachabilityObserver.hasChanged(to: .wifi)
    }
    
    func emulateConnectionOff() {
        decoratedCentre.hasChanged(to: .none)
        subcriptiontransportReachabilityObserver.hasChanged(to: .none)
        queryReachabilityObserver.hasChanged(to: .none)
    }
    
    func emulateConnectionStatus(_ status: AWSIoTMQTTStatus) {
        clientFactoryMock.connectorMock.send(status: status)
    }
    
    func emulateSubscriptionRequestSuccess() {
        subscriptionTransportMock.jsonCompletionHandler.forEach({ $0([:], nil)})
    }
    
    func emulateSubscriptionRequestError() {
        let error = NSError(domain: "TEST", code: NSURLErrorNetworkConnectionLost, userInfo: nil)
        subscriptionTransportMock.jsonCompletionHandler.forEach({$0(nil, error) })
    }
    
    
    func checkSendSubscriptionRequestSent(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(subscriptionTransportMock.subscriptionOperations.count, numberOfTimes, file: file, line: line)
    }
    
    func checkSuscribeTo(topic: String, calledNumberOfTimes times: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(clientFactoryMock.connectorMock.subscribedTopics.filter({$0 == topic}).count,
                       times,
                       file: file,
                       line: line)
        
    }
    
    func checkConnectTo(client: String, calledNumberOfTimes times: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(clientFactoryMock.connectorMock.connectedClients.filter({$0 == client}).count,
                       times,
                       file: file,
                       line: line)
    }
    
    func checkConnectTo(host: String, calledNumberOfTimes times: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(clientFactoryMock.connectorMock.connectedHosts.filter({$0 == host}).count,
                       times,
                       file: file,
                       line: line)
    }
}
