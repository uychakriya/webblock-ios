import XCTest
final class FlowShot: XCTestCase {
    func waitHittable(_ app: XCUIApplication, _ el: XCUIElement) {
        for _ in 0..<20 {
            if app.buttons["Not Now"].exists { app.buttons["Not Now"].tap() }
            if el.exists && el.isHittable { return }
            sleep(1)
        }
    }
    func testFlow() throws {
        let dir = ProcessInfo.processInfo.environment["SHOTS"]!
        func shot(_ app: XCUIApplication, _ n: String) { try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(n).png")) }
        let app = XCUIApplication(); app.launch()
        let site = app.staticTexts["E2E Final Coffee"]
        waitHittable(app, site); site.tap(); sleep(4)
        let card = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'B sl soy'")).firstMatch
        waitHittable(app, card); card.tap(); sleep(3)
        shot(app, "f-detail")
        app.buttons["Edit product"].firstMatch.tap(); sleep(3)
        shot(app, "f-form")
        app.swipeUp(); sleep(1)
        shot(app, "f-form-bottom")
        app.buttons["Close"].firstMatch.tap(); sleep(2)
        app.buttons["Back"].firstMatch.tap(); sleep(2)
        app.buttons["Monitoring"].firstMatch.tap(); sleep(5)
        app.buttons["Activity"].firstMatch.tap(); sleep(2)
        shot(app, "f-activity")
        app.swipeUp(); sleep(1)
        shot(app, "f-activity-2")
    }
}
