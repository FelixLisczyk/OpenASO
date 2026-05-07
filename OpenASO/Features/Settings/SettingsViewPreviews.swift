import SwiftUI

#if DEBUG
#Preview("Apple Ads Settings") {
    NavigationStack {
        SettingsView()
    }
    .previewAppDependencies()
    .frame(width: 540, height: 760)
}

#Preview("Apple Ads Settings - Connected") {
    NavigationStack {
        SettingsView(initialConnectionState: .connected(updatedAt: .now))
    }
    .previewAppDependencies()
    .frame(width: 540, height: 760)
}

#Preview("Apple Ads Settings - Expired") {
    NavigationStack {
        SettingsView(
            initialConnectionState: .expiredSession("Apple Ads asked for sign-in again. Refresh the session to continue.")
        )
    }
    .previewAppDependencies()
    .frame(width: 540, height: 760)
}

#Preview("Apple Ads Settings - No Linked Apps") {
    NavigationStack {
        SettingsView(initialConnectionState: .noLinkedApps)
    }
    .previewAppDependencies()
    .frame(width: 540, height: 760)
}

#Preview("Apple Ads Settings - API Issue") {
    NavigationStack {
        SettingsView(initialConnectionState: .apiIssue("Apple Ads returned HTTP 500. Try again shortly."))
    }
    .previewAppDependencies()
    .frame(width: 540, height: 760)
}
#endif
