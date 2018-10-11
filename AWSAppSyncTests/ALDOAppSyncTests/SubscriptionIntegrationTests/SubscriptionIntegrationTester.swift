//
//  SubscriptionIntegrationTester.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-16.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import Reachability
@testable import AWSAppSync
import XCTest

final class ALDOMQTTClientFactoryMock: ALDOClientFactory {
    

    let connectorMock = MQTTClientConnectorMock()
    let clientMock: ALDOMQTTClient
    var connectorMocks: [MQTTClientConnectorMock] = []
    var newConnectorCalledCount: Int {
        return connectorMocks.count
    }
    init() {
        clientMock = ALDOMQTTClient(client: connectorMock)
    }
    
    
    func newConnector(for clientID: String) -> ALDOMQTTClientConnector {
        let connector = MQTTClientConnectorMock()
        connector.clientID = clientID
        connectorMocks.append(connector)
        
        return ALDOMQTTClient(client: connector)
    }

    func connectorMock(for id: String) -> [MQTTClientConnectorMock] {
        return connectorMocks.filter({ $0.clientID == id})
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


final class LoggerMock: AWSLogger {
    func log(message: String, filename: StaticString, line: Int, funcname: StaticString) {
       
        debugPrint("[AWS: \( filename.description.components(separatedBy: "/").last!) \(funcname) line: \(line)]: \(message) ")
    }
    
    func log(error: Error, filename: StaticString, line: Int, funcname: StaticString) {
        debugPrint("[AWS: \(filename) \(funcname) line: \(line)]: \(error.localizedDescription) ")
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
    let infoFactory = SubscriptionWatcherInfoBuilder()
    let logger: LoggerMock
    let networkMonitor = NetworkMonitorSystem()
    let connectionStatusProvider = ConnectionStatusMockProvider()
 
    init() {
        
        let logger = LoggerMock()
        self.logger = logger
        let centre  = ALDOAppSyncSubscriptionCentre(client: ALDOConnector(factory: clientFactoryMock),logger: logger)
        let provider = connectionStatusProvider
        decoratedCentre = ALDOAppSyncSubscriptionCentreReconnector(decorated: centre,
                                                                   logger: logger,
                                                                   connectionStateRequest: { provider.connection })
        
        subcriptiontransportReachabilityObserver = AWSNetworkTransportDecorator(decorated: subscriptionTransportMock,
                                                                                logger: logger,
                                                                                connectionStateRequest: { return .wifi })
        
        subscriptionTransport = AWSNetworkTransportCredentialsUpdateDecorator(decorated: subcriptiontransportReachabilityObserver,
                                                                              credentialsUpdater: credentialsUpdater, logger: logger)
        
        queryReachabilityObserver = AWSNetworkTransportDecorator(decorated: networkTransportMock,
                                                                 logger: logger,
                                                                 connectionStateRequest: { return .wifi })
        
        queryTransport = AWSNetworkTransportCredentialsUpdateDecorator(decorated: queryReachabilityObserver,
                                                                       credentialsUpdater: credentialsUpdater,
                                                                       logger: logger)
        

        
      
        networkMonitor.addObserver(decoratedCentre)
        networkMonitor.addObserver(subscriptionTransport)
        networkMonitor.addObserver(queryTransport)

    }
    
    
    
    func subscribeWatcher(forClientID id: String,
                          allowedTopics: [String],
                          connectionTopics: [String],
                          url: String = "url") {
        
       
        
        infoFactory.clean()
        infoFactory.setURL(url)
        infoFactory.setTopics(connectionTopics, clientID: id)
        infoFactory.setCurrentSubscriptionTopics(allowedTopics)

        SubscriptionResponseParserMock.result = Result.success(infoFactory.info)
        let parser = GraphQLDataBasicTransformer(parser: GraphQLBasicParser(cacheKeyForObject: storeMock.cacheKeyForObject))
        let requester = ALDOSubscriptionRequester(httpLevelRequesting: subscriptionTransport,
                                                  parserType: SubscriptionResponseParserMock.self)
        let watcher = ALDOMQTTSubscritionWatcher(subscription: MockSubscriptionRequest(),
                                                 requester: requester,
                                                 parser: parser,
                                                 logger: logger)
        
    
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
                                                         query: MockGraphQLQuery(),
                                                         logger: logger)
        
        syncWatcher.subscribe { (result) in
            self.syncWatcherResult = result.result
        }

        decoratedCentre.addObserver(syncWatcher)
        
        decoratedCentre.subscribe(watcher: syncWatcher)
    }
    
    
    func emulateConnectionOn() {
        networkMonitor.hasChanged(to: .wifi)

    }
    
    func setCurrentConnectionStatus(_ status: Reachability.Connection) {
        connectionStatusProvider.connection = status
    }
    
    func emulateConnectionOff() {
        networkMonitor.hasChanged(to: .none)
    }
    
    func emulateConnectionStatus(_ status: AWSIoTMQTTStatus, for clientID: String) {
        clientFactoryMock.connectorMock(for: clientID).forEach({ $0.send(status: status) })

    }
    
    func emulateSubscriptionRequestSuccess() {
        subscriptionTransportMock.jsonCompletionHandler.forEach({ $0([:], nil)})
    }
    
    func cleanRequestCallbacks() {
        subscriptionTransportMock.jsonCompletionHandler = []
    }
    
    func emulateSubscriptionRequestError() {
        let error = NSError(domain: "TEST", code: NSURLErrorNetworkConnectionLost, userInfo: nil)
        subscriptionTransportMock.jsonCompletionHandler.forEach({$0(nil, error) })
    }
    
    
    func emulateSyncQuerySuccess() {
        networkTransportMock.sendOperationCompletion.forEach({ $0(GraphQLResponse(operation: MockGraphQLQuery(), body: [:]), nil) })
    }
    
    func checkSendSubscriptionRequestSent(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(subscriptionTransportMock.subscriptionOperations.count, numberOfTimes, file: file, line: line)
    }
    
    
    func checkSyncQuerySent(numberOfTimes: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(networkTransportMock.operations.count, numberOfTimes, file: file, line: line)
    }
    
    func checkSuscribeTo(topic: String, calledNumberOfTimes times: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(clientFactoryMock.connectorMocks.flatMap( { $0.subscribedTopics }).filter({$0 == topic}).count,
                       times,
                       file: file,
                       line: line)
        
    }
    
    func checkConnectTo(client: String, calledNumberOfTimes times: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(clientFactoryMock.connectorMocks.flatMap( {$0.connectedClients }).filter({$0 == client}).count,
                       times,
                       file: file,
                       line: line)
    }
    
    func checkConnectTo(host: String, calledNumberOfTimes times: Int,file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(clientFactoryMock.connectorMocks.flatMap( {$0.connectedHosts }).filter({$0 == host}).count,
                       times,
                       file: file,
                       line: line)
    }
}
