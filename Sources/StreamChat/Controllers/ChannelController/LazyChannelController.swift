//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import CoreData
import Foundation

// MARK: - Lazy Observer

/// Observes changes of the list of items specified using an `NSFetchRequest`in the provided `NSManagedObjectContext`.
///
/// `ListObserver` is just a wrapper around `NSFetchedResultsController` and `ChangeAggregator`. You can use both of
/// these elements separately, if it better fits your use case.
class LazyListDatabaseObserver<DTO: NSManagedObject> {
    /// The current collection of items matching the provided fetch request. To receive granular updates to this collection,
    /// you can use the `onChange` callback.
    func object(at index: Int) -> DTO? {
        guard index >= 0, index < frc.fetchedObjects?.count ?? 0 else { return nil }
        return frc.object(at: IndexPath(item: index, section: 0))
    }

    func numberOfItems() -> Int {
        frc.fetchedObjects?.count ?? 0
    }

    /// Called with the aggregated changes after the internal `NSFetchResultsController` calls `controllerDidChangeContent`
    /// on its delegate.
    var onChange: (([ErasedChange]) -> Void)? {
        didSet {
            changeAggregator.onChange = { [unowned self] in
                self.onChange?($0)
            }
        }
    }

    /// Acts like the `NSFetchedResultsController`'s delegate and aggregates the reported changes into easily consumable form.
    private(set) lazy var changeAggregator: LazyListChangeAggregator<DTO> = LazyListChangeAggregator()

    /// Used for observing the changes in the DB.
    private(set) var frc: NSFetchedResultsController<DTO>!

    let request: NSFetchRequest<DTO>
    let context: NSManagedObjectContext

    /// When called, release the notification observers
    var releaseNotificationObservers: (() -> Void)?

    /// Creates a new `ListObserver`.
    ///
    /// Please note that no updates are reported until you call `startUpdating`.
    ///
    ///  - Important: ⚠️ Because the observer uses `NSFetchedResultsController` to observe the entity in the DB, it's required
    /// that the provided `fetchRequest` has at lease one `NSSortDescriptor` specified.
    ///
    /// - Parameters:
    ///   - context: The `NSManagedObjectContext` the observer observes.
    ///   - fetchRequest: The `NSFetchRequest` that specifies the elements of the list.
    ///   - itemCreator: A close the observe uses to convert DTO objects into Model objects.
    ///   - fetchedResultsControllerType: The `NSFetchedResultsController` subclass the observe uses to create its FRC. You can
    ///    inject your custom subclass if needed, i.e. when testing.
    init(
        context: NSManagedObjectContext,
        fetchRequest: NSFetchRequest<DTO>,
        fetchedResultsControllerType: NSFetchedResultsController<DTO>.Type = NSFetchedResultsController<DTO>.self
    ) {
        self.context = context
        request = fetchRequest
        frc = fetchedResultsControllerType.init(
            fetchRequest: request,
            managedObjectContext: self.context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        listenForRemoveAllDataNotifications()
    }

    deinit {
        releaseNotificationObservers?()
    }

    /// Starts observing the changes in the database. The current items in the list are synchronously available in the
    /// `item` variable, after this function returns.
    ///
    /// - Throws: An error if the provided fetch request fails.
    func startObserving() throws {
        try frc.performFetch()
        frc.delegate = changeAggregator

        // This is a workaround for the situation when someone wants to observe only the `items` array without
        // listening to changes. We just need to make sure the `didSet` callback of `onChange` is executed at least once.
        if onChange == nil {
            onChange = nil
        }
    }

    /// Listens for `Will/DidRemoveAllData` notifications from the context and simulates the callback when the notifications
    /// are received.
    private func listenForRemoveAllDataNotifications() {
        let notificationCenter = NotificationCenter.default

        // When `WillRemoveAllDataNotification` is received, we need to simulate the callback from change observer, like all
        // existing entities are being removed. At this point, these entities still existing in the context, and it's safe to
        // access and serialize them.
        let willRemoveAllDataNotificationObserver = notificationCenter.addObserver(
            forName: DatabaseContainer.WillRemoveAllDataNotification,
            object: context,
            queue: .main
        ) { [weak self] _ in
            // Technically, this should rather be `unowned`, however, `deinit` is not always called on the main thread which can
            // cause a race condition when the notification observers are not removed at the right time.
            guard let self = self else { return }

            // Simulate ChangeObserver callbacks like all data are being removed
            self.changeAggregator.controllerWillChangeContent(self.frc as! NSFetchedResultsController<NSFetchRequestResult>)

            self.frc.fetchedObjects?.enumerated().forEach { index, item in
                self.changeAggregator.controller(
                    self.frc as! NSFetchedResultsController<NSFetchRequestResult>,
                    didChange: item,
                    at: IndexPath(item: index, section: 0),
                    for: .delete,
                    newIndexPath: nil
                )
            }
        }

        // When `DidRemoveAllDataNotification` is received, we need to reset the FRC. At this point, the entities are removed but
        // the FRC doesn't know about it yet. Resetting the FRC removes the content of `FRC.fetchedObjects`. We also need to
        // call `controllerDidChangeContent` on the change aggregator to finish reporting about the removed object which started
        // in the `WillRemoveAllDataNotification` handler above.
        let didRemoveAllDataNotificationObserver = notificationCenter.addObserver(
            forName: DatabaseContainer.DidRemoveAllDataNotification,
            object: context,
            queue: .main
        ) { [weak self] _ in
            // Technically, this should rather be `unowned`, however, `deinit` is not always called on the main thread which can
            // cause a race condition when the notification observers are not removed at the right time.
            guard let self = self else { return }

            // Reset FRC which causes the current `frc.fetchedObjects` to be reloaded
            try! self.startObserving()

            // Publish the changes started in `WillRemoveAllDataNotification`
            self.changeAggregator.controllerDidChangeContent(self.frc as! NSFetchedResultsController<NSFetchRequestResult>)
        }

        releaseNotificationObservers = { [weak notificationCenter] in
            notificationCenter?.removeObserver(willRemoveAllDataNotificationObserver)
            notificationCenter?.removeObserver(didRemoveAllDataNotificationObserver)
        }
    }
}

/// When this object is set as `NSFetchedResultsControllerDelegate`, it aggregates the callbacks from the fetched results
/// controller and forwards them in the way of `[Change<Item>]`. You can set the `onChange` callback to receive these updates.
class LazyListChangeAggregator<DTO: NSManagedObject>: NSObject, NSFetchedResultsControllerDelegate {
    // TODO: Extend this to also provide `CollectionDifference` and `NSDiffableDataSourceSnapshot`

    /// Called with the aggregated changes after `FetchResultsController` calls controllerDidChangeContent` on its delegate.
    var onChange: (([ErasedChange]) -> Void)?

    /// An array of changes in the current update. It gets reset every time `controllerWillChangeContent` is called, and
    /// published to the observer when `controllerDidChangeContent` is called.
    private var currentChanges: [ErasedChange] = []

    // MARK: - NSFetchedResultsControllerDelegate

    // This should ideally be in the extensions but it's not possible to implement @objc methods in extensions of generic types.

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        currentChanges = []
    }

    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?
    ) {
        switch type {
        case .insert:
            guard let index = newIndexPath else {
                log.warning("Skipping the update from DB because `newIndexPath` is missing for `.insert` change.")
                return
            }
            currentChanges.append(.insert(index))

        case .move:
            guard let fromIndex = indexPath, let toIndex = newIndexPath else {
                log.warning("Skipping the update from DB because `indexPath` or `newIndexPath` are missing for `.move` change.")
                return
            }
            currentChanges.append(.move(from: fromIndex, to: toIndex))

        case .update:
            guard let index = indexPath else {
                log.warning("Skipping the update from DB because `indexPath` is missing for `.update` change.")
                return
            }
            currentChanges.append(.update(index))

        case .delete:
            guard let index = indexPath else {
                log.warning("Skipping the update from DB because `indexPath` is missing for `.delete` change.")
                return
            }
            currentChanges.append(.remove(index))

        default:
            break
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // All destination indices of `move` changes
        let moveToIndexChanges: [IndexPath] = currentChanges.compactMap {
            if case let .move(_, toIndex) = $0 {
                return toIndex
            }
            return nil
        }

        // Remove `update` operations with the same index path as move's `toIndex`changes.
        currentChanges = currentChanges.filter {
            if case let .update(index) = $0 {
                // Include only if the update `index` is not a `move` change destination index.
                return moveToIndexChanges.contains(index) == false
            }
            return true
        }

        onChange?(currentChanges)
    }
}

// MARK: - Lazy controller

public extension _ChatClient {
    /// Creates a new `ChatChannelController` for the channel with the provided id and options.
    ///
    /// - Parameter channelId: The id of the channel this controller represents.
    /// - Parameter options: Query options (See `QueryOptions`)
    ///
    /// - Returns: A new instance of `ChatChannelController`.
    ///
    func lazyChannelController(for cid: ChannelId) -> _LazyChatChannelController<ExtraData> {
        .init(channelQuery: .init(cid: cid), client: self)
    }

    /// Creates a new `ChatChannelController` for the channel with the provided channel query.
    ///
    /// - Parameter channelQuery: The ChannelQuery this controller represents
    ///
    /// - Returns: A new instance of `ChatChannelController`.
    ///
    func lazyChannelController(for channelQuery: _ChannelQuery<ExtraData>) -> _LazyChatChannelController<ExtraData> {
        .init(channelQuery: channelQuery, client: self)
    }

    /// Creates a new `ChatChannelController` that will create a new channel.
    ///
    /// - Parameters:
    ///   - cid: The `ChannelId` for the new channel.
    ///   - name: The new channel name.
    ///   - imageURL: The new channel avatar URL.
    ///   - team: Team for new channel.
    ///   - members: Ds for the new channel members.
    ///   - isCurrentUserMember: If set to `true` the current user will be included into the channel. Is `true` by default.
    ///   - invites: IDs for the new channel invitees.
    ///   - extraData: Extra data for the new channel.
    /// - Throws: `ClientError.CurrentUserDoesNotExist` if there is no currently logged-in user.
    /// - Returns: A new instance of `ChatChannelController`.
    func lazyChannelController(
        createChannelWithId cid: ChannelId,
        name: String?,
        imageURL: URL?,
        team: String? = nil,
        members: Set<UserId> = [],
        isCurrentUserMember: Bool = true,
        invites: Set<UserId> = [],
        extraData: ExtraData.Channel
    ) throws -> _LazyChatChannelController<ExtraData> {
        guard let currentUserId = currentUserId else {
            throw ClientError.CurrentUserDoesNotExist()
        }

        let payload = ChannelEditDetailPayload<ExtraData>(
            cid: cid,
            name: name,
            imageURL: imageURL,
            team: team,
            members: members.union(isCurrentUserMember ? [currentUserId] : []),
            invites: invites,
            extraData: extraData
        )

        return .init(channelQuery: .init(channelPayload: payload), client: self, isChannelAlreadyCreated: false)
    }

    /// Creates a new `ChatChannelController` that will create new a channel with provided members without having to specify
    /// the channel id explicitly.
    ///
    /// This is great for direct message channels because the channel should be uniquely identified by its members.
    ///
    /// - Parameters:
    ///   - members: Members for the new channel. Must not be empty.
    ///   - isCurrentUserMember: If set to `true` the current user will be included into the channel. Is `true` by default.
    ///   - name: The new channel name.
    ///   - imageURL: The new channel avatar URL.
    ///   - team: Team for the new channel.
    ///   - extraData: Extra data for the new channel.
    /// - Throws:
    ///     - `ClientError.ChannelEmptyMembers` if `members` is empty.
    ///     - `ClientError.CurrentUserDoesNotExist` if there is no currently logged-in user.
    /// - Returns: A new instance of `ChatChannelController`.
    func lazyChannelController(
        createDirectMessageChannelWith members: Set<UserId>,
        isCurrentUserMember: Bool = true,
        name: String?,
        imageURL: URL?,
        team: String? = nil,
        extraData: ExtraData.Channel
    ) throws -> _LazyChatChannelController<ExtraData> {
        guard let currentUserId = currentUserId else { throw ClientError.CurrentUserDoesNotExist() }
        guard !members.isEmpty else { throw ClientError.ChannelEmptyMembers() }

        let payload = ChannelEditDetailPayload<ExtraData>(
            type: .messaging,
            name: name,
            imageURL: imageURL,
            team: team,
            members: members.union(isCurrentUserMember ? [currentUserId] : []),
            invites: [],
            extraData: extraData
        )
        return .init(channelQuery: .init(channelPayload: payload), client: self, isChannelAlreadyCreated: false)
    }
}

/// `ChatChannelController` is a controller class which allows mutating and observing changes of a specific chat channel.
///
/// `ChatChannelController` objects are lightweight, and they can be used for both, continuous data change observations (like
/// getting new messages in the channel), and for quick channel mutations (like adding a member to a channel).
///
/// Learn more about `ChatChannelController` and its usage in our [cheat sheet](https://github.com/GetStream/stream-chat-swift/wiki/StreamChat-SDK-Cheat-Sheet#channel).
///
/// - Note: `ChatChannelController` is a typealias of `_LazyChatChannelController` with default extra data. If you're using custom
/// extra data, create your own typealias of `_LazyChatChannelController`.
///
/// Learn more about using custom extra data in our [cheat sheet](https://github.com/GetStream/stream-chat-swift/wiki/StreamChat-SDK-Cheat-Sheet#working-with-extra-data).
///
public typealias LazyChatChannelController = _LazyChatChannelController<NoExtraData>

/// `ChatChannelController` is a controller class which allows mutating and observing changes of a specific chat channel.
///
/// `ChatChannelController` objects are lightweight, and they can be used for both, continuous data change observations (like
/// getting new messages in the channel), and for quick channel mutations (like adding a member to a channel).
///
/// Learn more about `ChatChannelController` and its usage in our [cheat sheet](https://github.com/GetStream/stream-chat-swift/wiki/StreamChat-SDK-Cheat-Sheet#channel).
///
/// - Note: `_LazyChatChannelController` type is not meant to be used directly. If you're using default extra data, use
/// `ChatChannelController` typealias instead. If you're using custom extra data, create your own typealias
/// of `_LazyChatChannelController`.
///
/// Learn more about using custom extra data in our [cheat sheet](https://github.com/GetStream/stream-chat-swift/wiki/StreamChat-SDK-Cheat-Sheet#working-with-extra-data).
///
public class _LazyChatChannelController<ExtraData: ExtraDataTypes>: DataController, DelegateCallable, DataStoreProvider {
    /// The ChannelQuery this controller observes.
    @Atomic public private(set) var channelQuery: _ChannelQuery<ExtraData>

    /// Flag indicating whether channel is created on backend. We need this flag to restrict channel modification requests
    /// before channel is created on backend.
    /// There are 2 ways of creating new channel:
    /// 1. Direct message channel.
    /// In this case before channel creation `cid` on `channelQuery` will be nil cause it will be generated on backend.
    /// 2. Channels with client generated `id`.
    /// In this case `cid` on `channelQuery `will be valid but all channel modifications will
    /// fail because channel with provided `id` will be missing on backend side.
    /// That is why we need to check both flag and valid `cid` before modifications.
    private var isChannelAlreadyCreated: Bool

    /// The identifier of a channel this controller observes.
    /// Will be `nil` when we want to create direct message channel and `id`
    /// is not yet generated by backend.
    public var cid: ChannelId? { channelQuery.cid }

    /// The `ChatClient` instance this controller belongs to.
    public let client: _ChatClient<ExtraData>

    /// The channel the controller represents.
    ///
    /// To observe changes of the channel, set your class as a delegate of this controller or use the provided
    /// `Combine` publishers.
    ///
    public var channel: _ChatChannel<ExtraData>? {
        if state == .initialized {
            setLocalStateBasedOnError(startDatabaseObservers())
        }
        return channelObserver?.item
    }

    public var numberOfItems: Int {
        if state == .initialized {
            setLocalStateBasedOnError(startDatabaseObservers())
        }
        return messagesObserver?.numberOfItems() ?? 0
    }

    public func item(at index: Int) -> _ChatMessage<ExtraData>? {
        guard index < numberOfItems else { return nil }
        return messagesObserver?.object(at: index)?.asModel()
    }

    private var firstItemID: String? {
        messagesObserver?.object(at: 0)?.id
    }

    private var lastItemID: String? {
        messagesObserver?.object(at: numberOfItems - 1)?.id
    }

//    private var messages: [MessageDTO] {
//        if state == .initialized {
//            setLocalStateBasedOnError(startDatabaseObservers())
//        }
//        return messagesObserver?.items ?? []
//    }

    /// Describes the ordering the messages are presented.
    ///
    /// - Important: ⚠️ Changing this value doesn't trigger delegate methods. You should reload your UI manually after changing
    /// the `listOrdering` value to reflect the changes. Further updates to the messages will be delivered using the delegate
    /// methods, as usual.
    ///
    public var listOrdering: ListOrdering = .topToBottom {
        didSet {
            if state != .initialized {
                setLocalStateBasedOnError(startMessagesObserver())
                log.warning(
                    "Changing `listOrdering` will update data inside controller, but you have to update your UI manually "
                        + "to see changes."
                )
            }
        }
    }

    /// The worker used to fetch the remote data and communicate with servers.
    private lazy var updater: ChannelUpdater<ExtraData> = self.environment.channelUpdaterBuilder(
        client.databaseContainer,
        client.apiClient
    )

    private lazy var eventSender: EventSender<ExtraData> = self.environment.eventSenderBuilder(
        client.databaseContainer,
        client.apiClient
    )

    /// A type-erased delegate.
    var multicastDelegate: MulticastDelegate<AnyLazyChannelControllerDelegate<ExtraData>> = .init() {
        didSet {
            stateMulticastDelegate.mainDelegate = multicastDelegate.mainDelegate
            stateMulticastDelegate.additionalDelegates = multicastDelegate.additionalDelegates

            // After setting delegate local changes will be fetched and observed.
            setLocalStateBasedOnError(startDatabaseObservers())
        }
    }

    /// Database observers.
    /// Will be `nil` when observing channel with backend generated `id` is not yet created.
    @Cached private var channelObserver: EntityDatabaseObserver<_ChatChannel<ExtraData>, ChannelDTO>?
    @Cached private var messagesObserver: LazyListDatabaseObserver<MessageDTO>?

    private var eventObservers: [EventObserver] = []
    private let environment: Environment

    /// This callback is called after channel is created on backend but before channel is saved to DB. When channel is created
    /// we receive backend generated cid and setting up current `ChannelController` to observe this channel DB changes.
    /// Completion will be called if DB fetch will fail after setting new `ChannelQuery`.
    private func channelCreated(forwardErrorTo completion: ((_ error: Error?) -> Void)?) -> ((ChannelId) -> Void) {
        return { [weak self] cid in
            guard let self = self else { return }
            self.isChannelAlreadyCreated = true
            completion?(self.set(cid: cid))
        }
    }

    /// Helper for updating state after fetching local data.
    private var setLocalStateBasedOnError: ((_ error: Error?) -> Void) {
        return { [weak self] error in
            // Update observing state
            self?.state = error == nil ? .localDataFetched : .localDataFetchFailed(ClientError(with: error))
        }
    }

    /// Creates a new `ChannelController`
    /// - Parameters:
    ///   - channelQuery: channel query for observing changes
    ///   - client: The `Client` this controller belongs to.
    ///   - environment: Environment for this controller.
    ///   - isChannelAlreadyCreated: Flag indicating whether channel is created on backend.
    init(
        channelQuery: _ChannelQuery<ExtraData>,
        client: _ChatClient<ExtraData>,
        environment: Environment = .init(),
        isChannelAlreadyCreated: Bool = true
    ) {
        self.channelQuery = channelQuery
        self.client = client
        self.environment = environment
        self.isChannelAlreadyCreated = isChannelAlreadyCreated
        super.init()

        setChannelObserver()
        setMessagesObserver()
    }

    private func setChannelObserver() {
        _channelObserver.computeValue = { [unowned self] in
            guard let cid = self.cid else { return nil }
            let observer = EntityDatabaseObserver(
                context: self.client.databaseContainer.viewContext,
                fetchRequest: ChannelDTO.fetchRequest(for: cid),
                itemCreator: { $0.asModel() as _ChatChannel<ExtraData> }
            ).onChange { change in
                self.delegateCallback { $0.channelController(self, didUpdateChannel: change) }
            }
            .onFieldChange(\.currentlyTypingMembers) { change in
                self.delegateCallback {
                    $0.channelController(self, didChangeTypingMembers: change.item)
                }
            }

            return observer
        }
    }

    private func setMessagesObserver() {
        _messagesObserver.computeValue = { [unowned self] in
            guard let cid = self.cid else { return nil }
            let sortAscending = self.listOrdering == .topToBottom ? false : true
            let request = MessageDTO.messagesFetchRequest(for: cid, sortAscending: sortAscending)
            request.fetchBatchSize = 20
            let observer = LazyListDatabaseObserver(
                context: self.client.databaseContainer.viewContext,
                fetchRequest: request
            )
            observer.onChange = { changes in
                self.delegateCallback {
                    $0.channelController(self, didUpdateMessages: changes)
                }
            }

            return observer
        }
    }

    override public func synchronize(_ completion: ((_ error: Error?) -> Void)? = nil) {
        let channelCreatedCallback = isChannelAlreadyCreated ? nil : channelCreated(forwardErrorTo: setLocalStateBasedOnError)
        updater.update(
            channelQuery: channelQuery,
            channelCreatedCallback: channelCreatedCallback
        ) { error in
            self.state = error == nil ? .remoteDataFetched : .remoteDataFetchFailed(ClientError(with: error))
            self.callback { completion?(error) }
        }

        /// Setup event observers if channel is already created on backend side and have a valid `cid`.
        /// Otherwise they will be set up after channel creation.
        if let cid = cid, isChannelAlreadyCreated {
            setupEventObservers(for: cid)
        }
    }

    /// Sets new cid of the query if necessary, and resets event and database observers.
    ///
    /// This should only be called when the controller is initialized with a new channel
    /// (which doesn't exist on backend), and after that channel is created on backend.
    /// If the newly created channel has a different cid than initially thought
    /// (such is the case for direct messages - backend generates custom cid),
    /// this function will set the new cid and reset observers.
    /// If the cid is still the same, this function will only reset the observers
    /// - since we don't need to set a new query in that case.
    /// - Parameter cid: New cid for the channel
    /// - Returns: Error if it occurs while setting up database observers.
    private func set(cid: ChannelId) -> Error? {
        if channelQuery.cid != cid {
            channelQuery = _ChannelQuery(cid: cid, channelQuery: channelQuery)
        }
        setupEventObservers(for: cid)
        return startDatabaseObservers()
    }

    private func startDatabaseObservers() -> Error? {
        startChannelObserver() ?? startMessagesObserver()
    }

    private func startChannelObserver() -> Error? {
        _channelObserver.reset()

        do {
            try channelObserver?.startObserving()
            return nil
        } catch {
            log.error("Failed to perform fetch request with error: \(error). This is an internal error.")
            return ClientError.FetchFailed()
        }
    }

    private func startMessagesObserver() -> Error? {
        _messagesObserver.reset()

        do {
            try messagesObserver?.startObserving()
            return nil
        } catch {
            log.error("Failed to perform fetch request with error: \(error). This is an internal error.")
            return ClientError.FetchFailed()
        }
    }

    private func setupEventObservers(for cid: ChannelId) {
        eventObservers.removeAll()
        // We can't setup event observers in connectionless mode
        guard let webSocketClient = client.webSocketClient else { return }
        let center = webSocketClient.eventNotificationCenter
        eventObservers = [
            MemberEventObserver(notificationCenter: center, cid: cid) { [unowned self] event in
                self.delegateCallback {
                    $0.channelController(self, didReceiveMemberEvent: event)
                }
            }
        ]
    }

    /// Sets the provided object as a delegate of this controller.
    ///
    /// - Note: If you don't use custom extra data types, you can set the delegate directly using `controller.delegate = self`.
    /// Due to the current limits of Swift and the way it handles protocols with associated types, it's required to use this
    /// method to set the delegate, if you're using custom extra data types.
    ///
    /// - Parameter delegate: The object used as a delegate. It's referenced weakly, so you need to keep the object
    /// alive if you want keep receiving updates.
    ///
    public func setDelegate<Delegate: _LazyChatChannelControllerDelegate>(_ delegate: Delegate)
        where Delegate.ExtraData == ExtraData {
        multicastDelegate.mainDelegate = AnyLazyChannelControllerDelegate(delegate)
    }
}

// MARK: - Channel actions

public extension _LazyChatChannelController {
    /// Updated channel with new data.
    ///
    /// - Parameters:
    ///   - team: New team.
    ///   - members: New members.
    ///   - invites: New invites.
    ///   - extraData: New `ExtraData`.
    ///   - completion: The completion. Will be called on a **callbackQueue** when the network request is finished.
    ///                 If request fails, the completion will be called with an error.
    ///
    func updateChannel(
        name: String?,
        imageURL: URL?,
        team: String?,
        members: Set<UserId> = [],
        invites: Set<UserId> = [],
        extraData: ExtraData.Channel,
        completion: ((Error?) -> Void)? = nil
    ) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed(completion)
            return
        }

        let payload: ChannelEditDetailPayload<ExtraData> = .init(
            cid: cid,
            name: name,
            imageURL: imageURL,
            team: team,
            members: members,
            invites: invites,
            extraData: extraData
        )

        updater.updateChannel(channelPayload: payload) { error in
            self.callback {
                completion?(error)
            }
        }
    }

    /// Mutes the channel this controller manages.
    ///
    /// - Parameter completion: The completion. Will be called on a **callbackQueue** when the network request is finished.
    ///                         If request fails, the completion will be called with an error.
    ///
    func muteChannel(completion: ((Error?) -> Void)? = nil) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed(completion)
            return
        }

        updater.muteChannel(cid: cid, mute: true) { error in
            self.callback {
                completion?(error)
            }
        }
    }

    /// Unmutes the channel this controller manages.
    ///
    /// - Parameters:
    ///   - completion: The completion. Will be called on a **callbackQueue** when the network request is finished.
    ///                 If request fails, the completion will be called with an error.
    ///
    func unmuteChannel(completion: ((Error?) -> Void)? = nil) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed(completion)
            return
        }

        updater.muteChannel(cid: cid, mute: false) { error in
            self.callback {
                completion?(error)
            }
        }
    }

    /// Delete the channel this controller manages.
    /// - Parameters:
    ///   - completion: The completion. Will be called on a **callbackQueue** when the network request is finished.
    ///                 If request fails, the completion will be called with an error.
    func deleteChannel(completion: ((Error?) -> Void)? = nil) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed(completion)
            return
        }

        updater.deleteChannel(cid: cid) { error in
            self.callback {
                completion?(error)
            }
        }
    }

    /// Hide the channel this controller manages from queryChannels for the user until a message is added.
    ///
    /// - Parameters:
    ///   - clearHistory: Flag to remove channel history (**false** by default)
    ///   - completion: The completion. Will be called on a **callbackQueue** when the network request is finished.
    ///                 If request fails, the completion will be called with an error.
    ///
    func hideChannel(clearHistory: Bool = false, completion: ((Error?) -> Void)? = nil) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed(completion)
            return
        }

        updater.hideChannel(cid: cid, clearHistory: clearHistory) { error in
            self.callback {
                completion?(error)
            }
        }
    }

    /// Removes hidden status for the channel this controller manages.
    ///
    /// - Parameter completion: The completion. Will be called on a **callbackQueue** when the network request is finished.
    ///                         If request fails, the completion will be called with an error.
    ///
    func showChannel(completion: ((Error?) -> Void)? = nil) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed(completion)
            return
        }

        updater.showChannel(cid: cid) { error in
            self.callback {
                completion?(error)
            }
        }
    }

    /// Loads previous messages from backend.
    ///
    /// - Parameters:
    ///   - messageId: ID of the last fetched message. You will get messages `older` than the provided ID.
    ///   - limit: Limit for page size.
    ///   - completion: The completion. Will be called on a **callbackQueue** when the network request is finished.
    ///                 If request fails, the completion will be called with an error.
    ///
    func loadPreviousMessages(
        before messageId: MessageId? = nil,
        limit: Int = 25,
        completion: ((Error?) -> Void)? = nil
    ) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard cid != nil, isChannelAlreadyCreated else {
            channelModificationFailed(completion)
            return
        }

        guard let messageId = messageId ?? lastItemID else {
            log.error(ClientError.ChannelEmptyMessages().localizedDescription)
            callback { completion?(ClientError.ChannelEmptyMessages()) }
            return
        }

        channelQuery.pagination = MessagesPagination(pageSize: limit, parameter: .lessThan(messageId))

        updater.update(channelQuery: channelQuery, completion: { error in
            self.callback { completion?(error) }
        })
    }

    /// Loads next messages from backend.
    ///
    /// - Parameters:
    ///   - messageId: ID of the current first message. You will get messages `newer` than the provided ID.
    ///   - limit: Limit for page size.
    ///   - completion: The completion. Will be called on a **callbackQueue** when the network request is finished.
    ///                 If request fails, the completion will be called with an error.
    ///
    func loadNextMessages(
        after messageId: MessageId? = nil,
        limit: Int = 25,
        completion: ((Error?) -> Void)? = nil
    ) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard cid != nil, isChannelAlreadyCreated else {
            channelModificationFailed(completion)
            return
        }

        guard let messageId = messageId ?? firstItemID else {
            log.error(ClientError.ChannelEmptyMessages().localizedDescription)
            callback { completion?(ClientError.ChannelEmptyMessages()) }
            return
        }

        channelQuery.pagination = MessagesPagination(pageSize: limit, parameter: .greaterThan(messageId))

        updater.update(channelQuery: channelQuery, completion: { error in
            self.callback { completion?(error) }
        })
    }

    /// Sends the start typing event and schedule a timer to send the stop typing event.
    ///
    /// This method is meant to be called every time the user presses a key. The method will manage requests and timer as needed.
    ///
    /// - Parameter completion: a completion block with an error if the request was failed.
    ///
    func sendKeystrokeEvent(completion: ((Error?) -> Void)? = nil) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed { completion?($0) }
            return
        }

        eventSender.keystroke(in: cid, completion: completion)
    }

    /// Sends the start typing event.
    ///
    /// For the majority of cases, you don't need to call `sendStartTypingEvent` directly. Instead, use `sendKeystrokeEvent`
    /// method and call it every time the user presses a key. The controller will manage
    /// `sendStartTypingEvent`/`sendStopTypingEvent` calls automatically.
    ///
    /// - Parameter completion: a completion block with an error if the request was failed.
    ///
    func sendStartTypingEvent(completion: ((Error?) -> Void)? = nil) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed { completion?($0) }
            return
        }

        eventSender.startTyping(in: cid, completion: completion)
    }

    /// Sends the stop typing event.
    ///
    /// For the majority of cases, you don't need to call `sendStopTypingEvent` directly. Instead, use `sendKeystrokeEvent`
    /// method and call it every time the user presses a key. The controller will manage
    /// `sendStartTypingEvent`/`sendStopTypingEvent` calls automatically.
    ///
    /// - Parameter completion: a completion block with an error if the request was failed.
    ///
    func sendStopTypingEvent(completion: ((Error?) -> Void)? = nil) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed { completion?($0) }
            return
        }

        eventSender.stopTyping(in: cid, completion: completion)
    }

    /// Creates a new message locally and schedules it for send.
    ///
    /// - Parameters:
    ///   - text: Text of the message.
    ///   - extraData: Additional extra data of the message object.
    ///   - attachments: An array of the attachments for the message.
    ///   - quotedMessageId: An id of the message new message quotes. (inline reply)
    ///   - completion: Called when saving the message to the local DB finishes.
    ///
    func createNewMessage(
        text: String,
//        command: String? = nil,
//        arguments: String? = nil,
        attachments: [_ChatMessageAttachment<ExtraData>.Seed] = [],
        quotedMessageId: MessageId? = nil,
        extraData: ExtraData.Message = .defaultValue,
        completion: ((Result<MessageId, Error>) -> Void)? = nil
    ) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed { error in
                completion?(.failure(error ?? ClientError.Unknown()))
            }
            return
        }

        /// Send stop typing event.
        eventSender.stopTyping(in: cid)

        updater.createNewMessage(
            in: cid,
            text: text,
            command: nil,
            arguments: nil,
            attachments: attachments,
            quotedMessageId: quotedMessageId,
            extraData: extraData
        ) { result in
            self.callback {
                completion?(result)
            }
        }
    }

    // It's impossible to perform any channel modification before it's creation on backend.
    // So before any modification attempt we need to check if channel is already created and call this function if not.
    private func channelModificationFailed(_ completion: ((Error?) -> Void)?) {
        let error = ClientError.ChannelNotCreatedYet()
        log.error(error.localizedDescription)
        callback {
            completion?(error)
        }
    }

    /// Add users to the channel as members.
    ///
    /// - Parameters:
    ///   - users: Users Id to add to a channel.
    ///   - completion: The completion. Will be called on a **callbackQueue** when the network request is finished.
    ///                 If request fails, the completion will be called with an error.
    ///
    func addMembers(userIds: Set<UserId>, completion: ((Error?) -> Void)? = nil) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed(completion)
            return
        }

        updater.addMembers(cid: cid, userIds: userIds) { error in
            self.callback {
                completion?(error)
            }
        }
    }

    /// Remove users to the channel as members.
    ///
    /// - Parameters:
    ///   - users: Users Id to add to a channel.
    ///   - completion: The completion. Will be called on a **callbackQueue** when the network request is finished.
    ///                 If request fails, the completion will be called with an error.
    ///
    func removeMembers(userIds: Set<UserId>, completion: ((Error?) -> Void)? = nil) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed(completion)
            return
        }

        updater.removeMembers(cid: cid, userIds: userIds) { error in
            self.callback {
                completion?(error)
            }
        }
    }

    /// Marks the channel as read.
    ///
    /// - Parameter completion: The completion. Will be called on a **callbackQueue** when the network request is finished.
    ///                         If request fails, the completion will be called with an error.
    ///
    func markRead(completion: ((Error?) -> Void)? = nil) {
        /// Perform action only if channel is already created on backend side and have a valid `cid`.
        guard let cid = cid, isChannelAlreadyCreated else {
            channelModificationFailed(completion)
            return
        }
        updater.markRead(cid: cid) { error in
            self.callback {
                completion?(error)
            }
        }
    }
}

extension _LazyChatChannelController {
    struct Environment {
        var channelUpdaterBuilder: (
            _ database: DatabaseContainer,
            _ apiClient: APIClient
        ) -> ChannelUpdater<ExtraData> = ChannelUpdater.init

        var eventSenderBuilder: (
            _ database: DatabaseContainer,
            _ apiClient: APIClient
        ) -> EventSender<ExtraData> = EventSender.init
    }
}

public extension _LazyChatChannelController where ExtraData == NoExtraData {
    /// Set the delegate of `ChannelController` to observe the changes in the system.
    ///
    /// - Note: The delegate can be set directly only if you're **not** using custom extra data types. Due to the current
    /// limits of Swift and the way it handles protocols with associated types, it's required to use `setDelegate` method
    /// instead to set the delegate, if you're using custom extra data types.
    var delegate: LazyChatChannelControllerDelegate? {
        get { multicastDelegate.mainDelegate?.wrappedDelegate as? LazyChatChannelControllerDelegate }
        set { multicastDelegate.mainDelegate = AnyLazyChannelControllerDelegate(newValue) }
    }
}

// MARK: - Delegates

/// `ChatChannelController` uses this protocol to communicate changes to its delegate.
///
/// This protocol can be used only when no custom extra data are specified. If you're using custom extra data types,
/// please use `_LazyChatChannelControllerDelegate` instead.
///
public protocol LazyChatChannelControllerDelegate: DataControllerStateDelegate {
    /// The controller observed a change in the `Channel` entity.
    func lazyChannelController(
        _ channelController: LazyChatChannelController,
        didUpdateChannel channel: EntityChange<ChatChannel>
    )

    /// The controller observed changes in the `Messages` of the observed channel.
    func lazyChannelController(
        _ channelController: LazyChatChannelController,
        didUpdateMessages changes: [ErasedChange]
    )

    /// The controller received a `MemberEvent` related to the channel it observes.
    func lazyChannelController(_ channelController: LazyChatChannelController, didReceiveMemberEvent: MemberEvent)

    /// The controller received a change related to members typing in the channel it observes.
    func lazyChannelController(
        _ channelController: LazyChatChannelController,
        didChangeTypingMembers typingMembers: Set<ChatChannelMember>
    )
}

public extension LazyChatChannelControllerDelegate {
    func lazyChannelController(
        _ channelController: LazyChatChannelController,
        didUpdateChannel channel: EntityChange<ChatChannel>
    ) {}

    func lazyChannelController(
        _ channelController: LazyChatChannelController,
        didUpdateMessages changes: [ErasedChange]
    ) {}

    func lazyChannelController(_ channelController: LazyChatChannelController, didReceiveMemberEvent: MemberEvent) {}

    func lazyChannelController(
        _ channelController: LazyChatChannelController,
        didChangeTypingMembers typingMembers: Set<ChatChannelMember>
    ) {}
}

// MARK: Generic Delegates

/// `ChatChannelController` uses this protocol to communicate changes to its delegate.
///
/// If you're **not** using custom extra data types, you can use a convenience version of this protocol
/// named `ChatChannelControllerDelegate`, which hides the generic types, and make the usage easier.
///
public protocol _LazyChatChannelControllerDelegate: DataControllerStateDelegate {
    associatedtype ExtraData: ExtraDataTypes

    /// The controller observed a change in the `Channel` entity.
    func lazyChannelController(
        _ channelController: _LazyChatChannelController<ExtraData>,
        didUpdateChannel channel: EntityChange<_ChatChannel<ExtraData>>
    )

    /// The controller observed changes in the `Messages` of the observed channel.
    func lazyChannelController(
        _ channelController: _LazyChatChannelController<ExtraData>,
        didUpdateMessages changes: [ErasedChange]
    )

    /// The controller received a `MemberEvent` related to the channel it observes.
    func lazyChannelController(_ channelController: _LazyChatChannelController<ExtraData>, didReceiveMemberEvent: MemberEvent)

    /// The controller received a change related to members typing in the channel it observes.
    func lazyChannelController(
        _ channelController: _LazyChatChannelController<ExtraData>,
        didChangeTypingMembers typingMembers: Set<_ChatChannelMember<ExtraData.User>>
    )
}

public extension _LazyChatChannelControllerDelegate {
    func lazyChannelController(
        _ channelController: _LazyChatChannelController<ExtraData>,
        didUpdateChannel channel: EntityChange<_ChatChannel<ExtraData>>
    ) {}

    func lazyChannelController(
        _ channelController: _LazyChatChannelController<ExtraData>,
        didUpdateMessages changes: [ErasedChange]
    ) {}

    func lazyChannelController(_ channelController: _LazyChatChannelController<ExtraData>, didReceiveMemberEvent: MemberEvent) {}

    func lazyChannelController(
        _ channelController: _LazyChatChannelController<ExtraData>,
        didChangeTypingMembers: Set<_ChatChannelMember<ExtraData.User>>
    ) {}
}

// MARK: Type erased Delegate

class AnyLazyChannelControllerDelegate<ExtraData: ExtraDataTypes>: _LazyChatChannelControllerDelegate {
    private var _controllerDidUpdateMessages: (
        _LazyChatChannelController<ExtraData>,
        [ErasedChange]
    ) -> Void

    private var _controllerDidUpdateChannel: (
        _LazyChatChannelController<ExtraData>,
        EntityChange<_ChatChannel<ExtraData>>
    ) -> Void

    private var _controllerDidChangeState: (DataController, DataController.State) -> Void

    private var _controllerDidReceiveMemberEvent: (
        _LazyChatChannelController<ExtraData>,
        MemberEvent
    ) -> Void

    private var _controllerDidChangeTypingMembers: (
        _LazyChatChannelController<ExtraData>,
        Set<_ChatChannelMember<ExtraData.User>>
    ) -> Void

    weak var wrappedDelegate: AnyObject?

    init(
        wrappedDelegate: AnyObject?,
        controllerDidChangeState: @escaping (DataController, DataController.State) -> Void,
        controllerDidUpdateChannel: @escaping (
            _LazyChatChannelController<ExtraData>,
            EntityChange<_ChatChannel<ExtraData>>
        ) -> Void,
        controllerDidUpdateMessages: @escaping (
            _LazyChatChannelController<ExtraData>,
            [ErasedChange]
        ) -> Void,
        controllerDidReceiveMemberEvent: @escaping (
            _LazyChatChannelController<ExtraData>,
            MemberEvent
        ) -> Void,
        controllerDidChangeTypingMembers: @escaping (
            _LazyChatChannelController<ExtraData>,
            Set<_ChatChannelMember<ExtraData.User>>
        ) -> Void
    ) {
        self.wrappedDelegate = wrappedDelegate
        _controllerDidChangeState = controllerDidChangeState
        _controllerDidUpdateChannel = controllerDidUpdateChannel
        _controllerDidUpdateMessages = controllerDidUpdateMessages
        _controllerDidReceiveMemberEvent = controllerDidReceiveMemberEvent
        _controllerDidChangeTypingMembers = controllerDidChangeTypingMembers
    }

    func controller(_ controller: DataController, didChangeState state: DataController.State) {
        _controllerDidChangeState(controller, state)
    }

    func channelController(
        _ controller: _LazyChatChannelController<ExtraData>,
        didUpdateChannel channel: EntityChange<_ChatChannel<ExtraData>>
    ) {
        _controllerDidUpdateChannel(controller, channel)
    }

    func channelController(
        _ controller: _LazyChatChannelController<ExtraData>,
        didUpdateMessages changes: [ErasedChange]
    ) {
        _controllerDidUpdateMessages(controller, changes)
    }

    func channelController(
        _ controller: _LazyChatChannelController<ExtraData>,
        didReceiveMemberEvent event: MemberEvent
    ) {
        _controllerDidReceiveMemberEvent(controller, event)
    }

    func channelController(
        _ channelController: _LazyChatChannelController<ExtraData>,
        didChangeTypingMembers typingMembers: Set<_ChatChannelMember<ExtraData.User>>
    ) {
        _controllerDidChangeTypingMembers(channelController, typingMembers)
    }
}

extension AnyLazyChannelControllerDelegate {
    convenience init<Delegate: _LazyChatChannelControllerDelegate>(_ delegate: Delegate) where Delegate.ExtraData == ExtraData {
        self.init(
            wrappedDelegate: delegate,
            controllerDidChangeState: { [weak delegate] in delegate?.controller($0, didChangeState: $1) },
            controllerDidUpdateChannel: { [weak delegate] in delegate?.lazyChannelController($0, didUpdateChannel: $1) },
            controllerDidUpdateMessages: { [weak delegate] in delegate?.lazyChannelController($0, didUpdateMessages: $1) },
            controllerDidReceiveMemberEvent: { [weak delegate] in
                delegate?.lazyChannelController($0, didReceiveMemberEvent: $1)
            },
            controllerDidChangeTypingMembers: { [weak delegate] in
                delegate?.lazyChannelController($0, didChangeTypingMembers: $1)
            }
        )
    }
}

extension AnyLazyChannelControllerDelegate where ExtraData == NoExtraData {
    convenience init(_ delegate: LazyChatChannelControllerDelegate?) {
        self.init(
            wrappedDelegate: delegate,
            controllerDidChangeState: { [weak delegate] in delegate?.controller($0, didChangeState: $1) },
            controllerDidUpdateChannel: { [weak delegate] in delegate?.lazyChannelController($0, didUpdateChannel: $1) },
            controllerDidUpdateMessages: { [weak delegate] in delegate?.lazyChannelController($0, didUpdateMessages: $1) },
            controllerDidReceiveMemberEvent: { [weak delegate] in
                delegate?.lazyChannelController($0, didReceiveMemberEvent: $1)
            },
            controllerDidChangeTypingMembers: { [weak delegate] in
                delegate?.lazyChannelController($0, didChangeTypingMembers: $1)
            }
        )
    }
}

public enum ErasedChange: Equatable {
    /// A new item was inserted on the given index path.
    case insert(IndexPath)

    /// An item was moved from `fromIndex` to `toIndex`. Moving an item also automatically mean you should reload its UI.
    case move(from: IndexPath, to: IndexPath)

    /// An item was updated at the given `index`. An `update` change is also automatically generated by moving an item.
    case update(IndexPath)

    /// An item was removed from the given `index`.
    case remove(IndexPath)
}

extension ListChange {
    var erased: ErasedChange {
        switch self {
        case let .insert(_, indexPath):
            return .insert(indexPath)
        case let .move(_, from, to):
            return .move(from: from, to: to)
        case let .update(_, indexPath):
            return .update(indexPath)
        case let .remove(_, indexPath):
            return .remove(indexPath)
        }
    }
}
