#!/usr/bin/env python3
"""Test script for ScriptGenerator."""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from cks_lab_generator.config import Config
from cks_lab_generator.models import ContentMap
from cks_lab_generator.script_generator import ScriptGenerator


def main():
    """Test ScriptGenerator with a sample topic."""
    content_map_path = ".kiro/specs/cks-lab-exercises-generator/content-map.json"

    if not Path(content_map_path).exists():
        print(f"❌ Content map not found: {content_map_path}")
        print("Run test_analyzer.py first to generate content map")
        return 1

    print("🔍 Testing ScriptGenerator...")
    print(f"📄 Content map: {content_map_path}\n")

    try:
        # Load content map
        content_map = ContentMap.load_from_json(content_map_path)
        print(f"✓ Loaded content map with {len(content_map.domains)} domains")

        # Initialize
        config = Config()
        generator = ScriptGenerator(config)

        # Get first domain and first topic
        domain = content_map.domains[0]
        if not domain.skill_topics:
            print("❌ No skill topics found in first domain")
            return 1

        topic = domain.skill_topics[0]
        print(f"\n📝 Generating scripts for:")
        print(f"   Domain: {domain.number} - {domain.name}")
        print(f"   Topic: {topic.id} - {topic.name}")
        print(f"   Commands: {len(topic.commands)}")
        print(f"   YAML Manifests: {len(topic.yaml_manifests)}\n")

        # Generate scripts
        print("⏳ Generating scripts...")
        setup_script = generator.generate_setup_script(topic)
        cleanup_script = generator.generate_cleanup_script(topic)
        verify_script = generator.generate_verify_script(topic)

        # Display results
        print("\n" + "=" * 80)
        print("✅ Scripts generated successfully!")
        print("=" * 80)

        print(f"\n📄 setup.sh ({len(setup_script)} bytes):")
        print("-" * 80)
        print(setup_script[:500])
        print("...")
        print("-" * 80)

        print(f"\n📄 cleanup.sh ({len(cleanup_script)} bytes):")
        print("-" * 80)
        print(cleanup_script[:300])
        print("...")
        print("-" * 80)

        print(f"\n📄 verify.sh ({len(verify_script)} bytes):")
        print("-" * 80)
        print(verify_script[:500])
        print("...")
        print("-" * 80)

        # Save to test files
        test_dir = Path("test-scripts")
        test_dir.mkdir(exist_ok=True)

        (test_dir / "setup.sh").write_text(setup_script, encoding="utf-8")
        (test_dir / "cleanup.sh").write_text(cleanup_script, encoding="utf-8")
        (test_dir / "verify.sh").write_text(verify_script, encoding="utf-8")

        # Make executable
        for script in ["setup.sh", "cleanup.sh", "verify.sh"]:
            (test_dir / script).chmod(0o755)

        print(f"\n💾 Scripts saved to: {test_dir}/")
        print(f"\n💡 To test the scripts:")
        print(f"   cd {test_dir}")
        print(f"   ./setup.sh")
        print(f"   ./verify.sh")
        print(f"   ./cleanup.sh")
        print(f"\n🧹 To clean up test scripts:")
        print(f"   rm -rf {test_dir}")

        return 0

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
