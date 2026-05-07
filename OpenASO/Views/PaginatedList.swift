import SwiftUI

struct PaginatedListPageRequest: Sendable, Hashable {
    let offset: Int
    let limit: Int
}

struct PaginatedListPage<Item: Sendable>: Sendable {
    let items: [Item]
    let hasMore: Bool
}

struct PaginatedList<Item, Row, EmptyContent>: View where Item: Identifiable & Sendable, Row: View, EmptyContent: View {
    let resetID: String
    let pageSize: Int
    let spacing: CGFloat
    let contentInsets: EdgeInsets
    let loadPage: @Sendable (PaginatedListPageRequest) async throws -> PaginatedListPage<Item>
    let row: (Item) -> Row
    let emptyContent: () -> EmptyContent
    let onItemsChange: ([Item]) -> Void

    @State private var items: [Item] = []
    @State private var hasMore = true
    @State private var isLoading = false
    @State private var loadError: Error?

    init(
        resetID: String,
        pageSize: Int = 25,
        spacing: CGFloat = 12,
        contentInsets: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 18, trailing: 0),
        loadPage: @escaping @Sendable (PaginatedListPageRequest) async throws -> PaginatedListPage<Item>,
        @ViewBuilder row: @escaping (Item) -> Row,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent,
        onItemsChange: @escaping ([Item]) -> Void = { _ in }
    ) {
        self.resetID = resetID
        self.pageSize = pageSize
        self.spacing = spacing
        self.contentInsets = contentInsets
        self.loadPage = loadPage
        self.row = row
        self.emptyContent = emptyContent
        self.onItemsChange = onItemsChange
    }

    var body: some View {
        Group {
            if items.isEmpty, isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty, loadError != nil {
                retryView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                emptyContent()
            } else {
                ScrollView {
                    LazyVStack(spacing: spacing) {
                        ForEach(items) { item in
                            row(item)
                        }

                        footer
                    }
                    .padding(contentInsets)
                }
            }
        }
        .task(id: resetID) {
            await resetAndLoad()
        }
    }

    @ViewBuilder
    private var footer: some View {
        if isLoading {
            ProgressView()
                .padding(.vertical, 10)
        } else if loadError != nil {
            retryView
                .padding(.vertical, 10)
        } else if hasMore {
            Color.clear
                .frame(height: 1)
                .onAppear {
                    Task {
                        await loadNextPage()
                    }
                }
        }
    }

    private var retryView: some View {
        VStack(spacing: 10) {
            Text("Could not load more results.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Retry") {
                Task {
                    await loadNextPage()
                }
            }
        }
    }

    @MainActor
    private func resetAndLoad() async {
        items = []
        hasMore = true
        loadError = nil
        onItemsChange(items)
        await loadNextPage()
    }

    @MainActor
    private func loadNextPage() async {
        guard !isLoading, hasMore else { return }

        isLoading = true
        loadError = nil
        let request = PaginatedListPageRequest(offset: items.count, limit: pageSize)

        do {
            let page = try await loadPage(request)
            items.append(contentsOf: page.items)
            hasMore = page.hasMore
            onItemsChange(items)
        } catch {
            loadError = error
        }

        isLoading = false
    }
}
