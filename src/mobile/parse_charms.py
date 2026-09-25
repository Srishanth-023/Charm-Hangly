import re
import os

with open('src/Hangly.Core/Models/CharmCatalog.Generated.cs', 'r', encoding='utf-8') as f:
    text = f.read()

# Pattern for each new CharmCatalogEntry
# new(
#   Id: "...",
#   DisplayName: "...",
#   FileName: "...",
#   Mass: ...,
#   RadiusRatio: ...,
#   Palette: new CharmPalette(
#       new CharmColor(r, g, b)...
#   CategoryId: "...",
#   Description: "...",
pattern = re.compile(
    r'Id:\s*"([^"]+)",\s*'
    r'DisplayName:\s*"([^"]+)",\s*'
    r'FileName:\s*"([^"]+)",\s*'
    r'Mass:\s*([0-9\.]+),\s*'
    r'RadiusRatio:\s*([0-9\.]+),\s*'
    r'Palette:\s*new CharmPalette\(\s*new CharmColor\(([0-9\.]+),\s*([0-9\.]+),\s*([0-9\.]+)\)',
    re.DOTALL
)

matches = pattern.findall(text)
print(f"Found {len(matches)} charms in CharmCatalog.Generated.cs")

# Also find CategoryId and Description for each
blocks = text.split('new(')[1:]
charms_data = []

# List all available SVGs in mobile/assets/charms
available_svgs = {}
for root, _, files in os.walk('mobile/assets/charms'):
    for file in files:
        if file.endswith('.svg'):
            rel = os.path.relpath(os.path.join(root, file), 'mobile').replace('\\', '/')
            available_svgs[file.lower()] = rel

print(f"Available SVGs on disk: {len(available_svgs)}")

for block in blocks:
    id_m = re.search(r'Id:\s*"([^"]+)"', block)
    name_m = re.search(r'DisplayName:\s*"([^"]+)"', block)
    file_m = re.search(r'FileName:\s*"([^"]+)"', block)
    mass_m = re.search(r'Mass:\s*([0-9\.]+)', block)
    radius_m = re.search(r'RadiusRatio:\s*([0-9\.]+)', block)
    cat_m = re.search(r'CategoryId:\s*"([^"]+)"', block)
    desc_m = re.search(r'Description:\s*"([^"]+)"', block)
    color_m = re.search(r'new CharmColor\(([0-9\.]+),\s*([0-9\.]+),\s*([0-9\.]+)\)', block)

    if id_m and name_m and file_m and mass_m and radius_m:
        cid = id_m.group(1)
        name = name_m.group(1)
        fname = file_m.group(1)
        mass = float(mass_m.group(1))
        radius = float(radius_m.group(1))
        cat = cat_m.group(1) if cat_m else 'classic'
        desc = desc_m.group(1).replace('"', '\\"') if desc_m else ''
        
        # Color
        if color_m:
            r = int(float(color_m.group(1)) * 255)
            g = int(float(color_m.group(2)) * 255)
            b = int(float(color_m.group(3)) * 255)
            hex_color = f"0xFF{r:02X}{g:02X}{b:02X}"
        else:
            hex_color = "0xFF1E88E5"

        # Asset path
        asset_path = available_svgs.get(fname.lower())
        if not asset_path:
            # Try finding by basename
            base = os.path.basename(fname).lower()
            asset_path = available_svgs.get(base)

        if asset_path:
            charms_data.append({
                'id': cid,
                'name': name,
                'category': cat,
                'assetPath': asset_path,
                'mass': mass,
                'radius': radius,
                'color': hex_color,
                'description': desc
            })
        else:
            print(f"WARNING: SVG not found for: {fname} (ID: {cid})")

print(f"Successfully matched {len(charms_data)} charms with assets on disk!")

with open('mobile/generated_charms.dart', 'w', encoding='utf-8') as out:
    out.write("// Auto-generated from CharmCatalog.Generated.cs\n")
    out.write("import 'package:flutter/material.dart';\n")
    out.write("import '../../features/hangly_scene/physics/charm_metrics.dart';\n")
    out.write("import 'charm.dart';\n\n")
    out.write("const List<Charm> allCharms = [\n")
    for c in charms_data:
        out.write(f"  Charm(\n")
        out.write(f"    id: '{c['id']}',\n")
        out.write(f"    name: '{c['name']}',\n")
        out.write(f"    category: '{c['category']}',\n")
        out.write(f"    assetPath: '{c['assetPath']}',\n")
        out.write(f"    metrics: CharmMetrics(mass: {c['mass']}, radiusRatio: {c['radius']}, knotInset: 0.90),\n")
        out.write(f"    primaryColor: Color({c['color']}),\n")
        out.write(f"    description: \"{c['description']}\",\n")
        out.write(f"  ),\n")
    out.write("];\n")
