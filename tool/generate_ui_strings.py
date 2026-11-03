#!/usr/bin/env python3
"""Regenerate ui_strings.dart from the two ARB files."""
from pathlib import Path
import json
root = Path(__file__).resolve().parents[1]
en = json.loads((root / 'lib/l10n/app_en.arb').read_text())
de = json.loads((root / 'lib/l10n/app_de.arb').read_text())
pairs = {value: de[key] for key, value in en.items()
         if not key.startswith('@') and key in de and not key.startswith('nav') and key != 'appName'}
def dart_quote(text):
    return "'" + text.replace('\\', '\\\\').replace("'", "\\'").replace('\n','\\n').replace('$','\\$') + "'"
lines = ['// Generated from app_en.arb and app_de.arb; edit those files and regenerate.',
         'const Map<String, String> appGermanUiStrings = {']
for source, localized in sorted(pairs.items()):
    lines.append(f'  {dart_quote(source)}: {dart_quote(localized)},')
lines.append('};\n')
(root / 'lib/l10n/ui_strings.dart').write_text('\n'.join(lines))
