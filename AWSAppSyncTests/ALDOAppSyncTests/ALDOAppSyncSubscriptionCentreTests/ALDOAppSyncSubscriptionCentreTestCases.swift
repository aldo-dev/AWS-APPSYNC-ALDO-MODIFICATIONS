//
//  ALDOAppSyncSubscriptionCentreTestCases.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-09.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import XCTest
@testable import AWSAppSync

class ALDOAppSyncSubscriptionCentreTestCases: XCTestCase {
    
    var tester: ALDOAppSyncSubscriptionCentreTester!
    
    override func setUp() {
        super.setUp()
        tester = ALDOAppSyncSubscriptionCentreTester()
    }
    
    func test_subscribing_a_watcher_requests_subscription() {
        tester.connectWatcher(with: 1)
        tester.checkRequestSubscriptionHasBeenCalled(numberOfTimes: 1)
    }
    
    func test_subscribing_a_watcher_establishes_connection() {
        tester.connectWatcher(with: 1)
        tester.checkEstablishConnection()
    }
    
    func test_unsubscribe_a_watcher() {
        tester.setTopics(["topic1","topic2"])
        tester.connectWatcher(with: 1)
        tester.connectWatcher(with: 2)
        tester.unsubscribeWatcher(with: 2)
        let data = "String".data(using: .utf8)!
        tester.postData(data: data, for: "topic1")
        tester.checkWatcherReceivedData([data], watcherID: 1)
        tester.checkWatcherReceivedData([], watcherID: 2)
    }
    
    func test_subscribed_watcher_receive_data_for_topic() {
        let topic = "topic"
        tester.setTopics([topic])
        tester.connectWatcher(with: 1)
        let data = topic.data(using: .utf8)!
        tester.postData(data: data, for: topic)
        tester.checkWatcherReceivedData([data], watcherID: 1)
    }
    
    func test_unsubscribed_watcher_dont_receive_data() {
        let topic = "topic"
        tester.setTopics([topic])
        tester.connectWatcher(with: 1)
        tester.unsubscribeWatcher(with: 1)
        let data = topic.data(using: .utf8)!
        tester.postData(data: data, for: topic)
        tester.checkWatcherReceivedData([], watcherID: 1)
    }
    
    func test_wacher_received_the_data_for_its_own_topic() {
        let topic1 = "topic1"
        let topic2 = "topic2"
        tester.setTopics([topic1])
        tester.connectWatcher(with: 1)
        let data = topic1.data(using: .utf8)!
        tester.postData(data: data, for: topic2)
        tester.checkWatcherReceivedData([], watcherID: 1)
    }
    
    
    func test_subscribing_fails_with_request_should_call_error_callback() {
        let error = NSError(domain: "SubscriptionRequest", code: 1, userInfo: nil)
        tester.connectWatcher(with: 1, requestError: error)
        tester.checkSubscribingFails(withErrors: [error])
    }
    
    func test_status_change_to_disconnected_generates_error() {
        tester.connectWatcher(with: 1)
        tester.emulateStatusChange(newStatus: .disconnected)
        tester.checkSubscribingFails(withErrors: [MQTTStatusError()])
    }
    
    func test_unsubscribe_watcher_all_watcher_for_topic_triggers_topic_disconnect() {
        let topic1 = "topic1"
        let topic2 = "topic2"
        tester.setTopics([topic1])
        tester.connectWatcher(with: 1)
        tester.setTopics([topic2])
        tester.connectWatcher(with: 2)
        tester.unsubscribeWatcher(with: 1)
        tester.checkDisconnectTopicCallend(numberOfTimes: 1, topic: topic1)
        tester.checkDisconnectCalled(numberOfTimes: 0)
    }
    
    func test_unsubscribe_all_watchers_closes_connection() {
        let topic1 = "topic1"
        let topic2 = "topic2"
        tester.setTopics([topic1])
        tester.connectWatcher(with: 1)
        tester.setTopics([topic2])
        tester.connectWatcher(with: 2)
        tester.unsubscribeWatcher(with: 1)
        tester.unsubscribeWatcher(with: 2)
        tester.checkDisconnectCalled(numberOfTimes: 1)
        
    }
    
    func test_unsubscribe_twice() {
        let topic1 = "topic1"
        tester.setTopics([topic1])
        tester.connectWatcher(with: 1)
        tester.unsubscribeWatcher(with: 1)
        tester.unsubscribeWatcher(with: 1)
        tester.checkDisconnectCalled(numberOfTimes: 1)
        tester.checkDisconnectTopicCallend(numberOfTimes: 1, topic: topic1)
    }
    
    func test_notifies_obsver_about_connection_establish() {
        tester.connectWatcher(with: 1)
        tester.connectObserver()
        tester.emulateStatusChange(newStatus: .connected)
        tester.checkObserverReceivesEstablishConnection(numberOfTimes: 1)
        tester.checkObserverReceivesErrorConnection(numberOfTimes: 0)
    }
    
    
    func test_notifies_new_subscribed_observer_after_connection_established() {
        tester.connectWatcher(with: 1)
        tester.emulateStatusChange(newStatus: .connected)
        tester.connectObserver()
        tester.checkObserverReceivesEstablishConnection(numberOfTimes: 1)
        tester.checkObserverReceivesErrorConnection(numberOfTimes: 0)
    }
    func test_notifies_about_status_error() {
        
    }
}
