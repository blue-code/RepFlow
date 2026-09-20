import XCTest

/// Fastlane Snapshot 기반 자동 스크린샷 캡처.
/// fastlane screenshots 실행 시 ko/en/ja/zh-Hans 각각 4개 화면 캡처.
///
/// `setupSnapshot`/`snapshot` 은 MainActor 격리된 전역 함수라 Xcode 27 에서는
/// 클래스 전체를 MainActor 로 묶어야 컴파일된다 (UI 테스트는 어차피 메인에서 돈다).
@MainActor
final class RepFlowSnapshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += [
            "UI_TESTING",
            "UI_TESTING_MOCK_DATA",
            "UI_TESTING_SKIP_ONBOARDING",
            "UI_TESTING_PRO"
        ]
        app.launch()
    }

    func testCaptureScreens() {
        // 시뮬레이션 데이터가 로드될 시간
        sleep(2)

        // 1. Dashboard
        snapshot("01_Dashboard")

        // 2. Programs
        if app.tabBars.buttons.count >= 2 {
            app.tabBars.buttons.element(boundBy: 1).tap()
            sleep(1)
            snapshot("02_Programs")
        }

        // 3. History
        if app.tabBars.buttons.count >= 3 {
            app.tabBars.buttons.element(boundBy: 2).tap()
            sleep(1)
            snapshot("03_History")
        }

        // 4. Settings
        if app.tabBars.buttons.count >= 4 {
            app.tabBars.buttons.element(boundBy: 3).tap()
            sleep(1)
            snapshot("04_Settings")
        }
    }
}
