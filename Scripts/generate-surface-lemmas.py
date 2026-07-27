#!/usr/bin/env python3

import argparse
import json
import re
from pathlib import Path

import pymorphy3


RUSSIAN_WORD = re.compile(r"[А-Яа-яЁё]+")


def normalized(value: str) -> str:
    return value.lower().replace("ё", "е")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Add a derived Russian surface-to-lemma map to the long-term manifest."
    )
    parser.add_argument("manifest", type=Path)
    arguments = parser.parse_args()

    manifest_path = arguments.manifest.resolve()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    morphology = pymorphy3.MorphAnalyzer()
    forms: set[str] = set()
    for sentence in manifest["sentences"]:
        forms.update(
            normalized(match.group(0))
            for match in RUSSIAN_WORD.finditer(sentence["practiceRu"])
        )

    lemmas = {
        form: normalized(morphology.parse(form)[0].normal_form)
        for form in sorted(forms)
    }
    # Stable corrections for high-frequency homographs in this reviewed corpus.
    lemmas.update(
        {
            "все": "весь",
            "стоит": "стоить",
        }
    )
    manifest["surfaceLemmas"] = dict(sorted(lemmas.items()))
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"surface_lemmas=PASS unique_forms={len(lemmas)} "
        f"manifest={manifest_path}"
    )


if __name__ == "__main__":
    main()
