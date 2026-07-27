#!/usr/bin/env python3
"""Apply contextual stress marks to the derived long-term corpus.

This script never reads from or writes to the source Obsidian vault. It only
updates `stressedForm` in the reviewed, derived JSON manifest.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from silero_stress import load_accentor


ACUTE = "\u0301"
VOWELS = "АЕЁИОУЫЭЮЯаеёиоуыэюя"
CYRILLIC_SEGMENT = re.compile(rf"[А-Яа-яЁё{ACUTE}]+")
CONTEXT_CORRECTIONS = {
    "Мне уже лучше.": "Мне уже́ лу́чше.",
    "У нас экзамены уже на носу.": "У нас экза́мены уже́ на носу́.",
    "Сколько стоит эта сумка?": "Ско́лько сто́ит э́та су́мка?",
}


def combining_acute(text: str) -> str:
    text = re.sub(rf"\+([{VOWELS}])", rf"\1{ACUTE}", text)
    text = text.replace(f"Ё{ACUTE}", "Ё").replace(f"ё{ACUTE}", "ё")

    def simplify(segment: re.Match[str]) -> str:
        value = segment.group(0)
        vowel_count = sum(character in VOWELS for character in value)
        return value.replace(ACUTE, "") if vowel_count <= 1 else value

    return CYRILLIC_SEGMENT.sub(simplify, text)


def canonical(text: str) -> str:
    return text.replace(ACUTE, "").replace("ё", "е").replace("Ё", "Е")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    accentor = load_accentor()
    changed = 0
    for sentence in manifest["sentences"]:
        source = sentence["practiceRu"].replace(ACUTE, "")
        stressed = CONTEXT_CORRECTIONS.get(
            source,
            combining_acute(accentor(source)),
        )
        if canonical(stressed) != canonical(source):
            raise ValueError(
                f"accentor changed sentence text: {sentence['id']}"
            )
        if sentence.get("stressedForm") != stressed:
            sentence["stressedForm"] = stressed
            changed += 1

    print(
        f"stress_annotation=PASS sentences={len(manifest['sentences'])} "
        f"changed={changed}"
    )
    if args.write:
        args.manifest.write_text(
            json.dumps(
                manifest,
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
