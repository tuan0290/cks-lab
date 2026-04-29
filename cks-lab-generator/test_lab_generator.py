#!/usr/bin/env python3
"""Test script for LabGenerator."""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from cks_lab_generator.config import Config
from cks_lab_generator.lab_generator import LabGenerator
from cks_lab_generator.models import ContentMap


def main():
    """Test LabGenerator with a sample topic."""
    content_map_path = ".kiro/specs/cks-lab-exercises-generator/content-map.json"

    if not Path(content_map_path).exists():
        print(f"❌ Content map not found: {content_map_path}")
        print("Run test_analyzer.py first to generate content map")
        return 1

    print("🔍 Testing LabGenerator...")
    print(f"📄 Content map: {content_map_path}\n")

    try:
        # Load content map
        content_map = ContentMap.load_from_json(content_map_path)
        print(f"✓ Loaded content map with {len(content_map.domains)} domains")

        # Initialize
        config = Config()
        # Use a test output directory
        config.config["output_directory"] = "test-labs"
        generator = LabGenerator(config)

        # Get first domain and first topic
        domain = content_map.domains[0]
        if not domain.skill_topics:
            print("❌ No skill topics found in first domain")
            return 1

        topic = domain.skill_topics[0]
        print(f"\n📝 Generating test lab for:")
        print(f"   Domain: {domain.number} - {domain.name}")
        print(f"   Topic: {topic.id} - {topic.name}")
        print(f"   Difficulty: {topic.difficulty}")
        print(f"   Estimated Time: {topic.estimated_time} min\n")

        # Generate lab
        print("⏳ Generating lab...")
        lab = generator.generate_lab(topic, domain)

        # Display results
        print("\n" + "=" * 80)
        print(f"✅ Lab generated successfully!")
        print("=" * 80)
        print(f"\n📁 Lab Directory: {lab.directory_path}")
        print(f"🆔 Lab ID: {lab.lab_id}")
        print(f"\n📄 Files created:")
        lab_path = Path(lab.directory_path)
        for file in sorted(lab_path.rglob("*")):
            if file.is_file():
                size = file.stat().st_size
                print(f"   - {file.relative_to(lab_path)} ({size} bytes)")

        print(f"\n📊 README.md preview (first 500 chars):")
        print("-" * 80)
        print(lab.readme_content[:500])
        print("...")
        print("-" * 80)

        print(f"\n💡 To view the full lab:")
        print(f"   cat {lab_path}/README.md")
        print(f"\n🧹 To clean up test lab:")
        print(f"   rm -rf test-labs")

        return 0

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
