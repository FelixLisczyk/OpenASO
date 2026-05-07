import SwiftUI

struct AppleAdsConnectionStatusRow: View {
    let state: AppleAdsConnectionState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: state.systemImage)
                .foregroundStyle(state.tint)
                .imageScale(.large)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(state.title)
                    .font(.headline)
                Text(state.message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AppStoreConnectConnectionStatusRow: View {
    let state: AppStoreConnectConnectionState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: state.systemImage)
                .foregroundStyle(state.tint)
                .imageScale(.large)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(state.title)
                    .font(.headline)
                Text(state.message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

struct VerificationStatus {
    let message: String
    let isSuccess: Bool

    static func success(_ message: String) -> VerificationStatus {
        VerificationStatus(message: message, isSuccess: true)
    }

    static func failure(_ message: String) -> VerificationStatus {
        VerificationStatus(message: message, isSuccess: false)
    }

    var systemImage: String {
        isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    var tint: Color {
        isSuccess ? .green : .red
    }
}
