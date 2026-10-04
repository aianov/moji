#!/usr/bin/env python3
import argparse
import collections
import json
import math
import pickle
import re
import subprocess
import sys
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL = Path(__file__).resolve().parent
DATA = TOOL / "data"
KANJI_DATA = ROOT / "Moji" / "modules" / "alphabet" / "shared"
DECK = ROOT / "Moji" / "Resources" / "WordDeck" / "moji-word-deck.json"
XML_LANG = "{http://www.w3.org/XML/1998/namespace}lang"
SYNTHESIZED_VOICE = "morioki (AivisSpeech)"

DECK_SIZE = 8000
SECTION_SIZE = 100
CANDIDATES = 11000
MAX_SENTENCES = 3
MAX_TRANSLATED = 1
MAX_RECORDED_TRANSLATED = 1
MAX_SENTENCE_LENGTH = 30
IDEAL_SENTENCE_LENGTH = (7, 20)
MAX_USES_PER_SENTENCE = 4
FIX_SUPPORT = 2
FIX_SHARE = 0.7

GRAMMAR_POS = {"particle", "copula", "auxiliary verb", "auxiliary adjective", "auxiliary"}
AFFIX_POS = {"prefix", "suffix"}
NAME_MISC = {
    "organization name", "company name", "product name", "work of art, literature, music, etc. name",
    "place name", "family or surname", "full name of a particular person",
    "given name or forename, gender not specified", "unclassified name", "ship name", "character", "deity",
    "service", "event", "creature", "object", "document", "group", "religion", "legend", "mythology",
    "fiction", "quotation",
}
OLD_MISC = {"archaic", "obsolete term", "rare term"}
RARE_KANJI_FORM = {
    "rarely used kanji form", "search-only kanji form", "word containing out-dated kanji or kanji usage",
    "word containing irregular kanji usage", "irregular okurigana usage",
}
RARE_KANA_FORM = {
    "search-only kana form", "rarely used kana form", "out-dated or obsolete kana usage",
    "word containing irregular kana usage",
}
KANA_ONLY = "word usually written using kana alone"
COMMON_TAGS = {"ichi1", "news1", "spec1", "gai1", "spec2", "ichi2", "gai2", "news2"}
GRAMMAR_STARTS = (
    "に", "と", "で", "が", "を", "の", "は", "も", "か", "ば", "て", "だ", "じゃ", "ず", "べ", "な", "ま",
    "よう", "そう", "ほう", "こと", "わけ", "はず", "ため", "ところ",
)
INFLECTION = {
    "ます", "まし", "ませ", "ましょ", "ましょう", "た", "だ", "て", "で", "ない", "なかっ", "なく", "なけれ",
    "ず", "たい", "たく", "たかっ", "れる", "れ", "られ", "られる", "せる", "せ", "させ", "させる", "よう",
    "う", "ば", "たら", "たり", "ちゃう", "ちゃっ", "てる", "でる",
}
INFLECTING = {"verb", "adj_i"}
VERB_AUXILIARY = INFLECTION | {"なさい", "ながら", "やすい", "にくい", "すぎる", "すぎ", "そう"}
VERB_TAIL = (
    "すぎ", "過ぎ", "ちゃ", "ます", "まし", "ませ", "たい", "たく", "たがっ", "たかっ",
    "やす", "易", "にく", "て", "ながら", "なさい",
)
HONORIFIC_TAIL = (
    "でき", "する", "すれ", "し", "さ", "せ", "になる", "になり", "になっ", "下さ", "くださ", "いたし", "致し", "いただ", "頂",
    "です", "でし",
)
STEM_TAIL = (
    "ない", "なかっ", "なく", "きれ", "きる", "きっ", "切れ", "切る", "切っ", "始め", "続け", "出す", "出し", "込む", "込ん",
    "合う", "合っ", "合わ", "直す", "直し", "終わ", "終え", "こな",
)
STEM_ENDINGS = set("いきぎしじちぢにひびぴみりえけげせぜてでねへべぺめれ")
TITLE_SUFFIXES = ("さん", "さま", "様", "ちゃん", "くん")
FINE_WORDS = ("いい", "良", "よい", "よし", "よかっ", "よく", "十分", "結構", "大丈夫", "かまわ", "構わ")
JOINING_CONJUNCTIONS = {
    "または", "および", "あるいは", "ならびに", "かつ", "もしくは", "ないし", "すなわち", "ために", "けん", "だって",
}
KANA_PARTICLES = {
    "は", "が", "を", "に", "で", "と", "も", "へ", "の", "や", "か", "ね", "よ", "な", "て", "た", "だ",
    "から", "まで", "より", "だけ", "など", "って", "けど", "し",
}
NUMERALS = set("0123456789０１２３４５６７８９一二三四五六七八九十百千万億数何")
COUNTED = NUMERALS | set("幾半両毎")

POS_RULES = [
    ("expressions", "expression"),
    ("Ichidan verb", "verb"),
    ("Godan verb", "verb"),
    ("Kuru verb", "verb"),
    ("suru verb - included", "verb"),
    ("suru verb - special class", "verb"),
    ("irregular", "verb"),
    ("adjective (keiyoushi)", "adj_i"),
    ("adjectival nouns or quasi-adjectives", "adj_na"),
    ("pre-noun adjectival", "adj_pn"),
    ("pronoun", "pronoun"),
    ("adverb", "adverb"),
    ("conjunction", "conjunction"),
    ("interjection", "interjection"),
    ("counter", "counter"),
    ("numeric", "number"),
    ("noun or participle which takes the aux. verb suru", "noun_suru"),
    ("noun", "noun"),
    ("suffix", "suffix"),
    ("prefix", "prefix"),
]

TOKEN = re.compile(
    r"^(?P<head>[^(\[{~|]+)(?:\((?P<reading>[^)]*)\))?(?:\[(?P<sense>[^\]]*)\])?(?:\{(?P<form>[^}]*)\})?(?P<checked>~)?$"
)
KANJI_CELL = re.compile(r'\.kanji\("([^"]+)", "([^"]+)", "([^"]+)", "([^"]+)"\)')
READINGS_ENTRY = re.compile(r'^\s*"([^"]+)": \[([^\]]*)\],?\s*$', re.MULTILINE)
QUOTED = re.compile(r'"([^"]+)"')
SENTENCE_STRIP = set("。、！？!?.,「」『』（）()…・：:；; 　\"“”'’‘")
PUNCTUATION = set("。、！？!?.,「」『』（）()・…〜～：:；; 　“”\"'")
RU_DROP = re.compile(r"^\s*\((?:см|ср|уст|диал|арх|редк|кит|кор|англ|ант|тж)\.?\)")


def is_kana(char):
    return "ぁ" <= char <= "ゟ" or "゠" <= char <= "ヿ"


def is_kanji(char):
    code = ord(char)
    return (
        char in "々〇" or 0x3400 <= code <= 0x4DBF or 0x4E00 <= code <= 0x9FFF
        or 0xF900 <= code <= 0xFAFF or 0x20000 <= code <= 0x2FA1F
    )


def has_kanji(text):
    return any(is_kanji(c) for c in text)


def hiragana(text):
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in text)


def script(text):
    if text and all("ぁ" <= c <= "ゖ" or c == "ー" for c in text):
        return "hiragana"
    if text and all("ァ" <= c <= "ヺ" or c == "ー" for c in text):
        return "katakana"
    return None


def script_clash(entry, head):
    first = script(entry["rebs"][0]["text"]) if entry["rebs"] else None
    return 1 if first and script(head) and script(head) != first else 0


def load_json(path, default):
    path = Path(path)
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=1), encoding="utf-8")


def read_tsv(path, width):
    rows = []
    path = Path(path)
    if not path.exists():
        return rows
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < width[0] or len(parts) > width[1]:
            sys.exit(f"{path.name}:{number}: expected {width[0]} to {width[1]} columns, got {len(parts)}")
        rows.append([p.strip() for p in parts] + [""] * (width[1] - len(parts)))
    return rows


def align(surface, reading):
    runs = []
    for char in surface:
        ruby = not (is_kana(char) or char == "ー")
        if runs and runs[-1][1] == ruby:
            runs[-1][0] += char
        else:
            runs.append([char, ruby])
    target = hiragana(reading)

    def solve(index, position):
        if index == len(runs):
            return [] if position == len(target) else None
        text, ruby = runs[index]
        if ruby:
            for end in range(position + 1, len(target) + 1):
                rest = solve(index + 1, end)
                if rest is not None:
                    return [(text, target[position:end])] + rest
            return None
        literal = hiragana(text)
        if target.startswith(literal, position):
            rest = solve(index + 1, position + len(literal))
            if rest is not None:
                return [(text, None)] + rest
        return None

    return solve(0, 0)


def kuru_reading(surface):
    if len(surface) >= 2 and surface[0] in "来來" and all(is_kana(c) for c in surface[1:]):
        stem = KURU_READING.get(surface[1])
        if stem:
            return stem + hiragana(surface[1:])
    return None


def surface_reading(surface, head, head_reading, whole=False):
    if not has_kanji(surface):
        return None
    if head in ("来る", "來る") and surface not in ("来る", "來る"):
        return kuru_reading(surface)
    if surface == head:
        return hiragana(head_reading)
    segments = align(head, head_reading)
    if segments is None:
        return None
    runs = []
    for char in surface:
        kind = is_kana(char) or char == "ー"
        if runs and runs[-1][1] == kind:
            runs[-1][0] += char
        else:
            runs.append([char, kind])
    result = []
    index = 0
    for number, (text, kana) in enumerate(runs):
        if kana:
            result.append(hiragana(text))
            continue
        found = head_span(segments, index, text)
        if found is None:
            return None
        index, spoken = found
        following = runs[number + 1][0] if number + 1 < len(runs) else ""
        if text[-1] in "来來" and spoken.endswith("く") and following:
            stem = KURU_READING.get(following[0])
            if stem:
                spoken = spoken[:-1] + stem
        result.append(spoken)
    rest = segments[index:]
    if whole and not runs[-1][1] and rest and all(ruby is None for _, ruby in rest):
        result.append(hiragana("".join(piece for piece, _ in rest)))
    return "".join(result)


def head_span(segments, index, text):
    for start in range(index, len(segments)):
        if segments[start][1] is None:
            continue
        letters = ""
        spoken = ""
        for end in range(start, len(segments)):
            piece, ruby = segments[end]
            spoken += ruby if ruby is not None else hiragana(piece)
            if ruby is None:
                continue
            letters += piece
            if letters == text:
                return end + 1, spoken
            if not text.startswith(letters):
                break
    return None


def kanji_catalog():
    readings = {}
    for path in sorted(KANJI_DATA.glob("alphabet-data-kanji*.swift")):
        source = path.read_text(encoding="utf-8")
        for glyph, _romaji, reading, _meaning in KANJI_CELL.findall(source):
            readings.setdefault(glyph, []).append(reading)
    others = (KANJI_DATA / "alphabet-data-kanji-readings.swift").read_text(encoding="utf-8")
    body = others.split("kanjiOtherReadings: [String: [String]] = [", 1)[1]
    for glyph, items in READINGS_ENTRY.findall(body):
        if glyph in readings:
            readings[glyph] += QUOTED.findall(items)
    return readings


def parse_jmdict(path, cache):
    cache = Path(cache)
    if cache.exists():
        return pickle.loads(cache.read_bytes())
    entries = []
    for _, element in ET.iterparse(path, events=("end",)):
        if element.tag != "entry":
            continue
        kebs = [
            {"text": k.findtext("keb"), "pri": [p.text for p in k.findall("ke_pri")], "inf": [i.text for i in k.findall("ke_inf")]}
            for k in element.findall("k_ele")
        ]
        rebs = [
            {
                "text": r.findtext("reb"),
                "pri": [p.text for p in r.findall("re_pri")],
                "restr": [x.text for x in r.findall("re_restr")],
                "nokanji": r.find("re_nokanji") is not None,
                "inf": [i.text for i in r.findall("re_inf")],
            }
            for r in element.findall("r_ele")
        ]
        senses = []
        last_pos = []
        for sense in element.findall("sense"):
            pos = [p.text for p in sense.findall("pos")] or last_pos
            last_pos = pos
            senses.append({
                "pos": pos,
                "misc": [m.text for m in sense.findall("misc")],
                "en": [g.text for g in sense.findall("gloss") if g.get(XML_LANG) in (None, "eng") and g.text],
                "ru": [g.text for g in sense.findall("gloss") if g.get(XML_LANG) == "rus" and g.text],
            })
        entries.append({"seq": int(element.findtext("ent_seq")), "kebs": kebs, "rebs": rebs, "senses": senses})
        element.clear()
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_bytes(pickle.dumps(entries))
    return entries


class Dictionary:
    def __init__(self, entries):
        self.entries = entries
        self.by_seq = {e["seq"]: e for e in entries}
        self.by_form = collections.defaultdict(set)
        for e in entries:
            for k in e["kebs"]:
                self.by_form[k["text"]].add(e["seq"])
            for r in e["rebs"]:
                self.by_form[r["text"]].add(e["seq"])

    @staticmethod
    def tags(entry):
        return {p for k in entry["kebs"] for p in k["pri"]} | {p for r in entry["rebs"] for p in r["pri"]}

    @staticmethod
    def news_band(entry):
        bands = [int(t[2:]) for t in Dictionary.tags(entry) if t.startswith("nf")]
        return min(bands) if bands else None

    def priority(self, entry):
        common = bool(self.tags(entry) & COMMON_TAGS)
        band = self.news_band(entry)
        return (0 if common else 1, band if band is not None else 99)

    def kana_fit(self, entry, head):
        if not all(is_kana(c) or c == "ー" for c in head):
            return 0 if any(k["text"] == head for k in entry["kebs"]) else 1
        if not entry["kebs"] or all(set(k["inf"]) & RARE_KANJI_FORM for k in entry["kebs"]):
            return 0
        if KANA_ONLY in entry["senses"][0]["misc"]:
            return 0
        reb_priority = any(r["text"] == head and r["pri"] for r in entry["rebs"])
        keb_priority = any(k["pri"] for k in entry["kebs"])
        return 1 if reb_priority and not keb_priority else 2

    def resolve(self, head, reading):
        if reading and reading.startswith("#"):
            seq = int(reading[1:]) if reading[1:].isdigit() else None
            return seq if seq in self.by_seq else None
        candidates = self.by_form.get(head, set())
        if reading:
            candidates = {s for s in candidates if any(r["text"] == reading for r in self.by_seq[s]["rebs"])}
        if not candidates:
            return None
        return min(candidates, key=lambda s: (
            script_clash(self.by_seq[s], head), self.kana_fit(self.by_seq[s], head), self.priority(self.by_seq[s]), s,
        ))

    def head_reading(self, seq, head, reading):
        entry = self.by_seq[seq]
        if reading and not reading.startswith("#"):
            return reading
        if all(is_kana(c) or c == "ー" for c in head):
            return head
        for r in entry["rebs"]:
            if r["nokanji"] or set(r["inf"]) & RARE_KANA_FORM:
                continue
            if r["restr"] and head not in r["restr"]:
                continue
            return r["text"]
        return entry["rebs"][0]["text"]


def parse_bline(line):
    tokens = []
    for raw in line.split(" "):
        match = TOKEN.match(raw)
        if not match:
            continue
        tokens.append({
            "head": match.group("head"),
            "reading": match.group("reading"),
            "form": match.group("form") or match.group("head"),
            "checked": bool(match.group("checked")),
        })
    return tokens


def tatoeba_index(path):
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        parts = line.split("\t")
        if len(parts) >= 3:
            yield parts[0], parts[1], parse_bline(parts[2])


def pos_code(pos):
    for needle, code in POS_RULES:
        if any(needle in p for p in pos):
            return code
    return None


GODAN_ROWS = {
    "く": "かきくけこい", "ぐ": "がぎぐげごい", "す": "さしすせそ", "つ": "たちつてとっ", "ぬ": "なにぬねのん",
    "ぶ": "ばびぶべぼん", "む": "まみむめもん", "る": "らりるれろっ", "う": "わいうえおっ",
}
ICHIDAN_NEXT = "まみたてなずるれろよらさちとつそやゃ"
ADJECTIVE_NEXT = ("い", "く", "か", "け", "さ", "そう", "すぎ", "げ", "め", "み")
KURU_READING = {"ま": "き", "た": "き", "て": "き", "ち": "き", "な": "こ", "よ": "こ", "い": "こ", "ら": "こ", "さ": "こ", "る": "く", "れ": "く"}


def conjugation(pos):
    joined = " | ".join(pos)
    if "Kuru verb" in joined:
        return "kuru"
    if "Iku/Yuku special class" in joined:
        return "iku"
    if "-aru special class" in joined:
        return "aru"
    if "suru verb" in joined and "noun or participle" not in joined:
        return "suru"
    if "Ichidan verb" in joined:
        return "ichidan"
    match = re.search(r"Godan verb with '(\w+)' ending", joined)
    if match:
        return "godan"
    if "adjective (keiyoushi)" in joined:
        return "adjective"
    return None


def continues_word(conj, ending, rest):
    if not rest:
        return True
    first = rest[0]
    if conj == "adjective":
        return rest.startswith(ADJECTIVE_NEXT)
    if conj == "ichidan":
        return first in ICHIDAN_NEXT
    if conj == "kuru":
        return first in KURU_READING
    if conj == "suru":
        return first in "さしすせ"
    if conj == "aru":
        return first in "いらりるれっ"
    if conj == "iku":
        return first in "かきくけこっ"
    if conj == "godan":
        row = GODAN_ROWS.get(ending, "")
        if row and first == row[0]:
            return len(rest) > 1 and rest[1] in "なれせず"
        return first in row
    return False


def clean_english(gloss):
    text = re.sub(
        r"\s*\((?:esp|e\.g|usu|i\.e|incl|as in|in|of|with|for|at|on|by|from|often|also|lit|orig|fig|formerly|abbr|polite|humble|honorific|colloquial|slang)\b[^)]*\)",
        "",
        gloss,
    )
    text = re.sub(r"\s+", " ", text).strip(" ;,")
    return text or gloss


def english_meaning(entry):
    result = []
    for gloss in (clean_english(g) for g in entry["senses"][0]["en"]):
        if not gloss or gloss in result:
            continue
        if result and len(", ".join(result + [gloss])) > 34:
            break
        result.append(gloss)
        if len(result) == 3:
            break
    return ", ".join(result) or (entry["senses"][0]["en"][0] if entry["senses"][0]["en"] else "")


def clean_russian(glosses):
    items = []
    for gloss in glosses:
        for piece in re.split(r";\s*|\s+(?=\d\)\s)", gloss):
            piece = re.sub(r"^\s*\d+\)\s*", "", piece)
            if RU_DROP.match(piece) or "(см.)" in piece:
                continue
            piece = re.sub(r"\{[^}]*\}", "", piece)
            piece = re.sub(r"\[[^\]]*\]", "", piece)
            piece = re.sub(r"\s*\([^)]*\)", "", piece)
            piece = re.sub(r"[:：]\s*$", "", piece)
            piece = re.sub(r"\s+", " ", piece).strip(" ,;:")
            if not piece or re.search(r"[぀-ヿ一-鿿]", piece):
                continue
            if piece not in items:
                items.append(piece)
    return items


def russian_suggestion(items):
    result = []
    for item in items:
        if result and len(", ".join(result + [item])) > 32:
            break
        result.append(item)
        if len(result) == 2:
            break
    return ", ".join(result)


def choose_forms(entry):
    first = entry["senses"][0]
    kebs = [k for k in entry["kebs"] if not set(k["inf"]) & RARE_KANJI_FORM]
    usable_rebs = [r for r in entry["rebs"] if not set(r["inf"]) & RARE_KANA_FORM] or entry["rebs"]
    usable_rebs = [r for r in usable_rebs if "・" not in r["text"]] or usable_rebs
    if not kebs or KANA_ONLY in first["misc"]:
        reading = usable_rebs[0]["text"].replace("・", "")
        return reading, reading
    plain = [k for k in kebs if not any(c.isdigit() for c in k["text"])] or kebs
    preferred = [k for k in plain if k["pri"]] or plain
    written = preferred[0]["text"]
    reading = next(
        (r["text"] for r in usable_rebs if not r["nokanji"] and not (r["restr"] and written not in r["restr"])),
        usable_rebs[0]["text"],
    ).replace("・", "")
    if align(written, reading) is None:
        swapped = written.replace("ヶ", "か").replace("ヵ", "か")
        if align(swapped, reading) is not None:
            written = swapped
    return written, reading


def spellable(kana):
    letters = 0
    for char in hiragana(unicodedata.normalize("NFC", kana)):
        if "ぁ" <= char <= "ゖ" or char in "ー〜":
            letters += char not in "ー〜っ"
            continue
        plain = unicodedata.normalize("NFKC", char)
        if len(plain) == 1 and plain.isascii() and plain.isalnum():
            letters += 1
            continue
        return False
    return letters > 0


def word_problem(word):
    if not word["pos"]:
        return "no part of speech"
    if not spellable(word["reading"]):
        return f"no romaji for {word['reading']}"
    if has_kanji(word["written"]):
        if any(not (is_kana(c) and "ぁ" <= hiragana(c) <= "ゖ" or c == "ー") for c in word["reading"]):
            return f"reading {word['reading']} is not kana"
        if align(word["written"], word["reading"]) is None:
            return f"{word['written']} does not align with {word['reading']}"
    return None


def exclusion(entry, written, en):
    first = entry["senses"][0]
    pos = set(first["pos"])
    if pos & GRAMMAR_POS:
        return "grammar"
    if pos and all(p in AFFIX_POS for p in pos):
        return "affix"
    if set(first["misc"]) & NAME_MISC:
        return "name"
    if set(first["misc"]) & OLD_MISC:
        return "old"
    if len(written) == 1 and is_kana(written):
        return "single kana"
    if "expressions (phrases, clauses, etc.)" in pos:
        kana = hiragana(entry["rebs"][0]["text"])
        if "..." in en or "…" in en or kana.startswith(GRAMMAR_STARTS) or len(kana) > 9:
            return "grammar phrase"
    return None


def step_words(args):
    work = Path(args.work)
    dictionary = Dictionary(parse_jmdict(args.jmdict, work / "jmdict.pkl"))
    catalog = kanji_catalog()
    tatoeba = Path(args.tatoeba)

    counts = collections.Counter()
    for _sid, _mid, tokens in tatoeba_index(tatoeba / "jpn_indices.csv"):
        seen = set()
        for token in tokens:
            seq = dictionary.resolve(token["head"], token["reading"])
            if seq is not None and seq not in seen:
                seen.add(seq)
                counts[seq] += 1
    tanaka_rank = {seq: i + 1 for i, (seq, count) in enumerate(counts.most_common()) if count >= 2}

    pinned = {int(row[0][1:]) for row in read_tsv(DATA / "pinned.tsv", (1, 2))}
    rows = []
    dropped = collections.Counter()
    for entry in dictionary.entries:
        tags = dictionary.tags(entry)
        band = dictionary.news_band(entry)
        news = (band - 1) * 500 + 250 if band else (12000 if "news1" in tags else (24000 if "news2" in tags else None))
        tanaka = tanaka_rank.get(entry["seq"])
        if news and tanaka:
            score = news ** 0.45 * tanaka ** 0.55
        elif tanaka:
            score = tanaka * (1.4 if tags & COMMON_TAGS else 2.5)
        elif news:
            score = news * 8.0
        elif tags & COMMON_TAGS:
            score = 40000
        else:
            continue
        written, reading = choose_forms(entry)
        reason = exclusion(entry, written, " ".join(entry["senses"][0]["en"]))
        if reason and entry["seq"] not in pinned:
            dropped[reason] += 1
            continue
        ru_items = clean_russian([g for s in entry["senses"] for g in s["ru"]])
        rows.append({
            "id": f"w{entry['seq']}",
            "seq": entry["seq"],
            "written": written,
            "reading": reading,
            "score": round(score, 1),
            "news": news,
            "tanaka": counts.get(entry["seq"], 0),
            "pos": pos_code(entry["senses"][0]["pos"]),
            "conj": conjugation(entry["senses"][0]["pos"]),
            "misc": entry["senses"][0]["misc"],
            "en": english_meaning(entry),
            "en_senses": [s["en"][:4] for s in entry["senses"][:3]],
            "ru": russian_suggestion(ru_items),
            "ru_hints": ru_items[:6],
            "kanji_missing": [c for c in written if is_kanji(c) and c != "々" and c not in catalog],
        })
    rows.sort(key=lambda r: (r["score"], r["seq"]))
    seen_forms = set()
    unique = []
    for row in rows:
        key = (row["written"], hiragana(row["reading"]))
        if key in seen_forms:
            dropped["duplicate form"] += 1
            continue
        seen_forms.add(key)
        unique.append(row)
    for index, row in enumerate(unique, 1):
        row["order"] = index
    save_json(work / "words.json", unique[:CANDIDATES])
    print(json.dumps({"candidates": len(unique), "kept": min(len(unique), CANDIDATES), "dropped": dropped}, ensure_ascii=False))


def read_folder(name, width):
    rows = []
    folder = DATA / name
    if not folder.exists():
        return rows
    for path in sorted(folder.glob("*.tsv")):
        rows += [(path.name, row) for row in read_tsv(path, width)]
    return rows


def load_decisions():
    decisions = {}
    for source, (word_id, ru, en) in read_folder("meanings", (2, 3)):
        if word_id in decisions:
            sys.exit(f"meanings/{source}: {word_id} appears twice")
        decisions[word_id] = {"ru": ru, "en": en}
    return decisions


def load_translations():
    translations = {}
    for source, (sid, ru, en) in read_folder("translations", (2, 3)):
        if sid in translations:
            sys.exit(f"translations/{source}: {sid} appears twice")
        translations[sid] = {"ru": ru, "en": en}
    return translations


def load_own_sentences():
    own = collections.defaultdict(list)
    for source, (word_id, japanese, ru, en) in read_folder("sentences", (4, 4)):
        own[word_id].append({"ja": japanese, "ru": ru, "en": en, "source": source})
    return own


def kept_words(work):
    words = load_json(Path(work) / "words.json", [])
    decisions = load_decisions()
    return [w for w in words if decisions.get(w["id"], {}).get("ru") != "-"]


def step_review(args):
    work = Path(args.work)
    words = load_json(work / "words.json", [])
    decisions = load_decisions()
    pending = []
    kept = 0
    for row in words:
        decision = decisions.get(row["id"])
        if decision:
            if decision["ru"] != "-":
                kept += 1
            continue
        pending.append(row)
    need = max(0, DECK_SIZE - kept)
    batch = pending[: min(args.size, need + args.spare)] if need else []
    folder = work / "review"
    folder.mkdir(parents=True, exist_ok=True)
    lines = []
    for row in batch:
        senses = " / ".join("; ".join(s) for s in row["en_senses"] if s)
        hints = "; ".join(row["ru_hints"][:5])
        flags = ",".join(x for x in [row["pos"] or "", "kana" if row["written"] == row["reading"] else ""] if x)
        lines.append(f"{row['id']}\t{row['written']}\t{row['reading']}\t{flags}\t{row['en']}\t{senses[:150]}\t{hints[:140]}")
    target = folder / f"batch-{args.name}.tsv"
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"kept": kept, "need": need, "pending": len(pending), "batch": len(batch), "file": str(target)}, ensure_ascii=False))


def read_sentences(path):
    texts = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        parts = line.split("\t")
        if len(parts) >= 3:
            texts[parts[0]] = parts[2]
    return texts


def read_links(path):
    links = collections.defaultdict(list)
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            links[parts[0]].append(parts[1])
    return links


def read_audio(path, japanese):
    audio = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        parts = line.split("\t")
        if len(parts) >= 4 and parts[0] in japanese and parts[0] not in audio:
            audio[parts[0]] = {"audio": parts[1], "speaker": parts[2], "license": parts[3]}
    return audio


def audio_license(audio):
    value = (audio or {}).get("license") or ""
    return "" if value == "\\N" else value


def usable_audio(audio, mode):
    if not audio:
        return False
    return mode == "all" or bool(audio_license(audio))


def pick_translation(ids, texts, preferred=None):
    if preferred and preferred in texts and preferred in ids:
        return preferred, texts[preferred]
    found = [(len(texts[i]), int(i), i) for i in ids if i in texts]
    if not found:
        return None, ""
    _, _, best = min(found)
    return best, texts[best]


def allowed_sentence(text):
    if not text or len(text) > MAX_SENTENCE_LENGTH:
        return False
    if any(c in "ゝゞヽヾヷヸヹヺゟヿ" for c in text):
        return False
    return all(is_kana(c) or is_kanji(c) or c in SENTENCE_STRIP or c == "ー" for c in text)


def locate(text, tokens):
    spans = []
    position = 0
    for token in tokens:
        start = text.find(token["form"], position)
        if start < 0:
            return None
        spans.append((start, start + len(token["form"])))
        position = start + len(token["form"])
    return spans


def tokenizer_binary(work):
    source = TOOL / "tokenize.swift"
    binary = Path(work) / "tokenize"
    if not binary.exists() or binary.stat().st_mtime < source.stat().st_mtime:
        subprocess.run(["xcrun", "swiftc", "-O", "-o", str(binary), str(source)], check=True)
    return binary


def step_tokenize(args):
    work = Path(args.work)
    tatoeba = Path(args.tatoeba)
    japanese = read_sentences(tatoeba / "jpn_sentences.tsv")
    russian = read_sentences(tatoeba / "rus_sentences.tsv")
    english = read_sentences(tatoeba / "eng_sentences.tsv")
    to_russian = read_links(tatoeba / "jpn-rus_links.tsv")
    to_english = read_links(tatoeba / "jpn-eng_links.tsv")
    audio = read_audio(tatoeba / "sentences_with_audio.csv", japanese)

    pool = {}
    for sid, mid, tokens in tatoeba_index(tatoeba / "jpn_indices.csv"):
        text = japanese.get(sid)
        if not allowed_sentence(text) or not tokens:
            continue
        ru_id, ru = pick_translation(to_russian.get(sid, []), russian)
        en_id, en = pick_translation(to_english.get(sid, []), english, preferred=mid)
        if not ru and not en and sid not in audio:
            continue
        pool[sid] = {"text": text, "bline": tokens, "ru": ru, "ru_id": ru_id, "en": en, "en_id": en_id, "audio": audio.get(sid)}
    for sid, text in japanese.items():
        if sid in pool or not allowed_sentence(text):
            continue
        ru_id, ru = pick_translation(to_russian.get(sid, []), russian)
        if sid not in audio and not ru:
            continue
        en_id, en = pick_translation(to_english.get(sid, []), english)
        pool[sid] = {"text": text, "bline": None, "ru": ru, "ru_id": ru_id, "en": en, "en_id": en_id, "audio": audio.get(sid)}

    save_json(work / "pool.json", pool)
    source = work / "tokenize-input.tsv"
    source.write_text("\n".join(f"{sid}\t{entry['text']}" for sid, entry in pool.items()) + "\n", encoding="utf-8")
    subprocess.run([str(tokenizer_binary(work)), str(source), str(work / "tokens.jsonl")], check=True)
    print(json.dumps({
        "pool": len(pool),
        "indexed": sum(1 for e in pool.values() if e["bline"]),
        "recorded": sum(1 for e in pool.values() if e["audio"]),
        "with russian": sum(1 for e in pool.values() if e["ru"]),
    }, ensure_ascii=False))


def load_tokens(work):
    tokens = {}
    for line in (Path(work) / "tokens.jsonl").read_text(encoding="utf-8").splitlines():
        entry = json.loads(line)
        tokens[entry["id"]] = [(t["s"], hiragana(t["r"]) if has_kanji(t["s"]) else "") for t in entry["t"]]
    return tokens


def boundaries(tokens):
    edges = {0}
    position = 0
    for surface, _ in tokens:
        position += len(surface)
        edges.add(position)
    return edges


def span_reading(tokens, start, end):
    position = 0
    pieces = []
    for surface, reading in tokens:
        token_end = position + len(surface)
        if token_end <= start:
            position = token_end
            continue
        if position >= end:
            break
        if position < start or token_end > end:
            return None
        pieces.append(reading if has_kanji(surface) else hiragana(surface))
        position = token_end
    return "".join(pieces) if pieces else None


def indexed_analysis(entry, tokens, dictionary):
    text = entry["text"]
    spans = locate(text, entry["bline"])
    if spans is None:
        return None
    pieces = []
    position = 0
    seqs = []
    for token, (start, end) in zip(entry["bline"], spans):
        if start > position:
            pieces.append({"start": position, "end": start, "kind": "gap"})
        seq = dictionary.resolve(token["head"], token["reading"])
        head_reading = dictionary.head_reading(seq, token["head"], token["reading"]) if seq else None
        whole = bool(seq) and conjugation(dictionary.by_seq[seq]["senses"][0]["pos"]) is None
        reading = surface_reading(token["form"], token["head"], head_reading, whole) if head_reading else None
        pieces.append({
            "start": start, "end": end, "kind": "word", "seq": seq, "head": token["head"],
            "head_reading": head_reading, "reading": reading, "checked": token["checked"],
        })
        seqs.append(seq)
        position = end
    if position < len(text):
        pieces.append({"start": position, "end": len(text), "kind": "gap"})
    return pieces


def doubtful_reading(token, piece, text):
    form, head = token["form"], token["head"]
    if not has_kanji(form) or not has_kanji(head):
        return False
    if any(is_kanji(c) and c not in head for c in form):
        return True
    start = piece["start"]
    after_numeral = start > 0 and text[start - 1] in NUMERALS
    return after_numeral and form.startswith("万") and (piece["reading"] or "").startswith("ばん")


def misread(tokens, dictionary):
    for surface, reading, _ in tokens:
        if not reading or not has_kanji(surface):
            continue
        readings = {
            hiragana(r["text"])
            for seq in dictionary.by_form.get(surface, ())
            for r in dictionary.by_seq[seq]["rebs"]
            if not r["restr"] or surface in r["restr"]
        }
        if readings and hiragana(reading) not in readings:
            return True
    return False


def kana_homonym(dictionary, word):
    if has_kanji(word["written"]):
        return False
    for seq in dictionary.by_form.get(word["written"], ()):
        if seq == word["seq"]:
            continue
        entry = dictionary.by_seq[seq]
        if not Dictionary.tags(entry) & COMMON_TAGS:
            continue
        if not entry["kebs"] or KANA_ONLY in entry["senses"][0]["misc"]:
            return True
    return False


def learn_fixes(pool, tokens, dictionary):
    stats = collections.defaultdict(collections.Counter)
    for sid, entry in pool.items():
        if not entry["bline"] or sid not in tokens:
            continue
        pieces = indexed_analysis(entry, tokens[sid], dictionary)
        if pieces is None:
            continue
        edges = boundaries(tokens[sid])
        for piece in pieces:
            if piece["kind"] != "word" or not piece["reading"]:
                continue
            if piece["start"] not in edges or piece["end"] not in edges:
                continue
            seen = span_reading(tokens[sid], piece["start"], piece["end"])
            if seen is None:
                continue
            surface = entry["text"][piece["start"]:piece["end"]]
            stats[(surface, seen)][piece["reading"]] += 1
    fixes = {}
    for (surface, seen), outcomes in stats.items():
        if len(surface) < 2:
            continue
        reading, count = outcomes.most_common(1)[0]
        total = sum(outcomes.values())
        if reading != seen and count >= FIX_SUPPORT and count / total >= FIX_SHARE:
            fixes[(surface, seen)] = reading
    for _source, (surface, reading) in read_folder("reading-fixes", (2, 2)):
        fixes[(surface, None)] = hiragana(reading)
    return fixes


def apply_fixes(tokens, fixes):
    result = []
    index = 0
    while index < len(tokens):
        replaced = False
        for length in (3, 2, 1):
            if index + length > len(tokens):
                continue
            chunk = tokens[index:index + length]
            surface = "".join(s for s, _ in chunk)
            if not has_kanji(surface):
                continue
            before = tokens[index - 1][0] if index > 0 else ""
            after = tokens[index + length][0] if index + length < len(tokens) else ""
            if (before and is_kanji(before[-1])) or (after and is_kanji(after[0])):
                continue
            seen = "".join(r if has_kanji(s) else hiragana(s) for s, r in chunk)
            fixed = fixes.get((surface, seen)) or fixes.get((surface, None))
            if fixed:
                result.append((surface, fixed))
                index += length
                replaced = True
                break
        if not replaced:
            result.append(tokens[index])
            index += 1
    return result


def fix_kuru(tokens):
    result = []
    for index, (surface, reading) in enumerate(tokens):
        if surface in ("来", "來") and index + 1 < len(tokens):
            following = tokens[index + 1][0]
            stem = KURU_READING.get(following[:1]) if following and is_kana(following[0]) else None
            if stem:
                result.append((surface, stem))
                continue
        fixed = kuru_reading(surface)
        result.append((surface, fixed) if fixed else (surface, reading))
    return result


def merge_inflections(tokens):
    merged = []
    for surface, reading in tokens:
        if merged:
            previous_surface, previous_reading = merged[-1]
            verb_like = has_kanji(previous_surface) and is_kana(previous_surface[-1])
            polite_negative = surface == "ん" and previous_surface.endswith("ませ")
            if (verb_like and surface in INFLECTION) or polite_negative:
                combined = previous_reading + hiragana(surface) if has_kanji(previous_surface) else ""
                merged[-1] = (previous_surface + surface, combined)
                continue
        merged.append((surface, reading))
    return merged


def word_pattern(word):
    written = word["written"]
    conj = word.get("conj")
    ending = written[-1]
    if not has_kanji(written):
        if len(written) < 3:
            return None
        inflects = conj is not None and is_kana(ending)
        text = written[:-1] if inflects else written
        return {"text": text, "core": None, "ruby": None, "inflects": inflects, "kana": True, "conj": conj, "ending": ending, "tail": True}
    segments = align(written, word["reading"])
    if segments is None:
        return None
    lead = ""
    for text, ruby in segments:
        if ruby is not None:
            break
        lead += text
    tail = ""
    for text, ruby in reversed(segments):
        if ruby is not None:
            break
        tail = text + tail
    core = written[len(lead):len(written) - len(tail)] if tail else written[len(lead):]
    inflects = conj is not None and bool(tail)
    text = lead + core + (tail[:-1] if inflects else tail)
    ruby = "".join(r for t, r in segments if r is not None)
    if conj == "kuru":
        ruby = None
    return {
        "text": text, "lead": lead, "core": core, "ruby": ruby, "inflects": inflects, "kana": False,
        "conj": conj, "ending": ending, "tail": bool(tail), "noun": word["pos"] in ("noun", "noun_suru"),
    }


def match_word(text, tokens, edges, pattern, start):
    end = start + len(pattern["text"])
    if not text.startswith(pattern["text"], start):
        return None
    position = 0
    first = None
    last = None
    for index, (surface, _) in enumerate(tokens):
        token_end = position + len(surface)
        if first is None and position <= start < token_end:
            first = index
            if position != start:
                return None
        if position < end <= token_end:
            last = index
            break
        position = token_end
    if first is None or last is None:
        return None
    if pattern["kana"] and end not in edges and tokens[first][0] in KANA_PARTICLES and len(tokens[first][0]) < len(pattern["text"]):
        return None
    before = tokens[first - 1][0] if first > 0 else ""
    if pattern["kana"] and pattern["text"].startswith(("た", "て", "ちゃ", "な")) and before[-1:] in STEM_ENDINGS and (has_kanji(before) or before in ("し", "み", "き")):
        return None
    token_end = sum(len(s) for s, _ in tokens[: last + 1])
    if not pattern["inflects"] and token_end != end:
        return None
    if pattern["inflects"] and token_end > end and not all(is_kana(c) for c in text[end:token_end]):
        return None
    if pattern["inflects"] and not continues_word(pattern["conj"], pattern["ending"], text[end:]):
        return None
    if pattern["conj"] == "kuru" and pattern["text"].endswith("く") and not text[end:].startswith(("る", "れば")):
        return None
    following = tokens[last + 1][0] if last + 1 < len(tokens) else ""
    previous = tokens[first - 1][0] if first > 0 else ""
    if not pattern["inflects"] and pattern["tail"] and following in INFLECTION:
        return None
    if pattern.get("noun") and pattern["tail"] and following and (is_kanji(following[0]) or following in VERB_AUXILIARY):
        return None
    if not pattern["kana"] and not pattern.get("lead") and previous and is_kanji(previous[-1]):
        return None
    if not pattern["inflects"] and not pattern["tail"] and following and is_kanji(following[0]):
        return None
    if not pattern["kana"] and not pattern["tail"] and following and "ァ" <= following[0] <= "ヺ":
        return None
    if pattern["kana"] and script(pattern["text"]) == "katakana":
        if (following and "ァ" <= following[0] <= "ヺ") or (previous and "ァ" <= previous[-1] <= "ヺ"):
            return None
    if not pattern["kana"] and pattern["ruby"] is not None:
        chunk = tokens[first:last + 1]
        chunk_surface = "".join(s for s, _ in chunk)
        chunk_reading = "".join(r if has_kanji(s) else hiragana(s) for s, r in chunk)
        segments = align(chunk_surface, chunk_reading)
        if segments is None:
            return None
        lead = pattern.get("lead", "")
        offset = 0
        ruby = []
        core_start = len(lead)
        core_end = core_start + len(pattern["core"])
        for segment_text, segment_ruby in segments:
            segment_start, segment_end = offset, offset + len(segment_text)
            offset = segment_end
            if segment_ruby is None:
                continue
            if segment_end <= core_start or segment_start >= core_end:
                continue
            if segment_start < core_start or segment_end > core_end:
                return None
            ruby.append(segment_ruby)
        if "".join(ruby) != pattern["ruby"]:
            return None
    last_index = last
    if pattern["inflects"]:
        while last_index + 1 < len(tokens) and tokens[last_index + 1][0] in INFLECTION:
            last_index += 1
    return first, last_index


def display_tokens(tokens, first, last):
    before = merge_inflections(tokens[:first])
    target_surface = "".join(s for s, _ in tokens[first:last + 1])
    target_reading = "".join(r if has_kanji(s) else hiragana(s) for s, r in tokens[first:last + 1]) if has_kanji(target_surface) else ""
    after = merge_inflections(tokens[last + 1:])
    return [[s, r, False] for s, r in before] + [[target_surface, target_reading, True]] + [[s, r, False] for s, r in after]


def indexed_tokens(entry, tokens, pieces, target_index, word):
    text = entry["text"]
    result = []
    word_count = -1
    for piece in pieces:
        surface = text[piece["start"]:piece["end"]]
        if piece["kind"] == "gap":
            position = 0
            inside = []
            for token_surface, token_reading in tokens:
                token_end = position + len(token_surface)
                if position >= piece["start"] and token_end <= piece["end"]:
                    inside.append((token_surface, token_reading))
                position = token_end
            if "".join(s for s, _ in inside) != surface:
                if has_kanji(surface):
                    return None
                inside = [(surface, "")]
            result += [[s, r if has_kanji(s) else "", False] for s, r in merge_inflections(inside)]
            continue
        word_count += 1
        is_target = word_count == target_index
        reading = piece["reading"] if has_kanji(surface) else ""
        if is_target and has_kanji(surface):
            reading = surface_reading(surface, word["written"], word["reading"], word.get("conj") is None) or reading
        if has_kanji(surface) and not reading:
            reading = span_reading(tokens, piece["start"], piece["end"]) or ""
        result.append([surface, reading, is_target])
    return result


def reading_stem(text, conj):
    if conj in ("kuru", "suru"):
        return text[:-2]
    if conj and len(text) > 1:
        return text[:-1]
    return text


def target_fits(word, tokens):
    targets = [(surface, reading) for surface, reading, target in tokens if target]
    if len(targets) != 1:
        return False
    surface, reading = targets[0]
    conj = word.get("conj")
    full = hiragana(word["reading"])
    stems = {reading_stem(full, conj)}
    if full.endswith("ない"):
        stems.add(full[:-2] + "ませ")
    if has_kanji(surface):
        spoken = hiragana(reading)
    elif has_kanji(word["written"]):
        spoken = hiragana(surface)
    else:
        stems.add(hiragana(reading_stem(word["written"], conj)))
        spoken = hiragana(surface)
    if surface[0] in "おご御" and spoken[:1] in ("お", "ご") and not full.startswith(spoken[:1]):
        spoken = spoken[1:]
    return any(spoken.startswith(stem) for stem in stems)


def kanji_part(surface, reading):
    if sum(1 for c in surface if is_kanji(c)) != 1 or not reading:
        return None
    segments = align(surface, reading)
    if not segments:
        return None
    rubies = [(text, ruby) for text, ruby in segments if ruby is not None]
    return (rubies[0][0], hiragana(rubies[0][1])) if len(rubies) == 1 else None


def reading_stats(tokens):
    stats = collections.defaultdict(collections.Counter)
    for raw in tokens.values():
        for surface, reading in raw:
            part = kanji_part(surface, reading)
            if part:
                stats[part[0]][part[1]] += 1
    return stats


def tokenizer_disagrees(result, raw, stats):
    position = 0
    for surface, reading, target in result:
        start, end = position, position + len(surface)
        position = end
        if not target:
            continue
        mine = kanji_part(surface, reading)
        seen = span_reading(raw, start, end)
        theirs = kanji_part(surface, seen) if seen else None
        if not mine or not theirs or mine[1] == theirs[1]:
            return False
        counts = stats.get(mine[0])
        if not counts:
            return False
        total = sum(counts.values())
        return counts[mine[1]] / total >= 0.1 and counts[theirs[1]] / total >= 0.1
    return False


def counter_without_number(word, tokens, counters):
    if word["id"] not in counters:
        return False
    previous = ""
    for surface, _, target in tokens:
        if target:
            return not previous or previous[-1] not in COUNTED
        previous = surface
    return False


def nani_misread(tokens):
    for index, (surface, reading, _) in enumerate(tokens):
        if surface != "何" or not reading:
            continue
        following = "".join(t[0] for t in tokens[index + 1:index + 3])
        expected = "なん" if following[:1] in "とだでのなねんて" or (following[:1] and is_kanji(following[0])) else "なに"
        if hiragana(reading) != expected:
            return True
    return False


def misplaced_conjunction(word, tokens):
    if word["pos"] != "conjunction" or hiragana(word["reading"]) in JOINING_CONJUNCTIONS:
        return False
    for index, (_, _, target) in enumerate(tokens):
        if target:
            previous = tokens[index - 1][0] if index > 0 else ""
            following = tokens[index + 1][0] if index + 1 < len(tokens) else ""
            if following in ("は", "も", "の", "が", "を") or following.startswith(FINE_WORDS):
                return True
            return bool(previous) and not all(c in PUNCTUATION for c in previous)
    return False


def inside_title(word, tokens):
    if word["written"].endswith(TITLE_SUFFIXES):
        return False
    for index, (_, _, target) in enumerate(tokens):
        if target:
            following = tokens[index + 1][0] if index + 1 < len(tokens) else ""
            return following.startswith(TITLE_SUFFIXES)
    return False


def verb_stem_nouns(words, dictionary):
    stems = set()
    for word in words:
        written = word["written"]
        if word["pos"] not in ("noun", "noun_suru") or len(written) != 1 or not has_kanji(written):
            continue
        reading = hiragana(word["reading"]) + "る"
        for seq in dictionary.by_form.get(written + "る", ()):
            if any(hiragana(r["text"]) == reading for r in dictionary.by_seq[seq]["rebs"]):
                stems.add(word["id"])
    return stems


def verb_use(word, tokens, stems):
    written = word["written"]
    if word["pos"] not in ("noun", "noun_suru") or not has_kanji(written):
        return False
    if not (is_kana(written[-1]) or len(written) == 1):
        return False
    for index, (_, _, target) in enumerate(tokens):
        if not target:
            continue
        following = tokens[index + 1][0] if index + 1 < len(tokens) else ""
        previous = tokens[index - 1][0] if index > 0 else ""
        if following.startswith(VERB_TAIL) or following in ("た", "たら", "たり"):
            return True
        if not is_kana(written[-1]) and word["id"] not in stems:
            return False
        return following.startswith(STEM_TAIL) or (previous in ("お", "ご", "御") and following.startswith(HONORIFIC_TAIL))
    return False


def valid_tokens(result):
    if not result or sum(1 for t in result if t[2]) != 1:
        return False
    for surface, reading, _ in result:
        if not surface or any(c in "[]|*()" for c in surface):
            return False
        if has_kanji(surface):
            if not reading or any(not ("ぁ" <= c <= "ゖ" or c == "ー") for c in reading):
                return False
            if align(surface, reading) is None:
                return False
        elif reading:
            return False
        if not all(c in PUNCTUATION for c in surface) and not spellable(reading or surface):
            return False
    return True


def step_sentences(args):
    work = Path(args.work)
    dictionary = Dictionary(parse_jmdict(args.jmdict, work / "jmdict.pkl"))
    catalog = kanji_catalog()
    words = kept_words(work)
    by_seq = {w["seq"]: w for w in words}
    order = {w["seq"]: w["order"] for w in words}
    pool = load_json(work / "pool.json", {})
    tokens = {sid: fix_kuru(value) for sid, value in load_tokens(work).items()}
    fixes = learn_fixes(pool, tokens, dictionary)
    translations = load_translations()
    translated = {sid for sid, item in translations.items() if item["ru"] != "-"}
    unusable = {sid for sid, item in translations.items() if item["ru"] == "-"}
    pool = {sid: entry for sid, entry in pool.items() if sid not in unusable}
    grammar_seqs = {e["seq"] for e in dictionary.entries if set(e["senses"][0]["pos"]) & GRAMMAR_POS}
    stems = verb_stem_nouns(words, dictionary)
    stats = reading_stats(tokens)
    counters = {
        w["id"] for w in words
        if w["pos"] == "counter" and any(g.lower().startswith("counter for") for g in dictionary.by_seq[w["seq"]]["senses"][0]["en"][:1])
    }

    rejected = collections.Counter()
    patterns = collections.defaultdict(list)
    for word in words:
        if kana_homonym(dictionary, word):
            rejected["kana homonym words"] += 1
            continue
        pattern = word_pattern(word)
        if pattern:
            patterns[pattern["text"][0]].append((word, pattern))

    candidates = collections.defaultdict(list)
    analysed = {}
    for sid, entry in pool.items():
        if sid not in tokens:
            continue
        text = entry["text"]
        raw = tokens[sid]
        outside = {c for c in text if is_kanji(c) and c != "々" and c not in catalog}
        if entry["bline"]:
            pieces = indexed_analysis(entry, raw, dictionary)
            if pieces is None:
                rejected["unaligned"] += 1
                continue
            words_in = [p for p in pieces if p["kind"] == "word"]
            ranks = [math.log(order.get(p["seq"], 20000)) for p in words_in if p["seq"] and p["seq"] not in grammar_seqs]
            difficulty = sum(ranks) / len(ranks) if ranks else 10.0
            analysed[sid] = {"pieces": pieces, "difficulty": difficulty}
            for index, piece in enumerate(words_in):
                word = by_seq.get(piece["seq"])
                if word is None or piece["head_reading"] is None:
                    continue
                if hiragana(piece["head_reading"]) != hiragana(word["reading"]):
                    continue
                if doubtful_reading(entry["bline"][index], piece, text):
                    rejected["doubtful reading"] += 1
                    continue
                surface = text[piece["start"]:piece["end"]]
                if outside - {c for c in surface}:
                    continue
                kana_use = has_kanji(word["written"]) and not has_kanji(surface)
                candidates[word["id"]].append({"sid": sid, "target": index, "checked": piece["checked"], "free": False, "kana_use": kana_use})
        else:
            fixed = fix_kuru(apply_fixes(raw, fixes))
            edges = boundaries(fixed)
            seen = set()
            ranks = []
            for start in sorted(edges):
                if start >= len(text):
                    continue
                for word, pattern in patterns.get(text[start], []):
                    if word["id"] in seen or not text.startswith(pattern["text"], start):
                        continue
                    found = match_word(text, fixed, edges, pattern, start)
                    if not found:
                        continue
                    seen.add(word["id"])
                    ranks.append(math.log(word["order"]))
                    surface = "".join(s for s, _ in fixed[found[0]:found[1] + 1])
                    if outside - {c for c in surface}:
                        continue
                    candidates[word["id"]].append({"sid": sid, "target": found, "checked": False, "free": True, "kana_use": False})
            difficulty = sum(ranks) / len(ranks) if ranks else 10.0
            analysed[sid] = {"fixed": fixed, "difficulty": difficulty}

    uses = collections.Counter()
    chosen = {}
    tiers = collections.Counter()
    excluded = {(word_id, sid) for _source, (word_id, sid) in read_folder("exclusions", (2, 2))}
    for word in words:
        options = []
        for candidate in candidates.get(word["id"], []):
            if (word["id"], candidate["sid"]) in excluded:
                rejected["excluded by hand"] += 1
                continue
            entry = pool[candidate["sid"]]
            recorded = usable_audio(entry["audio"], args.audio)
            has_ru = bool(entry["ru"]) or candidate["sid"] in translated
            if recorded and has_ru:
                tier = 0
            elif recorded:
                tier = 1
            elif candidate["checked"] and has_ru:
                tier = 2
            elif has_ru:
                tier = 3
            elif candidate["checked"]:
                tier = 4
            else:
                tier = 5
            length = len([c for c in entry["text"] if c not in SENTENCE_STRIP])
            low, high = IDEAL_SENTENCE_LENGTH
            penalty = max(0, low - length) + max(0, length - high)
            score = (
                tier * 100 + penalty * 3 + analysed[candidate["sid"]]["difficulty"] * 4
                + (8 if candidate["free"] else 0) + (40 if candidate["kana_use"] else 0)
            )
            options.append((score, int(candidate["sid"]), candidate, tier, has_ru, recorded))
        options.sort(key=lambda option: (option[0] + uses[option[2]["sid"]] * 6, option[1]))
        picked = []
        keys = set()
        needs_translation = 0
        needs_recorded = 0
        for _, _, candidate, tier, has_ru, recorded in options:
            if len(picked) >= MAX_SENTENCES:
                break
            sid = candidate["sid"]
            if uses[sid] >= MAX_USES_PER_SENTENCE:
                continue
            key = "".join(c for c in pool[sid]["text"] if c not in SENTENCE_STRIP)
            if key in keys:
                continue
            if not has_ru:
                if recorded:
                    if needs_recorded >= MAX_RECORDED_TRANSLATED:
                        continue
                elif needs_translation >= MAX_TRANSLATED or picked:
                    continue
            if candidate["free"]:
                first, last = candidate["target"]
                result = display_tokens(analysed[sid]["fixed"], first, last)
            else:
                result = indexed_tokens(pool[sid], tokens[sid], analysed[sid]["pieces"], candidate["target"], word)
            if result is None or not valid_tokens(result):
                rejected["readings"] += 1
                continue
            if misread(result, dictionary):
                rejected["misread"] += 1
                continue
            if not target_fits(word, result):
                rejected["target reading"] += 1
                continue
            if verb_use(word, result, stems):
                rejected["verb use"] += 1
                continue
            if misplaced_conjunction(word, result):
                rejected["conjunction inside a clause"] += 1
                continue
            if inside_title(word, result):
                rejected["part of a title"] += 1
                continue
            if tokenizer_disagrees(result, tokens[sid], stats):
                rejected["tokenizer reads it differently"] += 1
                continue
            if counter_without_number(word, result, counters):
                rejected["counter without a number"] += 1
                continue
            if nani_misread(result):
                rejected["何 read the wrong way"] += 1
                continue
            if not has_ru:
                if recorded:
                    needs_recorded += 1
                else:
                    needs_translation += 1
            keys.add(key)
            picked.append({"sid": sid, "tier": tier, "tokens": result})
        for item in picked:
            uses[item["sid"]] += 1
            tiers[item["tier"]] += 1
        chosen[word["id"]] = picked

    used = {item["sid"] for picks in chosen.values() for item in picks}
    save_json(work / "sentences.json", {
        "chosen": chosen,
        "sentences": {sid: {k: v for k, v in pool[sid].items() if k != "bline"} for sid in used},
    })
    without = [w["id"] for w in words[:DECK_SIZE] if not chosen.get(w["id"])]
    to_translate = sorted({sid for sid in used if not pool[sid]["ru"] and sid not in translated}, key=int)
    save_json(work / "without-sentences.json", without)
    print(json.dumps({
        "words": len(words),
        "deck words without sentences": len(without),
        "sentences": len(used),
        "recorded": sum(1 for sid in used if usable_audio(pool[sid]["audio"], args.audio)),
        "need translation": len(to_translate),
        "need english too": sum(1 for sid in to_translate if not pool[sid]["en"]),
        "fixes learned": len(fixes),
        "by tier": dict(sorted(tiers.items())),
        "rejected": rejected,
    }, ensure_ascii=False))


def final_words(work):
    decisions = load_decisions()
    words = []
    for word in load_json(Path(work) / "words.json", []):
        decision = decisions.get(word["id"])
        if not decision or decision["ru"] == "-":
            continue
        words.append((word, decision))
        if len(words) == DECK_SIZE:
            break
    return words


def step_todo(args):
    work = Path(args.work)
    selection = load_json(work / "sentences.json", {"chosen": {}, "sentences": {}})
    translations = load_translations()
    own = load_own_sentences()
    folder = work / "todo"
    folder.mkdir(parents=True, exist_ok=True)
    pending = {}
    lonely = []
    for word, decision in final_words(work):
        picks = selection["chosen"].get(word["id"], [])
        if not picks and not own.get(word["id"]):
            lonely.append(f"{word['id']}\t{word['written']}\t{word['reading']}\t{word['pos'] or ''}\t{decision['ru']}\t{decision['en'] or word['en']}")
        for pick in picks:
            sentence = selection["sentences"][pick["sid"]]
            translated = translations.get(pick["sid"], {})
            if translated.get("ru") == "-":
                continue
            if (translated.get("ru") or sentence["ru"]) and (translated.get("en") or sentence["en"]):
                continue
            entry = pending.setdefault(pick["sid"], {"sentence": sentence, "words": []})
            entry["words"].append(f"{word['written']}={decision['ru']}")
    ordered = sorted(pending.items(), key=lambda item: int(item[0]))
    batch = ordered[: args.size]
    lines = [
        f"{sid}\t{entry['sentence']['text']}\t{entry['sentence']['en'] or '-'}\t{'; '.join(entry['words'])}\t{entry['sentence']['ru'] or '-'}"
        for sid, entry in batch
    ]
    (folder / f"translate-{args.name}.tsv").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (folder / f"own-{args.name}.tsv").write_text("\n".join(lonely[: args.size]) + "\n", encoding="utf-8")
    print(json.dumps({
        "need translation": len(ordered),
        "need english too": sum(1 for _, e in ordered if not e["sentence"]["en"]),
        "batch": len(batch),
        "words without sentences": len(lonely),
    }, ensure_ascii=False))


def deck_tokens(tokens):
    pieces = []
    for surface, reading, target in tokens:
        piece = ("*" if target else "") + surface
        if reading:
            piece += f"[{reading}]"
        pieces.append(piece)
    return "|".join(pieces)


def parse_own(notation):
    tokens = []
    for piece in notation.split("|"):
        target = piece.startswith("*")
        piece = piece[1:] if target else piece
        reading = ""
        if piece.endswith("]") and "[" in piece:
            piece, reading = piece[:-1].split("[", 1)
        tokens.append([piece, reading, target])
    return tokens


def check_text(label, text, problems):
    if "—" in text or "–" in text:
        problems.append(f"{label}: long dash in {text}")
    if "\t" in text or "\n" in text:
        problems.append(f"{label}: control character")


def step_deck(args):
    work = Path(args.work)
    selection = load_json(work / "sentences.json", {"chosen": {}, "sentences": {}})
    translations = load_translations()
    own = load_own_sentences()
    tokenizer_readings = {}
    problems = []
    report = collections.Counter()
    speakers = collections.Counter()
    licenses = collections.Counter()
    synthesized_file = DATA / "synthesized-audio.txt"
    synthesized = set(synthesized_file.read_text(encoding="utf-8").split()) if synthesized_file.exists() else set()
    deck_words = []
    final = final_words(work)
    own_texts = {}
    for word_id, items in own.items():
        for index, item in enumerate(items):
            own_texts[f"{word_id}#{index}"] = "".join(t[0] for t in parse_own(item["ja"]))
    if own_texts:
        source = work / "own-input.tsv"
        source.write_text("\n".join(f"{key}\t{text}" for key, text in own_texts.items()) + "\n", encoding="utf-8")
        subprocess.run([str(tokenizer_binary(work)), str(source), str(work / "own-tokens.jsonl")], check=True)
        for line in (work / "own-tokens.jsonl").read_text(encoding="utf-8").splitlines():
            entry = json.loads(line)
            tokenizer_readings[entry["id"]] = "".join(
                hiragana(t["r"]) if has_kanji(t["s"]) else hiragana(t["s"]) for t in entry["t"]
            )
    disagreements = []
    for position, (word, decision) in enumerate(final, 1):
        ru = decision["ru"] if decision["ru"] != "=" else word["ru"]
        en = decision["en"] or word["en"]
        issue = word_problem(word)
        if issue:
            problems.append(f"{word['id']} {word['written']}: {issue}")
        check_text(word["id"], ru, problems)
        check_text(word["id"], en, problems)
        examples = []
        for pick in selection["chosen"].get(word["id"], []):
            sentence = selection["sentences"][pick["sid"]]
            translated = translations.get(pick["sid"], {})
            if translated.get("ru") == "-":
                report["sentences marked unusable"] += 1
                continue
            sentence_ru = translated.get("ru") or sentence["ru"]
            sentence_en = translated.get("en") or sentence["en"]
            if not sentence_ru or not sentence_en:
                report["sentences waiting for translation"] += 1
                continue
            if not valid_tokens(pick["tokens"]):
                report["sentences with bad readings"] += 1
                continue
            check_text(pick["sid"], sentence_ru, problems)
            check_text(pick["sid"], sentence_en, problems)
            example = {"ja": deck_tokens(pick["tokens"]), "ru": sentence_ru, "en": sentence_en, "tatoeba": int(pick["sid"])}
            if usable_audio(sentence["audio"], args.audio):
                example["audio"] = f"s{sentence['audio']['audio']}"
                if example["audio"] in synthesized:
                    example["by"] = SYNTHESIZED_VOICE
                    report["synthesized sentences"] += 1
                else:
                    rights = audio_license(sentence["audio"])
                    example["by"] = sentence["audio"]["speaker"]
                    if rights:
                        example["lic"] = rights
                    speakers[sentence["audio"]["speaker"]] += 1
                    licenses[rights or "unspecified"] += 1
                    report["recorded sentences"] += 1
            examples.append(example)
        if len(examples) < MAX_SENTENCES:
            for index, item in enumerate(own.get(word["id"], [])):
                if len(examples) >= MAX_SENTENCES:
                    break
                tokens = parse_own(item["ja"])
                if not valid_tokens(tokens):
                    problems.append(f"{word['id']}: own sentence has bad tokens: {item['ja']}")
                    continue
                expected = "".join(r if has_kanji(s) else hiragana(s) for s, r, _ in tokens)
                seen = tokenizer_readings.get(f"{word['id']}#{index}")
                if seen and seen != expected:
                    disagreements.append(f"{word['id']}\t{item['ja']}\t{seen}")
                check_text(word["id"], item["ru"], problems)
                check_text(word["id"], item["en"], problems)
                examples.append({"ja": item["ja"], "ru": item["ru"], "en": item["en"]})
                report["own sentences"] += 1
        if not examples:
            report["words without sentences"] += 1
        record = {
            "id": word["id"], "w": word["written"], "r": word["reading"], "en": en, "ru": ru,
            "rank": position, "sec": (position - 1) // SECTION_SIZE + 1, "ex": examples,
        }
        if word["pos"]:
            record["pos"] = word["pos"]
        deck_words.append(record)
        report["words"] += 1
        report["sentences"] += len(examples)

    used_speakers = ", ".join(name for name, _ in speakers.most_common())
    credits = [
        {
            "en": "Words, readings and meanings: JMdict by the Electronic Dictionary Research and Development Group (EDRDG), CC BY-SA 4.0. Russian meanings were rewritten for Moji. Order: newspaper frequency and the Tanaka corpus.",
            "ru": "Слова, чтения и значения: JMdict, Electronic Dictionary Research and Development Group (EDRDG), CC BY-SA 4.0. Русские значения переписаны для Moji. Порядок: частотность в газетах и корпус Танаки.",
        },
        {
            "en": "Example sentences and translations: Tatoeba (tatoeba.org), CC BY 2.0 FR. Each card shows the sentence number. Missing translations were written for Moji and some were corrected. Sentences without a number were written for Moji.",
            "ru": "Примеры и переводы: Tatoeba (tatoeba.org), CC BY 2.0 FR. На каждой карточке есть номер предложения. Недостающие переводы написаны для Moji, часть исправлена. Предложения без номера написаны для Moji.",
        },
        {
            "en": f"Sentence recordings: Tatoeba speakers {used_speakers}. Licenses vary by recording and are shown on the card.",
            "ru": f"Записи предложений: дикторы Tatoeba {used_speakers}. Лицензия у каждой записи своя, она указана на карточке.",
        },
        {
            "en": "Word recordings: JapanesePod101. Words and sentences with no recording are read by the AivisSpeech voice morioki.",
            "ru": "Записи слов: JapanesePod101. Слова и предложения без записи читает голос morioki из AivisSpeech.",
        },
    ]
    deck = {"version": 2, "credits": credits, "words": deck_words}
    for problem in problems[:40]:
        print("PROBLEM", problem)
    if problems:
        sys.exit(f"{len(problems)} problem(s), deck not written")
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(deck, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    (work / "own-disagreements.tsv").write_text("\n".join(disagreements) + "\n", encoding="utf-8")
    report["deck bytes"] = output.stat().st_size
    report["speakers"] = len(speakers)
    print(json.dumps({"report": report, "licenses": licenses, "reading disagreements in own sentences": len(disagreements)}, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("step", choices=["words", "review", "tokenize", "sentences", "todo", "deck"])
    parser.add_argument("--jmdict", default="")
    parser.add_argument("--tatoeba", default="")
    parser.add_argument("--work", required=True)
    parser.add_argument("--size", type=int, default=400)
    parser.add_argument("--spare", type=int, default=0)
    parser.add_argument("--name", default="next")
    parser.add_argument("--output", default=str(DECK))
    parser.add_argument("--audio", choices=["all", "licensed"], default="all")
    args = parser.parse_args()
    steps = {
        "words": step_words,
        "review": step_review,
        "tokenize": step_tokenize,
        "sentences": step_sentences,
        "todo": step_todo,
        "deck": step_deck,
    }
    steps[args.step](args)


if __name__ == "__main__":
    main()
