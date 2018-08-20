# AWS-Appsync-Aldo


### Diagrams
- [Web sequence](https://www.lucidchart.com/invitations/accept/b60444f2-6543-4d62-9c13-12fdfdc07a5c)
- [Activity diagram for the whole system](https://www.lucidchart.com/invitations/accept/8b91585b-3901-46cd-992a-b5caea1e22c5)
- [Sync watcher decorator](https://www.lucidchart.com/invitations/accept/291451e2-b3b5-47ef-8d1d-fe488cc7c319)


### Modifications:
- Decoupling the logic so it can be testable
- Throught the usage of design patterns adapted architecture for the testing and scalability


### What has been fixed:
The main case that we are trying to fix with this update is sustanable websocket connection. If the connection is dropped for any reasons it should be able to reconnect itself. In addition if during the network drop(or app spend time in the background) the logic should send missing events that is made through calling a query.

The main challenge ist that due to the network conditions subscription might fail 5 different levels(see below), so the logic should be able to recover on those levels
- Requesting topics/url with token
- Syncing part
- Establishing connection
- when Cognito Token is expired
- when requesting new token update


# Known issues:
- `MQTTClient` recognizes status very slow after several network issues. Might be a timer that is not updates correctly when a connetion is established correctly, so the next time if the error occurs it takes less time
- Crash sometimes in `MQTTEncoder` in function `encodeMessage` when trying to release a semaphore 
- As there is no way to cancel the Promise if a syncing process is canceled the promise will still return the result thus causing the client to receive sync payload several times under certain conditions

# What to improve 
- I'd redesign `AWSAppSyncHTTPNetworkTransport` to have only one method that is dictated by protocol `NetworkTransport`. All the rest modifications/adjustment should be done through decoration. For example override_map could have been done that way, the same thing for `sendSubcriptionRequest`
