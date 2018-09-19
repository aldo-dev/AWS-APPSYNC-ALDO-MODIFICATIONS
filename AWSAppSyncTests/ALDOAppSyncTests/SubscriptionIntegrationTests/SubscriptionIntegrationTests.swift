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
    let infoFactory = SubscriptionWatcherInfoFactory()
    override func setUp() {
        super.setUp()
        tester = SubscriptionIntegrationTester()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
  
    func test_initial_no_wifi_doesnt_trigger_subscription_request_send() {
        let info = infoFactory.getInfo(withTopics: ["1"], client: "1", url: "url")
        tester.subscribeWatcher(withExpectedResponse: Promise(fulfilled: info))
        tester.checkSendSubscriptionRequestSent(numberOfTimes: 0)
    }
    
    func test_switch_from_none_to_wifi_continues_subscription_request() {
        let info = infoFactory.getInfo(withTopics: ["1"], client: "1", url: "url")
        tester.subscribeWatcher(withExpectedResponse: Promise(fulfilled: info))
        tester.emulateConnectionOn()
        tester.checkSendSubscriptionRequestSent(numberOfTimes: 1)
    }
    
    func test_successeful_subscription_request_triggers_connect_to_client() {
        let info = infoFactory.getInfo(withTopics: ["1"], client: "1", url: "url")
        tester.emulateConnectionOn()
        tester.subscribeWatcher(withExpectedResponse: Promise(fulfilled: info))
        tester.emulateSubscriptionRequestSuccess()
        tester.checkConnectTo(client: "1", calledNumberOfTimes: 1)
        tester.checkConnectTo(host: "url", calledNumberOfTimes: 1)
    }
    
    func test_successeful_subscription_and_connection_triggers_subscribe_to_topic() {
        let info = infoFactory.getInfo(withTopics: ["1"], client: "1", url: "url")
        tester.emulateConnectionOn()
        tester.subscribeWatcher(withExpectedResponse: Promise(fulfilled: info))
        tester.emulateSubscriptionRequestSuccess()
        tester.emulateConnectionStatus(.connecting)
        tester.emulateConnectionStatus(.connected)
        tester.checkSuscribeTo(topic: "1", calledNumberOfTimes: 1)
    }
    
    
    func test_status_change_to_disconnect_triggers_resubscribe() {
        tester.emulateConnectionOn()
        let info = infoFactory.getInfo(withTopics: ["1"], client: "1", url: "url")

        tester.subscribeWatcher(withExpectedResponse: Promise(fulfilled: info))
        tester.emulateConnectionOff()
        tester.emulateConnectionOn()

    
        wait(timeInterval: .milliseconds(60))
        tester.emulateSubscriptionRequestSuccess()

        tester.emulateConnectionStatus(.connecting)
        tester.emulateConnectionStatus(.connected)

        tester.checkSendSubscriptionRequestSent(numberOfTimes: 2)
        tester.checkConnectTo(host: "url", calledNumberOfTimes: 1)
        tester.checkConnectTo(client: "1", calledNumberOfTimes: 1)
        tester.checkSuscribeTo(topic: "1", calledNumberOfTimes: 1)
    }
    
}
