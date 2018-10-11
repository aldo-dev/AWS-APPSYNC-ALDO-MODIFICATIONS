//
//  SubscriptionIntegrationTests.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-16.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import XCTest
@testable import AWSAppSync

class SubscriptionIntegrationTests: XCTestCase {
    
    
    var tester: SubscriptionIntegrationTester!
    let infoFactory = SubscriptionWatcherInfoBuilder()
    override func setUp() {
        super.setUp()
        tester = SubscriptionIntegrationTester()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
  
    func test_initial_no_wifi_doesnt_trigger_subscription_request_send() {
        tester.subscribeWatcher(forClientID: "1", allowedTopics: ["1"], connectionTopics: ["1"])
        tester.checkSendSubscriptionRequestSent(numberOfTimes: 0)
    }
    
    func test_switch_from_none_to_wifi_continues_subscription_request() {
        tester.subscribeWatcher(forClientID: "1", allowedTopics: ["1"], connectionTopics: ["1"])
        tester.emulateConnectionOn()
        tester.checkSendSubscriptionRequestSent(numberOfTimes: 1)
    }
    
    func test_successeful_subscription_request_triggers_connect_to_client() {
        tester.emulateConnectionOn()
        tester.subscribeWatcher(forClientID: "1", allowedTopics: ["1"], connectionTopics: ["1"])
        tester.emulateSubscriptionRequestSuccess()
        tester.checkConnectTo(client: "1", calledNumberOfTimes: 1)
        tester.checkConnectTo(host: "url", calledNumberOfTimes: 1)
    }
    
    func test_successeful_subscription_and_connection_triggers_subscribe_to_topic() {
        tester.emulateConnectionOn()
        
        tester.subscribeWatcher(forClientID: "1", allowedTopics: ["1"], connectionTopics: ["1"])
        tester.emulateSubscriptionRequestSuccess()
        tester.emulateConnectionStatus(.connecting, for: "1")
        tester.emulateConnectionStatus(.connected, for: "1")
        tester.checkSuscribeTo(topic: "1", calledNumberOfTimes: 1)
    }
  
}
