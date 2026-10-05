"""Reject literal text in common UI APIs; this is a guardrail, not a proof of complete coverage."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LITERAL = r'"((?:\\.|[^"\\])*)"'
RULES = [
    (
        "clients/ios/Classes",
        (".swift",),
        rf"\b(?:Text|Button|Label|TextField|SecureField|Picker)\(\s*{LITERAL}",
    ),
    (
        "clients/ios/Classes",
        (".m",),
        rf"(?:\.(?:text|title|placeholder|accessibilityLabel)\s*=\s*|\b(?:addTitle|addFeedListTitle|setTitle|setMessage|setPlaceholder):\s*)@{LITERAL}",
    ),
    (
        "clients/android/NewsBlur/app/src/main",
        (".kt",),
        rf"\b(?:Text|TextField)\(\s*(?:text\s*=\s*)?{LITERAL}",
    ),
    (
        "clients/android/NewsBlur/app/src/main/res",
        (".xml",),
        r'android:(?:text|hint|contentDescription)="([^"@?][^"]*)"',
    ),
    ("media/js/newsblur", (".js",), r'\.(?:text|html)\(\s*[\'"]([A-Za-z][^\'"\n]*[a-z][.!?]?)[\'"]\s*\)'),
]
# audit.py excludes literal examples of user data and ISO language-code input hints.
EXAMPLES = {
    ("clients/ios/Classes/FollowGrid.m", "roy"),
    ("clients/ios/Classes/DiscoverSites/Tabs/GoogleNewsTabView.swift", "en"),
    ("clients/android/NewsBlur/app/src/main/res/layout/include_intel_explainer.xml", "John Gruber"),
    ("clients/android/NewsBlur/app/src/main/res/layout/include_intel_explainer.xml", "Apple"),
}


def findings():
    for base, suffixes, pattern in RULES:
        for path in sorted((ROOT / base).rglob("*")):
            if path.suffix not in suffixes or "TestHarness" in path.name or "/values-" in str(path):
                continue
            content = path.read_text()
            for match in re.finditer(pattern, content):
                number = content.count("\n", 0, match.start()) + 1
                line = content.splitlines()[number - 1]
                if line.lstrip().startswith(("//", "*", "<!--")):
                    continue
                value = match[1]
                if not re.search(r"[A-Za-z]{2}", value) or value.startswith(("\\u", "http", "@")):
                    continue
                # Interpolated messages need a complete-message conversion, not literal wrapping.
                if "\\(" in value or "$" in value or "<" in value:
                    continue
                if (str(path.relative_to(ROOT)), value) in EXAMPLES:
                    continue
                yield str(path.relative_to(ROOT)), number, value


def main():
    remaining = list(findings())
    for path, line, value in remaining:
        print(f"{path}:{line}: hardcoded UI text: {value}")
    # audit.py also rejects snake_case protocol identifiers accidentally wrapped by UI conversions.
    identifiers = []
    for path in sorted((ROOT / "media/js/newsblur").rglob("*.js")):
        content = path.read_text()
        for match in re.finditer(r"gettext\(['\"]([a-z]+(?:_[a-z]+)+)['\"]\)", content):
            line = content.count("\n", 0, match.start()) + 1
            identifiers.append((path, line, match[1]))
    for path, line, value in identifiers:
        print(f"{path.relative_to(ROOT)}:{line}: translated protocol identifier: {value}")
    print(
        f"{len(remaining)} hardcoded UI literals and {len(identifiers)} translated identifiers in audited APIs"
    )
    return bool(remaining or identifiers)


if __name__ == "__main__":
    sys.exit(main())
