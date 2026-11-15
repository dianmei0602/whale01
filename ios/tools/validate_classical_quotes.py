#!/usr/bin/env python3
"""Validate the bundled, source-pinned Nomi classical quote library."""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path


HANZI_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]")
EXPECTED_COUNT = 365
EXPECTED_BOOKS = 13
EXPECTED_REVISION = "4e746ea9fa99c3c0d7051c45397330bef7b0962d"


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: validate_classical_quotes.py App/Resources/classical_quotes.json")

    path = Path(sys.argv[1])
    quotes = json.loads(path.read_text(encoding="utf-8"))

    if len(quotes) != EXPECTED_COUNT:
        fail(f"expected {EXPECTED_COUNT} quotes, found {len(quotes)}")

    ids = [quote.get("id") for quote in quotes]
    if len(set(ids)) != len(ids):
        fail("duplicate quote ids")

    normalized = ["".join(HANZI_RE.findall(quote.get("text", ""))) for quote in quotes]
    if len(set(normalized)) != len(normalized):
        fail("duplicate normalized quote text")

    books = Counter(quote.get("book") for quote in quotes)
    if len(books) != EXPECTED_BOOKS:
        fail(f"expected {EXPECTED_BOOKS} books, found {len(books)}")

    for quote, hanzi in zip(quotes, normalized):
        quote_id = quote.get("id", "<missing>")
        if quote.get("hanziCount") != len(hanzi):
            fail(f"{quote_id}: recorded and actual Han character counts differ")
        if not 15 <= len(hanzi) <= 30:
            fail(f"{quote_id}: expected 15-30 Han characters, found {len(hanzi)}")
        if not quote.get("verified"):
            fail(f"{quote_id}: verified is false")
        if quote.get("verificationLevel") not in {
            "curated-source-match",
            "automated-source-match",
        }:
            fail(f"{quote_id}: unknown verification level")
        if not quote.get("sourcePath") or quote.get("book", "") not in quote["sourcePath"]:
            fail(f"{quote_id}: source path does not contain its book")
        for part in quote.get("chapter", "").split("·"):
            if part and part not in quote["sourcePath"]:
                fail(f"{quote_id}: source path does not contain chapter part {part}")
        if EXPECTED_REVISION not in quote.get("sourceUrl", ""):
            fail(f"{quote_id}: source URL is not pinned to the verified revision")

    print(f"PASS: {len(quotes)} quotes, {len(books)} books")
    for book, count in books.items():
        print(f"  {book}: {count}")


if __name__ == "__main__":
    main()
