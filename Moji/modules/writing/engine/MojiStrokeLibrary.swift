import CoreGraphics
import Foundation

struct MojiStrokeGlyph: Equatable, Sendable {
    let scalar: Unicode.Scalar
    let strokes: [[CGPoint]]
}

struct MojiStrokeLibrary: Sendable {
    static let gridSize: CGFloat = 109
    static let credit = "KanjiVG"
    static let resourceName = "moji-strokes"
    static let resourceExtension = "dat"
    static let shared = MojiStrokeLibrary.bundled()

    private static let magic = Data("MJSK".utf8)
    private static let version = 1
    private static let headerSize = 16
    private static let entrySize = 8

    let count: Int
    private let data: Data
    private let quantum: CGFloat

    init?(data: Data) {
        guard data.count >= Self.headerSize, data.prefix(4) == Self.magic else { return nil }
        let header = data.withUnsafeBytes { raw in
            (
                version: Int(UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: 4, as: UInt16.self))),
                grid: Int(UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: 6, as: UInt16.self))),
                quantum: Int(UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: 8, as: UInt16.self))),
                count: Int(UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: 12, as: UInt32.self)))
            )
        }
        guard header.version == Self.version,
              CGFloat(header.grid) == Self.gridSize,
              header.quantum > 0,
              Self.headerSize + header.count * Self.entrySize <= data.count else { return nil }
        self.data = data
        count = header.count
        quantum = CGFloat(header.quantum)
    }

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return nil }
        self.init(data: data)
    }

    static func bundled(in bundle: Bundle = .main) -> MojiStrokeLibrary? {
        let url = bundle.url(forResource: resourceName, withExtension: resourceExtension)
            ?? bundle.url(forResource: resourceName, withExtension: resourceExtension, subdirectory: "Strokes")
        return url.flatMap(MojiStrokeLibrary.init(url:))
    }

    var scalars: [Unicode.Scalar] {
        data.withUnsafeBytes { raw in
            (0..<count).compactMap { slot in
                Unicode.Scalar(UInt32(littleEndian: raw.loadUnaligned(
                    fromByteOffset: Self.headerSize + slot * Self.entrySize,
                    as: UInt32.self
                )))
            }
        }
    }

    func contains(_ scalar: Unicode.Scalar) -> Bool {
        offset(of: scalar) != nil
    }

    func canWrite(_ text: String) -> Bool {
        !text.unicodeScalars.isEmpty && text.unicodeScalars.allSatisfy(contains)
    }

    func glyph(_ scalar: Unicode.Scalar) -> MojiStrokeGlyph? {
        guard let start = offset(of: scalar) else { return nil }
        let size = data.count
        let scale = quantum
        let strokes: [[CGPoint]]? = data.withUnsafeBytes { raw in
            guard start < size else { return nil }
            let strokeCount = Int(raw[start])
            guard strokeCount > 0 else { return nil }
            var cursor = start + 1
            var strokes: [[CGPoint]] = []
            strokes.reserveCapacity(strokeCount)
            for _ in 0..<strokeCount {
                guard cursor + 2 <= size else { return nil }
                let length = Int(UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: cursor, as: UInt16.self)))
                cursor += 2
                guard length >= 2, cursor + length * 4 <= size else { return nil }
                var points: [CGPoint] = []
                points.reserveCapacity(length)
                for index in 0..<length {
                    let x = Int16(littleEndian: raw.loadUnaligned(fromByteOffset: cursor + index * 4, as: Int16.self))
                    let y = Int16(littleEndian: raw.loadUnaligned(fromByteOffset: cursor + index * 4 + 2, as: Int16.self))
                    points.append(CGPoint(x: CGFloat(x) / scale, y: CGFloat(y) / scale))
                }
                cursor += length * 4
                strokes.append(points)
            }
            return strokes
        }
        return strokes.map { MojiStrokeGlyph(scalar: scalar, strokes: $0) }
    }

    func glyphs(_ text: String) -> [MojiStrokeGlyph]? {
        let scalars = Array(text.unicodeScalars)
        guard !scalars.isEmpty else { return nil }
        var result: [MojiStrokeGlyph] = []
        for scalar in scalars {
            guard let glyph = glyph(scalar) else { return nil }
            result.append(glyph)
        }
        return result
    }

    func figure(for text: String) -> MojiWritingFigure? {
        glyphs(text).flatMap(MojiWritingLayout.figure)
    }

    private func offset(of scalar: Unicode.Scalar) -> Int? {
        let target = scalar.value
        let size = data.count
        return data.withUnsafeBytes { raw -> Int? in
            var low = 0
            var high = count - 1
            while low <= high {
                let middle = (low + high) / 2
                let entry = Self.headerSize + middle * Self.entrySize
                let value = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: entry, as: UInt32.self))
                if value == target {
                    let offset = Int(UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: entry + 4, as: UInt32.self)))
                    return offset < size ? offset : nil
                }
                if value < target {
                    low = middle + 1
                } else {
                    high = middle - 1
                }
            }
            return nil
        }
    }
}
