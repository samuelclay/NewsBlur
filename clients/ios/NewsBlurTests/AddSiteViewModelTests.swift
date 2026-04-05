import XCTest

@testable import NewsBlur

@MainActor
final class AddSiteViewModelTests: XCTestCase {
    private final class MockAppEnvironment: AddSiteViewModelAppEnvironment {
        var url: String?
        var dictFoldersArray: Any?

        init(url: String?, folders: [String]) {
            self.url = url
            self.dictFoldersArray = folders
        }
    }

    private final class MockURLProtocol: URLProtocol {
        static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

        override class func canInit(with request: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            guard let handler = Self.requestHandler else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }

            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func test_foldersFiltersSystemFolders() {
        let environment = MockAppEnvironment(
            url: "https://www.newsblur.com",
            folders: ["everything", "saved_stories", "Tech", "Top \u{25B8} iOS"]
        )
        let viewModel = AddSiteViewModel(appEnvironment: environment)

        XCTAssertEqual(viewModel.folders, ["Tech", "Top \u{25B8} iOS"])
        XCTAssertEqual(viewModel.displayFolder, "— Top Level —")
    }

    func test_addSiteMarksSuccessAndBuildsExpectedRequest() async throws {
        let environment = MockAppEnvironment(url: "https://example.com", folders: [])
        let viewModel = AddSiteViewModel(
            appEnvironment: environment,
            session: makeSession()
        )

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/reader/add_url")
            XCTAssertEqual(request.httpMethod, "POST")

            let body = try XCTUnwrap(Self.requestBody(for: request))
            let fields = Self.formFields(from: body)
            XCTAssertEqual(fields["folder"], "Tech")
            XCTAssertEqual(fields["url"], "https://example.com/feed")
            XCTAssertEqual(fields["new_folder"], "Swift")

            let response = try XCTUnwrap(
                HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = try JSONSerialization.data(withJSONObject: ["code": 1])
            return (response, data)
        }

        viewModel.searchText = "https://example.com/feed"
        viewModel.selectedFolder = "Tech"
        viewModel.showAddFolder = true
        viewModel.newFolderName = "Swift"

        viewModel.addSite()

        await waitUntil { viewModel.addedSuccess && !viewModel.isAdding }
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_addSiteSurfacesServerErrors() async {
        let environment = MockAppEnvironment(url: "https://example.com", folders: [])
        let viewModel = AddSiteViewModel(
            appEnvironment: environment,
            session: makeSession()
        )

        MockURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = try JSONSerialization.data(withJSONObject: ["code": -1, "message": "Already subscribed"])
            return (response, data)
        }

        viewModel.searchText = "https://example.com/feed"
        viewModel.addSite()

        await waitUntil { viewModel.errorMessage == "Already subscribed" && !viewModel.isAdding }
        XCTAssertFalse(viewModel.addedSuccess)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func requestBody(for request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while stream.hasBytesAvailable {
            let readCount = stream.read(&buffer, maxLength: bufferSize)
            guard readCount > 0 else { break }
            data.append(buffer, count: readCount)
        }

        return data.isEmpty ? nil : data
    }

    private static func formFields(from body: Data) -> [String: String] {
        let bodyString = String(decoding: body, as: UTF8.self)
        return bodyString
            .split(separator: "&")
            .reduce(into: [:]) { result, pair in
                let components = pair.split(separator: "=", maxSplits: 1).map(String.init)
                guard let key = components.first else { return }
                let value = components.count > 1 ? components[1] : ""
                let decodedValue = value.removingPercentEncoding ?? value
                result[key] = decodedValue
            }
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }

            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for condition")
    }
}
