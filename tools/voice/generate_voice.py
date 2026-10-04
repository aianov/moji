#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "Moji" / "modules" / "alphabet" / "shared"
OUTPUT = ROOT / "Moji" / "Resources" / "Voice"
CACHE = Path(tempfile.gettempdir()) / "moji-voice"

NHK_PAGE = "https://www3.nhk.or.jp/nhkworld/lesson/en/letters/hiragana.html"
NHK_STREAM = "https://vod-stream.nhk.jp/nhkworld/lesson/assets/data/hls/{}/index.m3u8"
NHK_RENAMED = {"ji2": "di", "zu2": "du"}
JPOD = "https://assets.languagepod101.com/dictionary/japanese/audiomp3.php"
JPOD_MISSING = "7e2c2f954ef6051373ba916f000168dc"
JPOD_DICTIONARY = "https://www.japanesepod101.com/learningcenter/reference/dictionary_post"
ENGINE = "http://127.0.0.1:10101"
VOICE = "morioki"
TARGET_RMS = -14.0
BITRATE = 96000

KANA_WORDS = {
    "aa": ("嗚呼", "ああ"),
    "ii": ("良い", "いい"),
    "ee": ("ええ", "ええ"),
    "ei": ("英", "えい"),
    "ou": ("王", "おう"),
}
KANJI_WORDS = {
    "j-香": ("香り", "かおり"),
}
SOUND_ALIKE = {
    "こん": ("紺", "こん"),
    "でん": ("伝", "でん"),
    "がん": ("癌", "がん"),
    "みん": ("明", "みん"),
    "ぼう": ("棒", "ぼう"),
    "そく": ("足", "そく"),
    "わく": ("枠", "わく"),
    "らん": ("欄", "らん"),
    "らく": ("楽", "らく"),
}

KANA_PATTERN = re.compile(r'\.kana\("([^"]+)", "([^"]+)"(?:, id: "([^"]+)")?\)')
KANJI_PATTERN = re.compile(r'\.kanji\("([^"]+)", "([^"]+)", "([^"]+)", "([^"]+)"')
TRIM = ",".join([
    "aformat=sample_fmts=flt:channel_layouts=mono",
    "aresample=44100",
    "highpass=f=60",
    "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02",
    "areverse",
    "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.06",
    "areverse",
])


def resource_name(character_id: str) -> str:
    parts = []
    for char in character_id:
        if char.isascii() and (char.isalnum() or char == "-"):
            parts.append(char)
        else:
            parts.append(f"u{ord(char):X}")
    return "voice-" + "".join(parts)


def to_katakana(text: str) -> str:
    return "".join(chr(ord(c) + 0x60) if "ぁ" <= c <= "ゖ" else c for c in text)


def load_kana():
    source = (DATA / "alphabet-data-kana.swift").read_text(encoding="utf-8")
    items = []
    for script, prefix in [("hiragana", "h"), ("katakana", "k")]:
        start = source.index(f"static let {script} =")
        chunk = source[start:].split("lookAlikes:")[0]
        for glyph, romaji, override in KANA_PATTERN.findall(chunk):
            key = override or romaji
            items.append({"id": f"{prefix}-{key}", "key": key, "glyph": glyph, "script": script})
    return items


def load_kanji():
    items = {}
    for name in sorted(DATA.glob("alphabet-data-kanji*.swift")):
        source = name.read_text(encoding="utf-8")
        for glyph, _romaji, reading, _meaning in KANJI_PATTERN.findall(source):
            plain = reading.replace("(", "").replace(")", "")
            ending = reading[reading.index("(") + 1:reading.index(")")] if "(" in reading else ""
            items.setdefault(f"j-{glyph}", {"id": f"j-{glyph}", "glyph": glyph, "word": glyph + ending, "kana": plain})
    return list(items.values())


def morae(kana: str) -> int:
    return len([char for char in kana if char not in "ゃゅょャュョ"])


def get(url: str, data: bytes | None = None) -> bytes:
    request = urllib.request.Request(url, data=data, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def nhk_clips(cache: Path) -> dict:
    folder = cache / "nhk"
    folder.mkdir(parents=True, exist_ok=True)
    page = folder / "page.html"
    if not page.exists():
        page.write_bytes(get(NHK_PAGE))
    html = page.read_text(encoding="utf-8")
    pairs = re.findall(
        r'data-audio="(\d+)"><i class="icn-play"></i></div>\s*<figure>\s*<img src="/nhkworld/lesson/assets/images/letters/detail/hira/([a-z0-9]+)\.png"',
        html,
    )

    def download(pair):
        number, name = pair
        target = folder / f"{number}.m4a"
        if not target.exists():
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", NHK_STREAM.format(number), "-vn", "-c", "copy", str(target)],
                check=True,
            )
        return NHK_RENAMED.get(name, name), target

    with ThreadPoolExecutor(max_workers=6) as pool:
        return dict(pool.map(download, pairs))


def jpod(cache: Path, word: str, kana: str) -> Path | None:
    folder = cache / "jpod"
    folder.mkdir(parents=True, exist_ok=True)
    stem = hashlib.md5(f"{word}|{kana}".encode()).hexdigest()
    found, missing = folder / f"{stem}.mp3", folder / f"{stem}.none"
    if found.exists():
        return found
    if missing.exists():
        return None
    data = None
    for _ in range(3):
        try:
            data = get(JPOD + "?" + urllib.parse.urlencode({"kanji": word, "kana": kana}))
            break
        except Exception:
            continue
    if data is None or hashlib.md5(data).hexdigest() == JPOD_MISSING:
        missing.touch()
        return None
    found.write_bytes(data)
    return found


def dictionary(cache: Path, query: str) -> list:
    folder = cache / "dictionary"
    folder.mkdir(parents=True, exist_ok=True)
    index = folder / f"{hashlib.md5(query.encode()).hexdigest()}.json"
    if index.exists():
        return json.loads(index.read_text(encoding="utf-8"))
    body = urllib.parse.urlencode({
        "post": "dictionary_reference",
        "match_type": "exact",
        "search_query": query,
        "vulgar": "true",
    }).encode()
    html = None
    for _ in range(3):
        try:
            html = get(JPOD_DICTIONARY, body).decode("utf-8")
            break
        except Exception:
            continue
    if html is None:
        return []
    rows = []
    for chunk in html.split('dc-result-row"')[1:]:
        vocab = re.search(r"class='dc-vocab'>([^<]*)", chunk)
        kana = re.search(r"class='dc-vocab_kana'>([^<]*)", chunk)
        audio = re.search(r'src="(https://[^"]+\.mp3)"', chunk)
        if kana and audio:
            rows.append([vocab.group(1).strip() if vocab else "", kana.group(1).strip(), audio.group(1)])
    index.write_text(json.dumps(rows, ensure_ascii=False), encoding="utf-8")
    return rows


def dictionary_clip(cache: Path, query: str, kana: str, word: str = "") -> Path | None:
    for vocab, reading, url in dictionary(cache, query):
        if reading != kana or (word and vocab != word):
            continue
        target = cache / "dictionary" / f"{hashlib.md5(url.encode()).hexdigest()}.mp3"
        if not target.exists():
            try:
                data = get(url)
            except Exception:
                continue
            if len(data) < 1024:
                continue
            target.write_bytes(data)
        return target
    return None


def synthesize(cache: Path, engine: str, voice: str, text: str) -> Path:
    folder = cache / "tts"
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / f"{hashlib.md5(f'{voice}|{text}'.encode()).hexdigest()}.wav"
    if target.exists():
        return target
    with urllib.request.urlopen(f"{engine}/speakers", timeout=60) as response:
        speakers = json.load(response)
    style = next((s["styles"][0]["id"] for s in speakers if s["name"] == voice), None)
    if style is None:
        sys.exit(f"voice {voice} is not installed in the engine at {engine}")
    query = json.loads(get(f"{engine}/audio_query?" + urllib.parse.urlencode({"text": text + "。", "speaker": style}), b""))
    query["prePhonemeLength"] = 0.1
    query["postPhonemeLength"] = 0.2
    request = urllib.request.Request(
        f"{engine}/synthesis?" + urllib.parse.urlencode({"speaker": style}),
        data=json.dumps(query).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=300) as response:
        target.write_bytes(response.read())
    return target


def rms_db(path: Path) -> float:
    log = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "astats=measure_overall=RMS_level:measure_perchannel=none", "-f", "null", "-"],
        capture_output=True, text=True,
    ).stderr
    for line in log.splitlines():
        if "RMS level dB" in line:
            return float(line.rsplit(":", 1)[1])
    raise RuntimeError(f"no loudness for {path}")


def master(source: Path, target: Path) -> None:
    with tempfile.TemporaryDirectory() as folder:
        trimmed = Path(folder) / "trimmed.wav"
        finished = Path(folder) / "finished.wav"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "quiet", "-i", str(source), "-af", TRIM, str(trimmed)], check=True)
        gain = TARGET_RMS - rms_db(trimmed)
        chain = f"volume={gain:.2f}dB,alimiter=limit=0.89:attack=1:release=50:level=false,adelay=80,apad=pad_dur=0.3"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "quiet", "-i", str(trimmed), "-af", chain, str(finished)], check=True)
        subprocess.run(
            ["afconvert", "-f", "m4af", "-d", "aac", "-b", str(BITRATE), "-c", "1", str(finished), str(target)],
            check=True,
        )


def plan(cache: Path, engine: str, voice: str):
    nhk = nhk_clips(cache)
    kana_items = load_kana()
    kanji_items = load_kanji()
    hiragana_key = {item["glyph"]: item["key"] for item in kana_items if item["script"] == "hiragana"}

    sources = {}
    for item in kana_items:
        key = item["key"]
        if key in nhk:
            sources[item["id"]] = ("nhk", nhk[key])
        elif key in KANA_WORDS and (path := jpod(cache, *KANA_WORDS[key])):
            sources[item["id"]] = ("word", path)
        else:
            sources[item["id"]] = ("tts", to_katakana(item["glyph"]))

    with ThreadPoolExecutor(max_workers=8) as pool:
        direct = dict(zip(
            [item["id"] for item in kanji_items],
            pool.map(lambda item: jpod(cache, item["word"], item["kana"]), kanji_items),
        ))
    lacking = [item for item in kanji_items if not direct[item["id"]]]
    with ThreadPoolExecutor(max_workers=6) as pool:
        listed = dict(zip(
            [item["id"] for item in lacking],
            pool.map(lambda item: dictionary_clip(cache, item["word"], item["kana"], item["word"]), lacking),
        ))
        list(pool.map(lambda kana: dictionary(cache, kana), sorted({item["kana"] for item in lacking})))
    by_sound = {}
    for item in kanji_items:
        if clip := direct[item["id"]] or listed.get(item["id"]):
            by_sound.setdefault(item["kana"], clip)

    for item in kanji_items:
        kana = item["kana"]
        if direct[item["id"]]:
            sources[item["id"]] = ("word", direct[item["id"]])
        elif listed.get(item["id"]):
            sources[item["id"]] = ("word", listed[item["id"]])
        elif path := jpod(cache, kana, kana):
            sources[item["id"]] = ("same sound", path)
        elif item["id"] in KANJI_WORDS and (path := jpod(cache, *KANJI_WORDS[item["id"]])):
            sources[item["id"]] = ("word", path)
        elif morae(kana) == 1 and hiragana_key.get(kana) in nhk:
            sources[item["id"]] = ("nhk", nhk[hiragana_key[kana]])
        elif kana in by_sound:
            sources[item["id"]] = ("same sound", by_sound[kana])
        elif path := dictionary_clip(cache, kana, kana):
            sources[item["id"]] = ("same sound", path)
        elif kana in SOUND_ALIKE and (path := jpod(cache, *SOUND_ALIKE[kana])):
            sources[item["id"]] = ("same sound", path)
        else:
            sources[item["id"]] = ("tts", to_katakana(kana))

    for item_id, (kind, value) in list(sources.items()):
        if kind == "tts":
            sources[item_id] = ("tts", synthesize(cache, engine, voice, value), value)
    return sources


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", default=str(CACHE))
    parser.add_argument("--output", default=str(OUTPUT))
    parser.add_argument("--engine", default=ENGINE)
    parser.add_argument("--voice", default=VOICE)
    parser.add_argument("--only", default="")
    args = parser.parse_args()

    cache = Path(args.cache)
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    sources = plan(cache, args.engine, args.voice)
    if args.only:
        wanted = set(args.only.split(","))
        sources = {key: value for key, value in sources.items() if key in wanted}

    names = {item_id: resource_name(item_id) for item_id in sources}
    if len(set(names.values())) != len(names):
        sys.exit("resource names collide")

    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(lambda item_id: master(sources[item_id][1], output / f"{names[item_id]}.m4a"), sources))

    counts = {}
    for value in sources.values():
        counts[value[0]] = counts.get(value[0], 0) + 1
    synthesized = sorted(item_id for item_id, value in sources.items() if value[0] == "tts")
    print(json.dumps({"written": len(sources), "by_source": counts, "synthesized": synthesized}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
