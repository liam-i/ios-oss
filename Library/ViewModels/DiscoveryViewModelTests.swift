@testable import KsApi
@testable import Library
import Prelude
import ReactiveExtensions_TestHelpers
import ReactiveSwift
import UIKit
import XCTest

internal final class DiscoveryViewModelTests: TestCase {
  fileprivate let vm: DiscoveryViewModelType = DiscoveryViewModel()

  fileprivate let configureDataSource = TestObserver<[DiscoveryParams.Sort], Never>()
  fileprivate let configureNavigationHeader = TestObserver<DiscoveryParams, Never>()
  fileprivate let loadFilterIntoDataSource = TestObserver<DiscoveryParams, Never>()
  fileprivate let navigateToSort = TestObserver<DiscoveryParams.Sort, Never>()
  fileprivate let navigateDirection = TestObserver<UIPageViewController.NavigationDirection, Never>()
  fileprivate let selectSortPage = TestObserver<DiscoveryParams.Sort, Never>()
  fileprivate let updateSortPagerStyle = TestObserver<Int?, Never>()

  let initialParams = .defaults
    |> DiscoveryParams.lens.includePOTD .~ true

  let categoryParams = .defaults |> DiscoveryParams.lens.category .~ .art
  let subcategoryParams = .defaults |> DiscoveryParams.lens.category .~ .documentary
  let starredParams = .defaults |> DiscoveryParams.lens.starred .~ true

  internal override func setUp() {
    super.setUp()
    self.vm.outputs.loadFilterIntoDataSource.observe(self.loadFilterIntoDataSource.observer)
    self.vm.outputs.configurePagerDataSource.observe(self.configureDataSource.observer)
    self.vm.outputs.navigateToSort.map { $0.0 }.observe(self.navigateToSort.observer)
    self.vm.outputs.navigateToSort.map { $0.1 }.observe(self.navigateDirection.observer)
    self.vm.outputs.selectSortPage.observe(self.selectSortPage.observer)
    self.vm.outputs.updateSortPagerStyle.observe(self.updateSortPagerStyle.observer)
    self.vm.outputs.configureNavigationHeader.observe(self.configureNavigationHeader.observer)
  }

  func testConfigureDataSource() {
    self.configureDataSource.assertValueCount(0, "Data source doesn't configure immediately.")

    self.vm.inputs.viewDidLoad()

    self.configureDataSource.assertValueCount(1, "Data source configures after view loads.")
  }

  func testConfigureDataSourceRemoteConfigConfiguration() {
    withEnvironment(remoteConfigClient: MockRemoteConfigClient()) {
      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(animated: false)
      self.vm.inputs.remoteConfigClientConfigured()

      self.configureDataSource.assertValueCount(1)
    }
  }

  func testConfigureDataSource_RemoteConfigConfiguration_Failed() {
    withEnvironment(remoteConfigClient: nil) {
      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(animated: false)

      self.vm.inputs.remoteConfigClientConfigurationFailed()

      self.configureDataSource.assertValueCount(1)
    }
  }

  func testLoadFilterIntoDataSource() {
    withEnvironment {
      self.loadFilterIntoDataSource.assertValueCount(0)

      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(animated: false)
      self.scheduler.advance()

      self.loadFilterIntoDataSource.assertValues(
        [self.initialParams],
        "Initial params load into data source immediately."
      )

      self.vm.inputs.filter(withParams: self.starredParams)

      self.loadFilterIntoDataSource.assertValues(
        [self.initialParams, self.starredParams],
        "New params load into data source after selecting."
      )
    }
  }

  func testLoadFilterIntoDataSource_RemoteConfigConfiguration() {
    withEnvironment(remoteConfigClient: nil) {
      self.loadFilterIntoDataSource.assertValueCount(0)

      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(animated: false)

      self.loadFilterIntoDataSource.assertDidNotEmitValue("Waits for Remote Config configuration")

      self.vm.inputs.remoteConfigClientConfigured()

      self.scheduler.advance()

      self.loadFilterIntoDataSource.assertValues([self.initialParams])

      self.vm.inputs.filter(withParams: self.starredParams)

      self.loadFilterIntoDataSource.assertValues(
        [self.initialParams, self.starredParams],
        "New params load into data source after selecting."
      )
    }
  }

  func testLoadFilterIntoDataSource_RemoteConfigConfiguration_Failed() {
    withEnvironment(remoteConfigClient: nil) {
      self.loadFilterIntoDataSource.assertValueCount(0)

      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(animated: false)

      self.loadFilterIntoDataSource.assertDidNotEmitValue("Waits for Remote Config configuration")

      self.vm.inputs.remoteConfigClientConfigurationFailed()

      self.scheduler.advance()

      self.loadFilterIntoDataSource.assertValues([self.initialParams], "Proceeds after 3 seconds")

      self.vm.inputs.filter(withParams: self.starredParams)

      self.loadFilterIntoDataSource.assertValues(
        [self.initialParams, self.starredParams],
        "New params load into data source after selecting."
      )
    }
  }

  func testLoadRecommendedProjectsIntoDataSource_UserRecommendationsOptedOut() {
    let user = User.template
      |> \.optedOutOfRecommendations .~ true

    withEnvironment(config: Config.template, currentUser: user) {
      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(animated: false)

      self.scheduler.advance()

      self.configureNavigationHeader.assertValues([initialParams])
    }
  }

  func testLoadRecommendedProjectsIntoDataSource_UserRecommendationsOptedIn() {
    let recsInitialParams = .defaults
      |> DiscoveryParams.lens.includePOTD .~ true
      |> DiscoveryParams.lens.recommended .~ true
      |> DiscoveryParams.lens.backed .~ false

    let user = User.template
      |> \.optedOutOfRecommendations .~ false

    withEnvironment(config: Config.template, currentUser: user) {
      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(animated: false)

      self.scheduler.advance()

      self.configureNavigationHeader.assertValues([recsInitialParams])
    }
  }

  func testLoadRecommendedProjectsIntoDataSource_AfterChangingSetting() {
    let recsInitialParams = .defaults
      |> DiscoveryParams.lens.includePOTD .~ true
      |> DiscoveryParams.lens.recommended .~ true
      |> DiscoveryParams.lens.backed .~ false

    let user = User.template
      |> \.optedOutOfRecommendations .~ false

    let optedOutUser = User.template
      |> \.optedOutOfRecommendations .~ true

    withEnvironment(config: Config.template, currentUser: user) {
      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(animated: false)

      self.scheduler.advance()

      self.configureNavigationHeader.assertValues([recsInitialParams])

      withEnvironment(currentUser: optedOutUser) {
        self.vm.inputs.didChangeRecommendationsSetting()
        self.vm.inputs.viewWillAppear(animated: false)

        self.scheduler.advance()

        self.configureNavigationHeader.assertValues([recsInitialParams, initialParams])
      }
    }
  }

  func testConfigureNavigationHeader() {
    self.configureNavigationHeader.assertValueCount(0)

    self.vm.inputs.viewDidLoad()
    self.vm.inputs.viewWillAppear(animated: false)

    self.scheduler.advance()

    self.configureNavigationHeader.assertValues([self.initialParams])
  }

  func testConfigureNavigationHeader_RemoteConfigConfiguration() {
    withEnvironment(remoteConfigClient: nil) {
      self.configureNavigationHeader.assertValueCount(0)

      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(animated: false)

      self.configureNavigationHeader.assertDidNotEmitValue("Waits for Remote Config configuration")

      self.vm.inputs.remoteConfigClientConfigured()

      self.scheduler.advance()

      self.configureNavigationHeader.assertValues([self.initialParams])

      self.vm.inputs.filter(withParams: self.starredParams)

      self.configureNavigationHeader.assertValues(
        [self.initialParams, self.starredParams],
        "New params load into data source after selecting."
      )
    }
  }

  func testConfigureNavigationHeader_RemoteConfigConfiguration_Failed() {
    withEnvironment(remoteConfigClient: nil) {
      self.configureNavigationHeader.assertValueCount(0)

      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(animated: false)

      self.configureNavigationHeader.assertDidNotEmitValue("Waits for Remote Config configuration")

      self.vm.inputs.remoteConfigClientConfigurationFailed()

      self.scheduler.advance()

      self.configureNavigationHeader.assertValues([self.initialParams], "Proceeds after 3 seconds")

      self.vm.inputs.filter(withParams: self.starredParams)

      self.configureNavigationHeader.assertValues(
        [self.initialParams, self.starredParams],
        "New params load into data source after selecting."
      )
    }
  }

  func testOrdering() {
    let test = TestObserver<String, Never>()
    Signal.merge(
      self.vm.outputs.configurePagerDataSource.mapConst("configureDataSource"),
      self.vm.outputs.loadFilterIntoDataSource.mapConst("loadFilterIntoDataSource")
    ).observe(test.observer)

    self.vm.inputs.viewDidLoad()
    self.vm.inputs.viewWillAppear(animated: false)

    self.scheduler.advance()

    test.assertValues(
      ["configureDataSource", "loadFilterIntoDataSource"],
      "The data source should be configured first, and then the filter changed."
    )
  }

  /**
   Tests the ways in which a user can swipe between sorts and select sorts from the page.
   */
  func testNavigatingSorts() {
    self.vm.inputs.viewDidLoad()

    self.selectSortPage.assertValues([], "Nothing emits at first.")
    self.navigateToSort.assertValues([], "Nothing emits at first.")
    self.navigateDirection.assertValues([], "Nothing emits at first.")

    self.vm.inputs.willTransition(toPage: 1)

    self.selectSortPage.assertValues([], "Nothing emits when a swipe transition starts.")
    self.navigateToSort.assertValues([], "Nothing emits when a swipe transition starts.")
    self.navigateDirection.assertValues([], "Nothing emits when a swipe transition starts.")

    self.vm.inputs.pageTransition(completed: false)

    self.selectSortPage.assertValues([], "Nothing emits when a transition doesn't complete.")
    self.navigateToSort.assertValues([], "Nothing emits when a transition doesn't complete.")
    self.navigateDirection.assertValues([], "Nothing emits when a transition doesn't complete.")

    self.vm.inputs.willTransition(toPage: 1)

    self.selectSortPage.assertValues([], "Nothing emits when a swipe transition starts.")
    self.navigateToSort.assertValues([], "Nothing emits when a swipe transition starts.")
    self.navigateDirection.assertValues([], "Nothing emits when a swipe transition starts.")

    self.vm.inputs.pageTransition(completed: true)

    self.selectSortPage.assertValues([.popular], "Select the popular page in the pager.")
    self.navigateToSort.assertValues([], "Don't navigate to a page.")
    self.navigateDirection.assertValues([], "Don't navigate to a page.")

    self.vm.inputs.willTransition(toPage: 2)
    self.vm.inputs.pageTransition(completed: true)

    self.selectSortPage.assertValues([.popular, .newest], "Select the newest page in the pager.")
    self.navigateToSort.assertValues([], "Navigate to the newest page.")
    self.navigateDirection.assertValues([], "Navigate forward to the page.")

    self.vm.inputs.sortPagerSelected(sort: .magic)

    self.selectSortPage.assertValues([.popular, .newest, .magic], "Select the magic page in the pager.")
    self.navigateToSort.assertValues([.magic], "Navigate to the magic page.")
    self.navigateDirection.assertValues([.reverse], "Navigate backwards to the page.")

    self.vm.inputs.sortPagerSelected(sort: .magic)

    self.selectSortPage.assertValues(
      [.popular, .newest, .magic],
      "Selecting the same page again emits nothing new."
    )
    self.navigateToSort.assertValues(
      [.magic],
      "Selecting the same page again emits nothing new."
    )
    self.navigateDirection.assertValues(
      [.reverse],
      "Selecting the same page again emits nothing new."
    )
  }

  /**
   Tests that events are tracked correctly while swiping sorts and selecting sorts from the page.
   */
  func testSortSwipeEventTracking() {
    self.vm.inputs.viewDidLoad()
    self.vm.inputs.viewWillAppear(animated: true)

    XCTAssertEqual([], self.segmentTrackingClient.events)

    self.vm.inputs.willTransition(toPage: 1)

    XCTAssertEqual(
      [],
      self.segmentTrackingClient.events,
      "No events tracked when starting a swipe transition."
    )

    self.vm.inputs.pageTransition(completed: false)

    XCTAssertEqual(
      [],
      self.segmentTrackingClient.events,
      "No events tracked when the transition did not complete."
    )

    self.vm.inputs.willTransition(toPage: 1)

    XCTAssertEqual(
      [],
      self.segmentTrackingClient.events,
      "Still no events tracked when starting transition."
    )

    self.vm.inputs.pageTransition(completed: true)

    XCTAssertEqual(
      ["CTA Clicked"], self.segmentTrackingClient.events,
      "Swipe event tracked once the transition completes."
    )

    XCTAssertEqual(
      ["popular"], self.segmentTrackingClient.properties(forKey: "context_type"),
      "Correct sort is tracked."
    )

    XCTAssertEqual(
      ["magic"], self.segmentTrackingClient.properties(forKey: "discover_sort"),
      "Correct sort is tracked."
    )

    self.vm.inputs.sortPagerSelected(sort: .newest)

    XCTAssertEqual(
      ["CTA Clicked", "CTA Clicked"],
      self.segmentTrackingClient.events,
      "Event is tracked when a sort is chosen from the pager."
    )

    XCTAssertEqual(
      ["magic", "popular"],
      self.segmentTrackingClient.properties(forKey: "discover_sort"),
      "Correct sort is tracked."
    )

    XCTAssertEqual(
      ["popular", "newest"],
      self.segmentTrackingClient.properties(forKey: "context_type"),
      "Correct sort is tracked."
    )

    self.vm.inputs.sortPagerSelected(sort: .newest)

    XCTAssertEqual(
      ["CTA Clicked", "CTA Clicked"],
      self.segmentTrackingClient.events,
      "Selecting the same sort again does not track another event."
    )

    XCTAssertEqual(
      ["magic", "popular"],
      self.segmentTrackingClient.properties(forKey: "discover_sort")
    )

    XCTAssertEqual(
      ["popular", "newest"],
      self.segmentTrackingClient.properties(forKey: "context_type"),
      "Correct sort is tracked."
    )
  }

  func testUpdateSortPagerStyle() {
    self.vm.inputs.viewDidLoad()

    self.updateSortPagerStyle.assertValueCount(0)

    self.vm.inputs.filter(withParams: self.categoryParams)

    self.updateSortPagerStyle.assertValues([1], "Emits the category id")

    self.vm.inputs.filter(withParams: self.categoryParams)

    self.updateSortPagerStyle.assertValues([1], "Does not emit a repeat value.")

    self.vm.inputs.filter(withParams: self.subcategoryParams)

    self.updateSortPagerStyle.assertValues([1, 30], "Emits root category id.")
  }
}
