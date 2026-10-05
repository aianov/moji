import Foundation

extension LearnServicesStore {
    func searchOrder(_ page: MojiPage) -> [String] {
        planner.batches(page).flatMap(\.characterIDs)
    }

    func batchID(containing characterID: String, in page: MojiPage) -> String? {
        planner.batches(page).first { $0.characterIDs.contains(characterID) }?.id
    }
}
