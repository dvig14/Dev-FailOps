#!/usr/bin/env python3
import os
import yaml
from pathlib import Path
from collections import defaultdict

ROOT_DIR = Path(__file__).parent.parent
SCENARIO_DIR = ROOT_DIR / "failops-scenarios"
OUTPUT_FILE = ROOT_DIR / SCENARIO_DIR / "README.md"

tables = defaultdict(list)

for meta_file in SCENARIO_DIR.rglob("meta.yml"):

    meta_path = Path(meta_file)
    folder_path = meta_path.parent

    with open(meta_file, "r", encoding="utf-8") as f:
        meta = yaml.safe_load(f)

    category = meta.get("category")
    meta['folder_rel_path'] = folder_path.relative_to(SCENARIO_DIR).as_posix()
    tables[category].append(meta)

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    f.write("# 📚 FailOps Failure Catalog\n\n")
    f.write("> Auto-generated from `meta.yml` files.\n\n<br>\n\n")

    for category, scenarios in tables.items():
        f.write(f"## {category} Failures\n\n")
        f.write("| ID | Title | Level | Tools | Description |\n")
        f.write("|----|-------|-------|-------|-------------|\n")

        sorted_scenarios = sorted(
            scenarios, 
            key=lambda x: x['created_at'], 
            reverse=True
        )

        for i, s in enumerate(sorted_scenarios, start=1):
            tools = " + ".join(s.get("tools", []))
            f.write(f"| {i:02} | [{s['title']}]({s['folder_rel_path']}) | {s['level']} | {tools} | {s['description']} |\n")
        f.write("\n")
