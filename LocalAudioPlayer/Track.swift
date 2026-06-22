import Foundation

struct Track: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let url: URL
    var duration: TimeInterval?
    /// Whether this track requires security-scoped access
    let isSecurityScoped: Bool

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}
