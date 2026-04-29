#!/usr/bin/env python3
"""
CKS Lab Auto-Generator
Analyzes CKS_2026_Lab_Guide.md and regenerates all lab exercises.
Run from workspace root: python3 cks-lab-generator/generate_all_labs.py
Or from cks-lab-generator/: python3 generate_all_labs.py
"""

import sys
import logging
from pathlib import Path

# Suppress verbose logging
logging.disable(logging.CRITICAL)

# Resolve paths relative to this script's location
SCRIPT_DIR = Path(__file__).parent.resolve()
WORKSPACE_ROOT = SCRIPT_DIR.parent

sys.path.insert(0, str(SCRIPT_DIR / "src"))

from cks_lab_generator.config import Config
from cks_lab_generator.content_analyzer import ContentAnalyzer
from cks_lab_generator.models import ContentMap
from cks_lab_generator.lab_generator import LabGenerator
from cks_lab_generator.script_generator import ScriptGenerator


GUIDE_PATH = str(WORKSPACE_ROOT / "CKS_2026_Lab_Guide.md")
OUTPUT_DIR = str(WORKSPACE_ROOT / "cks-lab-exercises" / "labs")
CONTENT_MAP_PATH = str(SCRIPT_DIR / ".kiro" / "specs" / "cks-lab-exercises-generator" / "content-map.json")


def step1_analyze_guide(config):
    """Parse guide and update content map."""
    print("Step 1: Analyzing CKS_2026_Lab_Guide.md ...")
    analyzer = ContentAnalyzer(config)
    content_map = analyzer.parse_guide(GUIDE_PATH)
    content_map.save_to_json(CONTENT_MAP_PATH)
    print(f"  ✓ {len(content_map.domains)} domains, {content_map.total_topics} topics extracted")
    return content_map


def step2_generate_labs(content_map, config):
    """Generate/update all lab files."""
    print("Step 2: Generating lab exercises ...")
    generator = LabGenerator(config)
    script_gen = ScriptGenerator(config)
    domains_dict = {d.number: d for d in content_map.domains}

    total = 0
    errors = []

    for domain_num in range(1, 7):
        domain = domains_dict.get(domain_num)
        if not domain:
            continue

        print(f"  Domain {domain_num}: {domain.name} ({len(domain.skill_topics)} topics)")
        for topic in domain.skill_topics:
            try:
                lab = generator.generate_lab(topic, domain, OUTPUT_DIR)
                lab_path = Path(lab.directory_path)

                scripts = {
                    "setup.sh": script_gen.generate_setup_script(topic),
                    "cleanup.sh": script_gen.generate_cleanup_script(topic),
                    "verify.sh": script_gen.generate_verify_script(topic),
                }
                for name, content in scripts.items():
                    p = lab_path / name
                    p.write_text(content, encoding="utf-8")
                    p.chmod(0o755)

                print(f"    ✓ {lab.lab_id}")
                total += 1
            except Exception as e:
                errors.append(f"{topic.id}: {e}")
                print(f"    ✗ {topic.id} - {e}")

    return total, errors


def main():
    print("=" * 60)
    print("CKS Lab Generator - Auto Regeneration")
    print("=" * 60)

    if not Path(GUIDE_PATH).exists():
        print(f"ERROR: Guide not found: {GUIDE_PATH}")
        return 1

    config = Config()
    config.config["output_directory"] = OUTPUT_DIR

    # Step 1: Analyze guide
    content_map = step1_analyze_guide(config)

    # Step 2: Generate labs
    total, errors = step2_generate_labs(content_map, config)

    print("=" * 60)
    print(f"✓ {total} labs generated/updated")
    print(f"  Output: {OUTPUT_DIR}")
    if errors:
        print(f"  Warnings ({len(errors)}):")
        for e in errors:
            print(f"    - {e}")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    sys.exit(main())
