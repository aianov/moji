import Foundation

extension LearnServicesStore {
    func searchOrder(_ page: MojiPage) -> [String] {
        planner.batches(page).flatMap(\.characterIDs)
    }

    func batchIndex(containing characterID: String, in page: MojiPage) -> Int? {
        planner.batches(page).first { $0.characterIDs.contains(characterID) }?.index
    }
}
