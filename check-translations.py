#!/usr/bin/env python3

# pylint: disable = missing-module-docstring, line-too-long

import os
import sys
import io

import vdf
from git import Repo

repo = Repo(os.getcwd())

format_markdown = os.environ.get("FORMAT_MARKDOWN", "0") == "1"
languages = [i for i in os.listdir("translations")
             if os.path.isdir(os.path.join("translations", i))]

ALL_LANGUAGES = {
    "ar": "Arabic",
    "bg": "Bulgarian",
    "chi": "Chinese (Simplified)",
    "cze": "Czech",
    "da": "Danish",
    "de": "German",
    "el": "Greek",
    "en": "English",
    "es": "Spanish",
    "fi": "Finnish",
    "fr": "French",
    "he": "Hebrew",
    "hu": "Hungarian",
    "it": "Italian",
    "jp": "Japanese",
    "ko": "Korean",
    "las": "Latin American Spanish",
    "lt": "Lithuanian",
    "lv": "Latvian",
    "nl": "Dutch",
    "no": "Norwegian",
    "pl": "Polish",
    "pt": "Brazilian",
    "pt_p": "Portuguese",
    "ro": "Romanian",
    "ru": "Russian",
    "sk": "Slovak",
    "sv": "Swedish",
    "th": "Thai",
    "tr": "Turkish",
    "ua": "Ukrainian",
    "vi": "Vietnamese",
    "zho": "Chinese (Traditional)"
}

with open("translations/reverts.phrases.txt", encoding="utf-8") as f:
    all_phrases: dict[str, dict[str, str]] = vdf.loads(f.read()).get("Phrases")

if all_phrases is None:
    raise ValueError("Phrases not valid.")

tasklist_symbol = ""
if os.environ.get("FORMAT_TASKLIST", "0") == "1" and format_markdown:
    tasklist_symbol = "[ ] "

# pylint: disable = invalid-name
for i in languages:
    if (language := ALL_LANGUAGES.get(i)) is None:
        print(f"Warning: Unknown language {i}", file=sys.stderr)
        language = i
    if format_markdown:
        print("### ", end="")
    print(f"Problems for {language}", end="")
    if not format_markdown:
        print(":")
    else:
        print()

    problems_count = 0
    TRANSLATION_FILE_PATH = f"translations/{i}/reverts.phrases.txt"
    with open(TRANSLATION_FILE_PATH, encoding="utf-8") as f:
        language_phrases = vdf.loads(f.read()).get("Phrases")
    if language_phrases is None:
        print(f"Warning: Section \"Phrases\" doesn't exist for {language}", file=sys.stderr)
        continue

    for key in all_phrases:
        if key not in language_phrases:
            formatted_key = key
            if format_markdown:
                formatted_key = f"`{key}`"
            print(f"- {tasklist_symbol}Key {formatted_key} doesn't exist for {language}")
            problems_count += 1

    last_modified_commit = next(repo.iter_commits(max_count=1, paths=TRANSLATION_FILE_PATH))
    old_base_phrases_file = last_modified_commit.tree / "translations/reverts.phrases.txt"
    with io.BytesIO(old_base_phrases_file.data_stream.read()) as f:
        old_base_phrases: dict[str, dict[str, str]] = vdf.loads(f.read().decode()).get("Phrases")
    if old_base_phrases is None:
        raise ValueError(f"Base phrases from commit {last_modified_commit.hexsha} is invalid")
    for key, value in old_base_phrases.items():
        if all_phrases.get(key).get("en") != value.get("en"):
            formatted_key = key
            if format_markdown:
                formatted_key = f"`{key}`"
            formatted_commit = repo.git.rev_parse(last_modified_commit.hexsha, short=True)
            if format_markdown:
                formatted_commit = f"`{formatted_commit}`"
            print(f"- {tasklist_symbol}Key {formatted_key} was changed from commit {formatted_commit}")
            problems_count += 1

    if not problems_count:
        print(f"No problems for {language}")
    print()
