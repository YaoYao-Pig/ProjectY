"""Check local inline Markdown file links without loading document bodies into AI context."""

import argparse
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit


LINK = re.compile(r'!?\[[^\]\n]*\]\((<[^>\n]+>|[^\s)]+)(?:\s+"[^"]*")?\)')
FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")


def check(paths):
    documents = set()
    problems = []
    checked = 0
    for value in paths:
        source = Path(value).resolve()
        if source.is_dir():
            documents.update(source.rglob("*.md"))
        elif source.is_file():
            documents.add(source)
        else:
            problems.append(f"Missing input: {source}")

    for document in sorted(documents):
        fence = None
        for number, line in enumerate(document.read_text(encoding="utf-8-sig").splitlines(), 1):
            marker = FENCE.match(line)
            if marker:
                token = marker.group(1)
                if fence is None:
                    fence = token
                elif token[0] == fence[0] and len(token) >= len(fence) and not line[marker.end():].strip():
                    fence = None
                continue
            if fence is not None:
                continue
            for match in LINK.finditer(line):
                target = match.group(1).strip("<>")
                # Markdown code samples are handled by fences above; only file paths are checked.
                if re.match(r"^[A-Za-z]:[\\/]", target):
                    path_text = target.split("#", 1)[0]
                else:
                    url = urlsplit(target)
                    if url.scheme or url.netloc or not url.path:
                        continue
                    path_text = url.path
                destination = document.parent / unquote(path_text)
                checked += 1
                if not destination.exists():
                    problems.append(f"{document}:{number}: missing {target}")

    for problem in problems:
        print(problem)
    print(f"{len(documents)} Markdown files, {checked} local links, {len(problems)} errors.")
    return 1 if problems else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", help="Markdown files or directories to check")
    sys.exit(check(parser.parse_args().paths))
