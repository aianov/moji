import Foundation

struct MojiLossyArray<Element: Codable>: Codable {
    let elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        while !container.isAtEnd {
            let index = container.currentIndex
            if let element = try? container.decode(Element.self) {
                elements.append(element)
                continue
            }
            if container.currentIndex == index {
                _ = try container.decode(MojiSkippedValue.self)
            }
            if container.currentIndex == index {
                break
            }
        }
        self.elements = elements
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(elements)
    }
}

extension MojiLossyArray: Sendable where Element: Sendable {}

private struct MojiSkippedValue: Decodable {
    init(from decoder: any Decoder) throws {}
}
