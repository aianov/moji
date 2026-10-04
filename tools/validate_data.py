import os
import re
import sys
from collections import Counter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Moji", "modules", "alphabet", "shared")

KANA = {
    "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
    "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
    "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
    "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
    "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
    "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
    "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
    "や": "ya", "ゆ": "yu", "よ": "yo",
    "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
    "わ": "wa", "を": "wo", "ん": "n",
    "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
    "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
    "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
    "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
    "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
}
SMALL = {"ゃ": "ya", "ゅ": "yu", "ょ": "yo"}
KATA_OFFSET = ord("ア") - ord("あ")
DASHES = ("—", "–")

THEME_SIZE = (60, 200)
THEME_SIZE_EXCEPTIONS = {}
KANJI_ID_PREFIX = "j"
REGISTRY_FILE = "alphabet-data-kanji.swift"
THEMES_FILE = "alphabet-kanji-themes.swift"
RU_FILE = "alphabet-data-kanji-ru.swift"
READINGS_FILE = "alphabet-data-kanji-readings.swift"


def read(name):
    with open(os.path.join(ROOT, name), encoding="utf-8") as handle:
        return handle.read()


def to_hira(text):
    out = []
    for ch in text:
        code = ord(ch)
        if ord("ァ") <= code <= ord("ヶ"):
            out.append(chr(code - KATA_OFFSET))
        else:
            out.append(ch)
    return "".join(out)


def romanize(text):
    text = to_hira(text)
    result = []
    i = 0
    geminate = False
    while i < len(text):
        ch = text[i]
        if ch in "()":
            result.append(ch)
            i += 1
            continue
        if ch == "っ":
            geminate = True
            i += 1
            continue
        if ch == "ー":
            if result:
                last = result[-1]
                result.append(last[-1])
            i += 1
            continue
        syllable = KANA.get(ch)
        if syllable is None:
            return None
        if i + 1 < len(text) and text[i + 1] in SMALL:
            small = SMALL[text[i + 1]]
            if syllable in ("shi", "chi", "ji"):
                syllable = syllable[:-1] + small[1:]
            else:
                syllable = syllable[:-1] + small
            i += 1
        if geminate:
            syllable = syllable[0] + syllable
            geminate = False
        result.append(syllable)
        i += 1
    return "".join(result)


def has_dash(text):
    return any(dash in text for dash in DASHES)


def theme_file_name(raw_value):
    return "alphabet-data-kanji-" + raw_value.replace("_", "-") + ".swift"


def theme_variable(case):
    return "kanji" + case[0].upper() + case[1:]


kanji_pattern = re.compile(r'\.kanji\("([^"]+)", "([^"]+)", "([^"]+)", "([^"]+)"\)')
kana_pattern = re.compile(r'\.kana\("([^"]+)", "([^"]+)"(?:, id: "([^"]+)")?\)')
section_key_pattern = re.compile(r'key: "([^"]+)"')
section_title_pattern = re.compile(r'title: "([^"]+)"')
section_subtitle_pattern = re.compile(r'subtitle: "([^"]+)"')
definition_pattern = re.compile(r"static let (\w+) = MojiPageDefinition\(")
page_pattern = re.compile(r"page: \.kanji\(\.(\w+)\)")
prefix_pattern = re.compile(r'idPrefix: "([^"]*)"')
order_pattern = re.compile(r'lessonOrder: "([^"]*)"')
case_pattern = re.compile(r'^\s*case (\w+)(?: = "([^"]+)")?\s*$', re.MULTILINE)
localized_pattern = re.compile(r'String\(localized: "([^"]+)"\)')
symbol_pattern = re.compile(r'^\s*case \.(\w+): "([^"]+)"\s*$', re.MULTILINE)
ru_pattern = re.compile(r'^\s*"([^"]+)": "([^"]+)",?\s*$', re.MULTILINE)
readings_pattern = re.compile(r'^\s*"([^"]+)": \[([^\]]*)\],?\s*$', re.MULTILINE)
item_pattern = re.compile(r'"([^"]+)"')
group_pattern = re.compile(r"\[([^\[\]]*)\]")

problems = []
notes = []
all_glyphs = Counter()
theme_of = {}

ru_source = read(RU_FILE)
ru_body = ru_source.split("kanjiMeaningsRU: [String: String] = [", 1)[1]
ru_entries = ru_pattern.findall(ru_body)
ru_keys = Counter(glyph for glyph, _ in ru_entries)
for glyph, count in ru_keys.items():
    if count > 1:
        problems.append(f"ru: {glyph} has {count} entries (the app would crash on launch)")
ru = dict(ru_entries)

readings_source = read(READINGS_FILE)
readings_body = readings_source.split("kanjiOtherReadings: [String: [String]] = [", 1)[1]
reading_entries = [(glyph, item_pattern.findall(items)) for glyph, items in readings_pattern.findall(readings_body)]
reading_keys = Counter(glyph for glyph, _ in reading_entries)
for glyph, count in reading_keys.items():
    if count > 1:
        problems.append(f"readings: {glyph} has {count} entries (the app would crash on launch)")
other_readings = dict(reading_entries)
primary_reading = {}

themes_source = read(THEMES_FILE)
enum_body = themes_source.split("enum MojiKanjiTheme", 1)[1].split("var id", 1)[0]
cases = [(name, raw or name) for name, raw in case_pattern.findall(enum_body)]
raw_of_case = dict(cases)
for text in localized_pattern.findall(themes_source):
    if has_dash(text):
        problems.append(f"{THEMES_FILE}: theme text '{text}' has a long dash")
symbols = dict(symbol_pattern.findall(themes_source))

registry_source = read(REGISTRY_FILE)
if kanji_pattern.search(registry_source):
    problems.append(f"{REGISTRY_FILE}: kanji entries belong in the theme files, not in the registry")
registry_body = registry_source.split("kanjiThemes: [MojiPageDefinition] = [", 1)[1].split("]", 1)[0]
registry = re.findall(r"\w+", registry_body)
for name, count in Counter(registry).items():
    if count > 1:
        problems.append(f"{REGISTRY_FILE}: {name} is listed {count} times in kanjiThemes")
expected_registry = [theme_variable(case) for case, _ in cases]
if registry != expected_registry:
    problems.append(f"{REGISTRY_FILE}: kanjiThemes must list every theme once, in the order of MojiKanjiTheme")

theme_files = {}
for name in sorted(os.listdir(ROOT)):
    if not (name.startswith("alphabet-data-kanji") and name.endswith(".swift")):
        continue
    if name in (REGISTRY_FILE, RU_FILE, READINGS_FILE):
        continue
    source = read(name)
    page = page_pattern.search(source)
    if page is None:
        if kanji_pattern.search(source):
            problems.append(f"{name}: has kanji but no kanji theme page")
        elif "MojiPageDefinition" not in source:
            notes.append(f"{name} holds no data and can be deleted")
        continue
    theme_files[page.group(1)] = (name, source)

for case, raw in cases:
    if case not in theme_files:
        problems.append(f"theme {case} has no data file (expected {theme_file_name(raw)})")
for case in theme_files:
    if case not in raw_of_case:
        problems.append(f"{theme_files[case][0]}: .kanji(.{case}) is not a MojiKanjiTheme case")

sizes = {}
for case, raw in cases:
    if case not in theme_files:
        continue
    name, source = theme_files[case]
    if name != theme_file_name(raw):
        problems.append(f"{name}: theme {case} should live in {theme_file_name(raw)}")
    if len(page_pattern.findall(source)) != 1:
        problems.append(f"{name}: one kanji theme page per file")
    variables = definition_pattern.findall(source)
    if variables != [theme_variable(case)]:
        problems.append(f"{name}: expected one definition named {theme_variable(case)}, found {variables}")
    if prefix_pattern.findall(source) != [KANJI_ID_PREFIX]:
        problems.append(f"{name}: idPrefix must be \"{KANJI_ID_PREFIX}\" or saved progress loses its kanji")
    if "lookAlikes:" in source:
        problems.append(f"{name}: kanji look-alikes belong in kanjiLookAlikes in {REGISTRY_FILE}")

    entries = kanji_pattern.findall(source)
    glyphs = [entry[0] for entry in entries]
    sizes[case] = len(entries)
    for glyph in glyphs:
        all_glyphs[glyph] += 1
        if glyph in theme_of and theme_of[glyph] != case:
            problems.append(f"{glyph} is in both {theme_of[glyph]} and {case}")
        theme_of.setdefault(glyph, case)

    meanings = Counter(entry[3] for entry in entries)
    for meaning, count in meanings.items():
        if count > 1:
            problems.append(f"{name}: meaning '{meaning}' used {count} times")
    russian = Counter(ru[glyph] for glyph in glyphs if glyph in ru)
    for meaning, count in russian.items():
        if count > 1:
            problems.append(f"{name}: Russian meaning '{meaning}' used {count} times")
    for glyph, romaji, kana, meaning in entries:
        expected = romanize(kana)
        if expected is None:
            problems.append(f"{name}: {glyph} reading '{kana}' has unknown kana")
        elif expected != romaji:
            problems.append(f"{name}: {glyph} romaji '{romaji}' but kana '{kana}' reads '{expected}'")
        if kana.count("(") != romaji.count("("):
            problems.append(f"{name}: {glyph} bracket mismatch")
        primary_reading[glyph] = kana
        if glyph not in ru:
            problems.append(f"{name}: {glyph} ({meaning}) has no Russian meaning")
        for text in (meaning, ru.get(glyph, "")):
            if has_dash(text):
                problems.append(f"{name}: {glyph} meaning '{text}' has a long dash")

    orders = order_pattern.findall(source)
    if len(orders) != 1:
        problems.append(f"{name}: needs exactly one lessonOrder")
        order = []
    else:
        order = list(orders[0])
        if Counter(order) != Counter(glyphs):
            missing = "".join(sorted(set(glyphs) - set(order)))
            extra = "".join(sorted(set(order) - set(glyphs)))
            repeated = "".join(glyph for glyph, count in Counter(order).items() if count > 1)
            problems.append(
                f"{name}: lessonOrder must hold every kanji of the theme once"
                f" (missing '{missing}', not in theme '{extra}', repeated '{repeated}')"
            )
    position = {glyph: index for index, glyph in enumerate(order)}

    chunks = source.split("MojiSectionDefinition(")[1:]
    section_keys = []
    section_heads = []
    for chunk in chunks:
        key = section_key_pattern.search(chunk)
        key = key.group(1) if key else "?"
        section_keys.append(key)
        for pattern in (section_title_pattern, section_subtitle_pattern):
            text = pattern.search(chunk)
            if text and has_dash(text.group(1)):
                problems.append(f"{name}: section text '{text.group(1)}' has a long dash")
        cells = [entry[0] for entry in kanji_pattern.findall(chunk)]
        if not cells:
            problems.append(f"{name}: section {key} is empty")
            continue
        if all(glyph in position for glyph in cells):
            ranks = [position[glyph] for glyph in cells]
            if ranks != sorted(ranks):
                problems.append(f"{name}: section {key} does not follow lessonOrder")
            section_heads.append((ranks[0], key))
    for key, count in Counter(section_keys).items():
        if count > 1:
            problems.append(f"{name}: section key {key} used {count} times")
    heads = [rank for rank, _ in section_heads]
    if heads != sorted(heads):
        problems.append(f"{name}: sections must be ordered by their most common kanji")

    symbol = symbols.get(case)
    if symbol is None:
        problems.append(f"{THEMES_FILE}: theme {case} has no symbol")
    elif symbol not in glyphs:
        problems.append(f"{THEMES_FILE}: symbol {symbol} of theme {case} is not one of its kanji")

    low, high = THEME_SIZE
    reason = THEME_SIZE_EXCEPTIONS.get(case)
    if not low <= len(entries) <= high:
        if reason:
            notes.append(f"{case} has {len(entries)} kanji, outside {low} to {high}: {reason}")
        else:
            problems.append(f"{name}: {len(entries)} kanji, a theme needs {low} to {high} or a reason in THEME_SIZE_EXCEPTIONS")
    elif reason:
        problems.append(f"THEME_SIZE_EXCEPTIONS: {case} has {len(entries)} kanji and needs no exception any more")
    print(f"{case}: {len(entries)} kanji in {len(section_keys)} sections")

for case in THEME_SIZE_EXCEPTIONS:
    if case not in raw_of_case:
        problems.append(f"THEME_SIZE_EXCEPTIONS: {case} is not a theme")

for glyph, count in all_glyphs.items():
    if count > 1:
        problems.append(f"glyph {glyph} appears {count} times across kanji themes")
    if len(glyph) != 1:
        problems.append(f"glyph {glyph} is not a single character")

for glyph in ru:
    if glyph not in all_glyphs:
        problems.append(f"ru: {glyph} is not in any kanji theme")

reading_count = 0
for glyph, readings in other_readings.items():
    if glyph not in all_glyphs:
        problems.append(f"readings: {glyph} is not in any kanji theme")
        continue
    if not readings:
        problems.append(f"readings: {glyph} has an empty list; leave it out instead")
    if len(set(readings)) != len(readings):
        problems.append(f"readings: {glyph} repeats a reading in {readings}")
    for reading in readings:
        reading_count += 1
        if reading == primary_reading[glyph]:
            problems.append(f"readings: {glyph} lists its first reading {reading} again")
        opens, closes = reading.count("("), reading.count(")")
        if opens != closes or opens > 1 or (opens and (reading.startswith("(") or not reading.endswith(")"))):
            problems.append(f"readings: {glyph} reading '{reading}' has broken brackets")
        plain = reading.replace("(", "").replace(")", "")
        if plain.endswith("っ") or reading.split("(")[0].endswith("っ"):
            problems.append(f"readings: {glyph} reading '{reading}' ends on small っ")
        if romanize(reading) is None:
            problems.append(f"readings: {glyph} reading '{reading}' has something that is not kana")

look_body = registry_source.split("kanjiLookAlikes: [[String]] = [", 1)[1]
look_groups = [item_pattern.findall(group) for group in group_pattern.findall(look_body)]
cross_theme = 0
for group in look_groups:
    if len(group) < 2 or len(set(group)) != len(group):
        problems.append(f"look-alikes: group {group} needs two or more different kanji")
    for glyph in group:
        if glyph not in all_glyphs:
            problems.append(f"look-alikes: {glyph} in {group} is not in any kanji theme")
    if len({theme_of.get(glyph) for glyph in group}) > 1:
        cross_theme += 1

source = read("alphabet-data-kana.swift")
for script_name in ["hiragana", "katakana"]:
    start = source.index(f"static let {script_name} =")
    chunk = source[start:]
    chunk = chunk.split("lookAlikes:")[0]
    entries = kana_pattern.findall(chunk)
    ids = Counter((e[2] or e[1]) for e in entries)
    for key, count in ids.items():
        if count > 1:
            problems.append(f"{script_name}: id suffix '{key}' used {count} times")
    for glyph, romaji, _ in entries:
        expected = romanize(glyph)
        if glyph in ("を", "ヲ"):
            ok = romaji in ("o", "wo")
        else:
            ok = expected == romaji
        if not ok:
            problems.append(f"{script_name}: {glyph} romaji '{romaji}' expected '{expected}'")
    print(f"{script_name}: {len(entries)} characters")

print(f"Kanji: {sum(all_glyphs.values())} in {len(sizes)} themes, {min(sizes.values(), default=0)} to {max(sizes.values(), default=0)} per theme")
print(f"Look-alike groups: {len(look_groups)}, {cross_theme} of them across themes")
print(f"Russian meanings: {len(ru)}")
print(f"Other readings: {reading_count} for {len(other_readings)} kanji")
for note in notes:
    print(f"Note: {note}")
print()
if problems:
    print(f"{len(problems)} problem(s):")
    for problem in problems:
        print(" -", problem)
    sys.exit(1)
low, high = THEME_SIZE
print(
    f"OK: every kanji is in exactly one theme, themes hold {low} to {high} kanji"
    f"{' or say why not' if THEME_SIZE_EXCEPTIONS else ''}, lesson orders and sections agree,"
    " no duplicates, all romaji match their kana, every kanji has a Russian meaning, other readings are sound"
)
