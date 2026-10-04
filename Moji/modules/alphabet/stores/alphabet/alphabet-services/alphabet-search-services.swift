import Foundation

extension AlphabetServicesStore {
    func searchOrder(_ page: MojiPage) -> [String] {
        MojiAlphabetCatalog.shared.chart(page).map(\.id)
    }

    func rowID(containing characterID: String, in page: MojiPage) -> String? {
        guard let character = MojiAlphabetCatalog.shared.character(characterID) else { return nil }
        return sections(page)
            .first { $0.id == character.sectionID }?
            .rowID(containing: characterID)
    }
}
