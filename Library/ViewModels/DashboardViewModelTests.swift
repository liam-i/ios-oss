@testable import KsApi
@testable import Library
import Prelude
import ReactiveExtensions
import ReactiveExtensions_TestHelpers
import ReactiveSwift
import XCTest

internal final class DashboardViewModelTests: TestCase {
  internal let vm: DashboardViewModelType = DashboardViewModel()

  internal let animateOutProjectsDrawer = TestObserver<(), Never>()
  internal let dismissProjectsDrawer = TestObserver<(), Never>()
  internal let focusScreenReaderOnTitleView = TestObserver<(), Never>()
  internal let fundingStats = TestObserver<[ProjectStatsEnvelope.FundingDateStats], Never>()
  internal let goToMessageThread = TestObserver<Project, Never>()
  internal let loaderIsAnimating = TestObserver<Bool, Never>()
  internal let presentProjectsDrawer = TestObserver<[ProjectsDrawerData], Never>()
  internal let project = TestObserver<Project, Never>()
  internal let referrerCumulativeStats = TestObserver<ProjectStatsEnvelope.CumulativeStats, Never>()
  internal let referrerStats = TestObserver<[ProjectStatsEnvelope.ReferrerStats], Never>()
  internal let rewardStats = TestObserver<[ProjectStatsEnvelope.RewardStats], Never>()
  internal let updateTitleViewData = TestObserver<DashboardTitleViewData, Never>()
  internal let videoStats = TestObserver<ProjectStatsEnvelope.VideoStats, Never>()

  let project1 = Project.template
  let project2 = .template |> Project.lens.id .~ 4

  internal override func setUp() {
    super.setUp()
    self.vm.outputs.animateOutProjectsDrawer.observe(self.animateOutProjectsDrawer.observer)
    self.vm.outputs.dismissProjectsDrawer.observe(self.dismissProjectsDrawer.observer)
    self.vm.outputs.focusScreenReaderOnTitleView.observe(self.focusScreenReaderOnTitleView.observer)
    self.vm.outputs.fundingData.map { stats, _ in stats }.observe(self.fundingStats.observer)
    self.vm.outputs.goToMessageThread.map { $0.0 }.observe(self.goToMessageThread.observer)
    self.vm.outputs.loaderIsAnimating.observe(self.loaderIsAnimating.observer)
    self.vm.outputs.presentProjectsDrawer.observe(self.presentProjectsDrawer.observer)
    self.vm.outputs.project.observe(self.project.observer)
    self.vm.outputs.referrerData
      .map { cumulative, _, _, _ in cumulative }
      .observe(self.referrerCumulativeStats.observer)
    self.vm.outputs.referrerData.map { _, _, _, stats in stats }.observe(self.referrerStats.observer)
    self.vm.outputs.rewardData.map { stats, _ in stats }.observe(self.rewardStats.observer)
    self.vm.outputs.videoStats.observe(self.videoStats.observer)
    self.vm.outputs.updateTitleViewData.observe(self.updateTitleViewData.observer)
  }

  func testScreenReaderFocus() {
    let projects = [Project.template]

    let mockApiService = MockService(fetchProjectsResponse: projects)
    withEnvironment(apiService: mockApiService, isVoiceOverRunning: { true }) {
      self.focusScreenReaderOnTitleView.assertValueCount(0)

      self.vm.inputs.viewWillAppear(animated: false)

      self.focusScreenReaderOnTitleView.assertValueCount(1)

      self.vm.inputs.viewWillAppear(animated: false)

      self.focusScreenReaderOnTitleView.assertValueCount(2)
    }
  }

  func testProject() {
    let projects = (0...4).map { .template |> Project.lens.id .~ $0 }
    let titleViewData = DashboardTitleViewData(
      drawerState: DrawerState.closed,
      isArrowHidden: false,
      currentProjectIndex: 0
    )

    withEnvironment(apiService: MockService(fetchProjectsResponse: projects)) {
      self.vm.inputs.viewWillAppear(animated: false)

      self.project.assertValueCount(0)
      self.updateTitleViewData.assertValueCount(0)

      self.scheduler.advance()

      self.project.assertValues([.template |> Project.lens.id .~ 0])
      self.updateTitleViewData.assertValues([titleViewData], "Update title data")

      self.fundingStats.assertValueCount(1)

      let updatedProjects = (0...4).map {
        .template
          |> Project.lens.id .~ $0
          |> Project.lens.name %~ { "\($0)" + " (updated)" }
      }

      withEnvironment(apiService: MockService(fetchProjectsResponse: updatedProjects)) {
        self.vm.inputs.viewWillAppear(animated: false)
        self.scheduler.advance()

        self.project.assertValueCount(2)
        XCTAssertEqual("\(projects[0].name) (updated)", self.project.values.last!.name)

        self.fundingStats.assertValueCount(2)
      }
    }
  }

  func testTitleData_ForOneProject() {
    let projects = [Project.template]
    let titleViewData = DashboardTitleViewData(
      drawerState: DrawerState.closed,
      isArrowHidden: true,
      currentProjectIndex: 0
    )

    withEnvironment(apiService: MockService(fetchProjectsResponse: projects)) {
      self.vm.inputs.viewWillAppear(animated: false)

      self.updateTitleViewData.assertValueCount(0)

      self.scheduler.advance()

      self.updateTitleViewData.assertValues([titleViewData], "Update title data")
    }
  }

  func testLoaderIsAnimating() {
    let projects = (0...4).map { .template |> Project.lens.id .~ $0 }

    withEnvironment(apiService: MockService(fetchProjectsResponse: projects)) {
      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(animated: false)
      self.loaderIsAnimating.assertValues([true])

      self.scheduler.advance()
      self.loaderIsAnimating.assertValues([true, false])
    }
  }

  func testProjectStatsEmit() {
    let projects = [Project.template]
    let projects2 = projects + [.template |> Project.lens.id .~ 5]

    let statsEnvelope = .template
      |> ProjectStatsEnvelope.lens.cumulativeStats .~ .template
      |> ProjectStatsEnvelope.lens.fundingDistribution .~ [.template]
      |> ProjectStatsEnvelope.lens.referralDistribution .~ [.template]
      |> ProjectStatsEnvelope.lens.rewardDistribution .~ [.template, .template]
      |> ProjectStatsEnvelope.lens.videoStats .~ .template

    let statsEnvelope2 = .template
      |> ProjectStatsEnvelope.lens.cumulativeStats .~ .template
      |> ProjectStatsEnvelope.lens.fundingDistribution .~ [.template]
      |> ProjectStatsEnvelope.lens.referralDistribution .~ [.template, .template, .template]
      |> ProjectStatsEnvelope.lens.rewardDistribution .~ [.template]
      |> ProjectStatsEnvelope.lens.videoStats .~ nil

    withEnvironment(apiService: MockService(
      fetchProjectsResponse: projects,
      fetchProjectStatsResponse: statsEnvelope
    )) {
      self.vm.inputs.viewWillAppear(animated: false)

      self.videoStats.assertValueCount(0)
      self.fundingStats.assertValueCount(0)
      self.referrerCumulativeStats.assertValueCount(0)
      self.referrerStats.assertValueCount(0)
      self.rewardStats.assertValueCount(0)

      self.scheduler.advance()

      self.fundingStats.assertValues([[.template]], "Funding stats emitted.")
      self.referrerCumulativeStats.assertValues([.template], "Cumulative stats emitted.")
      self.referrerStats.assertValues([[.template]], "Referrer stats emitted.")
      self.rewardStats.assertValues([[.template, .template]], "Reward stats emitted.")
      self.videoStats.assertValues([.template], "Video stats emitted.")

      withEnvironment(apiService: MockService(
        fetchProjectsResponse: projects2,
        fetchProjectStatsResponse: statsEnvelope2
      )) {
        self.vm.inputs.viewWillAppear(animated: false)
        self.scheduler.advance()

        self.fundingStats.assertValues([[.template], [.template]], "Funding stats emitted.")
        self.referrerCumulativeStats.assertValues([.template, .template], "Cumulative stats emitted.")
        self.referrerStats.assertValues(
          [[.template], [.template, .template, .template]],
          "Referrer stats emitted."
        )
        self.rewardStats.assertValues([[.template, .template], [.template]], "Reward stats emitted.")
        self.videoStats.assertValues([.template], "Video stats does not emit")
      }
    }
  }

  func testDeepLink() {
    let projects = (0...4).map { .template |> Project.lens.id .~ $0 }

    withEnvironment(apiService: MockService(fetchProjectsResponse: projects)) {
      self.vm.inputs.switch(toProject: .id(projects.last!.id))
      self.vm.inputs.viewWillAppear(animated: false)
      self.scheduler.advance()

      self.project.assertValues([projects.last!])
    }
  }

  func testGoToThread() {
    let projects = (0...4).map { .template |> Project.lens.id .~ $0 }
    let thread = MessageThread.template

    let threadProj = projects[1]

    withEnvironment(apiService: MockService(fetchProjectsResponse: projects)) {
      self.project.assertValues([])

      self.vm.inputs.messageThreadNavigated(projectId: .id(threadProj.id), messageThread: thread)
      self.project.assertValues([])

      self.vm.inputs.viewWillAppear(animated: false)
      self.scheduler.advance()

      self.goToMessageThread.assertValues([threadProj], "Go to message thread emitted")
      self.project.assertValues([threadProj], "Thread project is selected")

      self.vm.inputs.viewWillDisappear()
      self.scheduler.advance()

      self.vm.inputs.viewWillAppear(animated: false)
      self.scheduler.advance()

      self.goToMessageThread.assertValues(
        [threadProj],
        "Go to message thread not emitted again when view appears"
      )

      self.project.assertValues(
        [threadProj, threadProj],
        "Keep previously selected project when view Appears"
      )
    }
  }

  func testProjectsDrawer_OpenClose() {
    let project1 = Project.template
    let project2 = .template |> Project.lens.id .~ 4
    let projects = [project1, project2]
    let projectData1 = ProjectsDrawerData(project: project1, indexNum: 0, isChecked: true)
    let projectData2 = ProjectsDrawerData(project: project2, indexNum: 1, isChecked: false)

    let titleViewDataClosed1 = DashboardTitleViewData(
      drawerState: DrawerState.closed,
      isArrowHidden: false,
      currentProjectIndex: 0
    )

    let titleViewDataOpen1 = DashboardTitleViewData(
      drawerState: DrawerState.open,
      isArrowHidden: false,
      currentProjectIndex: 0
    )

    let titleViewDataClosed2 = DashboardTitleViewData(
      drawerState: DrawerState.closed,
      isArrowHidden: false,
      currentProjectIndex: 1
    )

    let titleViewDataOpen2 = DashboardTitleViewData(
      drawerState: DrawerState.open,
      isArrowHidden: false,
      currentProjectIndex: 1
    )

    withEnvironment(apiService: MockService(fetchProjectsResponse: projects)) {
      self.vm.inputs.viewWillAppear(animated: false)
      self.scheduler.advance()

      self.updateTitleViewData.assertValues([titleViewDataClosed1], "Update title with closed data")

      self.vm.inputs.showHideProjectsDrawer()

      self.updateTitleViewData.assertValues(
        [titleViewDataClosed1, titleViewDataOpen1],
        "Update title with open data"
      )
      self.presentProjectsDrawer.assertValues([[projectData1, projectData2]])
      self.dismissProjectsDrawer.assertValueCount(0)
      self.animateOutProjectsDrawer.assertValueCount(0)

      self.vm.inputs.showHideProjectsDrawer()

      self.updateTitleViewData.assertValues(
        [titleViewDataClosed1, titleViewDataOpen1, titleViewDataClosed1],
        "Update title with closed data"
      )
      self.animateOutProjectsDrawer.assertValueCount(1)
      self.dismissProjectsDrawer.assertValueCount(0)

      self.vm.inputs.dashboardProjectsDrawerDidAnimateOut()

      self.dismissProjectsDrawer.assertValueCount(1)

      self.vm.inputs.showHideProjectsDrawer()

      self.updateTitleViewData.assertValues([
        titleViewDataClosed1, titleViewDataOpen1, titleViewDataClosed1,
        titleViewDataOpen1
      ], "Update title with open data")
      self.presentProjectsDrawer.assertValues([[projectData1, projectData2], [projectData1, projectData2]])

      self.vm.inputs.switch(toProject: .id(project2.id))

      self.updateTitleViewData.assertValues([
        titleViewDataClosed1, titleViewDataOpen1, titleViewDataClosed1,
        titleViewDataOpen1, titleViewDataClosed2
      ], "Update title with closed data")
      self.animateOutProjectsDrawer.assertValueCount(2, "Animate out drawer emits")
      self.dismissProjectsDrawer.assertValueCount(1, "Dismiss drawer does not emit")

      self.vm.inputs.dashboardProjectsDrawerDidAnimateOut()

      self.dismissProjectsDrawer.assertValueCount(2)

      self.vm.inputs.showHideProjectsDrawer()

      self.updateTitleViewData.assertValues([
        titleViewDataClosed1, titleViewDataOpen1, titleViewDataClosed1,
        titleViewDataOpen1, titleViewDataClosed2, titleViewDataOpen2
      ], "Update title with open data")
      self.presentProjectsDrawer.assertValues([
        [projectData1, projectData2], [projectData1, projectData2],
        [projectData1, projectData2]
      ])
      self.animateOutProjectsDrawer.assertValueCount(2, "Animate out drawer emits")
      self.dismissProjectsDrawer.assertValueCount(2, "Dismiss drawer does not emit")

      self.vm.inputs.showHideProjectsDrawer()
    }
  }

  func testTrackingEvents_CreatorDashboardViewed() {
    let projects = (0...4).map { .template |> Project.lens.id .~ $0 }

    withEnvironment(apiService: MockService(fetchProjectsResponse: projects)) {
      XCTAssertEqual([], self.segmentTrackingClient.events)

      self.vm.inputs.viewWillAppear(animated: false)

      XCTAssertEqual(["Page Viewed"], self.segmentTrackingClient.events)

      self.vm.inputs.viewWillDisappear()

      XCTAssertEqual(["Page Viewed"], self.segmentTrackingClient.events)

      self.vm.inputs.viewWillAppear(animated: false)

      XCTAssertEqual(["Page Viewed", "Page Viewed"], self.segmentTrackingClient.events)
    }
  }

  func testTrackingEvents_CreatorDashboardSwitchProjectClicked() {
    let project1 = Project.template
    let project2 = .template |> Project.lens.id .~ 4
    let projects = [project1, project2]

    withEnvironment(apiService: MockService(fetchProjectsResponse: projects)) {
      XCTAssertEqual([], self.segmentTrackingClient.events)

      self.vm.inputs.viewWillAppear(animated: false)

      self.scheduler.advance()

      self.project.assertValues([project1])
      XCTAssertEqual(["Page Viewed"], self.segmentTrackingClient.events)

      self.vm.inputs.switch(toProject: .id(project2.id))

      self.project.assertValues([project1, project2])
      XCTAssertEqual(["Page Viewed", "CTA Clicked"], self.segmentTrackingClient.events)

      self.vm.inputs.switch(toProject: .id(project1.id))

      self.project
        .assertValues([project1, project2, project1])
      XCTAssertEqual(["Page Viewed", "CTA Clicked", "CTA Clicked"], self.segmentTrackingClient.events)
    }
  }

  func testTrackingEvents_CreatorDashboardPostUpdateClicked() {
    withEnvironment(apiService: MockService(fetchProjectsResponse: [Project.template])) {
      XCTAssertEqual([], self.segmentTrackingClient.events)

      self.vm.inputs.viewWillAppear(animated: false)

      self.scheduler.advance()

      XCTAssertEqual(["Page Viewed"], self.segmentTrackingClient.events)

      self.vm.inputs.trackPostUpdateClicked()

      XCTAssertEqual(["Page Viewed", "CTA Clicked"], self.segmentTrackingClient.events)
    }
  }
}
