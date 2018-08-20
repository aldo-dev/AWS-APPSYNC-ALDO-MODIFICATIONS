//
//  ProcessingQueueObject.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-09.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation

public protocol QueueObject {
    func async(execute: @escaping () -> Void)
    func sync(execute: @escaping () -> Void )
    func asyncAfter(deadline: DispatchTime, execute work: @escaping @convention(block) () -> Swift.Void)
    func suspend()
    func resume()
}


/// Wrapper for DispatchQueue.
/// The main purpose to erase the type and help in unit testing

public final class ProcessingQueueObject: QueueObject, Loggable {
    
    private let dispatchQueue: DispatchQueue
    private var suspended = false
        
    static func concurrent(withLabel label: String) -> ProcessingQueueObject {
        return ProcessingQueueObject(dispatchQueue: DispatchQueue.init(label: label, attributes: .concurrent))
    }
    
    static func serial(withLabel label: String) -> ProcessingQueueObject {
        return ProcessingQueueObject(dispatchQueue: DispatchQueue.init(label: label))
    }
    
    public init(dispatchQueue: DispatchQueue) {
        self.dispatchQueue = dispatchQueue
    }
    
    public func async(execute: @escaping () -> Void) {
        dispatchQueue.async(execute: execute)
    }
    
    public func sync(execute: @escaping () -> Void) {
        dispatchQueue.sync(execute: execute)
    }
    
    public func asyncAfter(deadline: DispatchTime, execute work: @escaping @convention(block) () -> Swift.Void) {
        dispatchQueue.asyncAfter(deadline: deadline, execute: work)
    }
    
    
    public func suspend() {
        dispatchQueue.suspend()
        suspended = true
    }
    
    public func resume() {
        dispatchQueue.resume()
        suspended = false
    }
    
    deinit {
        // need to unpause the queue before deinit.
        // Otherwise it'll crash
        if suspended {
            dispatchQueue.resume()
        }
    }
    
}
