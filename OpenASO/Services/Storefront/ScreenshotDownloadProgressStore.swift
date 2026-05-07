import Foundation
import Observation

enum ScreenshotDownloadPhase: Sendable {
    case running
    case completed
    case failed

    var title: String {
        switch self {
        case .running:
            return "Downloading screenshots"
        case .completed:
            return "Screenshot download complete"
        case .failed:
            return "Screenshot download failed"
        }
    }
}

struct ScreenshotDownloadProgress: Identifiable, Sendable {
    let id: UUID
    let title: String
    let destinationURL: URL
    let startedAt: Date
    var phase: ScreenshotDownloadPhase
    var completed: Int
    var total: Int
    var failureCount: Int
    var completedAt: Date?
    var message: String?

    var progressValue: Double {
        Double(completed)
    }

    var progressTotal: Double {
        Double(max(total, 1))
    }

    var summaryText: String {
        if total <= 0 {
            return phase == .running ? "Preparing" : "No screenshots"
        }
        if failureCount > 0 {
            return "\(completed)/\(total), \(failureCount) failed"
        }
        return "\(completed)/\(total)"
    }
}

@MainActor
@Observable
final class ScreenshotDownloadProgressStore {
    private(set) var activeDownload: ScreenshotDownloadProgress?

    @ObservationIgnored
    private var clearTask: Task<Void, Never>?

    var isDownloading: Bool {
        activeDownload?.phase == .running
    }

    func begin(title: String, destinationURL: URL, total: Int) -> UUID {
        clearTask?.cancel()
        clearTask = nil

        let id = UUID()
        activeDownload = ScreenshotDownloadProgress(
            id: id,
            title: title,
            destinationURL: destinationURL,
            startedAt: .now,
            phase: .running,
            completed: 0,
            total: max(0, total),
            failureCount: 0,
            completedAt: nil,
            message: nil
        )
        return id
    }

    func update(id: UUID, completed: Int, total: Int, failureCount: Int) {
        guard var download = activeDownload, download.id == id else { return }
        download.completed = max(0, min(completed, max(0, total)))
        download.total = max(0, total)
        download.failureCount = max(0, failureCount)
        activeDownload = download
    }

    func finish(id: UUID, downloadedCount: Int, failureCount: Int, skippedAppCount: Int) {
        guard var download = activeDownload, download.id == id else { return }
        download.phase = failureCount > 0 ? .failed : .completed
        download.completed = download.total
        download.failureCount = max(0, failureCount)
        download.completedAt = .now

        var messageParts = ["\(downloadedCount) downloaded"]
        if skippedAppCount > 0 {
            messageParts.append("\(skippedAppCount) apps had no screenshots")
        }
        if failureCount > 0 {
            messageParts.append("\(failureCount) failed")
        }
        download.message = messageParts.joined(separator: ", ")
        activeDownload = download
        scheduleClear(downloadID: id)
    }

    func fail(id: UUID, message: String) {
        guard var download = activeDownload, download.id == id else { return }
        download.phase = .failed
        download.completedAt = .now
        download.message = message
        activeDownload = download
        scheduleClear(downloadID: id)
    }

    private func scheduleClear(downloadID: UUID) {
        clearTask?.cancel()
        clearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                guard self?.activeDownload?.id == downloadID else { return }
                self?.activeDownload = nil
                self?.clearTask = nil
            }
        }
    }
}
