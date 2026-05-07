import Foundation
import SwiftData

extension OpenASOSchemaV1 {
@Model
final class AppFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int
    var colorRaw: String = "blue"
    var isExpanded: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \TrackedApp.folder)
    var apps: [TrackedApp]

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int,
        colorRaw: String = "blue",
        isExpanded: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.colorRaw = colorRaw
        self.isExpanded = isExpanded
        self.createdAt = createdAt
        self.apps = []
    }
}
}

typealias AppFolder = OpenASOSchemaV1.AppFolder
