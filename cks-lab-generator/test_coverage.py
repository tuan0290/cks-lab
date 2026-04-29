#!/usr/bin/env python3
"""Quick test script for CoverageTracker."""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from cks_lab_generator.config import Config
from cks_lab_generator.coverage_tracker import CoverageTracker


def main():
    """Test CoverageTracker with existing labs."""
    content_map_path = ".kiro/specs/cks-lab-exercises-generator/content-map.json"

    if not Path(content_map_path).exists():
        print(f"❌ Content map not found: {content_map_path}")
        print("Run test_analyzer.py first to generate content map")
        return 1

    print("🔍 Testing CoverageTracker...")
    print(f"📄 Content map: {content_map_path}\n")

    try:
        # Initialize with correct path to existing labs
        config = Config()
        # Override the output directory to point to the actual labs location
        config.config["output_directory"] = "../cks-lab-exercises/labs"
        tracker = CoverageTracker(config)

        # Generate coverage report
        print("⏳ Generating coverage report...")
        report = tracker.generate_coverage_report(content_map_path)

        # Display report
        print("\n" + "=" * 80)
        print(report)
        print("=" * 80)

        # Save report
        output_path = ".kiro/specs/cks-lab-exercises-generator/coverage-report.md"
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        Path(output_path).write_text(report, encoding="utf-8")
        print(f"\n💾 Coverage report saved to: {output_path}")

        return 0

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
