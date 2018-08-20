//
//  ALDOMQTTClientTestCases.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-09.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import XCTest
@testable import AWSAppSync

class ALDOMQTTClientTestCases: XCTestCase {
    
    private var tester: ALDOMQTTClientTester!
    
    override func setUp() {
        super.setUp()
        tester = ALDOMQTTClientTester()
    }
    
    func test_connects_with_proper_data() {
        let host = "HOST"
        let id = "ID"
        tester.connect(to: host, with: id)
        tester.testConnectsToExpectedHosts([host])
        tester.testConnectsWithExpectedClients(ids: [id])
    }
    
    func test_pauses_queue_for_connection() {
        tester.connect(to: "host", with: "id")
        tester.testSuspendQueueCalled(numberOfTimes: 1)
        tester.testResumseQueueCalled(numberOfTimes: 0)
    }
    
    
    func test_pauses_queue_once_if_tries_to_connect_several_times_in_a_row() {
        tester.connect(to: "host", with: "id")
        tester.connect(to: "host", with: "id")
        tester.testSuspendQueueCalled(numberOfTimes: 1)
        tester.testResumseQueueCalled(numberOfTimes: 0)
    }
    
    func test_propogates_status() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connected)
        tester.testExpectedStatus(.connected)
        tester.testResumseQueueCalled(numberOfTimes: 1)
    }
    
    func test_unpauses_queue_for_connected_status() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connected)
        tester.testSuspendQueueCalled(numberOfTimes: 1)
        tester.testResumseQueueCalled(numberOfTimes: 1)
    }
    
    func test_unpauses_queu_for_disconneted_status() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.disconnected)
        tester.testSuspendQueueCalled(numberOfTimes: 1)
        tester.testResumseQueueCalled(numberOfTimes: 1)
    }
    
    func test_doesnt_call_connect_for_connecting_state() {
        let host = "HOST"
        let id = "ID"
        tester.connect(to: host, with: id)
        tester.connect(to: host, with: id)
        tester.testConnectsToExpectedHosts([host])
        tester.testConnectsWithExpectedClients(ids: [id])
    }
    
    func test_doesnt_call_connect_for_connected_state() {
        let host = "HOST"
        let id = "ID"
        tester.connect(to: host, with: id)
        tester.emulateStatus(.connected)
        tester.connect(to: host, with: id)
        tester.testConnectsToExpectedHosts([host])
        tester.testConnectsWithExpectedClients(ids: [id])
    }
    
    func test_allow_connet_if_discconeted_status_has_been_received() {
        let host = "HOST"
        let id = "ID"
        tester.connect(to: host, with: id)
        tester.emulateStatus(.disconnected)
        tester.connect(to: host, with: id)
        tester.testConnectsToExpectedHosts([host,host])
        tester.testConnectsWithExpectedClients(ids: [id,id])
    }
    
    func test_subscribe_returns_error_if_state_is_with_error() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connectionError)
        tester.subscribe(to: "topic")
        tester.testSubscribeResult(.failure(ALDOMQTTClientError.subscribingIsNotAllowed))
        tester.testExecuteQueueCalled(numberOfTimes: 0)
    }
    
    
    func test_subscribe_called_for_waiting_state() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connected)
        tester.subscribe(to: "topic")
        tester.testSubscribedTo(topics: ["topic"])
    }
    
    func test_changing_statuses_make_pause_susped_on_queue_balanced() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connecting)
        tester.emulateStatus(.connected)
        tester.emulateStatus(.disconnected)
        tester.emulateStatus(.connecting)
        tester.emulateStatus(.protocolError)
        tester.emulateStatus(.connecting)
        tester.emulateStatus(.connected)
        tester.testResumseQueueCalled(numberOfTimes: 3)
        tester.testSuspendQueueCalled(numberOfTimes: 3)
    }
    
    func test_changing_to_disconnection_should_balance_pause_resume() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connecting)
        tester.emulateStatus(.connected)
        tester.emulateStatus(.connectionRefused)
        tester.emulateStatus(.disconnected)
        tester.testResumseQueueCalled(numberOfTimes: 1)
        tester.testSuspendQueueCalled(numberOfTimes: 1)
    }

    
    func test_should_notify_from_connecting_to_disconnected() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connecting)
        tester.emulateStatus(.disconnected)
        tester.testExpectedStatus(.disconnected)
    }
    
    func test_should_notify_from_connecting_to_errorProtocol() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connecting)
        tester.emulateStatus(.protocolError)
        tester.testExpectedStatus(.protocolError)
    }
    
    func test_should_notify_from_connecting_to_connectionRefused() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connecting)
        tester.emulateStatus(.connectionRefused)
        tester.testExpectedStatus(.connectionRefused)
    }
    
    func test_should_notify_from_connecting_to_connected() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connecting)
        tester.emulateStatus(.connected)
        tester.testExpectedStatus(.connected)
    }
    
    func test_should_notify_from_connected_to_disconnected() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connected)
        tester.emulateStatus(.disconnected)
        tester.testExpectedStatus(.disconnected)
    }
    
    func test_should_notify_from_connected_to_connectionRefused() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connected)
        tester.emulateStatus(.connectionRefused)
        tester.testExpectedStatus(.connectionRefused)
    }
    
    
    func test_should_notify_from_connected_to_errorProtocol() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connected)
        tester.emulateStatus(.protocolError)
        tester.testExpectedStatus(.protocolError)
    }
    
    func test_shouldnot_notify_from_connected_to_connecting() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connected)
        tester.emulateStatus(.connecting)
        tester.testExpectedStatus(nil)
    }
    
    
    func test_shouldnot_notify_from_unknown_to_connecting() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.unknown)
        tester.emulateStatus(.connecting)
        tester.testExpectedStatus(nil)
    }
    func test_changing_to_connectionRefused_should_balance_pause_resume() {
        tester.connect(to: "host", with: "id")
        tester.emulateStatus(.connecting)
        tester.emulateStatus(.connected)
        tester.emulateStatus(.connectionRefused)
        tester.emulateStatus(.disconnected)
        tester.testExpectedStatus(nil)
    }
    
}
