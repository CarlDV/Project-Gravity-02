"""Keep the website's embedded prompt identical to its downloadable text."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "docs" / "plugins"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = SITE / "index.html"
    html = path.read_text(encoding="utf-8")
    prompt = (SITE / "plugin-prompt.txt").read_text(encoding="utf-8")
    encoded = json.dumps(prompt, ensure_ascii=False).replace("<", "\\u003c")
    updated, count = re.subn(
        r'(<script id="prompt-source" type="application/json">).*?(</script>)',
        lambda match: match[1] + encoded + match[2],
        html,
        flags=re.DOTALL,
    )
    assert count == 1, "expected exactly one embedded prompt"
    if args.check:
        if updated != html:
            raise SystemExit("Prompt is stale: run python tools/sync_plugin_docs.py")
        print("Website and downloadable LLM prompt match.")
    else:
        path.write_text(updated, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
