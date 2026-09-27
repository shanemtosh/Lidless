import XCTest

final class ClientRequirementTests: XCTestCase {

    // MARK: ClientRequirement.appBundleID(fromHelperLabel:)

    func testAppBundleIDFromReleaseLabel() {
        XCTAssertEqual(
            ClientRequirement.appBundleID(fromHelperLabel: "com.nghialuong.lidless.helper"),
            "com.nghialuong.lidless"
        )
    }

    func testAppBundleIDFromDevLabel() {
        XCTAssertEqual(
            ClientRequirement.appBundleID(fromHelperLabel: "com.nghialuong.lidless.dev.helper"),
            "com.nghialuong.lidless.dev"
        )
    }

    /// Round-trips against the label builder the app side uses, so the two can't
    /// drift apart silently.
    func testAppBundleIDInvertsLabelBuilder() {
        let appID = "com.example.lidless"
        let label = LidlessHelper.label(appBundleID: appID)
        XCTAssertEqual(ClientRequirement.appBundleID(fromHelperLabel: label), appID)
    }

    func testAppBundleIDRejectsNonHelperLabel() {
        XCTAssertNil(ClientRequirement.appBundleID(fromHelperLabel: "com.nghialuong.lidless"))
    }

    func testAppBundleIDRejectsBareSuffix() {
        XCTAssertNil(ClientRequirement.appBundleID(fromHelperLabel: ".helper"))
    }

    func testAppBundleIDRejectsEmpty() {
        XCTAssertNil(ClientRequirement.appBundleID(fromHelperLabel: ""))
    }

    // MARK: ClientRequirement.requirement

    func testRequirementShape() {
        XCTAssertEqual(
            ClientRequirement.requirement(appBundleID: "com.nghialuong.lidless", teamID: "TAFDRXJZSR"),
            "anchor apple generic and identifier \"com.nghialuong.lidless\" "
            + "and certificate leaf[subject.OU] = \"TAFDRXJZSR\""
        )
    }

    /// A fork signed by a different team gets a requirement naming *its* team, so
    /// nothing has to be edited by hand downstream.
    func testRequirementUsesSuppliedTeam() {
        let req = ClientRequirement.requirement(appBundleID: "com.example.lidless", teamID: "ABCDE12345")
        XCTAssertEqual(req?.contains("\"ABCDE12345\""), true)
        XCTAssertEqual(req?.contains("TAFDRXJZSR"), false)
    }

    // MARK: Injection

    /// A quote in either component would otherwise terminate the string literal
    /// and change what the requirement expression means.
    func testRequirementRejectsQuoteInBundleID() {
        XCTAssertNil(ClientRequirement.requirement(
            appBundleID: "com.evil\" or anchor apple generic and identifier \"x",
            teamID: "TAFDRXJZSR"
        ))
    }

    func testRequirementRejectsQuoteInTeamID() {
        XCTAssertNil(ClientRequirement.requirement(
            appBundleID: "com.nghialuong.lidless",
            teamID: "AAAA\" or anchor apple generic"
        ))
    }

    func testRequirementRejectsEmptyComponents() {
        XCTAssertNil(ClientRequirement.requirement(appBundleID: "", teamID: "TAFDRXJZSR"))
        XCTAssertNil(ClientRequirement.requirement(appBundleID: "com.nghialuong.lidless", teamID: ""))
    }

    func testSafeIdentifierAcceptsNormalIDs() {
        XCTAssertTrue(ClientRequirement.isSafeIdentifier("com.nghialuong.lidless.dev"))
        XCTAssertTrue(ClientRequirement.isSafeIdentifier("TAFDRXJZSR"))
        XCTAssertTrue(ClientRequirement.isSafeIdentifier("com.example.my-app"))
    }

    func testSafeIdentifierRejectsWhitespaceAndEscapes() {
        XCTAssertFalse(ClientRequirement.isSafeIdentifier("com.example app"))
        XCTAssertFalse(ClientRequirement.isSafeIdentifier("com.example\\lidless"))
        XCTAssertFalse(ClientRequirement.isSafeIdentifier("com.example\nlidless"))
    }
}
