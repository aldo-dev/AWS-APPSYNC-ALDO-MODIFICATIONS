//
//  ALDOSubscritionWatcherWithSyncTestCase.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-16.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import XCTest

class ALDOSubscritionWatcherWithSyncTestCase: XCTestCase {
    
    var tester: ALDOSubscritionWatcherWithSyncTester!
    private let defaultWaitInterval: DispatchTimeInterval = .milliseconds(100)
    
    override func setUp() {
        super.setUp()
        tester = ALDOSubscritionWatcherWithSyncTester()
    }

    func test_initial_state_of_queue_should_be_paused() {
        tester.checkTheQueuePaused(numberOfTimes: 0)
        tester.checkTheQueueResumed(numberOfTimes: 0)
    }
    
    func test_propogates_send_request_to_decorated_object() {
        tester.emulateSendRequest()
        wait(timeInterval: defaultWaitInterval)
        tester.checkRequestSubscriptionRequestCalled(numberOfTimes: 1)
    }
    
    func test_establish_connection_triggers_sync_call() {
         tester.emulateSendRequest()
         tester.emulateEstablishedConnection()
         wait(timeInterval: defaultWaitInterval)
         tester.checkSynQuerySent(numberOfTimes: 1)
    }
    
    func test_successeful_sync_query_unpauses_queue() {
        tester.emulateSendRequest()
        tester.checkTheQueueResumed(numberOfTimes: 0)
        tester.checkTheQueuePaused(numberOfTimes: 1)
        tester.emulateEstablishedConnection()
        wait(timeInterval: defaultWaitInterval)
        tester.checkTheQueuePaused(numberOfTimes: 1)
        tester.checkTheQueueResumed(numberOfTimes: 1)
       
    }
    
    func test_data_is_blocked_until_sync_is_finished() {
        tester.emulateSendRequest()
        wait(timeInterval: defaultWaitInterval)
        tester.emulateReceiveData()
        tester.checkReceivedDataCalled(numberOfTimes: 0)
    }
    
    func test_continue_sending_data_after_sync_finished() {
        tester.emulateSendRequest()
        tester.emulateReceiveData()
        tester.emulateReceiveData()
        tester.emulateReceiveData()
        tester.emulateEstablishedConnection()
        wait(timeInterval: defaultWaitInterval)
        tester.checkReceivedDataCalled(numberOfTimes: 3)
    }
    
    func test_initiating_start_several_times_should_balance_queue_calls() {
        tester.emulateSendRequest()
        wait(timeInterval: defaultWaitInterval)
        tester.emulateConnectionFailed()
        wait(timeInterval: defaultWaitInterval)
        tester.emulateSendRequest()
        wait(timeInterval: defaultWaitInterval)
        tester.emulateEstablishedConnection()
        wait(timeInterval: defaultWaitInterval)
        tester.checkTheQueuePaused(numberOfTimes: 1)
        tester.checkTheQueueResumed(numberOfTimes: 1)
    }
}
