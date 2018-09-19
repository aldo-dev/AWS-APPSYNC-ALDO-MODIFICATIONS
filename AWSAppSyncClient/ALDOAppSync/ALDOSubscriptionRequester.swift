//
//  ALDOSubscriptionRequester.swift
//  AWSAppSync
//
//  Created by Alex Hmelevski on 2018-08-07.
//  Copyright © 2018 Dubal, Rohan. All rights reserved.
//

import Foundation
import Dispatch

protocol SubscriptionRequester: class {
    func sendRequest<Operation: GraphQLOperation>(for subscription: Operation) -> Promise<SubscriptionWatcherInfo>
}

protocol SubscriptionResponseParser {
     init(body: JSONObject)
     func parseResult() throws -> AWSGraphQLSubscriptionResponse
}
extension AWSGraphQLSubscriptionResponseParser: SubscriptionResponseParser {}

final class ALDOSubscriptionRequester: SubscriptionRequester, Loggable {

    private let httpLevelRequesting: SubscriptionRequesting
    private let parserType: SubscriptionResponseParser.Type
    init(httpLevelRequesting: SubscriptionRequesting,
         parserType: SubscriptionResponseParser.Type = AWSGraphQLSubscriptionResponseParser.self) {
        self.httpLevelRequesting = httpLevelRequesting
        self.parserType = parserType
    }
    
    func sendRequest<Operation>(for subscription: Operation) -> Promise<SubscriptionWatcherInfo> where Operation : GraphQLOperation {
        return send(for: subscription).map(parserType.init)
                                      .map({ try $0.parseResult() })
                                      .flatMap(self.extractResult)
    }
    
    private func send<Operation>(for subscription: Operation) -> Promise<JSONObject>  where Operation : GraphQLOperation {
        return Promise<JSONObject>.init({ [weak self] (successCompletion, errorCompletion) in
            guard let `self` = self else { return }
            let _ = try self.httpLevelRequesting.sendSubscriptionRequest(operation: subscription,
                                                                         completionHandler: { (json, error) in

                guard let json = json else {
                    errorCompletion(error ?? NSError())
                    return
                }
                successCompletion(json)
            })
        })
    }
    
    
    private func extractResult(from info: AWSGraphQLSubscriptionResponse) -> Promise<SubscriptionWatcherInfo> {
        if let errors = info.errors {
            return Promise(rejected: AppSyncGraphQLErrorsContainer(errors: errors))
        }
        let newInfo = SubscriptionWatcherInfo.init(topics: info.newTopics ?? [], info: info.subscrptionInfo ?? [])
        return Promise(fulfilled: newInfo)
    }

}

