//
//  ALDOConnectorTestCase.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-09-10.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import XCTest
@testable import AWSAppSync

class ALDOConnectorTestCase: XCTestCase {
    
    var tester: ALDOConnectorTester!
    
    override func setUp() {
        super.setUp()
        tester = ALDOConnectorTester()
    }
    
    func test_connect_calls_factory_for_the_first_connection() {
        let defaultInfo = defatulWatcherInfo(with: [topicName(forClientID: "0", andTopicID: "0")], numberOfInfoItems: 2)
        tester.connect(using: defaultInfo)
        tester.checkFactoryHasBeenCalled(numberOfTimes: 1)
    }

    func test_connect_doesnt_call_factory_for_the_same_connection() {
        let defaultInfo = defatulWatcherInfo(with: [topicName(forClientID: "0", andTopicID: "0")], numberOfInfoItems: 2)
        tester.connect(using: defaultInfo)
        let secondInfo  = defatulWatcherInfo(with: [topicName(forClientID: "0", andTopicID: "1")], numberOfInfoItems: 2)
        tester.connect(using: secondInfo)
        tester.checkFactoryHasBeenCalled(numberOfTimes: 1)
    }
    
    func test_creates_a_new_connection_if_the_topic_is_not_in_the_first() {
        let defaultInfo = defatulWatcherInfo(with: [topicName(forClientID: "0", andTopicID: "0")], numberOfInfoItems: 2)
        tester.connect(using: defaultInfo)
        let secondInfo  = defatulWatcherInfo(with: [topicName(forClientID: "1", andTopicID: "")], numberOfInfoItems: 3)
        tester.connect(using: secondInfo)
        tester.checkFactoryHasBeenCalled(numberOfTimes: 1)
    }
    
    func test_subscribes_to_allowed_topic() {
        let allowedTopic = topicName(forClientID: "0", andTopicID: "0")
        let defaultInfo = defatulWatcherInfo(with: [allowedTopic], numberOfInfoItems: 2)
        tester.connect(using: defaultInfo)
        tester.subscribeToTopic(topic: allowedTopic)
        tester.checkSubscribedTopics(expected: [allowedTopic])
    }
    
    func test_doesnt_subscribes_to_unallowed_topic() {
        let allowedTopic = topicName(forClientID: "0", andTopicID: "0")
        let forbidenTopic = topicName(forClientID: "0", andTopicID: "5")
        let defaultInfo = defatulWatcherInfo(with: [allowedTopic], numberOfInfoItems: 2)
        tester.connect(using: defaultInfo)
        tester.subscribeToTopic(topic: forbidenTopic)
        tester.checkSubscribedTopics(expected: [])
        tester.testSubscribeResult(.failure(ALDOMQTTClientError.subscribingIsNotAllowed))
    }
    
    func defatulWatcherInfo(with currentTopics: [String], numberOfInfoItems number: Int) -> SubscriptionWatcherInfo {
        return SubscriptionWatcherInfo(topics: currentTopics,
                                       info: createInfo(numberOfTimes: number, withNumberOfTopics: 2))
    }
    
    func createInfo(numberOfTimes: Int, withNumberOfTopics number: Int) -> [AWSSubscriptionInfo] {
        return stride(from: 0, to: numberOfTimes, by: 1).map({defaultSubscriptionInfo(id: "\($0)", withNTopics: number)})
    }
    
    
    
    func defaultSubscriptionInfo(id: String, withNTopics number: Int) -> AWSSubscriptionInfo {
        return AWSSubscriptionInfo(clientId: "Defatul_\(id)",
                                   url: "Default_URL_\(id)",
            topics: stride(from: 0, to: number, by: 1).map({topicName(forClientID: id, andTopicID: "\($0)")}))
    }
    
    func topicName(forClientID clientID: String, andTopicID topicID: String) -> String {
        return "TOPIC_\(topicID)_for_\(clientID)"
    }
}
