import Foundation
import XCTest

final class Test_WidgetBuildConfiguration: XCTestCase {
    func test_macWidgetsCanFetchStoriesInEveryBuildConfiguration() throws {
        let iosDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let projectURL = iosDirectory.appendingPathComponent("NewsBlur.xcodeproj/project.pbxproj")
        let project = try XCTUnwrap(PropertyListSerialization.propertyList(
            from: Data(contentsOf: projectURL), options: [], format: nil) as? [String: Any])
        let objects = try XCTUnwrap(project["objects"] as? [String: [String: Any]])

        for targetName in ["NewsBlur Widget", "NewsBlur Alpha Widget"] {
            let target = try XCTUnwrap(objects.values.first {
                $0["isa"] as? String == "PBXNativeTarget" && $0["name"] as? String == targetName
            })
            let configurationListID = try XCTUnwrap(target["buildConfigurationList"] as? String)
            let configurationIDs = try XCTUnwrap(
                objects[configurationListID]?["buildConfigurations"] as? [String])
            let configurations = try configurationIDs.map { try XCTUnwrap(objects[$0]) }
            XCTAssertEqual(Set(configurations.compactMap { $0["name"] as? String }), ["Debug", "Release"])

            for configuration in configurations {
                let name = try XCTUnwrap(configuration["name"] as? String)
                let settings = try XCTUnwrap(configuration["buildSettings"] as? [String: Any])
                XCTAssertEqual(settings["ENABLE_OUTGOING_NETWORK_CONNECTIONS"] as? String, "YES",
                               "\(targetName) \(name) needs sandbox network access to fetch stories and images.")
            }
        }
    }
}
