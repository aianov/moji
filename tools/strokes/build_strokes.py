import argparse
import json
import math
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "Moji" / "modules" / "alphabet" / "shared"
OUTPUT = ROOT / "Moji" / "Resources" / "Strokes" / "moji-strokes.dat"

MAGIC = b"MJSK"
VERSION = 1
GRID = 109
QUANTUM = 20
FLATNESS = 0.004
TOLERANCE = 0.08
LONG_VOWEL = 0x30FC
SYNTHETIC = {LONG_VOWEL: [[(14.5, 53.0), (94.62, 50.38)]]}
HEADER = struct.Struct("<4sHHHHI")
ENTRY = struct.Struct("<II")

KANA_PATTERN = re.compile(r'\.kana\("([^"]+)", "([^"]+)"(?:, id: "([^"]+)")?\)')
KANJI_PATTERN = re.compile(r'\.kanji\("([^"]+)", "([^"]+)", "([^"]+)", "([^"]+)"')
PATH_PATTERN = re.compile(r"<path\b[^>]*>")
STROKE_ID_PATTERN = re.compile(r'\bid="kvg:([0-9a-fA-F]+)-s(\d+)"')
DATA_PATTERN = re.compile(r'\bd="([^"]*)"')
TOKEN_PATTERN = re.compile(r"[MmLlHhVvCcSsQqTtZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")
ARITY = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "T": 2}


def app_code_points():
    kana = (DATA / "alphabet-data-kana.swift").read_text(encoding="utf-8")
    points = {ord(char) for glyph, _, _ in KANA_PATTERN.findall(kana) for char in glyph}
    kanji = set()
    for name in sorted(DATA.glob("alphabet-data-kanji*.swift")):
        source = name.read_text(encoding="utf-8")
        kanji.update(ord(char) for glyph, _, _, _ in KANJI_PATTERN.findall(source) for char in glyph)
    return sorted(points), sorted(kanji)


def tokenize(data):
    leftover = TOKEN_PATTERN.sub(" ", data).replace(",", " ").strip()
    if leftover:
        raise ValueError(f"unexpected path data {leftover!r}")
    return TOKEN_PATTERN.findall(data)


def reflect(control, kind, x, y):
    if control is None or control[0] != kind:
        return (x, y)
    return (2 * x - control[1][0], 2 * y - control[1][1])


def segments(data):
    tokens = tokenize(data)
    result = []
    index = 0
    command = None
    x = y = 0.0
    start = (0.0, 0.0)
    control = None
    while index < len(tokens):
        if tokens[index].isalpha():
            command = tokens[index]
            index += 1
            if command in "Zz":
                if result and (x, y) != start:
                    result.append(("line", (x, y), start))
                x, y = start
                control = None
                command = None
                continue
        if command is None:
            raise ValueError("path data has numbers without a command")
        upper = command.upper()
        count = ARITY[upper]
        chunk = tokens[index:index + count]
        if len(chunk) < count or any(item.isalpha() for item in chunk):
            raise ValueError(f"command {command} needs {count} numbers")
        values = [float(item) for item in chunk]
        index += count
        relative = command.islower()
        dx, dy = (x, y) if relative else (0.0, 0.0)
        if upper == "M":
            x, y = values[0] + dx, values[1] + dy
            start = (x, y)
            result.append(("move", (x, y)))
            command = "l" if relative else "L"
            control = None
        elif upper in "LHV":
            if upper == "L":
                target = (values[0] + dx, values[1] + dy)
            elif upper == "H":
                target = (values[0] + dx, y)
            else:
                target = (x, values[0] + dy)
            result.append(("line", (x, y), target))
            x, y = target
            control = None
        elif upper in "CS":
            if upper == "C":
                first = (values[0] + dx, values[1] + dy)
                rest = values[2:]
            else:
                first = reflect(control, "C", x, y)
                rest = values
            second = (rest[0] + dx, rest[1] + dy)
            end = (rest[2] + dx, rest[3] + dy)
            result.append(("cubic", (x, y), first, second, end))
            control = ("C", second)
            x, y = end
        else:
            if upper == "Q":
                handle = (values[0] + dx, values[1] + dy)
                end = (values[2] + dx, values[3] + dy)
            else:
                handle = reflect(control, "Q", x, y)
                end = (values[0] + dx, values[1] + dy)
            result.append(("quad", (x, y), handle, end))
            control = ("Q", handle)
            x, y = end
    return result


def distance_to_segment(point, start, end):
    vx, vy = end[0] - start[0], end[1] - start[1]
    wx, wy = point[0] - start[0], point[1] - start[1]
    span = vx * vx + vy * vy
    if span == 0:
        return math.hypot(wx, wy)
    t = max(0.0, min(1.0, (wx * vx + wy * vy) / span))
    return math.hypot(wx - t * vx, wy - t * vy)


def midpoint(a, b):
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)


def cubic(points, p0, p1, p2, p3, depth=0):
    if depth >= 18 or max(distance_to_segment(p1, p0, p3), distance_to_segment(p2, p0, p3)) <= FLATNESS:
        points.append(p3)
        return
    a, b, c = midpoint(p0, p1), midpoint(p1, p2), midpoint(p2, p3)
    d, e = midpoint(a, b), midpoint(b, c)
    m = midpoint(d, e)
    cubic(points, p0, a, d, m, depth + 1)
    cubic(points, m, e, c, p3, depth + 1)


def flatten(parts):
    paths = []
    for part in parts:
        kind = part[0]
        if kind == "move":
            paths.append([part[1]])
            continue
        if not paths:
            raise ValueError("path draws before its first move")
        points = paths[-1]
        if kind == "line":
            points.append(part[2])
        elif kind == "cubic":
            cubic(points, *part[1:])
        else:
            p0, handle, p3 = part[1:]
            first = (p0[0] + 2 / 3 * (handle[0] - p0[0]), p0[1] + 2 / 3 * (handle[1] - p0[1]))
            second = (p3[0] + 2 / 3 * (handle[0] - p3[0]), p3[1] + 2 / 3 * (handle[1] - p3[1]))
            cubic(points, p0, first, second, p3)
    return [path for path in paths if len(path) > 1]


def deduplicate(points):
    result = []
    for point in points:
        if not result or point != result[-1]:
            result.append(point)
    return result


def simplify(points, tolerance):
    points = deduplicate(points)
    if len(points) <= 2:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    pending = [(0, len(points) - 1)]
    while pending:
        first, last = pending.pop()
        farthest, distance = None, -1.0
        for index in range(first + 1, last):
            gap = distance_to_segment(points[index], points[first], points[last])
            if gap > distance:
                farthest, distance = index, gap
        if farthest is not None and distance > tolerance:
            keep[farthest] = True
            pending.append((first, farthest))
            pending.append((farthest, last))
    return [point for point, kept in zip(points, keep) if kept]


def deviation(dense, sparse):
    worst = 0.0
    for point in dense:
        nearest = min(distance_to_segment(point, sparse[i], sparse[i + 1]) for i in range(len(sparse) - 1))
        worst = max(worst, nearest)
    return worst


def quantize(points):
    return deduplicate([(round(x * QUANTUM), round(y * QUANTUM)) for x, y in points])


def read_glyph(source, code_point):
    path = source / f"{code_point:05x}.svg"
    if not path.exists():
        if code_point in SYNTHETIC:
            return [list(stroke) for stroke in SYNTHETIC[code_point]], [list(stroke) for stroke in SYNTHETIC[code_point]], "synthetic"
        return None, None, "missing"
    text = path.read_text(encoding="utf-8")
    numbered = []
    for tag in PATH_PATTERN.findall(text):
        ident = STROKE_ID_PATTERN.search(tag)
        data = DATA_PATTERN.search(tag)
        if ident is None or data is None:
            continue
        if int(ident.group(1), 16) != code_point:
            raise ValueError(f"{path.name}: stroke id {ident.group(0)} belongs to another character")
        subpaths = flatten(segments(data.group(1)))
        if len(subpaths) != 1:
            raise ValueError(f"{path.name}: stroke {ident.group(2)} has {len(subpaths)} pieces")
        numbered.append((int(ident.group(2)), subpaths[0]))
    numbered.sort(key=lambda item: item[0])
    order = [number for number, _ in numbered]
    if order != list(range(1, len(order) + 1)):
        raise ValueError(f"{path.name}: stroke numbers {order} are not 1 to {len(order)}")
    dense = [deduplicate(points) for _, points in numbered]
    return dense, [simplify(points, TOLERANCE) for points in dense], "kanjivg"


def encode(glyphs):
    records = bytearray()
    entries = []
    base = HEADER.size + ENTRY.size * len(glyphs)
    for code_point, strokes in glyphs:
        if not 0 < len(strokes) < 256:
            raise ValueError(f"U+{code_point:04X} has {len(strokes)} strokes")
        entries.append((code_point, base + len(records)))
        records += struct.pack("<B", len(strokes))
        for stroke in strokes:
            if not 2 <= len(stroke) < 65536:
                raise ValueError(f"U+{code_point:04X} has a stroke of {len(stroke)} points")
            records += struct.pack("<H", len(stroke))
            for x, y in stroke:
                records += struct.pack("<hh", x, y)
    head = HEADER.pack(MAGIC, VERSION, GRID, QUANTUM, 0, len(glyphs))
    index = b"".join(ENTRY.pack(code_point, offset) for code_point, offset in entries)
    return head + index + bytes(records)


def decode(blob):
    magic, version, grid, quantum, _, count = HEADER.unpack_from(blob, 0)
    if magic != MAGIC or version != VERSION or grid != GRID or quantum != QUANTUM:
        raise ValueError("written file has a wrong header")
    glyphs = []
    for slot in range(count):
        code_point, offset = ENTRY.unpack_from(blob, HEADER.size + ENTRY.size * slot)
        stroke_count = blob[offset]
        cursor = offset + 1
        strokes = []
        for _ in range(stroke_count):
            (length,) = struct.unpack_from("<H", blob, cursor)
            cursor += 2
            stroke = [struct.unpack_from("<hh", blob, cursor + 4 * i) for i in range(length)]
            cursor += 4 * length
            strokes.append(stroke)
        glyphs.append((code_point, strokes))
    return glyphs


def resolve_source(value):
    source = Path(value).expanduser()
    if (source / "kanji").is_dir():
        source = source / "kanji"
    if not source.is_dir():
        sys.exit(f"no KanjiVG folder at {source}")
    return source


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", default=str(OUTPUT))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    source = resolve_source(args.source)
    kana, kanji = app_code_points()
    wanted = sorted(set(kana) | set(kanji))

    glyphs = []
    missing = []
    synthetic = []
    worst = 0.0
    dense_points = 0
    stroke_total = 0
    point_total = 0
    longest = 0
    bounds = [math.inf, math.inf, -math.inf, -math.inf]
    for code_point in wanted:
        dense, strokes, origin = read_glyph(source, code_point)
        if strokes is None:
            missing.append(f"{chr(code_point)} U+{code_point:04X}")
            continue
        if origin == "synthetic":
            synthetic.append(f"{chr(code_point)} U+{code_point:04X}")
        quantized = []
        for full, sparse in zip(dense, strokes):
            worst = max(worst, deviation(full, sparse))
            dense_points += len(full)
            stored = quantize(sparse)
            if len(stored) < 2:
                raise ValueError(f"U+{code_point:04X} has a stroke that collapses to a point")
            quantized.append(stored)
            for x, y in sparse:
                bounds = [min(bounds[0], x), min(bounds[1], y), max(bounds[2], x), max(bounds[3], y)]
        stroke_total += len(quantized)
        point_total += sum(len(stroke) for stroke in quantized)
        longest = max(longest, max(len(stroke) for stroke in quantized))
        glyphs.append((code_point, quantized))

    blob = encode(glyphs)
    if decode(blob) != [(code_point, [list(stroke) for stroke in strokes]) for code_point, strokes in glyphs]:
        sys.exit("the encoded file does not read back to the same strokes")

    output = Path(args.output)
    if not args.dry_run:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(blob)
        if decode(output.read_bytes()) != decode(blob):
            sys.exit("the written file does not read back")

    print(json.dumps({
        "written": None if args.dry_run else str(output.relative_to(ROOT) if output.is_relative_to(ROOT) else output),
        "glyphs": len(glyphs),
        "kana_code_points": len(kana),
        "kanji": len(kanji),
        "strokes": stroke_total,
        "points_before_simplify": dense_points,
        "points": point_total,
        "longest_stroke_points": longest,
        "bytes": len(blob),
        "max_deviation_units": round(worst + FLATNESS + math.sqrt(0.5) / QUANTUM, 4),
        "ink_bounds": [round(value, 2) for value in bounds],
        "synthetic": synthetic,
        "missing": missing,
    }, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
