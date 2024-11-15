import XCTest
@testable import PeaceWalker

class ProgressManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset ProgressManager before each test
        ProgressManager.shared.setGoal(targetDistance: 0)
    }

    override func tearDown() {
        super.tearDown()
    }

    func testSetGoal() {
        ProgressManager.shared.setGoal(targetDistance: 5000.0)
        XCTAssertEqual(ProgressManager.shared.getTargetDistance(), 5000.0, "Target distance should be set correctly.")
    }

    func testUpdateProgress() {
        ProgressManager.shared.setGoal(targetDistance: 5000.0)
        ProgressManager.shared.updateProgress(stepCount: 1000)
        let currentDistance = ProgressManager.shared.getCurrentDistance()
        XCTAssertGreaterThan(currentDistance, 0, "Current distance should be greater than 0 after updating progress.")
    }

    func testGetCurrentProgress() {
        ProgressManager.shared.setGoal(targetDistance: 1000.0)
        ProgressManager.shared.updateProgress(stepCount: 500)
        let progress = ProgressManager.shared.getCurrentProgress()
        XCTAssertEqual(progress, 0.5, accuracy: 0.01, "Progress should be 50% for halfway distance.")
    }

    func testCalculateStepsLeft() {
        ProgressManager.shared.setGoal(targetDistance: 5000.0)
        ProgressManager.shared.updateProgress(stepCount: 1000)
        let stepsLeft = ProgressManager.shared.calculateStepsLeft()
        XCTAssertGreaterThan(stepsLeft, 0, "Steps left should be greater than 0 after some progress.")
    }

    func testMilestoneCheck() {
        ProgressManager.shared.setGoal(targetDistance: 4000.0)
        ProgressManager.shared.updateProgress(stepCount: 2000)
        let milestones = ProgressManager.shared.checkMilestones()
        XCTAssertTrue(milestones.contains("Milestone reached: 50% completed!"), "Should detect reaching the 50% milestone.")
    }
}
