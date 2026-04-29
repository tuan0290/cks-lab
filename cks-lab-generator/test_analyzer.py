#!/usr/bin/env python3
"""Quick test script for ContentAnalyzer."""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from cks_lab_generator.config import Config
from cks_lab_generator.content_analyzer import ContentAnalyzer


def main():
    """Test ContentAnalyzer with CKS guide."""
    # Path to CKS guide (adjust as needed)
    guide_path = "../CKS_2026_Lab_Guide.md"

    if not Path(guide_path).exists():
        print(f"❌ Guide file not found: {guide_path}")
        print("Please adjust the path in test_analyzer.py")
        return 1

    print("🔍 Testing ContentAnalyzer...")
    print(f"📄 Guide path: {guide_path}\n")

    try:
        # Initialize
        config = Config()
        analyzer = ContentAnalyzer(config)

        # Parse guide
        print("⏳ Parsing CKS guide...")
        content_map = analyzer.parse_guide(guide_path)

        # Display results
        print(f"\n✅ Successfully parsed CKS guide!")
        print(f"\n📊 Summary:")
        print(f"  - Total domains: {len(content_map.domains)}")
        print(f"  - Total topics: {content_map.total_topics}")
        print(f"  - Extraction date: {content_map.extraction_date}")
        print(f"  - Guide version: {content_map.guide_version}")

        print(f"\n📋 Domains:")
        for domain in content_map.domains:
            print(f"\n  Domain {domain.number}: {domain.name} ({domain.weight}%)")
            print(f"    Topics: {len(domain.skill_topics)}")

            # Show first 3 topics
            for i, topic in enumerate(domain.skill_topics[:3]):
                print(f"      {topic.id}. {topic.name}")
                print(f"         Difficulty: {topic.difficulty}, Time: {topic.estimated_time} min")
                print(f"         Commands: {len(topic.commands)}, YAML: {len(topic.yaml_manifests)}")

            if len(domain.skill_topics) > 3:
                print(f"      ... and {len(domain.skill_topics) - 3} more topics")

        # Save content map
        output_path = ".kiro/specs/cks-lab-exercises-generator/content-map.json"
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        content_map.save_to_json(output_path)
        print(f"\n💾 Content map saved to: {output_path}")

        return 0

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
