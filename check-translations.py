#!/usr/bin/env python3

# pylint: disable=all

import argparse
import os
import sys
import io

import vdf
from git import Repo

repo = Repo(os.getcwd())
argument_parser = argparse.ArgumentParser(description="Helper script for checking translation status.")

argument_parser.add_argument("phrases", type=str, help="Phrases to check the translation status on.")
argument_parser.add_argument("-o", "--out", type=str, help="Output file (omit to print to stdout).")
argument_parser.add_argument("--format-markdown", help="Print in Markdown format.",
                             action="store_true")
argument_parser.add_argument("--format-tasklist", help="Print in GitHub tasklist format (Requires --format-markdown).",
                             action="store_true")

args = argument_parser.parse_args()

target_phrases: str = args.phrases
BASE_TRANSLATION_PATH = f"translations/{target_phrases}.phrases.txt"

if not os.path.isfile(BASE_TRANSLATION_PATH):
    print(f"Translation phrases \"{target_phrases}\" doesn't exist.", file=sys.stderr)
    sys.exit(1)

output_file = None
if args.out:
    output_file = open(args.out, "w")
    sys.stdout = output_file

format_markdown: bool = args.format_markdown
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

with open(BASE_TRANSLATION_PATH, encoding="utf-8") as f:
    all_phrases: dict[str, dict[str, str]] = vdf.loads(f.read()).get("Phrases")

if all_phrases is None:
    raise ValueError("Phrases not valid.")

tasklist_symbol = ""
if args.format_tasklist and format_markdown:
    tasklist_symbol = "[ ] "

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
    TRANSLATION_FILE_PATH = f"translations/{i}/{target_phrases}.phrases.txt"
    if not os.path.isfile(TRANSLATION_FILE_PATH):
        print(f"Translations phrases don't exist for {language} yet.\n")
        continue
    with open(TRANSLATION_FILE_PATH, encoding="utf-8") as f:
        language_phrases = vdf.loads(f.read()).get("Phrases")
    if language_phrases is None:
        print(f"Warning: Section \"Phrases\" doesn't exist for {language}.", file=sys.stderr)
        continue

    for key in all_phrases:
        if key not in language_phrases:
            formatted_key = key
            if format_markdown:
                formatted_key = f"`{key}`"
            print(f"- {tasklist_symbol}Key {formatted_key} doesn't exist for {language}")
            problems_count += 1

    last_modified_commit = next(repo.iter_commits(max_count=1, paths=TRANSLATION_FILE_PATH))
    old_base_phrases_file = last_modified_commit.tree / BASE_TRANSLATION_PATH
    with io.BytesIO(old_base_phrases_file.data_stream.read()) as f:
        old_base_phrases: dict[str, dict[str, str]] = vdf.loads(f.read().decode()).get("Phrases")
    if old_base_phrases is None:
        raise ValueError(f"Base phrases from commit {last_modified_commit.hexsha} is invalid")
    for key, value in old_base_phrases.items():
        if (all_phrases_key := all_phrases.get(key)) is None:
            print(f"Warning: Key \"{key}\" doesn't exist in current translation file.", file=sys.stderr)
            continue
        if all_phrases_key.get("en") != value.get("en"):
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

if output_file is not None:
    output_file.close()
