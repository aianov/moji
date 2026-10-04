import Foundation

struct MojiCharacterRow: Identifiable, Sendable {
    let id: String
    let slots: [MojiCharacterSlot]
}

extension MojiCharacterSection {
    var hasHeader: Bool {
        title != nil || subtitle != nil
    }

    var rows: [MojiCharacterRow] {
        let width = max(1, columns)
        return stride(from: 0, to: slots.count, by: width).map { start in
            MojiCharacterRow(
                id: rowID(at: start / width),
                slots: Array(slots[start..<min(start + width, slots.count)])
            )
        }
    }

    func rowID(containing characterID: String) -> String? {
        guard let index = slots.firstIndex(where: { $0.id == characterID }) else { return nil }
        return rowID(at: index / max(1, columns))
    }

    private func rowID(at row: Int) -> String {
        "\(id)#row\(row)"
    }
}
