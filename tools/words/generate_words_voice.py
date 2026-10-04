#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DECK = ROOT / "Moji" / "Resources" / "WordDeck" / "moji-word-deck.json"
OUTPUT = ROOT / "Moji" / "Resources" / "Words"
CACHE = Path(tempfile.gettempdir()) / "moji-words-voice"

JPOD = "https://assets.languagepod101.com/dictionary/japanese/audiomp3.php"
JPOD_MISSING = "7e2c2f954ef6051373ba916f000168dc"
JPOD_DICTIONARY = "https://www.japanesepod101.com/learningcenter/reference/dictionary_post"
TATOEBA = "https://tatoeba.org/audio/download/{}"
TATOEBA_STATIC = "https://audio.tatoeba.org/sentences/jpn/{}.mp3"
TARGET_RMS = -14.0
WORD_BITRATE = 96000
SENTENCE_BITRATE = 64000
TRIM = ",".join([
    "aformat=sample_fmts=flt:channel_layouts=mono",
    "aresample=44100",
    "highpass=f=60",
    "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02",
    "areverse",
    "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.06",
    "areverse",
])

progress_lock = threading.Lock()


def to_hiragana(text):
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in text)


def get(url, data=None):
    request = urllib.request.Request(url, data=data, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def fetch(url, data=None, attempts=4):
    for attempt in range(attempts):
        try:
            return get(url, data)
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None
            time.sleep(1.5 * (attempt + 1))
        except Exception:
            time.sleep(1.5 * (attempt + 1))
    return None


def jpod(cache, word, kana):
    folder = cache / "jpod"
    folder.mkdir(parents=True, exist_ok=True)
    stem = hashlib.md5(f"{word}|{kana}".encode()).hexdigest()
    found, missing = folder / f"{stem}.mp3", folder / f"{stem}.none"
    if found.exists():
        return found
    if missing.exists():
        return None
    data = fetch(JPOD + "?" + urllib.parse.urlencode({"kanji": word, "kana": kana}))
    if data is None:
        return None
    if hashlib.md5(data).hexdigest() == JPOD_MISSING or len(data) < 1024:
        missing.touch()
        return None
    found.write_bytes(data)
    return found


def dictionary(cache, query):
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
    data = fetch(JPOD_DICTIONARY, body)
    if data is None:
        return []
    rows = []
    for chunk in data.decode("utf-8", errors="replace").split('dc-result-row"')[1:]:
        vocab = re.search(r"class='dc-vocab'>([^<]*)", chunk)
        kana = re.search(r"class='dc-vocab_kana'>([^<]*)", chunk)
        audio = re.search(r'src="(https://[^"]+\.mp3)"', chunk)
        if kana and audio:
            rows.append([vocab.group(1).strip() if vocab else "", kana.group(1).strip(), audio.group(1)])
    index.write_text(json.dumps(rows, ensure_ascii=False), encoding="utf-8")
    return rows


def dictionary_clip(cache, query, kana, word):
    wanted = {to_hiragana(kana)}
    for vocab, reading, url in dictionary(cache, query):
        if to_hiragana(reading) not in wanted or (word and vocab != word):
            continue
        target = cache / "dictionary" / f"{hashlib.md5(url.encode()).hexdigest()}.mp3"
        if not target.exists():
            data = fetch(url)
            if data is None or len(data) < 1024:
                continue
            target.write_bytes(data)
        return target
    return None


def load_kanji_forms(path, ids):
    import xml.etree.ElementTree as ElementTree
    forms = {}
    for _, element in ElementTree.iterparse(path, events=("end",)):
        if element.tag != "entry":
            continue
        sequence = element.findtext("ent_seq")
        word_id = f"w{sequence}"
        if word_id in ids:
            forms[word_id] = [keb.text for keb in element.iter("keb") if keb.text]
        element.clear()
    return forms


def word_source(cache, word, same_sound, kanji_forms=()):
    written, reading = word["w"], word["r"]
    attempts = [(written, reading)]
    if written != reading and to_hiragana(reading) != reading:
        attempts.append((written, to_hiragana(reading)))
    for form in kanji_forms:
        if form != written:
            attempts.append((form, to_hiragana(reading)))
    for kanji, kana in attempts:
        if path := jpod(cache, kanji, kana):
            return "jpod", path
    if path := dictionary_clip(cache, written, reading, written):
        return "jpod dictionary", path
    if written != reading and (path := dictionary_clip(cache, reading, reading, written)):
        return "jpod dictionary", path
    for form in kanji_forms:
        if form != written and (path := dictionary_clip(cache, form, reading, form)):
            return "jpod dictionary", path
    if same_sound and written != reading:
        if path := jpod(cache, reading, reading):
            return "same sound", path
    return None, None


def quick_fetch(url):
    try:
        data = get(url)
    except Exception:
        return None
    return data if len(data) >= 1024 else None


def load_single_recordings(path):
    counts = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        sentence = line.split("\t", 1)[0]
        counts[sentence] = counts.get(sentence, 0) + 1
    return {sentence for sentence, count in counts.items() if count == 1}


def word_source_offline(cache, word, kanji_forms=()):
    written, reading = word["w"], word["r"]
    attempts = [(written, reading), (written, to_hiragana(reading))]
    attempts += [(form, to_hiragana(reading)) for form in kanji_forms]
    for kanji, kana in attempts:
        found = cache / "jpod" / f"{hashlib.md5(f'{kanji}|{kana}'.encode()).hexdigest()}.mp3"
        if found.exists():
            return "jpod", found
    return None, None


def sentence_source(cache, audio_id, sentence_id=None, single_recordings=frozenset()):
    folder = cache / "tatoeba"
    folder.mkdir(parents=True, exist_ok=True)
    found, missing = folder / f"{audio_id}.mp3", folder / f"{audio_id}.none"
    if found.exists():
        return "tatoeba", found
    if missing.exists():
        return None, None
    if sentence_id is not None and str(sentence_id) in single_recordings:
        if data := quick_fetch(TATOEBA_STATIC.format(sentence_id)):
            found.write_bytes(data)
            return "tatoeba", found
    data = fetch(TATOEBA.format(audio_id))
    if data is None or len(data) < 1024:
        missing.touch()
        return None, None
    found.write_bytes(data)
    return "tatoeba", found


def rms_db(path):
    log = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "astats=measure_overall=RMS_level:measure_perchannel=none", "-f", "null", "-"],
        capture_output=True, text=True,
    ).stderr
    for line in log.splitlines():
        if "RMS level dB" in line:
            value = line.rsplit(":", 1)[1].strip()
            if value not in ("-inf", "inf", "nan"):
                return float(value)
    raise RuntimeError(f"no loudness for {path}")


def master(source, target, bitrate):
    with tempfile.TemporaryDirectory() as folder:
        trimmed = Path(folder) / "trimmed.wav"
        finished = Path(folder) / "finished.wav"
        encoded = Path(folder) / "encoded.m4a"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "quiet", "-i", str(source), "-af", TRIM, str(trimmed)], check=True)
        gain = TARGET_RMS - rms_db(trimmed)
        chain = f"volume={gain:.2f}dB,alimiter=limit=0.89:attack=1:release=50:level=false,adelay=80,apad=pad_dur=0.3"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "quiet", "-i", str(trimmed), "-af", chain, str(finished)], check=True)
        subprocess.run(
            ["afconvert", "-f", "m4af", "-d", "aac", "-b", str(bitrate), "-c", "1", str(finished), str(encoded)],
            check=True,
        )
        shutil.move(str(encoded), str(target))


def load_jobs(deck_path, only, limit, kind):
    deck = json.loads(Path(deck_path).read_text(encoding="utf-8"))
    words = deck.get("words", [])
    if limit:
        words = words[:limit]
    wanted = set(x for x in only.split(",") if x) if only else set()
    word_jobs = []
    sentence_jobs = {}
    for word in words:
        if kind in ("all", "words") and (not wanted or word["id"] in wanted):
            word_jobs.append(word)
        if kind in ("all", "sentences"):
            for example in word.get("ex", []):
                audio = example.get("audio")
                if not audio or not audio.startswith("s") or not audio[1:].isdigit():
                    continue
                if wanted and audio not in wanted and word["id"] not in wanted:
                    continue
                sentence_jobs.setdefault(audio, (audio[1:], example.get("tatoeba"), spoken_text(example["ja"])))
    return deck, word_jobs, sentence_jobs


def spoken_text(tokens):
    parts = []
    for token in tokens.split("|"):
        token = token.lstrip("*")
        if "[" in token and token.endswith("]"):
            token = token[token.index("[") + 1:-1]
        parts.append(token)
    return "".join(parts)


def synthesize(cache, engine, voice, text):
    folder = cache / "tts"
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / f"{hashlib.md5(f'{voice}|{text}'.encode()).hexdigest()}.wav"
    if target.exists():
        return target
    speakers = json.loads(get(f"{engine}/speakers"))
    style = next((s["styles"][0]["id"] for s in speakers if s["name"] == voice), None)
    if style is None:
        raise RuntimeError(f"voice {voice} is not installed in the engine at {engine}")
    query = json.loads(get(f"{engine}/audio_query?" + urllib.parse.urlencode({"text": text, "speaker": style}), b""))
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


class Progress:
    def __init__(self, label, total):
        self.label = label
        self.total = total
        self.done = 0

    def tick(self):
        with progress_lock:
            self.done += 1
            if self.done % 200 == 0 or self.done == self.total:
                print(f"{self.label}: {self.done}/{self.total}", file=sys.stderr, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--deck", default=str(DECK))
    parser.add_argument("--output", default=str(OUTPUT))
    parser.add_argument("--cache", default=str(CACHE))
    parser.add_argument("--only", default="")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--kind", choices=["all", "words", "sentences"], default="all")
    parser.add_argument("--same-sound", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--prune", action="store_true")
    parser.add_argument("--workers", type=int, default=6)
    parser.add_argument("--jmdict", default="")
    parser.add_argument("--audio-list", default="")
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--synthesize", action="store_true")
    parser.add_argument("--engine", default="http://127.0.0.1:10101")
    parser.add_argument("--voice", default="morioki")
    args = parser.parse_args()

    for tool in ("ffmpeg", "afconvert"):
        if shutil.which(tool) is None:
            sys.exit(f"{tool} is required")

    cache = Path(args.cache)
    output = Path(args.output)
    cache.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    deck, word_jobs, sentence_jobs = load_jobs(args.deck, args.only, args.limit, args.kind)

    word_sources = {}
    sentence_sources = {}
    word_counts = {}
    sentence_counts = {}
    word_missing = []
    sentence_missing = []
    broken = []
    present = {"words": 0, "sentences": 0}

    pending_words = []
    for word in word_jobs:
        if not args.force and (output / f"{word['id']}.m4a").exists():
            present["words"] += 1
        else:
            pending_words.append(word)
    pending_sentences = []
    for name, job in sentence_jobs.items():
        if not args.force and (output / f"{name}.m4a").exists():
            present["sentences"] += 1
        else:
            pending_sentences.append((name, job))

    kanji_forms = {}
    if args.jmdict and pending_words:
        kanji_forms = load_kanji_forms(args.jmdict, {word["id"] for word in pending_words})

    progress = Progress("words looked up", len(pending_words))

    def look_up_word(word):
        if args.offline:
            result = word_source_offline(cache, word, kanji_forms.get(word["id"], ()))
        else:
            result = word_source(cache, word, args.same_sound, kanji_forms.get(word["id"], ()))
        progress.tick()
        return word, result

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for word, (source, path) in pool.map(look_up_word, pending_words):
            if path:
                word_sources[word["id"]] = (source, path)
                word_counts[source] = word_counts.get(source, 0) + 1
            else:
                word_missing.append(word["id"])

    single_recordings = load_single_recordings(args.audio_list) if args.audio_list else frozenset()
    progress = Progress("sentences downloaded", len(pending_sentences))

    def download_sentence(item):
        name, (audio_id, sentence_id, _) = item
        if args.offline:
            cached = cache / "tatoeba" / f"{audio_id}.mp3"
            result = ("tatoeba", cached) if cached.exists() else (None, None)
        else:
            result = sentence_source(cache, audio_id, sentence_id, single_recordings)
        progress.tick()
        return name, result

    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        for name, (source, path) in pool.map(download_sentence, pending_sentences):
            if path:
                sentence_sources[name] = (source, path)
                sentence_counts[source] = sentence_counts.get(source, 0) + 1
            else:
                sentence_missing.append(name)

    synthesized = []
    if args.synthesize:
        texts = {word["id"]: word["r"] + "。" for word in pending_words if word["id"] in set(word_missing)}
        texts.update({name: job[2] for name, job in pending_sentences if name in set(sentence_missing)})
        progress = Progress("clips synthesized", len(texts))

        def speak(item):
            name, text = item
            try:
                path = synthesize(cache, args.engine, args.voice, text)
            except Exception as error:
                print(f"synthesis failed for {name}: {error}", file=sys.stderr, flush=True)
                path = None
            progress.tick()
            return name, path

        with ThreadPoolExecutor(max_workers=max(1, min(args.workers, 3))) as pool:
            spoken = list(pool.map(speak, texts.items()))
        for name, path in spoken:
            if path is None:
                continue
            if name.startswith("w"):
                word_sources[name] = ("morioki", path)
                word_counts["morioki"] = word_counts.get("morioki", 0) + 1
                word_missing.remove(name)
            else:
                sentence_sources[name] = ("morioki", path)
                sentence_counts["morioki"] = sentence_counts.get("morioki", 0) + 1
                sentence_missing.remove(name)
            synthesized.append(name)

    jobs = [(name, path, WORD_BITRATE) for name, (_, path) in word_sources.items()]
    jobs += [(name, path, SENTENCE_BITRATE) for name, (_, path) in sentence_sources.items()]
    progress = Progress("clips mastered", len(jobs))

    def run_master(job):
        name, path, bitrate = job
        try:
            master(path, output / f"{name}.m4a", bitrate)
            ok = True
        except Exception:
            ok = False
        progress.tick()
        return name, path, ok

    written = {"words": 0, "sentences": 0}
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for name, path, ok in pool.map(run_master, jobs):
            kind = "sentences" if name.startswith("s") else "words"
            if ok:
                written[kind] += 1
                continue
            broken.append(name)
            Path(path).unlink(missing_ok=True)
            if kind == "words":
                word_missing.append(name)
            else:
                sentence_missing.append(name)

    pruned = []
    if args.prune and not args.only and not args.limit and args.kind == "all":
        referenced = {f"{w['id']}.m4a" for w in deck.get("words", [])}
        for word in deck.get("words", []):
            for example in word.get("ex", []):
                if example.get("audio"):
                    referenced.add(f"{example['audio']}.m4a")
        for path in sorted(output.glob("*.m4a")):
            if path.name not in referenced:
                path.unlink()
                pruned.append(path.name)

    summary = {
        "output": str(output),
        "words": {
            "in deck": len(deck.get("words", [])),
            "requested": len(word_jobs),
            "already present": present["words"],
            "written": written["words"],
            "by source": word_counts,
            "missing": sorted(set(word_missing)),
        },
        "sentences": {
            "requested": len(sentence_jobs),
            "already present": present["sentences"],
            "written": written["sentences"],
            "by source": sentence_counts,
            "missing": sorted(set(sentence_missing)),
        },
        "broken downloads": sorted(broken),
        "pruned": pruned,
        "synthesized": sorted(name for name in synthesized if name not in set(broken)),
    }
    print(json.dumps(summary, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
