//
//  WatcherSource.swift
//  AHFuture
//
//  Created by Alex Hmelevski on 2018-08-08.
//

import Foundation


struct WatcherSource<Key: Hashable> {
    
    private var _backstorage: [Key: [SubscriptionWatcher]] = [:]
    
    var allWatchers: [SubscriptionWatcher] {
        return _backstorage.values.flatMap({ $0 })
    }
    
    var isEmpty: Bool {
        return _backstorage.isEmpty
    }
    
    func isEmpty(for key: Key) -> Bool {
        return _backstorage[key]?.isEmpty ?? true
    }
    
    func watchers(for key: Key) -> [SubscriptionWatcher] {
        return _backstorage[key] ?? []
    }
    
    func watcher(with id: Int) -> SubscriptionWatcher? {
        return _backstorage.values.flatMap({ $0 }).first(where: { $0.id == id })
    }
    
    mutating func append(watcher: SubscriptionWatcher, for key: Key) {
        let values = _backstorage[key] ?? []
        _backstorage[key] = values + [watcher]
    }
    
    mutating func remove(watcher: SubscriptionWatcher, for key: Key) {
        guard let  values = _backstorage[key] else { return }
        let filtered = values.filter({ $0.id != watcher.id })
        guard !filtered.isEmpty else {
            _backstorage.removeValue(forKey: key)
            return
        }
        _backstorage[key] = values.filter({ $0.id != watcher.id })
    }

    
    mutating func remove(wather: SubscriptionWatcher) {
        topics(for: wather).forEach({ remove(watcher: wather, for: $0) })
    }
    
    mutating func topics(for watcher: SubscriptionWatcher) -> [Key] {
        return _backstorage.reduce([]) { (partial, element) -> [Key] in
            if element.value.contains(where: { $0.id == watcher.id }) {
                return partial + [element.key]
            } else {
                return partial
            }
        }
    }
}
