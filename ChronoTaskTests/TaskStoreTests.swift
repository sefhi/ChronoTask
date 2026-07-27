import XCTest
@testable import ChronoTask

@MainActor
final class TaskStoreTests: XCTestCase {

    private var defaults: TestSupport.Defaults!
    private var api: MockClickUpAPI!
    private var preferences: AppPreferences!
    private var store: TaskStore!

    override func setUp() async throws {
        try await super.setUp()
        defaults = TestSupport.Defaults()
        api = MockClickUpAPI()
        preferences = AppPreferences(defaults: defaults.store)
        store = TaskStore(api: api, preferences: preferences, ttl: 300)
        store.configure(teamId: "team", userId: 1)
    }

    override func tearDown() async throws {
        defaults.destroy()
        store = nil
        preferences = nil
        api = nil
        defaults = nil
        try await super.tearDown()
    }

    func testLoadFiltersOutIneligibleTasks() async {
        api.tasks = [
            TestSupport.makeTask(id: "1", name: "Abierta"),
            TestSupport.makeTask(id: "2", name: "Cerrada", status: "closed"),
            TestSupport.makeTask(id: "3", name: "Tip", status: "tip")
        ]

        await store.refresh()

        XCTAssertEqual(store.tasks.map(\.id), ["1"])
        XCTAssertEqual(store.rawCount, 3, "rawCount keeps the pre-filter figure")
        XCTAssertEqual(store.phase, .loaded)
    }

    /// The panel opens and closes constantly; without a TTL every open would be a
    /// network round trip.
    func testCacheSuppressesASecondLoadWithinTheTTL() async {
        api.tasks = [TestSupport.makeTask()]

        await store.loadIfStale()
        await store.loadIfStale()

        XCTAssertEqual(api.getTasksCallCount, 1)
    }

    func testRefreshBypassesTheCache() async {
        api.tasks = [TestSupport.makeTask()]

        await store.loadIfStale()
        await store.refresh()

        XCTAssertEqual(api.getTasksCallCount, 2)
    }

    func testExpiredCacheReloads() async {
        let expiring = TaskStore(api: api, preferences: preferences, ttl: 0)
        expiring.configure(teamId: "team", userId: 1)
        api.tasks = [TestSupport.makeTask()]

        await expiring.loadIfStale()
        await expiring.loadIfStale()

        XCTAssertEqual(api.getTasksCallCount, 2)
    }

    func testConcurrentLoadsCoalesceIntoOneRequest() async {
        api.tasks = [TestSupport.makeTask()]

        async let first: Void = store.loadIfStale()
        async let second: Void = store.loadIfStale()
        async let third: Void = store.loadIfStale()
        _ = await (first, second, third)

        XCTAssertEqual(api.getTasksCallCount, 1)
    }

    func testFailureIsReportedWithoutClearingTheCache() async {
        api.tasks = [TestSupport.makeTask(id: "keep")]
        await store.refresh()

        api.tasksError = APIError.networkError("sin red")
        await store.refresh()

        XCTAssertEqual(store.phase, .failed(APIError.networkError("sin red").localizedDescription))
        XCTAssertEqual(store.tasks.map(\.id), ["keep"])
    }

    func testUnauthorizedCallsBackInsteadOfSurfacingAnError() async {
        var loggedOut = false
        store.onUnauthorized = { loggedOut = true }
        api.tasksError = APIError.unauthorized

        await store.refresh()

        XCTAssertTrue(loggedOut)
    }

    // MARK: - Selection

    func testSelectionIsPersisted() {
        let task = TestSupport.makeTask(id: "chosen", name: "Elegida")
        store.selectedTask = task

        XCTAssertEqual(preferences.selectedTaskId, "chosen")
        XCTAssertEqual(preferences.selectedTaskSnapshot?.name, "Elegida")
    }

    /// The snapshot is what lets a cold start render the task name before the network
    /// answers.
    func testSelectionIsRestoredFromTheSnapshot() {
        preferences.setSelectedTask(TestSupport.makeTask(id: "saved", name: "Guardada"))

        let fresh = TaskStore(api: api, preferences: preferences)
        fresh.restoreSelection()

        XCTAssertEqual(fresh.selectedTask?.id, "saved")
        XCTAssertEqual(fresh.selectedTask?.name, "Guardada")
    }

    func testSelectionIsClearedWhenTheTaskIsNoLongerTrackable() async {
        store.selectedTask = TestSupport.makeTask(id: "gone", name: "Desaparecida")
        api.tasks = [TestSupport.makeTask(id: "other", name: "Otra")]

        await store.refresh()

        XCTAssertNil(store.selectedTask)
    }

    func testSelectionIsRepointedAtTheFreshInstance() async {
        store.selectedTask = TestSupport.makeTask(id: "same", name: "Nombre viejo")
        api.tasks = [TestSupport.makeTask(id: "same", name: "Nombre nuevo")]

        await store.refresh()

        XCTAssertEqual(store.selectedTask?.name, "Nombre nuevo")
    }
}
