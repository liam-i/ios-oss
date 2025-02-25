import KsApi
import Prelude
import ReactiveExtensions
import ReactiveSwift

public protocol ProjectNotificationCellViewModelInputs {
  /// Call with the initial cell notification value.
  func configureWith(notification: ProjectNotification)

  /// Call when the notification switch is tapped.
  func notificationTapped(on: Bool)
}

public protocol ProjectNotificationCellViewModelOutputs {
  /// Emits the project name.
  var name: Signal<String, Never> { get }

  /// Emits true when the notification is turned on, false otherwise.
  var notificationOn: Signal<Bool, Never> { get }

  /// Emits when an update error has occurred and a message should be displayed.
  var notifyDelegateOfSaveError: Signal<String, Never> { get }
}

public protocol ProjectNotificationCellViewModelType {
  var inputs: ProjectNotificationCellViewModelInputs { get }
  var outputs: ProjectNotificationCellViewModelOutputs { get }
}

public final class ProjectNotificationCellViewModel: ProjectNotificationCellViewModelType,
  ProjectNotificationCellViewModelInputs, ProjectNotificationCellViewModelOutputs {
  public init() {
    let notification = self.notificationProperty.signal.skipNil()
      .map(cached(notification:))

    self.name = notification.map { $0.project.name }

    let toggledNotification: Signal<ProjectNotification, Never> = notification
      .takePairWhen(self.notificationTappedProperty.signal)
      .map { notification, on -> ProjectNotification in
        let n = (notification
          |> ProjectNotification.lens.email .~ on
          |> ProjectNotification.lens.mobile .~ on)

        return n
      }

    let updateEvent = toggledNotification
      .switchMap {
        AppEnvironment.current.apiService.updateProjectNotification($0)
          .ksr_delay(AppEnvironment.current.apiDelayInterval, on: AppEnvironment.current.scheduler)
          .materialize()
      }

    self.notifyDelegateOfSaveError = updateEvent.errors()
      .map { env in
        env.errorMessages.first ?? Strings.profile_settings_error()
      }

    let previousNotificationOnError = notification
      .switchMap {
        .merge(
          SignalProducer(value: $0),
          SignalProducer(toggledNotification.skipRepeats())
        )
      }
      .combinePrevious()
      .takeWhen(self.notifyDelegateOfSaveError)
      .map { previous, _ in previous }

    Signal.merge(updateEvent.values(), previousNotificationOnError)
      .observeValues(cache(notification:))

    self.notificationOn = Signal.merge(
      notification,
      toggledNotification,
      previousNotificationOnError
    )
    .map { $0.email && $0.mobile }
    .skipRepeats()
  }

  fileprivate let notificationProperty = MutableProperty<ProjectNotification?>(nil)
  public func configureWith(notification: ProjectNotification) {
    self.notificationProperty.value = notification
  }

  fileprivate let notificationTappedProperty = MutableProperty(false)
  public func notificationTapped(on: Bool) {
    self.notificationTappedProperty.value = on
  }

  public let name: Signal<String, Never>
  public let notificationOn: Signal<Bool, Never>
  public let notifyDelegateOfSaveError: Signal<String, Never>

  public var inputs: ProjectNotificationCellViewModelInputs { return self }
  public var outputs: ProjectNotificationCellViewModelOutputs { return self }
}

private func cacheKey(forNotification notification: ProjectNotification) -> String {
  return "project_notification_view_model_notification_\(notification.id)"
}

private func cache(notification: ProjectNotification) {
  let key = cacheKey(forNotification: notification)
  AppEnvironment.current.cache[key] = notification.email && notification.mobile
}

private func cached(notification: ProjectNotification) -> ProjectNotification {
  let key = cacheKey(forNotification: notification)
  let on = AppEnvironment.current.cache[key] as? Bool
  return notification
    |> ProjectNotification.lens.email .~ (on ?? notification.email)
    |> ProjectNotification.lens.mobile .~ (on ?? notification.mobile)
}
