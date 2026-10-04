import Foundation

struct Token: Encodable {
    let s: String
    let r: String
}

struct Line: Encodable {
    let id: String
    let t: [Token]
}

func hiragana(_ latin: String) -> String {
    let mutable = NSMutableString(string: latin) as CFMutableString
    CFStringTransform(mutable, nil, kCFStringTransformLatinHiragana, false)
    return mutable as String
}

func tokens(of text: String, locale: CFLocale) -> [Token] {
    let string = text as CFString
    let range = CFRangeMake(0, CFStringGetLength(string))
    guard let tokenizer = CFStringTokenizerCreate(nil, string, range, kCFStringTokenizerUnitWordBoundary, locale) else {
        return [Token(s: text, r: "")]
    }
    let nsText = text as NSString
    var result: [Token] = []
    var cursor = 0
    while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
        let tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
        if tokenRange.location > cursor {
            let gap = nsText.substring(with: NSRange(location: cursor, length: tokenRange.location - cursor))
            result.append(Token(s: gap, r: ""))
        }
        let surface = nsText.substring(with: NSRange(location: tokenRange.location, length: tokenRange.length))
        let latin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String ?? ""
        result.append(Token(s: surface, r: latin.isEmpty ? "" : hiragana(latin)))
        cursor = tokenRange.location + tokenRange.length
    }
    if cursor < nsText.length {
        result.append(Token(s: nsText.substring(from: cursor), r: ""))
    }
    return result
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: tokenize <input.tsv> <output.jsonl>\n".utf8))
    exit(2)
}
guard let input = try? String(contentsOfFile: arguments[1], encoding: .utf8) else {
    FileHandle.standardError.write(Data("cannot read \(arguments[1])\n".utf8))
    exit(1)
}
let locale = Locale(identifier: "ja_JP") as CFLocale
let encoder = JSONEncoder()
var output = Data()
for line in input.split(separator: "\n", omittingEmptySubsequences: true) {
    let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { continue }
    let entry = Line(id: String(parts[0]), t: tokens(of: String(parts[1]), locale: locale))
    if let data = try? encoder.encode(entry) {
        output.append(data)
        output.append(0x0A)
    }
}
do {
    try output.write(to: URL(fileURLWithPath: arguments[2]))
} catch {
    FileHandle.standardError.write(Data("cannot write \(arguments[2])\n".utf8))
    exit(1)
}
