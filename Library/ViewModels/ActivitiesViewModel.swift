import KsApi
import Prelude
import ReactiveCocoa
import ReactiveExtensions
import Result

public protocol ActitiviesViewModelInputs {
  func activityUpdateCellTappedProjectImage(activity activity: Activity)

  /// Call when the login button is pressed in the logged-out empty state.
  func loginButtonPressed()

  /// Call when the feed should be refreshed, e.g. pull-to-refresh.
  func refresh()

  /// Call when an activity is tapped.
  func tappedActivity(activity: Activity)

  /// Call when a user session ends
  func userSessionEnded()

  /// Call when a user session has started
  func userSessionStarted()

  /// Call when the view appears.
  func viewWillAppear()

  /**
   Call from the controller's `tableView:willDisplayCell:forRowAtIndexPath` method.

   - parameter row:       The 0-based index of the row displaying.
   - parameter totalRows: The total number of rows in the table view.
   */
  func willDisplayRow(row: Int, outOf totalRows: Int)
}

public protocol ActivitiesViewModelOutputs {
  /// Emits an array of activities that should be displayed
  var activities: Signal<[Activity], NoError> { get }

  /// Emits a project and ref tag that should be used to present a project controller.
  var goToProject: Signal<(Project, RefTag), NoError> { get }

  /// Emits a boolean that indicates if the activities are refreshing.
  var isRefreshing: Signal<Bool, NoError> { get }

  /// Emits `true` when the logged-in empty state should be shown, and `false` when it should be hidden.
  var showLoggedInEmptyState: Signal<Bool, NoError> { get }

  /// Emits `true` when the logged-out empty state should be shown, and `false` when it should be hidden.
  var showLoggedOutEmptyState: Signal<Bool, NoError> { get }
}

public protocol ActivitiesViewModelType {
  var inputs: ActitiviesViewModelInputs { get }
  var outputs: ActivitiesViewModelOutputs { get }
}

public final class ActivitiesViewModel: ActivitiesViewModelType, ActitiviesViewModelInputs,
ActivitiesViewModelOutputs {
  typealias Model = Activity

  // swiftlint:disable function_body_length
  public init() {
    let isCloseToBottom = self.willDisplayRowProperty.signal.ignoreNil()
      .map { row, total in row >= total - 3 }
      .skipRepeats()
      .filter(isTrue)
      .ignoreValues()

    let requestFirstPage = Signal.merge(
      self.viewWillAppearProperty.signal.take(1),
      self.userSessionStartedProperty.signal,
      self.refreshProperty.signal
      )
      .filter { AppEnvironment.current.apiService.isAuthenticated }

    let activities: Signal<[Activity], NoError>
    let isLoading: Signal<Bool, NoError>
    (activities, isLoading, _) = paginate(
      requestFirstPageWith: requestFirstPage,
      requestNextPageWhen: isCloseToBottom,
      clearOnNewRequest: false,
      valuesFromEnvelope: { $0.activities },
      cursorFromEnvelope: { $0.urls.api.moreActivities },
      requestFromParams: { _ in AppEnvironment.current.apiService.fetchActivities() },
      requestFromCursor: { AppEnvironment.current.apiService.fetchActivities(paginationUrl: $0) })

    self.isRefreshing = isLoading

    let clearedActivitiesOnSessionEnd = self.userSessionEndedProperty.signal.mapConst([Activity]())

    self.activities = combineLatest(
        self.viewWillAppearProperty.signal.take(1),
        Signal.merge(activities, clearedActivitiesOnSessionEnd)
      )
      .map { _, activities in activities }

    let noActivities = self.activities.filter { $0.isEmpty }

    let isLoggedIn = Signal.merge([
      self.viewWillAppearProperty.signal,
      self.userSessionStartedProperty.signal,
      self.userSessionEndedProperty.signal
      ])
      .map { AppEnvironment.current.apiService.isAuthenticated }
      .skipRepeats(==)

    self.showLoggedInEmptyState = isLoggedIn
      .takeWhen(noActivities)
      .skipRepeats()

    self.showLoggedOutEmptyState = isLoggedIn
      .map(negate)
      .skipWhile(isFalse)
      .skipRepeats()

    self.goToProject = Signal.merge(
      self.tappedActivityProjectImage.signal.map { $0?.project },
      self.tappedActivityProperty.signal.map { $0?.project }
      )
      .ignoreNil()
      .map { ($0, RefTag.activity) }

    self.viewWillAppearProperty.signal
      .observeNext { AppEnvironment.current.koala.trackActivities() }
  }
  // swiftlint:enable function_body_length

  private let viewWillAppearProperty = MutableProperty(())
  public func viewWillAppear() {
    self.viewWillAppearProperty.value = ()
  }
  private let loginButtonPressedProperty = MutableProperty(())
  public func loginButtonPressed() {
    self.loginButtonPressedProperty.value = ()
  }
  private let userSessionStartedProperty = MutableProperty(())
  public func userSessionStarted() {
    self.userSessionStartedProperty.value = ()
  }
  private let userSessionEndedProperty = MutableProperty(())
  public func userSessionEnded() {
    self.userSessionEndedProperty.value = ()
  }
  private let refreshProperty = MutableProperty()
  public func refresh() {
    self.refreshProperty.value = ()
  }
  private let willDisplayRowProperty = MutableProperty<(row: Int, total: Int)?>(nil)
  public func willDisplayRow(row: Int, outOf totalRows: Int) {
    self.willDisplayRowProperty.value = (row, totalRows)
  }
  private let tappedActivityProjectImage = MutableProperty<Activity?>(nil)
  public func activityUpdateCellTappedProjectImage(activity activity: Activity) {
    self.tappedActivityProjectImage.value = activity
  }
  private let tappedActivityProperty = MutableProperty<Activity?>(nil)
  public func tappedActivity(activity: Activity) {
    self.tappedActivityProperty.value = activity
  }

  public let activities: Signal<[Activity], NoError>
  public let showLoggedInEmptyState: Signal<Bool, NoError>
  public let showLoggedOutEmptyState: Signal<Bool, NoError>
  public let isRefreshing: Signal<Bool, NoError>
  public let goToProject: Signal<(Project, RefTag), NoError>

  public var inputs: ActitiviesViewModelInputs { return self }
  public var outputs: ActivitiesViewModelOutputs { return self }
}