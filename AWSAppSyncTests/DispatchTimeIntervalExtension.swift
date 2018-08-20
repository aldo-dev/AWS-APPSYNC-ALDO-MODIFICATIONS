//
//  DispatchTimeIntervalExtension.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-13.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

extension DispatchTimeInterval {
    var timeInterval: TimeInterval {
        switch  self {
        case let .seconds(seconds): return TimeInterval(seconds)
        case let .milliseconds(milli): return Double(milli) * 0.001

        case let .microseconds(micro): return Double(micro) * 0.000001
        case let .nanoseconds(nano): return Double(nano) * 0.000000001
        case let .never: return -1
        }
    }
}
