"""Coverage tracker for monitoring lab coverage."""

import re
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple

from cks_lab_generator.config import Config, get_logger
from cks_lab_generator.models import (
    ContentMap,
    CoverageReport,
    ExistingLab,
    MissingTopic,
    SkillTopic,
)

logger = get_logger(__name__)


class CoverageTracker:
    """Track coverage of CKS exam topics."""

    def __init__(self, config: Config) -> None:
        """Initialize coverage tracker.

        Args:
            config: Configuration instance
        """
        self.config = config

    def scan_existing_labs(self, labs_dir: str) -> List[ExistingLab]:
        """Scan and catalog all existing labs.

        Args:
            labs_dir: Path to labs directory

        Returns:
            List of ExistingLab objects
        """
        logger.info(f"Scanning existing labs in {labs_dir}")
        labs_path = Path(labs_dir)

        if not labs_path.exists():
            logger.warning(f"Labs directory does not exist: {labs_dir}")
            return []

        existing_labs = []

        # Scan all domain directories
        for domain_dir in sorted(labs_path.iterdir()):
            if not domain_dir.is_dir() or domain_dir.name.startswith("."):
                continue

            # Extract domain number from directory name (e.g., "01-cluster-setup")
            domain_match = re.match(r"(\d+)-", domain_dir.name)
            if not domain_match:
                continue

            domain_number = int(domain_match.group(1))

            # Scan lab directories within domain
            for lab_dir in sorted(domain_dir.iterdir()):
                if not lab_dir.is_dir() or lab_dir.name.startswith("."):
                    continue

                # Extract lab info from directory name (e.g., "lab-1.1-network-policy")
                lab_match = re.match(r"lab-(\d+)\.(\d+)-(.+)", lab_dir.name)
                if not lab_match:
                    continue

                major = int(lab_match.group(1))
                minor = int(lab_match.group(2))
                topic_name = lab_match.group(3).replace("-", " ").title()

                # Check for required files
                has_readme = (lab_dir / "README.md").exists()
                has_setup = (lab_dir / "setup.sh").exists()
                has_cleanup = (lab_dir / "cleanup.sh").exists()
                has_verify = (lab_dir / "verify.sh").exists()
                has_solution = (lab_dir / "solution" / "solution.md").exists()

                # Determine covered skill topics
                skill_topic_id = f"{major}.{minor}"
                covered_topics = [skill_topic_id]

                existing_lab = ExistingLab(
                    lab_id=lab_dir.name,
                    domain_number=domain_number,
                    lab_number=minor,
                    topic_name=topic_name,
                    directory_path=str(lab_dir),
                    has_readme=has_readme,
                    has_setup=has_setup,
                    has_cleanup=has_cleanup,
                    has_verify=has_verify,
                    has_solution=has_solution,
                    covered_skill_topics=covered_topics,
                )
                existing_labs.append(existing_lab)

        logger.info(f"Found {len(existing_labs)} existing labs")
        return existing_labs

    def calculate_coverage(
        self, content_map: ContentMap, existing_labs: List[ExistingLab]
    ) -> CoverageReport:
        """Calculate coverage statistics.

        Args:
            content_map: Content map with all skill topics
            existing_labs: List of existing labs

        Returns:
            CoverageReport with coverage statistics
        """
        logger.info("Calculating coverage statistics")

        # Build set of covered skill topic IDs
        covered_ids = set()
        for lab in existing_labs:
            covered_ids.update(lab.covered_skill_topics)

        # Categorize topics
        covered_topics = []
        missing_topics = []
        partially_covered_topics = []

        for domain in content_map.domains:
            for topic in domain.skill_topics:
                if topic.id in covered_ids:
                    covered_topics.append(topic)
                else:
                    missing_topics.append(topic)

        # Calculate domain coverage
        domain_coverage: Dict[int, float] = {}
        for domain in content_map.domains:
            total = len(domain.skill_topics)
            if total == 0:
                domain_coverage[domain.number] = 100.0
                continue

            covered = sum(1 for topic in domain.skill_topics if topic.id in covered_ids)
            domain_coverage[domain.number] = (covered / total) * 100.0

        # Calculate overall weighted coverage
        overall_coverage = 0.0
        for domain in content_map.domains:
            weight = self.config.get_domain_weight(domain.number) / 100.0
            overall_coverage += domain_coverage[domain.number] * weight

        report = CoverageReport(
            overall_coverage=overall_coverage,
            domain_coverage=domain_coverage,
            covered_topics=covered_topics,
            missing_topics=self._create_missing_topics(missing_topics),
            partially_covered_topics=partially_covered_topics,
            report_date=datetime.now().isoformat(),
        )

        logger.info(f"Overall coverage: {overall_coverage:.1f}%")
        return report

    def _create_missing_topics(self, topics: List[SkillTopic]) -> List[MissingTopic]:
        """Create MissingTopic objects with priority.

        Args:
            topics: List of missing skill topics

        Returns:
            List of MissingTopic objects with priority
        """
        missing = []
        for topic in topics:
            # Calculate priority based on domain weight and difficulty
            domain_weight = self.config.get_domain_weight(topic.domain_number)

            # Priority: 1-10 (higher is more important)
            priority = domain_weight // 2  # Base priority from domain weight

            # Adjust for difficulty
            if topic.difficulty == "Hard":
                priority += 2
            elif topic.difficulty == "Medium":
                priority += 1

            # Cap at 10
            priority = min(priority, 10)

            missing_topic = MissingTopic(
                skill_topic=topic,
                priority=priority,
                reason="No lab found for this topic",
            )
            missing.append(missing_topic)

        return missing

    def identify_gaps(
        self, content_map: ContentMap, existing_labs: List[ExistingLab]
    ) -> List[MissingTopic]:
        """Identify missing or incomplete topics.

        Args:
            content_map: Content map with all skill topics
            existing_labs: List of existing labs

        Returns:
            List of MissingTopic objects
        """
        report = self.calculate_coverage(content_map, existing_labs)
        return report.missing_topics

    def prioritize_gaps(self, gaps: List[MissingTopic]) -> List[MissingTopic]:
        """Order gaps by exam weight and difficulty.

        Args:
            gaps: List of missing topics

        Returns:
            Sorted list of missing topics (highest priority first)
        """
        return sorted(gaps, key=lambda x: x.priority, reverse=True)

    def generate_report(self, coverage: CoverageReport) -> str:
        """Generate markdown coverage report.

        Args:
            coverage: Coverage report data

        Returns:
            Markdown formatted report
        """
        logger.info("Generating markdown coverage report")

        lines = []
        lines.append("# CKS Lab Coverage Report")
        lines.append("")
        lines.append(f"**Generated:** {coverage.report_date}")
        lines.append("")

        # Overall coverage
        lines.append("## Overall Coverage")
        lines.append("")
        lines.append(f"**{coverage.overall_coverage:.1f}%** of CKS exam content is covered")
        lines.append("")

        # Progress bar
        progress = int(coverage.overall_coverage / 10)
        bar = "█" * progress + "░" * (10 - progress)
        lines.append(f"`{bar}` {coverage.overall_coverage:.1f}%")
        lines.append("")

        # Domain coverage
        lines.append("## Coverage by Domain")
        lines.append("")
        lines.append("| Domain | Name | Weight | Coverage | Status |")
        lines.append("|--------|------|--------|----------|--------|")

        for domain_num in sorted(coverage.domain_coverage.keys()):
            cov = coverage.domain_coverage[domain_num]
            weight = self.config.get_domain_weight(domain_num)

            # Find domain name
            domain_name = f"Domain {domain_num}"
            for d in [t.domain_number for t in coverage.covered_topics + [mt.skill_topic for mt in coverage.missing_topics]]:
                if d == domain_num:
                    # Get domain name from ContentAnalyzer
                    from cks_lab_generator.content_analyzer import ContentAnalyzer
                    domain_name = ContentAnalyzer.DOMAIN_INFO.get(domain_num, {}).get("name", f"Domain {domain_num}")
                    break

            # Status indicator
            if cov >= 90:
                status = "✅ Complete"
            elif cov >= 50:
                status = "⚠️ Partial"
            else:
                status = "❌ Incomplete"

            lines.append(f"| {domain_num} | {domain_name} | {weight}% | {cov:.1f}% | {status} |")

        lines.append("")

        # Covered topics
        lines.append("## Covered Topics")
        lines.append("")
        if coverage.covered_topics:
            lines.append(f"**{len(coverage.covered_topics)} topics** are covered:")
            lines.append("")

            # Group by domain
            by_domain: Dict[int, List[SkillTopic]] = {}
            for topic in coverage.covered_topics:
                if topic.domain_number not in by_domain:
                    by_domain[topic.domain_number] = []
                by_domain[topic.domain_number].append(topic)

            for domain_num in sorted(by_domain.keys()):
                from cks_lab_generator.content_analyzer import ContentAnalyzer
                domain_name = ContentAnalyzer.DOMAIN_INFO.get(domain_num, {}).get("name", f"Domain {domain_num}")
                lines.append(f"### Domain {domain_num}: {domain_name}")
                lines.append("")

                for topic in sorted(by_domain[domain_num], key=lambda t: t.id):
                    lines.append(f"- ✅ **{topic.id}** {topic.name} ({topic.difficulty}, {topic.estimated_time} min)")

                lines.append("")
        else:
            lines.append("*No topics covered yet.*")
            lines.append("")

        # Missing topics
        lines.append("## Missing Topics")
        lines.append("")
        if coverage.missing_topics:
            lines.append(f"**{len(coverage.missing_topics)} topics** need labs:")
            lines.append("")

            # Sort by priority
            sorted_missing = self.prioritize_gaps(coverage.missing_topics)

            # Group by domain
            by_domain_missing: Dict[int, List[MissingTopic]] = {}
            for mt in sorted_missing:
                domain_num = mt.skill_topic.domain_number
                if domain_num not in by_domain_missing:
                    by_domain_missing[domain_num] = []
                by_domain_missing[domain_num].append(mt)

            for domain_num in sorted(by_domain_missing.keys()):
                from cks_lab_generator.content_analyzer import ContentAnalyzer
                domain_name = ContentAnalyzer.DOMAIN_INFO.get(domain_num, {}).get("name", f"Domain {domain_num}")
                lines.append(f"### Domain {domain_num}: {domain_name}")
                lines.append("")

                for mt in by_domain_missing[domain_num]:
                    topic = mt.skill_topic
                    priority_stars = "⭐" * min(mt.priority, 5)
                    lines.append(f"- ❌ **{topic.id}** {topic.name} ({topic.difficulty}, {topic.estimated_time} min) {priority_stars}")

                lines.append("")
        else:
            lines.append("*All topics are covered! 🎉*")
            lines.append("")

        # Summary
        lines.append("## Summary")
        lines.append("")
        lines.append(f"- **Total Topics:** {len(coverage.covered_topics) + len(coverage.missing_topics)}")
        lines.append(f"- **Covered:** {len(coverage.covered_topics)}")
        lines.append(f"- **Missing:** {len(coverage.missing_topics)}")
        lines.append(f"- **Overall Coverage:** {coverage.overall_coverage:.1f}%")
        lines.append("")

        if coverage.overall_coverage < 100:
            lines.append("### Next Steps")
            lines.append("")
            lines.append("Generate missing labs with:")
            lines.append("```bash")
            lines.append("cks-lab-gen generate")
            lines.append("```")
            lines.append("")

        return "\n".join(lines)

    def generate_coverage_report(self, content_map_path: str) -> str:
        """Generate complete coverage report.

        Args:
            content_map_path: Path to content map JSON

        Returns:
            Markdown coverage report
        """
        logger.info("Generating complete coverage report")

        # Load content map
        content_map = ContentMap.load_from_json(content_map_path)

        # Scan existing labs
        labs_dir = str(self.config.get_output_directory())
        existing_labs = self.scan_existing_labs(labs_dir)

        # Calculate coverage
        coverage = self.calculate_coverage(content_map, existing_labs)

        # Generate report
        report = self.generate_report(coverage)

        return report
