# AWS-Appsync-Aldo


### Diagrams
- [Web sequence](https://www.lucidchart.com/invitations/accept/b60444f2-6543-4d62-9c13-12fdfdc07a5c)
- [Activity diagram for the whole system](https://www.lucidchart.com/invitations/accept/8b91585b-3901-46cd-992a-b5caea1e22c5)
- [Sync watcher decorator](https://www.lucidchart.com/invitations/accept/291451e2-b3b5-47ef-8d1d-fe488cc7c319)


### Modifications:
- Decoupling the logic so it can be testable
- Added the usage of design patterns adapted architecture for the testing and scalability


### What has been fixed:
The main case that we are trying to fix with this update is sustanable websocket connections. If the connection is dropped for any reason, it should be able to reconnect itself. In addition, during network drops (or the app spending time in the background) logic was added to send missing events through calling a query.

Due to degraded or interrupted network conditions, subscriptions might fail at 5 different levels (see below). Logic should exist to be able to recover on those levels.
- Requesting topics/url with a token
- Syncing part
- Establishing a connection
- Cognito Token expiry
- When requesting a new token update


# Known issues:
- `MQTTClient` recognizes status very slow after several network issues. This might be due to a timer that is not updated properly when a connection is established correctly, so the next time if the error occurs it takes less time
- Crash sometimes in `MQTTEncoder` in function `encodeMessage` when trying to release a semaphore 
- As there is no way to cancel the Promise if a syncing process is canceled the Promise will still return the result thus causing the client to receive sync payload several times under certain conditions

# What to improve 
- Redesign `AWSAppSyncHTTPNetworkTransport` to only have one method that is dictated by protocol `NetworkTransport`. All the other modifications/adjustments should be done through decoration. For example, override_map could have been done that way, also `sendSubcriptionRequest`

