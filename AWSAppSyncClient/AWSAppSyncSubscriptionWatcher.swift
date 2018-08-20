//
//  AWSAppSyncSubscriptionWatcher.swift
//  AWSAppSync
//

import Dispatch
import Reachability
import Foundation

protocol Loggable {}

extension Loggable {
    func log(with message: String, function: String = #function) {
//        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            debugPrint("[AWS: \(self) \(function)] \(message)")
        }
        
//        #endif
    }
}

protocol MQTTSubscritionWatcher {
    func getIdentifier() -> Int
    func getTopics() -> [String]
    func messageCallbackDelegate(data: Data)
    func disconnectCallbackDelegate(error: Error)
}

final class TaskRepeater {
    
    private let queue: DispatchQueue
    private var workItem: DispatchWorkItem = DispatchWorkItem(block: {})
    init(queue: DispatchQueue = .global()) {
        self.queue = queue
    }
    
    func repeatTask(after interval: DispatchTimeInterval, task: @escaping () -> Void) {
        workItem.cancel()
        workItem = DispatchWorkItem(block: task)
        queue.asyncAfter(deadline: .now() + interval, execute: workItem)
    }
}


enum SyncState: Equatable {
    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs,rhs) {
        case (.inProgress,.inProgress),(.finished,.finished),(.finishedWith,.finishedWith): return true
        default: return false
        }
    }
    
    case inProgress
    case finished
    case finishedWith(error: Error)
}

class SubscriptionsOrderHelper {
    var count = 0
    var previousCall = Date()
    var pendingCount = 0
    var dispatchLock = DispatchQueue(label: "SubscriptionsQueue")
    var waitDictionary = [0: true]
    static let sharedInstance = SubscriptionsOrderHelper()
    
    func getLatestCount() -> Int {
        count = count + 1
        waitDictionary[count] = false
        return count
    }
    
    func markDone(id: Int) {
        waitDictionary[id] = true
    }
    
    func shouldWait(id: Int) -> Bool {
        for i in 0..<id {
            if (waitDictionary[i] == false) {
                return true
            }
        }
        return false
    }
}

protocol QuerySyncHandler {
    @discardableResult
    func performSync(lastSyncTime: String?, completion: SyncCompletion?) -> Bool
}

protocol RemoveNetworkWatchHander {
    func remove(_: NetworkConnectionNotification)
}

extension AWSAppSyncClient: RemoveNetworkWatchHander {
    func remove(_ notificationObserver: NetworkConnectionNotification) {
        var elementPosition: Int?
        for (index, element) in self.networkStatusWatchers.enumerated() {
            if element.identifier == notificationObserver.identifier {
                elementPosition = index
            }
        }
        if let elementPosition = elementPosition {
            self.networkStatusWatchers.remove(at: elementPosition)
        }
    }
}
typealias SyncCompletion = (Error?) -> Void
public typealias CompletionCallback<T> = (T) -> Void
public typealias RefreshTokenRequest = (@escaping CompletionCallback<Error?>) -> Void

public final class AWSAppSyncQuerySyncHandler<Query: GraphQLQuery>: QuerySyncHandler {
    
    weak var httpClient: AWSAppSyncHTTPNetworkTransport?
    let syncQuery: Query
    let store: ApolloStore
    let handlerQueue: DispatchQueue
    let syncResultHandler: QuerySyncResultHandler<Query>?
    let syncCallback: OperationResultHandler<Query>?
    var metadataCache: AWSSubscriptionMetaDataCache?
    var reachabilityClient: Reachability?
    var lastUpdatedTime: Date?
    var userCancelledSync: Bool = false
    var syncFinishedCallback: SyncCompletion?
    
    init(httpClient: AWSAppSyncHTTPNetworkTransport,
         store: ApolloStore,
         syncQuery: Query,
         handlerQueue: DispatchQueue,
         syncResultHandler: @escaping QuerySyncResultHandler<Query>) {
        self.httpClient = httpClient
        self.store = store
        self.syncQuery = syncQuery
        self.handlerQueue = handlerQueue
        self.syncCallback = nil
        self.syncResultHandler = syncResultHandler
    }
    
    init(httpClient: AWSAppSyncHTTPNetworkTransport,
         store: ApolloStore,
         syncQuery: Query,
         handlerQueue: DispatchQueue,
         syncCallback: @escaping OperationResultHandler<Query>) {
        self.httpClient = httpClient
        self.store = store
        self.syncQuery = syncQuery
        self.handlerQueue = handlerQueue
        self.syncResultHandler = nil
        self.syncCallback = syncCallback
    }
    
    func performSync(lastSyncTime: String?, completion: SyncCompletion?) -> Bool {
        
        func notifyResultHandler(result: GraphQLResult<Query.Data>?, transaction: ApolloStore.ReadWriteTransaction?, error: Error?) {
            
            handlerQueue.async {
                let _ = self.store.withinReadWriteTransaction { transaction in
                    self.syncResultHandler!(result, transaction, error)
                    completion?(nil)
                }
            }
        }
        
        var overrideMap = [String: String]()
        overrideMap["SDK_OVERRIDE"] = lastSyncTime ?? ""
        
        let _ = self.httpClient!.send(operation: syncQuery, overrideMap: overrideMap) { (response, error) in
            guard let response = response else {
                notifyResultHandler(result: nil, transaction: nil, error: error)
                completion?(error)
                return
            }
            
            firstly {
                try response.parseResult(cacheKeyForObject: self.store.cacheKeyForObject)
                }.andThen { (result, records) in
                    notifyResultHandler(result: result, transaction: nil, error: nil)
                    completion?(nil)
                    if let records = records {
                        self.store.publish(records: records, context: nil).catch { error in
                            preconditionFailure(String(describing: error))
                        }
                    }
                }.catch { error in
                    notifyResultHandler(result: nil, transaction: nil, error: error)
                    completion?(error)
            }
        }
        
        return true
    }
}


public final class AWSAppSyncQuerySyncWatcher<SyncQuery: GraphQLQuery>: NetworkConnectionNotification, Cancellable, Loggable {
    var identifier: String = UUID().uuidString
    weak var httpClient: AWSAppSyncHTTPNetworkTransport?
    let syncQuery: SyncQuery?
    let handlerQueue: DispatchQueue
    let store: ApolloStore
    let querySyncHandler: QuerySyncHandler?
    var lastUpdatedTime: Date?
    var userCancelledWatcher: Bool = false
    var reachabilityClient: Reachability?
    var metadataCache: AWSSubscriptionMetaDataCache?
    let queryOperationCancellable: Cancellable?
    var networkObserverDelegate: RemoveNetworkWatchHander
    var initialLoadDone: Bool = false
    var logger: AWSLogger?
    init(httpClient: AWSAppSyncHTTPNetworkTransport,
         store: ApolloStore,
         handlerQueue: DispatchQueue,
         syncQuery: SyncQuery,
         querySyncHandler: QuerySyncHandler,
         reachabilityClient: Reachability? = nil,
         metadataCache: AWSSubscriptionMetaDataCache? = nil,
         networkObserverDelegate: RemoveNetworkWatchHander,
         queryOperationCancellable: Cancellable?) {
    
        self.httpClient = httpClient
        self.store = store
        self.syncQuery = syncQuery
        self.querySyncHandler = querySyncHandler
        self.handlerQueue = handlerQueue
        self.reachabilityClient = reachabilityClient
        self.metadataCache = metadataCache
        self.queryOperationCancellable = queryOperationCancellable
        self.networkObserverDelegate = networkObserverDelegate
        
        // Add a notification handler for `applicationWillEnterForeground` to see if we need to perform a sync
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(applicationWillEnterForeground(_:)),
                                               name:.UIApplicationWillEnterForeground,
                                               object: nil)
        
        // start the subscription request process on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let `self` = self else {  return }
            self.loadLastUpdateTime()
            self.logger?.log(message: "Going to sync for time: \(self.lastUpdatedTime!.description)", filename: #file, line: #line , funcname: #function)
            let _ = self.querySyncHandler?.performSync(lastSyncTime: self.lastUpdatedTime!.timeIntervalSince1970.description,
                                                       completion: { [weak self] (error) in
                                                        if error == nil {
                                                            self?.lastUpdatedTime = Date()
                                                            let syncQueryString = "\(SyncQuery.operationString)__\((self?.syncQuery!.variables!.jsonObject)!)"
                                                            try? self?.metadataCache?.saveRecord(operationString: syncQueryString, operationName: syncQueryString, lastSyncDate: (self?.lastUpdatedTime!)!)
                                                        }
            })
            self.initialLoadDone = true
        }
    }
    
    func loadLastUpdateTime() {
        do {
            let syncQueryString = "\(SyncQuery.operationString)__\(self.syncQuery!.variables!.jsonObject)"
            self.lastUpdatedTime = try self.metadataCache?.getLastSyncTime(operationName: syncQueryString, operationString: syncQueryString)
        } catch {
            
        }
        if self.lastUpdatedTime == nil {
            self.logger?.log(message: "set lastSync time to current \(Date())", filename: #file, line: #line , funcname: #function)
            self.lastUpdatedTime = Date()
            let syncQueryString = "\(SyncQuery.operationString)__\(self.syncQuery!.variables!.jsonObject)"
            
            try? self.metadataCache?.saveRecord(operationString: syncQueryString, operationName: syncQueryString, lastSyncDate: self.lastUpdatedTime!)
        } else {
            self.logger?.log(message: "set lastSync time from cache", filename: #file, line: #line , funcname: #function)
        }
    }
    
    @objc func applicationWillEnterForeground(_ notification: NSNotification) {
        self.logger?.log(message: "Start", filename: #file, line: #line , funcname: #function)
        // when application enters foreground, we check the network connection
        // if the host is reachable, we start the subscription
        if let connection = reachabilityClient?.connection {
            self.logger?.log(message: "\(connection)", filename: #file, line: #line , funcname: #function)
            switch(connection) {
            case .cellular,.wifi: handleReconnect()
            case .none: self.logger?.log(message: "Skipping reconnetion for state\(connection)", filename: #file, line: #line , funcname: #function)
    
                
            }
        }
    }
    
    /// Reconnect is responsible for performing a sync
    func handleReconnect() {
        self.logger?.log(message: "Start", filename: #file, line: #line , funcname: #function)
        // start the sync request process on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let _ = self.querySyncHandler?.performSync(lastSyncTime: self.lastUpdatedTime!.timeIntervalSince1970.description, completion: { [weak self] (error) in
                if error == nil  {
                    self?.lastUpdatedTime = Date()
                    let syncQueryString = "\(SyncQuery.operationString)__\((self?.syncQuery!.variables!.jsonObject)!)"
                    try? self?.metadataCache?.saveRecord(operationString: syncQueryString, operationName: syncQueryString, lastSyncDate: (self?.lastUpdatedTime!)!)
                }
            })
        }
    }
    
    func onNetworkAvailabilityStatusChanged(isEndpointReachable: Bool, isInitialNotification: Bool) {
        log(with: "Start")
        if (isEndpointReachable && !isInitialNotification) {
            self.handleReconnect()
        }
    }
    
    deinit {
        // call cancel here before exiting
        cancel()
    }
    
    /// Cancel any in progress fetching operations and unsubscribe from the messages.
    public func cancel() {
        NotificationCenter.default.removeObserver(self)
        self.userCancelledWatcher = true
        self.queryOperationCancellable?.cancel()
        self.networkObserverDelegate.remove(self)
    }
}
public enum WatcherError: Error {
    case forcedDisconnection
}

public protocol AWSLogger {
    func log(message: String, filename: StaticString, line: Int, funcname: StaticString)
    func log(error: Error, filename: StaticString, line: Int, funcname: StaticString)
}

/// A `AWSAppSyncSubscriptionWatcher` is responsible for watching the subscription, and calling the result handler with a new result whenever any of the data is published on the MQTT topic. It also normalizes the cache before giving the callback to customer.
public final class AWSAppSyncSubscriptionWatcher<Subscription: GraphQLSubscription>: MQTTSubscritionWatcher, NetworkConnectionNotification, Cancellable {
    
    var identifier: String = UUID().uuidString
    weak var client: AppSyncMQTTClient?
    weak var httpClient: AWSAppSyncHTTPNetworkTransport?
    let subscription: Subscription?
    
    let handlerQueue: DispatchQueue
    let resultHandler: SubscriptionResultHandler<Subscription>
    internal var subscriptionTopic: [String]?
    let store: ApolloStore
    let querySyncHandler: QuerySyncHandler?
    public let uniqueIdentifier = SubscriptionsOrderHelper.sharedInstance.getLatestCount()
    var lastUpdatedTime: Date?
    var userCancelledSubscription: Bool = false
    var isSubscriptionActive: Bool = false
    var reachabilityClient: Reachability?
    var reconnectInProgress: Bool = false
    var metadataCache: AWSSubscriptionMetaDataCache?
    var networkObserverDelegate: RemoveNetworkWatchHander?
    var syncState = SyncState.inProgress
    var jammedData: [Data]  = []
    var refreshRequest: RefreshTokenRequest
    var reconnectionRepeater = TaskRepeater()
    var logger: AWSLogger?
    
    init(client: AppSyncMQTTClient,
         httpClient: AWSAppSyncHTTPNetworkTransport,
         store: ApolloStore,
         subscription: Subscription,
         handlerQueue: DispatchQueue,
         querySyncHandler: QuerySyncHandler? = nil,
         reachabilityClient: Reachability? = nil,
         networkObserverDelegate: RemoveNetworkWatchHander? = nil,
         metadataCache: AWSSubscriptionMetaDataCache? = nil,
         refreshRequest: @escaping RefreshTokenRequest = { $0(nil) },
         resultHandler: @escaping SubscriptionResultHandler<Subscription>) {
        self.client = client
        self.httpClient = httpClient
        self.store = store
        self.subscription = subscription
        self.handlerQueue = handlerQueue
        self.resultHandler = resultHandler
        self.querySyncHandler = querySyncHandler
        self.reachabilityClient = reachabilityClient
        self.metadataCache = metadataCache
        self.networkObserverDelegate = networkObserverDelegate
        self.refreshRequest = refreshRequest
        
        // Add a notification handler for `applicationWillEnterForeground` to see if we need to restart subscription.
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(applicationWillEnterForeground(_:)),
                                               name: .UIApplicationWillEnterForeground,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(applicationWillEnterBackground(_:)),
                                               name:.UIApplicationDidEnterBackground,
                                               object: nil)
        

        // start the subscriptionr request process on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let `self` = self else { return }
            self.loadLastUpdateTime()
            self.logger?.log(message: "Going to sync for time: \(self.lastUpdatedTime!.description)", filename: #file, line: #line , funcname: #function)
            self.performSubscriptionWithSync()
        }
    }
    
    
    func getIdentifier() -> Int {
        return uniqueIdentifier
    }
    
    func loadLastUpdateTime() {
        do {
            let subscriptionString = "\(Subscription.operationString)__\(subscription!.variables!.jsonObject)"
            self.lastUpdatedTime = try self.metadataCache?.getLastSyncTime(operationName: subscriptionString, operationString: subscriptionString)
            logger?.log(message: "set lastSync time from cache", filename: #file, line: #line , funcname: #function)

        } catch {
            
        }
        if self.lastUpdatedTime == nil {
            logger?.log(message: "set lastSync time to current \(Date())", filename: #file, line: #line , funcname: #function)
            self.lastUpdatedTime = Date()
            let subscriptionString = "\(Subscription.operationString)__\(subscription!.variables!.jsonObject)"
            logger?.log(message: "Operation string: \(subscriptionString)", filename: #file, line: #line , funcname: #function)
            try? self.metadataCache?.saveRecord(operationString: subscriptionString, operationName: subscriptionString, lastSyncDate: self.lastUpdatedTime!)
        }
    }
    
    @objc func applicationWillEnterForeground(_ notification: NSNotification) {
        // when application enters foreground, we check the network connection
        // if the host is reachable, we start the subscription
        log(with: "Connection: \(reachabilityClient!.connection)")
        switch(reachabilityClient!.connection) {
        case .cellular,.wifi:
            self.handleReconnect()
        case .none:
            break
        }
    }
    
    @objc func applicationWillEnterBackground(_ notification: NSNotification) {
        syncState = .inProgress
        disconnectCallbackDelegate(error: WatcherError.forcedDisconnection)
    }
    
    /// Reconnect is responsible for performing a delta sync and then starting the subsciption
    func handleReconnect() {
        logger?.log(message: "isSubscriptionActive: \(isSubscriptionActive)", filename: #file, line: #line , funcname: #function)
        logger?.log(message: "reconnectInProgress: \(reconnectInProgress)", filename: #file, line: #line , funcname: #function)

        // if the subscription is already active, we do not need to do any sync
        guard isSubscriptionActive != true && reconnectInProgress != true else {
            return
        }
        reconnectInProgress = true
        // start the subscription request process on a background thread
        DispatchQueue.global(qos: .userInitiated).async {[weak self] in
            self?.performSubscriptionWithSync()
        }
    }
    
    func updateTimeStamp() {
        self.lastUpdatedTime = Date()
        let subscriptionString = "\(Subscription.operationString)__\(self.subscription!.variables!.jsonObject)"
        try? self.metadataCache?.saveRecord(operationString: subscriptionString, operationName: subscriptionString, lastSyncDate: self.lastUpdatedTime!)
    }
    
    func performSubscriptionWithSync(retryTimes: Int = 3) {
        logger?.log(message: "Start with number of retries:  \(retryTimes)", filename: #file, line: #line , funcname: #function)
        self.startSubscription { [weak self] (error) in
            guard let `self` = self else { return }
            self.log(with: "Finished subscription with:  \(error)")
            if let error = error {
                self.logger?.log(error: error, filename: #file, line: #line, funcname: #function)
                self.proccessError(error, retryTimes: retryTimes)
            } else {
                self.logger?.log(message: "Finished subscription success", filename: #file, line: #line , funcname: #function)
                self.continueSubscriptionWithSync(retryTimes: retryTimes)
            }
        }
    }
    
    private func proccessError(_ error: Error, retryTimes: Int) {
        self.logger?.log(message:"Try to recover from error: \(error) with retry times \(retryTimes)", filename: #file, line: #line , funcname: #function)
        if needRefreshToken(forError: error) {
            self.logger?.log(message:"Need Reconection!! Sending Reconnection Request", filename: #file, line: #line , funcname: #function)

            refreshRequest({ [weak self] in self?.processRequestRefreshToken(withResult: $0, retryTimes: retryTimes) })
        } else {
            retryReconnection(retryTimes, for: error)
        }
    }
    
    private func processRequestRefreshToken(withResult result: Error?, retryTimes: Int) {
        guard let error = result else {
            self.logger?.log(message: "Connection Succeed", filename: #file, line: #line , funcname: #function)
            performSubscriptionWithSync(retryTimes: retryTimes)
            return
        }
        retryReconnection(retryTimes, for: error)
    }
    
    private func retryReconnection(_ retryTimes: Int, for error: Error) {
        self.logger?.log(message: "Retrying reconnection !", filename: #file, line: #line , funcname: #function)
        if retryTimes > 0 {
            let dispatchTimeInterval = DispatchTimeInterval.seconds(1)
            self.logger?.log(message: "Sending request in \(dispatchTimeInterval).....", filename: #file, line: #line , funcname: #function)
            reconnectionRepeater.repeatTask(after: dispatchTimeInterval) { [weak self] in
                 self?.logger?.log(message:  "Sending now!", filename: #file, line: #line , funcname: #function)
                 self?.performSubscriptionWithSync(retryTimes: retryTimes - 1)
            }
        } else {
            self.logger?.log(error: error, filename: #file, line: #line, funcname: #function)
            self.logger?.log(message:  "Notifying delegates", filename: #file, line: #line , funcname: #function)
            disconnectCallbackDelegate(error: error)
            notifyDelegate(with: error)
        }
    }
    
    private func continueSubscriptionWithSync(retryTimes: Int) {
        initiateSyncQuery(retryTimes: retryTimes)
    }
    
    
    private func needRefreshToken(forError error: Error) -> Bool {
        return Optional(error).flatMap({ $0 as? AWSAppSyncClientError })
                              .flatMap({ $0.response })
                              .map({$0.statusCode != 200 }) ?? false
    }

    private func initiateSyncQuery(retryTimes: Int) {
        self.logger?.log(message:  "Start", filename: #file, line: #line , funcname: #function)
        querySyncHandler?.performSync(lastSyncTime: self.lastUpdatedTime!.timeIntervalSince1970.description,
                                      completion: { [weak self] (error) in
                                       
                                        self?.updateTimeStamp()
                                        if let error = error {
                                            self?.logger?.log(error: error, filename: #file, line: #line, funcname: #function)
                                            self?.syncState = .finishedWith(error: error)
                                            self?.proccessError(error, retryTimes: retryTimes)
                                        } else {
                                            self?.logger?.log(message:  "Finish!", filename: #file, line: #line , funcname: #function)
                                            self?.syncState = .finished
                                            self?.proccessJammedData()
                                            self?.reconnectInProgress = false
                                        }
        })
    }
    
    
    
    func startSubscription(establishedCallBack: SyncCompletion? = nil)  {

        guard isSubscriptionActive != true else {
            establishedCallBack?(nil)
            return
        }
        do {
            while (SubscriptionsOrderHelper.sharedInstance.shouldWait(id: self.uniqueIdentifier)) {
                sleep(4)
            }
        
            let _ = try self.httpClient?.sendSubscriptionRequest(operation: subscription!, completionHandler: { (response, error) in
                SubscriptionsOrderHelper.sharedInstance.markDone(id: self.uniqueIdentifier)
                if let response = response {
                    do {
                        let subscriptionResult = try AWSGraphQLSubscriptionResponseParser(body: response).parseResult()
                        if let subscriptionInfo = subscriptionResult.subscrptionInfo {
                            self.subscriptionTopic = subscriptionResult.newTopics
                            self.client?.addWatcher(watcher: self, topics: subscriptionResult.newTopics!, identifier: self.uniqueIdentifier)
                            self.client?.startSubscriptions(subscriptionInfo: subscriptionInfo)
                            // we mark the subscription as active after we make the start subscription request.
                            self.isSubscriptionActive = true
                            establishedCallBack?(nil)
                        }
                    } catch {
                        self.resultHandler(nil, nil, AWSAppSyncSubscriptionError(additionalInfo: error.localizedDescription, errorDetails: nil))
                        establishedCallBack?(error)
                    }
                } else if let error = error {
                    self.resultHandler(nil, nil, AWSAppSyncSubscriptionError(additionalInfo: error.localizedDescription, errorDetails: nil))
                    establishedCallBack?(error)
                }
            })
        } catch {
            resultHandler(nil, nil, AWSAppSyncSubscriptionError(additionalInfo: error.localizedDescription, errorDetails: nil))
            establishedCallBack?(error)
        }
    }
    
    func getTopics() -> [String] {
        return subscriptionTopic ?? [String]()
    }
    
    func disconnectCallbackDelegate(error: Error) {
        logger?.log(message: "Disconnected", filename: #file, line: #line , funcname: #function)
        isSubscriptionActive = false
        reconnectInProgress = false
        client?.stopSubscription(subscription: self)
    }
    
    private func notifyDelegate(with error: Error) {
         self.resultHandler(nil, nil, error)
    }
    
    func onNetworkAvailabilityStatusChanged(isEndpointReachable: Bool, isInitialNotification: Bool) {
        logger?.log(message: "Changed", filename: #file, line: #line , funcname: #function)
        if (isEndpointReachable && !isInitialNotification) {
            self.handleReconnect()
        }
    }
    
    func proccessJammedData() {
        logger?.log(message: "Start", filename: #file, line: #line , funcname: #function)
        jammedData.forEach(self.messageCallbackDelegate)
        jammedData = []
        logger?.log(message: "Finished the scope", filename: #file, line: #line , funcname: #function)
    }
    
    func messageCallbackDelegate(data: Data) {
        guard syncState != .inProgress else {
            jammedData.append(data)
            return
        }
        do {
            let datastring = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
            let jsonObject = try JSONSerializationFormat.deserialize(data: datastring.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!) as! JSONObject
            let response = GraphQLResponse(operation: subscription!, body: jsonObject)
            
            
            firstly {
                try response.parseResult(cacheKeyForObject: self.store.cacheKeyForObject)
                }.andThen { (result, records) in
        
                    self.lastUpdatedTime = Date()
                    let subscriptionString = "\(Subscription.operationString)__\(self.subscription!.variables!.jsonObject)"
                    try self.metadataCache?.saveRecord(operationString: subscriptionString, operationName: subscriptionString, lastSyncDate: self.lastUpdatedTime!)
                    let _ = self.store.withinReadWriteTransaction { transaction in
                        self.resultHandler(result, transaction, nil)
                    }
                    
                    if let records = records {
                        self.store.publish(records: records, context: nil).catch { error in
                            preconditionFailure(String(describing: error))
                        }
                    }
                }
                .catch { error in
                    self.resultHandler(nil, nil, error)
            }
        } catch {
            self.resultHandler(nil, nil, error)
        }
    }
    
    deinit {
        // call cancel here before exiting
        cancel()
    }
    
    /// Cancel any in progress fetching operations and unsubscribe from the messages.
    public func cancel() {
        client?.stopSubscription(subscription: self)
        NotificationCenter.default.removeObserver(self)
        self.userCancelledSubscription = true
    }
}


extension AWSAppSyncSubscriptionWatcher: Loggable {
    
}
