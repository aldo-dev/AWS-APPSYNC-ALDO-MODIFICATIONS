//
//  WeakRetainer.swift
//  AWSAppSyncTests
//
//  Created by Alex Hmelevski on 2018-08-17.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

/// The idea of the class to be able create PointerArrays
/// It doesn't hold strong reference.
class WeakRetainer<T: AnyObject> {
    private(set) weak var value: T?
    init(value: T?) {
        self.value = value
    }
    
    /// Returns true if the object was dealocated
    var isNullified: Bool {
        return value == nil
    }
}
