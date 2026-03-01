#!/usr/bin/env python3
"""
telegramify.py — Convert markdown to Telegram-compatible format.

Reads markdown from stdin, outputs JSON with:
  {
    "chunks": [
      {"text": "...", "entities": [...MessageEntity dicts...]}
    ]
  }

Each chunk fits within Telegram's 4096 UTF-16 code unit message limit.
The chunks array always has at least one entry; callers send one API request
per chunk.

Usage:
  echo "**bold** and `code`" | python3 scripts/telegramify.py

Requires:
  pip install telegramify-markdown
  (or: pip install -r requirements.txt)
"""

import sys
import json
from telegramify_markdown import convert, split_entities


def main():
    markdown = sys.stdin.read()

    if not markdown.strip():
        print(json.dumps({"chunks": []}))
        return

    text, entities = convert(markdown)
    entity_dicts = [e.to_dict() for e in entities]

    # Split into chunks that fit within Telegram's 4096 UTF-16 code unit limit
    if len(text.encode("utf-16-le")) // 2 > 4000:
        chunks = []
        for chunk_text, chunk_entities in split_entities(text, entities, max_utf16_len=4000):
            chunks.append({
                "text": chunk_text,
                "entities": [e.to_dict() for e in chunk_entities],
            })
        print(json.dumps({"chunks": chunks}))
    else:
        print(json.dumps({"chunks": [{"text": text, "entities": entity_dicts}]}))


if __name__ == "__main__":
    main()
