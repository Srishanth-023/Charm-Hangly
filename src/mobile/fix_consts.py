import re
import os

files = [
    'lib/features/hangly_scene/presentation/hangly_scene_page.dart',
    'lib/features/charm_library/presentation/charm_library_page.dart',
    'lib/features/settings/presentation/settings_page.dart'
]

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # We will repeatedly replace 'const ' with '' if it precedes a block that contains HanglyTheme.
    # Actually, the simplest way is to just remove 'const ' from the specific lines mentioned in the error.
    # Since I don't have the exact error lines parsed easily in python, 
    # I can just remove 'const ' if the line or the next few lines contain HanglyTheme.
    # Better: just remove ALL 'const ' before widgets that commonly use colors!
    
    # Let's remove 'const ' before Text, TextStyle, Icon, Divider, BorderSide, BoxDecoration, InputDecoration, SnackBar, Row, Column, Center, Expanded, ListTile.
    content = re.sub(r'const\s+(Text|TextStyle|Icon|Divider|BorderSide|BoxDecoration|InputDecoration|SnackBar|Row|Column|Center|Expanded|ListTile|Container)\b', r'\1', content)
    
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)

print('Done')
