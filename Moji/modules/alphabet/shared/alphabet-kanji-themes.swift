import Foundation

enum MojiKanjiTheme: String, CaseIterable, Identifiable, Sendable {
    case people
    case time
    case numbers
    case nature
    case animals
    case plants
    case body
    case food
    case home
    case city
    case movement
    case actions
    case feelings
    case describing
    case thinking
    case words
    case study
    case work
    case society
    case media
    case history
    case religion
    case formal
    case names
    case oldForms = "old_forms"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .people: String(localized: "People")
        case .time: String(localized: "Time")
        case .numbers: String(localized: "Numbers & shapes")
        case .nature: String(localized: "Nature")
        case .animals: String(localized: "Animals")
        case .plants: String(localized: "Plants")
        case .body: String(localized: "Body & health")
        case .food: String(localized: "Food")
        case .home: String(localized: "Home & things")
        case .city: String(localized: "City")
        case .movement: String(localized: "Movement")
        case .actions: String(localized: "Actions")
        case .feelings: String(localized: "Feelings & character")
        case .describing: String(localized: "Describing")
        case .thinking: String(localized: "Thinking & talking")
        case .words: String(localized: "Everyday words")
        case .study: String(localized: "Study & science")
        case .work: String(localized: "Work & money")
        case .society: String(localized: "Society")
        case .media: String(localized: "Media")
        case .history: String(localized: "History & culture")
        case .religion: String(localized: "Religion")
        case .formal: String(localized: "Formal & literary")
        case .names: String(localized: "Names")
        case .oldForms: String(localized: "Old forms")
        }
    }

    var subtitle: String {
        switch self {
        case .people: String(localized: "Family, friends and how people are called")
        case .time: String(localized: "Days, seasons, calendars and moments")
        case .numbers: String(localized: "Counting, measures, sides and lines")
        case .nature: String(localized: "Weather, land, sea and sky")
        case .animals: String(localized: "Pets, wild beasts, birds and fish")
        case .plants: String(localized: "Trees, flowers, crops and fields")
        case .body: String(localized: "From head to toe, and the doctor")
        case .food: String(localized: "Meals, fruit, cooking and drinks")
        case .home: String(localized: "Rooms, furniture, clothes and tools")
        case .city: String(localized: "Towns, buildings, transport and directions")
        case .movement: String(localized: "Going, coming, rising, falling and sports")
        case .actions: String(localized: "Verbs for hands and everyday things")
        case .feelings: String(localized: "Emotions, attitudes, virtues and vices")
        case .describing: String(localized: "Size, colors, textures and qualities")
        case .thinking: String(localized: "Seeing, saying, judging and ideas")
        case .words: String(localized: "Small words that build many others")
        case .study: String(localized: "School, classes, research and machines")
        case .work: String(localized: "Jobs, offices, prices and the economy")
        case .society: String(localized: "Politics, law and community")
        case .media: String(localized: "Internet, shows, music, chat and manga")
        case .history: String(localized: "The past, old arts, the court and war")
        case .religion: String(localized: "Temples, rites, spirits and fortune")
        case .formal: String(localized: "News, documents, old books and poems")
        case .names: String(localized: "Surnames, places and given names")
        case .oldForms: String(localized: "Old shapes still seen in names, signs and old books")
        }
    }

    var symbol: String {
        switch self {
        case .people: "人"
        case .time: "時"
        case .numbers: "数"
        case .nature: "山"
        case .animals: "犬"
        case .plants: "木"
        case .body: "体"
        case .food: "食"
        case .home: "家"
        case .city: "町"
        case .movement: "動"
        case .actions: "作"
        case .feelings: "感"
        case .describing: "大"
        case .thinking: "言"
        case .words: "何"
        case .study: "学"
        case .work: "働"
        case .society: "民"
        case .media: "映"
        case .history: "史"
        case .religion: "神"
        case .formal: "及"
        case .names: "姓"
        case .oldForms: "國"
        }
    }
}
