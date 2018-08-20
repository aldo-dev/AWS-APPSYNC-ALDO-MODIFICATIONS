//
//  ALDOAppSyncSubscriptionCentreReconnectorTestCase.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import XCTest
@testable import AWSAppSync
class ALDOAppSyncSubscriptionCentreReconnectorTestCase: XCTestCase {
    
    var tester: ALDOAppSyncSubscriptionCentreReconnectorTester!
    var defaultWaitInterval: DispatchTimeInterval = .milliseconds(30)
    override func setUp() {
        super.setUp()
        tester = ALDOAppSyncSubscriptionCentreReconnectorTester()
    }
    
    func test_subscribe_passed_to_derocated_object() {
        tester.subscribeWatcher()
        tester.checkSubscribeWatcherHasBeenCalled(numberOfTimes: 1)
        tester.checkUnsubscribeWatcherHasBeenCalled(numberOfTimes: 0)
    }

    func test_unsubscribe_passed_to_decorated_object() {
        tester.unsubscribeWatcher()
        tester.checkSubscribeWatcherHasBeenCalled(numberOfTimes: 0)
        tester.checkUnsubscribeWatcherHasBeenCalled(numberOfTimes: 1)
    }
    
    func test_initial_state_is_locked_error_shouldnt_be_proccessed() {
        tester.emulateNetworkError(MQTTStatusError())
        wait(timeInterval: defaultWaitInterval)
        tester.checkSubscribeWatcherHasBeenCalled(numberOfTimes: 0)
        tester.checkUnsubscribeWatcherHasBeenCalled(numberOfTimes: 0)
    }
    
    func test_shouldn_call_reconnect_for_the_next_errors_if_connection_wasnt_established() {
        tester.subscribeWatcher()
        tester.emulateNetworkStatusChange(.none)
        wait(timeInterval: defaultWaitInterval)
        tester.emulateNetworkError(MQTTStatusError())
        wait(timeInterval: defaultWaitInterval)
        tester.emulateEstablishConnect()
        wait(timeInterval: defaultWaitInterval)
        tester.checkSubscribeWatcherHasBeenCalled(numberOfTimes: 2)
        tester.checkUnsubscribeWatcherHasBeenCalled(numberOfTimes: 1)
    }
    
    func test_getting_errors_during_reconnection_should_bypass_the_logic() {
        tester.subscribeWatcher()
        tester.emulateNetworkError(MQTTStatusError())
        wait(timeInterval: defaultWaitInterval)
        tester.emulateNetworkError(MQTTStatusError())
        wait(timeInterval: defaultWaitInterval)
        tester.emulateNetworkError(MQTTStatusError())
        wait(timeInterval: defaultWaitInterval)
        tester.checkSubscribeWatcherHasBeenCalled(numberOfTimes: 4)
        tester.checkUnsubscribeWatcherHasBeenCalled(numberOfTimes: 3)
    }
    
    
    func test_network_status_change_should_not_call_unsusbscribe_when_reconnect_item_exists() {
        tester.subscribeWatcher()
        tester.emulateNetworkError(MQTTStatusError())
        tester.emulateNetworkStatusChange(.none)
        wait(timeInterval: defaultWaitInterval)
        tester.checkSubscribeWatcherHasBeenCalled(numberOfTimes: 2)
        tester.checkUnsubscribeWatcherHasBeenCalled(numberOfTimes: 2)
    }
    
    
    func test_network_status_change_to_none_disconnects_watchers() {
        tester.subscribeWatcher()
        tester.emulateEstablishConnect()
        tester.emulateNetworkStatusChange(.none)
        wait(timeInterval: defaultWaitInterval)
        tester.checkSubscribeWatcherHasBeenCalled(numberOfTimes: 1)
        tester.checkUnsubscribeWatcherHasBeenCalled(numberOfTimes: 1)
    }
    
    func test_status_change_to_wifi_should_continue_the_item() {
        tester.subscribeWatcher()
        tester.emulateEstablishConnect()
        tester.emulateNetworkStatusChange(.none)
        tester.emulateNetworkStatusChange(.wifi)
        wait(timeInterval: defaultWaitInterval)
        tester.checkSubscribeWatcherHasBeenCalled(numberOfTimes: 2)
        tester.checkUnsubscribeWatcherHasBeenCalled(numberOfTimes: 1)
    }
    
}
