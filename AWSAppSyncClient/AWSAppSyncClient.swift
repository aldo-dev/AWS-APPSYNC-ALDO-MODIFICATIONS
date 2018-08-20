//
//  AWSAppSyncClient.swift
//  AWSAppSyncClient
//

import Foundation
import AWSCore
import Reachability

public enum ClientNetworkAccessState {
    case Online
    case Offline
}

public protocol ConnectionStateChangeHandler {
    func stateChanged(networkState: ClientNetworkAccessState)
}

public typealias SubscriptionResultHandler<Operation: GraphQLSubscription> = (_ result: GraphQLResult<Operation.Data>?, _ transaction: ApolloStore.ReadWriteTransaction?, _ error: Error?) -> Void

public typealias QuerySyncResultHandler<Operation: GraphQLQuery> = (_ result: GraphQLResult<Operation.Data>?, _ transaction: ApolloStore.ReadWriteTransaction?, _ error: Error?) -> Void

public typealias OptimisticResponseBlock = (ApolloStore.ReadWriteTransaction?) -> Void

public typealias MutationConflictHandler<Mutation: GraphQLMutation> = (_ serverState: Snapshot?, _ taskCompletionSource: AWSTaskCompletionSource<Mutation>?, _ resultHandler: OperationResultHandler<Mutation>?) -> Void

enum AWSAppSyncGraphQLOperation {
    case mutation
    case query
    case subscription
}

class SnapshotProcessController {
    let endpointURL: URL
    var reachability: Reachability?
    var networkStatusWatchers: [NetworkConnectionNotification] = []
    let allowsCellularAccess: Bool
    
    init(endpointURL: URL, allowsCellularAccess: Bool = true) {
        self.endpointURL = endpointURL
        self.allowsCellularAccess = allowsCellularAccess
        reachability = Reachability(hostname: endpointURL.host!)
        reachability?.allowsCellularConnection = allowsCellularAccess
    }
    
    
    func shouldExecuteOperation(operation: AWSAppSyncGraphQLOperation) -> Bool {
        switch operation {
        case .mutation:
            if !(reachability?.connection.description == "No Connection") {
                return true
            } else {
                return false
            }
        case .query:
            return true
        case .subscription:
            return true
        }
    }
}

public class AWSAppSyncClientConfiguration {
    
    fileprivate var url: URL
    fileprivate var region: AWSRegionType
    fileprivate var store: ApolloStore
    fileprivate var credentialsProvider: AWSCredentialsProvider?
    fileprivate var urlSessionConfiguration: URLSessionConfiguration
    fileprivate var databaseURL: URL?
    fileprivate var allowsCellularAccess: Bool = true
    fileprivate var autoSubmitOfflineMutations: Bool = true
    fileprivate var apiKeyAuthProvider: AWSAPIKeyAuthProvider?
    fileprivate var userPoolsAuthProvider: AWSCognitoUserPoolsAuthProvider?
    fileprivate var snapshotController: SnapshotProcessController?
    fileprivate var s3ObjectManager: AWSS3ObjectManager?
    fileprivate var presignedURLClient: AWSS3ObjectPresignedURLGenerator?
    fileprivate var connectionStateChangeHandler: ConnectionStateChangeHandler?
    
    /// Creates a configuration object for the `AWSAppSyncClient`.
    ///
    /// - Parameters:
    ///   - url: The endpoint url for Appsync endpoint.
    ///   - serviceRegion: The service region for Appsync.
    ///   - credentialsProvider: A `AWSCredentialsProvider` object for AWS_IAM based authorization.
    ///   - urlSessionConfiguration: A `URLSessionConfiguration` configuration object for custom HTTP configuration.
    ///   - databaseURL: The path to local sqlite database for persistent storage, if nil, an in-memory database is used.
    ///   - connectionStateChangeHandler: The delegate object to be notified when client network state changes.
    ///   - s3ObjectManager: The client used for uploading / downloading `S3Objects`.
    ///   - presignedURLClient: The `AWSAppSyncClientConfiguration` object.
    public init(url: URL,
                serviceRegion: AWSRegionType,
                credentialsProvider: AWSCredentialsProvider,
                urlSessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default,
                databaseURL: URL? = nil,
                connectionStateChangeHandler: ConnectionStateChangeHandler? = nil,
                s3ObjectManager: AWSS3ObjectManager? = nil,
                presignedURLClient: AWSS3ObjectPresignedURLGenerator? = nil) throws {
        self.url = url
        self.region = serviceRegion
        self.credentialsProvider = credentialsProvider
        self.urlSessionConfiguration = urlSessionConfiguration
        self.databaseURL = databaseURL
        self.apiKeyAuthProvider = nil
        self.userPoolsAuthProvider = nil
        self.store = ApolloStore(cache: InMemoryNormalizedCache())
        self.connectionStateChangeHandler = connectionStateChangeHandler
        if let databaseURL = databaseURL {
            do {
                self.store = try ApolloStore(cache: AWSSQLLiteNormalizedCache(fileURL: databaseURL))
            } catch {
                // Use in memory cache incase database init fails
            }
        }
        self.snapshotController = SnapshotProcessController(endpointURL: url)
        self.s3ObjectManager = s3ObjectManager
        self.presignedURLClient = presignedURLClient
    }
    
    /// Creates a configuration object for the `AWSAppSyncClient`.
    ///
    /// - Parameters:
    ///   - url: The endpoint url for Appsync endpoint.
    ///   - serviceRegion: The service region for Appsync.
    ///   - apiKeyAuthProvider: A `AWSAPIKeyAuthProvider` protocol object for API Key based authorization.
    ///   - urlSessionConfiguration: A `URLSessionConfiguration` configuration object for custom HTTP configuration.
    ///   - databaseURL: The path to local sqlite database for persistent storage, if nil, an in-memory database is used.
    ///   - connectionStateChangeHandler: The delegate object to be notified when client network state changes.
    ///   - s3ObjectManager: The client used for uploading / downloading `S3Objects`.
    ///   - presignedURLClient: The `AWSAppSyncClientConfiguration` object.
    public init(url: URL,
                serviceRegion: AWSRegionType,
                apiKeyAuthProvider: AWSAPIKeyAuthProvider,
                urlSessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default,
                databaseURL: URL? = nil,
                connectionStateChangeHandler: ConnectionStateChangeHandler? = nil,
                s3ObjectManager: AWSS3ObjectManager? = nil,
                presignedURLClient: AWSS3ObjectPresignedURLGenerator? = nil) throws {
        self.url = url
        self.region = serviceRegion
        self.credentialsProvider = nil
        self.userPoolsAuthProvider = nil
        self.apiKeyAuthProvider = apiKeyAuthProvider
        self.urlSessionConfiguration = urlSessionConfiguration
        self.databaseURL = databaseURL
        self.store = ApolloStore(cache: InMemoryNormalizedCache())
        if let databaseURL = databaseURL {
            do {
                self.store = try ApolloStore(cache: AWSSQLLiteNormalizedCache(fileURL: databaseURL))
            } catch {
                // Use in memory cache incase database init fails
            }
        }
        self.s3ObjectManager = s3ObjectManager
        self.presignedURLClient = presignedURLClient
        self.connectionStateChangeHandler = connectionStateChangeHandler
    }
    
    /// Creates a configuration object for the `AWSAppSyncClient`.
    ///
    /// - Parameters:
    ///   - url: The endpoint url for Appsync endpoint.
    ///   - serviceRegion: The service region for Appsync.
    ///   - userPoolsAuthProvider: A `AWSCognitoUserPoolsAuthProvider` protocol object for API Key based authorization.
    ///   - urlSessionConfiguration: A `URLSessionConfiguration` configuration object for custom HTTP configuration.
    ///   - databaseURL: The path to local sqlite database for persistent storage, if nil, an in-memory database is used.
    ///   - connectionStateChangeHandler: The delegate object to be notified when client network state changes.
    ///   - s3ObjectManager: The client used for uploading / downloading `S3Objects`.
    ///   - presignedURLClient: The `AWSAppSyncClientConfiguration` object.
    public init(url: URL,
                serviceRegion: AWSRegionType,
                userPoolsAuthProvider: AWSCognitoUserPoolsAuthProvider,
                urlSessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default,
                databaseURL: URL? = nil,
                connectionStateChangeHandler: ConnectionStateChangeHandler? = nil,
                s3ObjectManager: AWSS3ObjectManager? = nil,
                presignedURLClient: AWSS3ObjectPresignedURLGenerator? = nil) throws {
        self.url = url
        self.region = serviceRegion
        self.credentialsProvider = nil
        self.apiKeyAuthProvider = nil
        self.userPoolsAuthProvider = userPoolsAuthProvider
        self.urlSessionConfiguration = urlSessionConfiguration
        self.databaseURL = databaseURL
        self.store = ApolloStore(cache: InMemoryNormalizedCache())
        if let databaseURL = databaseURL {
            do {
                self.store = try ApolloStore(cache: AWSSQLLiteNormalizedCache(fileURL: databaseURL))
            } catch {
                // Use in memory cache incase database init fails
            }
        }
        self.s3ObjectManager = s3ObjectManager
        self.presignedURLClient = presignedURLClient
        self.connectionStateChangeHandler = connectionStateChangeHandler
    }
}

public struct AWSAppSyncClientError: Error, LocalizedError {

    /// The body of the response.
    public let body: Data?
    /// Information about the response as provided by the server.
    public let response: HTTPURLResponse?
    let isInternalError: Bool
    let additionalInfo: String?
    
    public var errorDescription: String? {
        if (isInternalError) {
            return additionalInfo
        }
        return "(\(response!.statusCode) \(response!.statusCodeDescription)) \(additionalInfo ?? "")"
    }
}

public struct AWSAppSyncSubscriptionError: Error, LocalizedError {
    let additionalInfo: String?
    let errorDetails: [String:String]?
    
    public var errorDescription: String? {
        return additionalInfo ?? "Unable to start subscription."
    }
    
    public var recoverySuggestion: String? {
        return errorDetails?["recoverySuggestion"]
    }
    
    public var failureReason: String? {
        return errorDetails?["failureReason"]
    }
}

protocol NetworkConnectionNotification {
    var identifier: String { get }
    func onNetworkAvailabilityStatusChanged(isEndpointReachable: Bool, isInitialNotification: Bool)
}

public protocol AWSAppSyncOfflineMutationDelegate {
    func mutationCallback(recordIdentifier: String, operationString: String, snapshot: Snapshot?, error: Error?) -> Void
}

// The client for making `Mutation`, `Query` and `Subscription` requests.
public class AWSAppSyncClient: NetworkConnectionNotification, Loggable {
    var identifier: String = UUID().uuidString
    public let apolloClient: ApolloClient?
    public var offlineMutationDelegate: AWSAppSyncOfflineMutationDelegate?
    public let store: ApolloStore?
    public let presignedURLClient: AWSS3ObjectPresignedURLGenerator?
    public let s3ObjectManager: AWSS3ObjectManager?
    
    var reachability: Reachability?
    
    var networkStatusWatchers: [NetworkConnectionNotification] = []
    var reachabilityObservers: [ReachabilityObserver] = []
    private var appSyncConfiguration: AWSAppSyncClientConfiguration
    internal var httpTransport: AWSAppSyncHTTPNetworkTransport?
    internal var subscriptionTransport: AWSNetworkTransport!
    private var offlineMuationCacheClient : AWSAppSyncOfflineMutationCache?
    private var offlineMutationExecutor: MutationExecutor?
    private var autoSubmitOfflineMutations: Bool = false
    private var mqttClient = MQTTClient<AnyObject, AnyObject>()
    private var appSyncMQTTClient = AppSyncMQTTClient()
    private var subscriptionCentre: (SubscriptionCentre & SubscriptionConnectionSubject)!
    private var subscriptionMetaDataCache: AWSSubscriptionMetaDataCache?
    private var isInitialNotification: Bool = true
    public var logger: AWSLogger?
    internal var connectionStateChangeHandler: ConnectionStateChangeHandler?
    
    
    /// Creates a client with the specified `AWSAppSyncClientConfiguration`.
    ///
    /// - Parameters:
    ///   - appSyncConfig: The `AWSAppSyncClientConfiguration` object.
    public init(appSyncConfig: AWSAppSyncClientConfiguration, logger: AWSLogger? = nil ) throws {
        self.appSyncConfiguration = appSyncConfig
        self.logger = logger
        reachability = Reachability(hostname: self.appSyncConfiguration.url.host!)
        self.autoSubmitOfflineMutations = self.appSyncConfiguration.autoSubmitOfflineMutations
        self.store = appSyncConfig.store
        self.appSyncMQTTClient.allowCellularAccess = self.appSyncConfiguration.allowsCellularAccess
        self.presignedURLClient = appSyncConfig.presignedURLClient
        self.s3ObjectManager = appSyncConfig.s3ObjectManager
        
        if let apiKeyAuthProvider = appSyncConfig.apiKeyAuthProvider {
            self.httpTransport = AWSAppSyncHTTPNetworkTransport(url: self.appSyncConfiguration.url,
                                                                      apiKeyAuthProvider: apiKeyAuthProvider,
                                                               configuration: self.appSyncConfiguration.urlSessionConfiguration)
        } else if let userPoolsAuthProvider = appSyncConfig.userPoolsAuthProvider {
            self.httpTransport = AWSAppSyncHTTPNetworkTransport(url: self.appSyncConfiguration.url,
                                                                      userPoolsAuthProvider: userPoolsAuthProvider,
                                                                      configuration: self.appSyncConfiguration.urlSessionConfiguration)
        } else {
        
            self.httpTransport = AWSAppSyncHTTPNetworkTransport(url: self.appSyncConfiguration.url,
                                                                      configuration: self.appSyncConfiguration.urlSessionConfiguration,
                                                                      region: self.appSyncConfiguration.region,
                                                                      credentialsProvider: self.appSyncConfiguration.credentialsProvider!)
        }
        self.apolloClient = ApolloClient(networkTransport: self.httpTransport!, store: self.appSyncConfiguration.store)
        
        try self.offlineMuationCacheClient = AWSAppSyncOfflineMutationCache()

        if let fileURL = self.appSyncConfiguration.databaseURL {
            do {
                self.offlineMuationCacheClient = try AWSAppSyncOfflineMutationCache(fileURL: fileURL)
            } catch {
                // continue using in memory cache client
            }
            do {
                self.subscriptionMetaDataCache = try AWSSubscriptionMetaDataCache(fileURL: fileURL)
            } catch {

            }
        } else {
            do {
                let databaseURL = URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("timestampSync")
                self.subscriptionMetaDataCache = try AWSSubscriptionMetaDataCache(fileURL: databaseURL)
            } catch {
                
            }
        }
        
        self.offlineMutationExecutor = MutationExecutor(networkClient: self.httpTransport!, appSyncClient: self, snapshotProcessController: SnapshotProcessController(endpointURL:self.appSyncConfiguration.url), fileURL: self.appSyncConfiguration.databaseURL)
        
        networkStatusWatchers.append(self.offlineMutationExecutor!)
        let centre  = ALDOAppSyncSubscriptionCentre(client: ALDOMQTTClient(client:  MQTTClient<AnyObject, AnyObject>(),
                                                                           logger: logger),
                                                    logger: logger)
        let decoratedCentre = ALDOAppSyncSubscriptionCentreReconnector(decorated: centre, logger: logger)
        subscriptionCentre = decoratedCentre
        let reachabilityObserver = AWSNetworkTransportDecorator(decorated: httpTransport!,logger: logger)
        
        if let userPool = appSyncConfig.userPoolsAuthProvider {
            subscriptionTransport = AWSNetworkTransportCredentialsUpdateDecorator(decorated: reachabilityObserver,
                                                                                  credentialsUpdater: userPool,
                                                                                  logger: logger)
        } else {
           subscriptionTransport = reachabilityObserver
        }
        reachabilityObservers.append(reachabilityObserver)
        reachabilityObservers.append(decoratedCentre)
//        NotificationCenter.default.addObserver(self, selector: #selector(checkForReachability(note:)), name: .reachabilityChanged, object: reachability)
        
        
        reachability!.whenReachable = { [weak self] reachability in
            guard let `self` = self else { return }
            var shouldNotify = false
            if reachability.connection == .wifi {
                shouldNotify = true
            } else {
                if (self.appSyncConfiguration.allowsCellularAccess) {
                    shouldNotify = true
                }
            }
            if shouldNotify {
                for watchers in self.networkStatusWatchers {
                    watchers.onNetworkAvailabilityStatusChanged(isEndpointReachable: shouldNotify, isInitialNotification: self.isInitialNotification)
                }
                if self.isInitialNotification {
                    self.isInitialNotification = false
                }
            }
            
            self.notifyReachabilityObservers(withState: reachability.connection)
        }
        reachability!.whenUnreachable = { [weak self] reachability in
            self?.notifyReachabilityObservers(withState: reachability.connection)
        }
        
        do{
            try self.reachability?.startNotifier()
        } catch {
        }
        
    }
    
    private func notifyReachabilityObservers(withState state: Reachability.Connection) {
        let notify: Bool
        switch state {
        case .none,.wifi: notify = true
        case .cellular: notify = appSyncConfiguration.allowsCellularAccess
        }
        if notify {
            reachabilityObservers.forEach({ $0.hasChanged(to: state) })
        }
    }
    
    /// Fetches a query from the server or from the local cache, depending on the current contents of the cache and the specified cache policy.
    ///
    /// - Parameters:
    ///   - query: The query to fetch.
    ///   - cachePolicy: A cache policy that specifies when results should be fetched from the server and when data should be loaded from the local cache.
    ///   - queue: A dispatch queue on which the result handler will be called. Defaults to the main queue.
    ///   - resultHandler: An optional closure that is called when query results are available or when an error occurs.
    ///   - result: The result of the fetched query, or `nil` if an error occurred.
    ///   - error: An error that indicates why the fetch failed, or `nil` if the fetch was succesful.
    /// - Returns: An object that can be used to cancel an in progress fetch.
    @discardableResult public func fetch<Query: GraphQLQuery>(query: Query, cachePolicy: CachePolicy = .returnCacheDataElseFetch, queue: DispatchQueue = DispatchQueue.main, resultHandler: OperationResultHandler<Query>? = nil) -> Cancellable {
        return apolloClient!.fetch(query: query, cachePolicy: cachePolicy, queue: queue, resultHandler: resultHandler)
    }
    
    /// Fetches a query from the server or from the local cache, depending on the current contents of the cache and the specified cache policy.
    ///
    /// - Parameters:
    ///   - query: The query to fetch.
    ///   - cachePolicy: A cache policy that specifies when results should be fetched from the server and when data should be loaded from the local cache.
    ///   - queue: A dispatch queue on which the result handler will be called. Defaults to the main queue.
    ///   - resultHandler: An optional closure that is called when query results are available or when an error occurs.
    ///   - result: The result of the fetched query, or `nil` if an error occurred.
    ///   - error: An error that indicates why the fetch failed, or `nil` if the fetch was succesful.
    /// - Returns: An object that can be used to cancel an in progress fetch.
    @discardableResult public func fetch<Query: GraphQLQuery, SyncQuery: GraphQLQuery>(query: Query, syncQuery: SyncQuery, cachePolicy: CachePolicy = .returnCacheDataElseFetch, reuseFetchForSync: Bool = false, queue: DispatchQueue = DispatchQueue.main, syncResultHandler: @escaping QuerySyncResultHandler<SyncQuery>, resultHandler: OperationResultHandler<Query>? = nil) -> Cancellable {
        
        let querySyncHandler = AWSAppSyncQuerySyncHandler(httpClient: self.httpTransport!,
                                                          store: self.store!,
                                                          syncQuery: syncQuery,
                                                          handlerQueue: queue,
                                                          syncResultHandler: syncResultHandler)
        let queryOperationCancellable = apolloClient!.fetch(query: query, cachePolicy: cachePolicy, queue: queue, resultHandler: resultHandler)
        
        let querySyncWatcher = AWSAppSyncQuerySyncWatcher(httpClient: self.httpTransport!, store: self.store!, handlerQueue: queue, syncQuery: syncQuery, querySyncHandler: querySyncHandler, reachabilityClient: self.reachability, metadataCache: self.subscriptionMetaDataCache, networkObserverDelegate: self, queryOperationCancellable: queryOperationCancellable)
        querySyncWatcher.logger = logger
        networkStatusWatchers.append(querySyncWatcher)
        
        
        return querySyncWatcher
    }
    
    /// Watches a query by first fetching an initial result from the server or from the local cache, depending on the current contents of the cache and the specified cache policy. After the initial fetch, the returned query watcher object will get notified whenever any of the data the query result depends on changes in the local cache, and calls the result handler again with the new result.
    ///
    /// - Parameters:
    ///   - query: The query to fetch.
    ///   - cachePolicy: A cache policy that specifies when results should be fetched from the server or from the local cache.
    ///   - queue: A dispatch queue on which the result handler will be called. Defaults to the main queue.
    ///   - resultHandler: An optional closure that is called when query results are available or when an error occurs.
    ///   - result: The result of the fetched query, or `nil` if an error occurred.
    ///   - error: An error that indicates why the fetch failed, or `nil` if the fetch was succesful.
    /// - Returns: A query watcher object that can be used to control the watching behavior.
    public func watch<Query: GraphQLQuery>(query: Query, cachePolicy: CachePolicy = .returnCacheDataElseFetch, queue: DispatchQueue = DispatchQueue.main, resultHandler: @escaping OperationResultHandler<Query>) -> GraphQLQueryWatcher<Query> {
        
        return apolloClient!.watch(query: query, cachePolicy: cachePolicy, queue: queue, resultHandler: resultHandler)
    }
    
    public func subscribe<Subscription: GraphQLSubscription>(subscription: Subscription,
                                                             queue: DispatchQueue = DispatchQueue.main,
                                                             refreshTokenRequest: @escaping RefreshTokenRequest = { $0(nil) },
                                                             resultHandler: @escaping SubscriptionResultHandler<Subscription>) throws -> AWSAppSyncSubscriptionWatcher<Subscription>? {
        
        return AWSAppSyncSubscriptionWatcher(client: self.appSyncMQTTClient,
                                              httpClient: self.httpTransport!,
                                              store: self.store!,
                                              subscription: subscription,
                                              handlerQueue: queue,
                                              refreshRequest: refreshTokenRequest,
                                              resultHandler: resultHandler)
    }
    
    
    
    public func subscribe<Subscription: GraphQLSubscription,D>(subscription: Subscription,
                                                             queue: DispatchQueue = DispatchQueue.main,
                                                             refreshTokenRequest: @escaping RefreshTokenRequest = { $0(nil) },
                                                             resultHandler: @escaping (Promise<D?>) -> Void) throws -> ALDOMQTTSubscritionWatcher<Subscription, D>?  where D == Subscription.Data {
        
        let requester = ALDOSubscriptionRequester(httpLevelRequesting: subscriptionTransport)
        let parser = GraphQLDataBasicTransformer(parser: GraphQLBasicParser(cacheKeyForObject: store!.cacheKeyForObject))
        let watcher = ALDOMQTTSubscritionWatcher<Subscription, D>.init(subscription: subscription,
                                                                      requester: requester,
                                                                      parser: parser,
                                                                      logger: logger)
        watcher.subscribe(resultHandler)
        subscriptionCentre.subscribe(watcher: watcher)
        let id = watcher.id
        watcher.setCancellationClosure { [weak self] in
            self?.subscriptionCentre.unsubscribe(watcherWithID: id)
        }
        return watcher
    }
    
    public func syncSubscribe<Subscription: GraphQLSubscription,D, Query: GraphQLQuery, QS>(
        subscription: Subscription,
        syncQuery: Query,
        queue: DispatchQueue = DispatchQueue.main,
        refreshTokenRequest: @escaping RefreshTokenRequest = { $0(nil) },
        syncResultHandler: @escaping (Promise<QS?>) -> Void,
        resultHandler: @escaping (Promise<D?>) -> Void) throws -> Int where D == Subscription.Data, QS == Query.Data {
        
       
        
        let requester = ALDOSubscriptionRequester(httpLevelRequesting: subscriptionTransport)
        
        let operationSender = ALDOGraphQLOperationSender(operationSending: subscriptionTransport,
                                                         cacheKeyForObject: store!.cacheKeyForObject,
                                                         storePublisher: store!)
        
        let timeStampCRUD = ALDOTimestampCRUD(metadataCache: subscriptionMetaDataCache!)
        let operationSenderWithSaving = ALDOGraphQLOperationSenderDecorator(decorated: operationSender,
                                                                            timestampCRUD: timeStampCRUD)
        let parser = GraphQLDataBasicTransformer(parser: GraphQLBasicParser(cacheKeyForObject: store!.cacheKeyForObject))
        let watcher = ALDOMQTTSubscritionWatcher<Subscription, D>.init(subscription: subscription,
                                                                       requester: requester,
                                                                       parser: parser,
                                                                       logger: logger)
        
        let syncWatcher = ALDOSubscritionWatcherWithSync(decorated: watcher,
                                                        querySender: operationSenderWithSaving,
                                                        query: syncQuery,
                                                        logger: logger)
      

        watcher.subscribe(resultHandler)
        syncWatcher.subscribe(syncResultHandler)
        let id = syncWatcher.id
        subscriptionCentre.addObserver(syncWatcher)
        
        syncWatcher.setCancellationClosure {[weak self, weak syncWatcher] in
            guard let syncWatcher = syncWatcher else { return }
            self?.subscriptionCentre.removeObserver(syncWatcher)
            self?.subscriptionCentre.unsubscribe(watcherWithID: id)
        
        }
        subscriptionCentre.subscribe(watcher: syncWatcher)
  
        return id
    }
    
    
    public func subscribeWithSync<Subscription: GraphQLSubscription, Query: GraphQLQuery>(
        subscription: Subscription,
        syncQuery: Query,
        queue: DispatchQueue = DispatchQueue.main,
        refreshTokenRequest: @escaping RefreshTokenRequest = { $0(nil) },
        syncResultHandler: @escaping QuerySyncResultHandler<Query>,
        resultHandler: @escaping SubscriptionResultHandler<Subscription>
        ) throws -> AWSAppSyncSubscriptionWatcher<Subscription>? {
        
        let querySyncHandler = AWSAppSyncQuerySyncHandler(httpClient: self.httpTransport!,
                                                          store: self.store!,
                                                          syncQuery: syncQuery,
                                                          handlerQueue: queue,
                                                          syncResultHandler: syncResultHandler)
        
        let subscriptionWatcher =  AWSAppSyncSubscriptionWatcher(client: self.appSyncMQTTClient,
                                                                 httpClient: self.httpTransport!,
                                                                 store: self.store!,
                                                                 subscription: subscription,
                                                                 handlerQueue: queue,
                                                                 querySyncHandler: querySyncHandler,
                                                                 reachabilityClient: self.reachability,
                                                                 networkObserverDelegate: self,
                                                                 metadataCache: self.subscriptionMetaDataCache,
                                                                 refreshRequest: refreshTokenRequest,
                                                                 resultHandler: resultHandler)
        
        networkStatusWatchers.append(subscriptionWatcher)
        subscriptionWatcher.logger = logger
        return subscriptionWatcher
    }
    
    /// Performs a mutation by sending it to the server.
    ///
    /// - Parameters:
    ///   - mutation: The mutation to perform.
    ///   - queue: A dispatch queue on which the result handler will be called. Defaults to the main queue.
    ///   - optimisticUpdate: An optional closure which gets executed before making the network call, should be used to update local store using the `transaction` object.
    ///   - conflictResolutionBlock: An optional closure that is called when mutation results into a conflict.
    ///   - resultHandler: An optional closure that is called when mutation results are available or when an error occurs.
    ///   - result: The result of the performed mutation, or `nil` if an error occurred.
    ///   - error: An error that indicates why the mutation failed, or `nil` if the mutation was succesful.
    /// - Returns: An object that can be used to cancel an in progress mutation.
    @discardableResult public func perform<Mutation: GraphQLMutation>(mutation: Mutation,
                                                                      queue: DispatchQueue = DispatchQueue.main,
                                                                      optimisticUpdate: OptimisticResponseBlock? = nil,
                                                                      conflictResolutionBlock: MutationConflictHandler<Mutation>? = nil,
                                                                      resultHandler: OperationResultHandler<Mutation>? = nil) -> PerformMutationOperation<Mutation>? {
        if let optimisticUpdate = optimisticUpdate {
            do {
                let _ = try self.store?.withinReadWriteTransaction { transaction in
                    optimisticUpdate(transaction)
                    }.await()
            } catch {
            }
        }
        
        let taskCompletionSource = AWSTaskCompletionSource<Mutation>()
        taskCompletionSource.task.continueWith(block: { (task) -> Any? in
            _ = task.result
            return nil
        })
        
        let serializationFormat = JSONSerializationFormat.self
        let bodyRequest = requestBody(for: mutation)
        let data = try! serializationFormat.serialize(value: bodyRequest)
        let record = AWSAppSyncMutationRecord()
        if let s3Object = self.checkAndFetchS3Object(variables: mutation.variables) {
            record.type = .graphQLMutationWithS3Object
            record.s3ObjectInput =  InternalS3ObjectDetails(bucket: s3Object.bucket,
                                                            key: s3Object.key,
                                                            region: s3Object.region,
                                                            contentType: s3Object.contentType,
                                                            localUri: s3Object.localUri)
        }
        record.data = data
        record.contentMap = mutation.variables
        record.jsonRecord = mutation.variables?.jsonObject
        record.recordState = .inQueue
        record.operationString = Mutation.operationString
        
        return PerformMutationOperation(offlineMutationRecord: record, client: self.apolloClient!, appSyncClient: self, offlineExecutor: self.offlineMutationExecutor!, mutation: mutation, handlerQueue: queue, mutationConflictHandler: conflictResolutionBlock, resultHandler: resultHandler)
    }
    
    private func checkAndFetchS3Object(variables:GraphQLMap?) -> (bucket: String, key: String, region: String, contentType: String, localUri: String)? {
        if let variables = variables {
            for key in variables.keys {
                if let object = variables[key].jsonValue as? Dictionary<String, String> {
                    guard let bucket = object["bucket"] else { return nil }
                    guard let key = object["key"] else { return nil }
                    guard let region = object["region"] else { return nil }
                    guard let contentType = object["mimeType"] else { return nil }
                    guard let localUri = object["localUri"] else { return nil }
                    return (bucket, key, region, contentType, localUri)
                }
            }
        }
        return nil
    }
    
    func onNetworkAvailabilityStatusChanged(isEndpointReachable: Bool, isInitialNotification: Bool) {
        var accessState: ClientNetworkAccessState = .Offline
        if (isEndpointReachable) {
            accessState = .Online
        }
        self.connectionStateChangeHandler?.stateChanged(networkState: accessState)
    }
    
    private func requestBody<Operation: GraphQLOperation>(for operation: Operation) -> GraphQLMap {
        return ["query": type(of: operation).requestString, "variables": operation.variables]
    }
}

protocol InMemoryMutationDelegate {
    func performMutation(dispatchGroup: DispatchGroup)
}

public final class PerformMutationOperation<Mutation: GraphQLMutation>: InMemoryMutationDelegate {
    let client: ApolloClient
    private weak var appSyncClient: AWSAppSyncClient?
    let mutation: Mutation
    let handlerQueue: DispatchQueue
    let mutationConflictHandler: MutationConflictHandler<Mutation>?
    let resultHandler: OperationResultHandler<Mutation>?
    let mutationExecutor: MutationExecutor
    public let mutationRecord: AWSAppSyncMutationRecord
    
    init(offlineMutationRecord: AWSAppSyncMutationRecord, client: ApolloClient, appSyncClient: AWSAppSyncClient, offlineExecutor: MutationExecutor, mutation: Mutation, handlerQueue: DispatchQueue, mutationConflictHandler: MutationConflictHandler<Mutation>?, resultHandler: OperationResultHandler<Mutation>?) {
        self.mutationRecord = offlineMutationRecord
        self.client = client
        self.appSyncClient = appSyncClient
        self.mutationExecutor = offlineExecutor
        self.mutation = mutation
        self.handlerQueue = handlerQueue
        self.resultHandler = resultHandler
        self.mutationConflictHandler = mutationConflictHandler
        // set the deletgate callback to self
        self.mutationRecord.inmemoryExecutor = self
        mutationExecutor.queueMutation(mutation: self.mutationRecord)
    }
    
    func performMutation(dispatchGroup: DispatchGroup) {
        guard let appSyncClient = appSyncClient else { return }
        dispatchGroup.enter()
        if self.mutationRecord.type == .graphQLMutationWithS3Object {
            // call s3mutation object here
            let _ = appSyncClient.performMutationWithS3Object(operation: self.mutation, s3Object: self.mutationRecord.s3ObjectInput!, conflictResolutionBlock: mutationConflictHandler, dispatchGroup: dispatchGroup, handlerQueue: handlerQueue, resultHandler: resultHandler)
        } else {
            let _ = appSyncClient.send(operation: self.mutation, context: nil, conflictResolutionBlock: self.mutationConflictHandler, dispatchGroup: dispatchGroup, handlerQueue: self.handlerQueue, resultHandler: self.resultHandler)
            let _  = dispatchGroup.wait(timeout: DispatchTime(uptimeNanoseconds: 3000000))
        }
    }
}
