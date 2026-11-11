#!/usr/bin/env python3
"""Merge contributor YouTube demo URLs into YouTubeExerciseVideos.json and regenerate the handoff list."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SEED = ROOT / "HotBod" / "Resources" / "ExerciseSeed.json"
DEFAULT_VIDEOS = ROOT / "HotBod" / "Resources" / "YouTubeExerciseVideos.json"
DEFAULT_HANDOFF = ROOT / "docs" / "exercise-video-handoff.md"

VIDEO_ID_RE = re.compile(r"^[A-Za-z0-9_-]{11}$")
KETTLEBELL_PRIORITY = (
    "kettlebell_swing",
    "goblet_squat",
    "farmers_carry",
    "single_leg_rdl",
)


def is_youtube_host(host: str) -> bool:
    host = host.lower().rstrip(".")
    if host == "youtu.be" or host.endswith(".youtu.be"):
        return True
    if host == "youtube.com" or host.endswith(".youtube.com"):
        return True
    if host == "youtube-nocookie.com" or host.endswith(".youtube-nocookie.com"):
        return True
    return False


def is_short_link_host(host: str) -> bool:
    host = host.lower().rstrip(".")
    return host == "youtu.be" or host.endswith(".youtu.be")


def validated_video_id(raw: str | None) -> str | None:
    if raw is None:
        return None
    trimmed = raw.strip()
    if not VIDEO_ID_RE.fullmatch(trimmed):
        return None
    return trimmed


def parse_youtube_video_id(url: str) -> str | None:
    parsed = urlparse(url.strip())
    if parsed.scheme not in ("http", "https"):
        return None
    host = parsed.hostname or ""
    if not is_youtube_host(host):
        return None
    parts = [p for p in parsed.path.split("/") if p]
    if is_short_link_host(host):
        return validated_video_id(parts[0] if parts else None)
    if not parts or parts[0] == "watch":
        values = parse_qs(parsed.query).get("v", [])
        return validated_video_id(values[0] if values else None)
    if parts[0] in {"embed", "shorts", "live", "v"} and len(parts) >= 2:
        return validated_video_id(parts[1])
    return None


def canonical_watch_url(video_id: str) -> str:
    return f"https://www.youtube.com/watch?v={video_id}"


def load_seed_exercises(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise SystemExit(f"Seed file must be a JSON array: {path}")
    return data


def load_video_map(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"Video map must be a JSON object: {path}")
    return {str(k): str(v) for k, v in data.items()}


def write_video_map(path: Path, mapping: dict[str, str]) -> None:
    ordered = {k: mapping[k] for k in sorted(mapping)}
    path.write_text(json.dumps(ordered, indent=2) + "\n", encoding="utf-8")


def parse_pair_lines(text: str, seed_ids: set[str]) -> tuple[dict[str, str], list[str]]:
    updates: dict[str, str] = {}
    errors: list[str] = []
    for line_number, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 2:
            errors.append(f"line {line_number}: expected 'exercise_id URL', got {raw_line!r}")
            continue
        exercise_id, url = parts[0], parts[1]
        if exercise_id not in seed_ids:
            errors.append(f"line {line_number}: unknown exercise id {exercise_id!r}")
            continue
        video_id = parse_youtube_video_id(url)
        if video_id is None:
            errors.append(f"line {line_number}: invalid YouTube URL {url!r}")
            continue
        updates[exercise_id] = canonical_watch_url(video_id)
    return updates, errors


def missing_exercises(exercises: list[dict], mapping: dict[str, str]) -> list[dict]:
    missing = [e for e in exercises if e.get("id") not in mapping]
    priority = {eid: index for index, eid in enumerate(KETTLEBELL_PRIORITY)}

    def sort_key(exercise: dict) -> tuple[int, str]:
        eid = str(exercise.get("id", ""))
        return (priority.get(eid, len(KETTLEBELL_PRIORITY)), eid)

    return sorted(missing, key=sort_key)


def write_handoff(path: Path, exercises: list[dict], mapping: dict[str, str]) -> None:
    missing = missing_exercises(exercises, mapping)
    covered = len(exercises) - len(missing)
    lines = [
        "# Exercise video handoff",
        "",
        "Reply with one `exercise_id` and one YouTube URL per line.",
        "",
        "Accepted URL shapes: watch, youtu.be, embed, shorts, m.youtube.",
        "Any public embeddable YouTube clip is fine. HotBod embeds only; it does not download the file.",
        "",
        "Example:",
        "",
        "```",
        "kettlebell_swing https://www.youtube.com/watch?v=VIDEO_ID",
        "goblet_squat https://youtu.be/VIDEO_ID",
        "```",
        "",
        f"## Missing ({len(missing)})",
        "",
    ]
    if not missing:
        lines.append("None — every seed exercise has a YouTube demo link.")
        lines.append("")
    else:
        lines.extend(["| id | name | equipment |", "| --- | --- | --- |"])
        for exercise in missing:
            eid = exercise.get("id", "")
            name = exercise.get("name", "")
            equipment = ", ".join(exercise.get("equipment") or [])
            lines.append(f"| `{eid}` | {name} | {equipment} |")
        lines.append("")
    lines.extend(
        [
            f"## Covered ({covered})",
            "",
            f"{covered} of {len(exercises)} seed exercises already have a YouTube entry.",
            "Do not re-find those unless replacing a bad link.",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def run_self_checks() -> None:
    assert parse_youtube_video_id("https://www.youtube.com/watch?v=gMgvBspQ9lk&t=12s") == "gMgvBspQ9lk"
    assert parse_youtube_video_id("https://youtu.be/gMgvBspQ9lk") == "gMgvBspQ9lk"
    assert parse_youtube_video_id("https://www.youtube.com/embed/gMgvBspQ9lk") == "gMgvBspQ9lk"
    assert parse_youtube_video_id("https://www.youtube.com/shorts/gMgvBspQ9lk") == "gMgvBspQ9lk"
    assert parse_youtube_video_id("https://m.youtube.com/watch?v=gMgvBspQ9lk") == "gMgvBspQ9lk"
    assert parse_youtube_video_id("https://example.com/watch?v=gMgvBspQ9lk") is None
    assert parse_youtube_video_id("https://www.youtube.com/watch?v=short") is None
    seed_ids = {"bench_press", "squat"}
    updates, errors = parse_pair_lines(
        "bench_press https://youtu.be/gMgvBspQ9lk\n",
        seed_ids,
    )
    assert errors == []
    assert updates == {"bench_press": "https://www.youtube.com/watch?v=gMgvBspQ9lk"}
    _, bad = parse_pair_lines("nope https://youtu.be/gMgvBspQ9lk\n", seed_ids)
    assert bad and "unknown exercise id" in bad[0]
    print("self-checks passed")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", action="store_true", help="Regenerate handoff markdown only")
    parser.add_argument("--input", type=Path, help="File of 'exercise_id URL' lines (default: stdin)")
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED)
    parser.add_argument("--videos", type=Path, default=DEFAULT_VIDEOS)
    parser.add_argument("--handoff", type=Path, default=DEFAULT_HANDOFF)
    parser.add_argument("--self-check", action="store_true", help="Run parser/merge unit checks and exit")
    args = parser.parse_args(argv)

    if args.self_check:
        run_self_checks()
        return 0

    if not args.seed.exists():
        print(f"missing seed file: {args.seed}", file=sys.stderr)
        return 1
    if not args.videos.exists():
        print(f"missing videos file: {args.videos}", file=sys.stderr)
        return 1

    exercises = load_seed_exercises(args.seed)
    seed_ids = {str(e["id"]) for e in exercises if "id" in e}
    mapping = load_video_map(args.videos)

    if args.report:
        write_handoff(args.handoff, exercises, mapping)
        missing = missing_exercises(exercises, mapping)
        print(f"wrote {args.handoff} ({len(missing)} missing, {len(mapping)} linked)")
        return 0

    if args.input is not None:
        text = args.input.read_text(encoding="utf-8")
    else:
        if sys.stdin.isatty():
            print("no input on stdin; pass --input PATH or pipe lines", file=sys.stderr)
            return 0
        text = sys.stdin.read()

    if not any(line.strip() and not line.strip().startswith("#") for line in text.splitlines()):
        print("empty input; videos unchanged")
        return 0

    updates, errors = parse_pair_lines(text, seed_ids)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    mapping.update(updates)
    write_video_map(args.videos, mapping)
    write_handoff(args.handoff, exercises, mapping)
    missing = missing_exercises(exercises, mapping)
    print(f"merged {len(updates)}; wrote {args.videos}; handoff missing={len(missing)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
