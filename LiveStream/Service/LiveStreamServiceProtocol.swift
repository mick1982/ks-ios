import FirebaseDatabase
import ReactiveSwift

public enum LiveApiError: Error {
  case genericFailure
  case invalidEventId
  case invalidJson
}

public protocol LiveStreamServiceProtocol {
  init()

  /// Deletes the database. Call when a connection is no longer needed.
  func deleteDatabase()

  /// Fetches an event with personalization added for the user.
  func fetchEvent(eventId: Int, uid: Int?) -> SignalProducer<LiveStreamEvent, LiveApiError>

  /// Creates a database reference.
  func initializeDatabase(userId: Int?, failed: (Void) -> Void, succeeded: (FIRDatabaseReference) -> Void)

  /// Acquires an anonymous id to be used in the case that a user is not logged-in.
  func signInAnonymously(completion: @escaping (String) -> Void)

  /// Subscribes/unsubscribes a user to an event.
  func subscribeTo(eventId: Int, uid: Int, isSubscribed: Bool) -> SignalProducer<Bool, LiveApiError>
}
