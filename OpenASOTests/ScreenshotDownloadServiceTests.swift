import Foundation
import Testing
@testable import OpenASO

struct ScreenshotDownloadServiceTests {
    @Test
    func downloadsScreenshotsAndContinuesAfterIndividualFailures() async throws {
        let service = ScreenshotDownloadService { url in
            if url.absoluteString.contains("failure") {
                throw URLError(.badServerResponse)
            }

            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/png"]
            ))
            return (Data("screenshot".utf8), response)
        }
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenASO-ScreenshotDownloadServiceTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let progressRecorder = ScreenshotDownloadProgressRecorder()
        let result = await service.download(
            jobs: [
                ScreenshotDownloadJob(
                    id: "success",
                    urlString: "https://example.com/success",
                    relativeDirectoryComponents: ["01 - Calm: Sleep", "iphone"],
                    filenameStem: "01 - phone"
                ),
                ScreenshotDownloadJob(
                    id: "failure",
                    urlString: "https://example.com/failure",
                    relativeDirectoryComponents: ["02 - Broken", "iphone"],
                    filenameStem: "01 - phone"
                )
            ],
            to: rootURL,
            maxConcurrentDownloads: 2
        ) { completed, total, failureCount in
            await progressRecorder.record(completed: completed, total: total, failureCount: failureCount)
        }

        #expect(result.completed.count == 1)
        #expect(result.failed.count == 1)
        #expect(result.completed.first?.relativePath == "01 - Calm- Sleep/iphone/01 - phone.png")
        #expect(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("01 - Calm- Sleep/iphone/01 - phone.png").path))

        let progressEvents = await progressRecorder.events
        #expect(progressEvents.first == ScreenshotDownloadProgressEvent(completed: 0, total: 2, failureCount: 0))
        #expect(progressEvents.last == ScreenshotDownloadProgressEvent(completed: 2, total: 2, failureCount: 1))
    }

    @Test
    func sanitizesUnsafePathComponents() {
        #expect(ScreenshotDownloadService.sanitizedPathComponent(" Calm / Sleep: Stories? ") == "Calm - Sleep- Stories")
        #expect(ScreenshotDownloadService.sanitizedPathComponent("...") == "Untitled")
    }
}

private struct ScreenshotDownloadProgressEvent: Equatable, Sendable {
    let completed: Int
    let total: Int
    let failureCount: Int
}

private actor ScreenshotDownloadProgressRecorder {
    private(set) var events: [ScreenshotDownloadProgressEvent] = []

    func record(completed: Int, total: Int, failureCount: Int) {
        events.append(ScreenshotDownloadProgressEvent(
            completed: completed,
            total: total,
            failureCount: failureCount
        ))
    }
}
