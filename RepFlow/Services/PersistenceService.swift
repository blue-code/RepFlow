import Foundation
import SwiftData

@MainActor
enum PersistenceService {
    static let shared: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            WorkoutSet.self,
            GTGDay.self,
            GTGPrompt.self,
            UserProfile.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("ModelContainer 초기화 실패: \(error)")
        }
    }()
}
