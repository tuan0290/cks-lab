"""Content analyzer for extracting structured data from CKS guide."""

import re
from datetime import datetime
from pathlib import Path
from typing import List, Optional, Tuple

import yaml
from markdown_it import MarkdownIt

from cks_lab_generator.config import Config, get_logger
from cks_lab_generator.models import (
    Command,
    ContentMap,
    Domain,
    SkillTopic,
    YAMLManifest,
)

logger = get_logger(__name__)


class ContentAnalyzer:
    """Analyze CKS guide and extract structured content."""

    # Domain mapping with weights
    DOMAIN_INFO = {
        1: {"name": "Cluster Setup", "weight": 15},
        2: {"name": "Cluster Hardening", "weight": 15},
        3: {"name": "System Hardening", "weight": 10},
        4: {"name": "Minimize Microservice Vulnerabilities", "weight": 20},
        5: {"name": "Supply Chain Security", "weight": 20},
        6: {"name": "Monitoring, Logging & Runtime Security", "weight": 20},
    }

    def __init__(self, config: Config) -> None:
        """Initialize content analyzer.

        Args:
            config: Configuration instance
        """
        self.config = config
        self.md = MarkdownIt()

    def parse_guide(self, guide_path: str) -> ContentMap:
        """Parse CKS guide and return structured content map.

        Args:
            guide_path: Path to CKS_2026_Lab_Guide.md

        Returns:
            ContentMap with all extracted content

        Raises:
            FileNotFoundError: If guide file doesn't exist
        """
        path = Path(guide_path)
        if not path.exists():
            raise FileNotFoundError(f"Guide file not found: {guide_path}")

        logger.info(f"Parsing CKS guide: {guide_path}")

        # Read guide content
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        # Extract domains
        domains = self.extract_domains(content)

        # Calculate total topics
        total_topics = sum(len(domain.skill_topics) for domain in domains)

        # Create content map
        content_map = ContentMap(
            domains=domains,
            total_topics=total_topics,
            extraction_date=datetime.now().isoformat(),
            guide_version="v2.0 (2026)",
        )

        logger.info(f"Extracted {len(domains)} domains with {total_topics} skill topics")
        return content_map

    def extract_domains(self, markdown_content: str) -> List[Domain]:
        """Extract all 6 domains from markdown.

        Args:
            markdown_content: Full markdown content

        Returns:
            List of Domain objects
        """
        domains = []

        # Pattern to match domain headers: ## Domain X: Name (Weight%)
        domain_pattern = r"## Domain (\d+): (.+?) \((\d+)%\)"

        # Split content by domain headers
        domain_matches = list(re.finditer(domain_pattern, markdown_content))

        for i, match in enumerate(domain_matches):
            domain_number = int(match.group(1))
            domain_name = match.group(2).strip()
            domain_weight = int(match.group(3))

            # Extract domain content (from this header to next domain or end)
            start_pos = match.end()
            end_pos = domain_matches[i + 1].start() if i + 1 < len(domain_matches) else len(markdown_content)
            domain_content = markdown_content[start_pos:end_pos]

            # Extract description (first paragraph after header)
            description = self._extract_domain_description(domain_content)

            # Extract skill topics within this domain
            skill_topics = self.extract_skill_topics(domain_content, domain_number)

            domain = Domain(
                number=domain_number,
                name=domain_name,
                weight=domain_weight,
                description=description,
                skill_topics=skill_topics,
            )
            domains.append(domain)

            logger.info(f"Extracted Domain {domain_number}: {domain_name} ({len(skill_topics)} topics)")

        return domains

    def _extract_domain_description(self, domain_content: str) -> str:
        """Extract domain description from content.

        Args:
            domain_content: Domain section content

        Returns:
            Description text
        """
        # Look for "Trọng tâm thi:" section
        match = re.search(r"\*\*Trọng tâm thi:\*\*\s*\n(.+?)(?:\n\n|\n\|)", domain_content, re.DOTALL)
        if match:
            return match.group(1).strip()

        # Fallback: get first paragraph
        lines = domain_content.strip().split("\n")
        for line in lines:
            line = line.strip()
            if line and not line.startswith("#") and not line.startswith("|"):
                return line

        return ""

    def extract_skill_topics(self, domain_content: str, domain_number: int) -> List[SkillTopic]:
        """Extract skill topics within a domain.

        Args:
            domain_content: Domain section content
            domain_number: Domain number (1-6)

        Returns:
            List of SkillTopic objects
        """
        skill_topics = []

        # Pattern to match lab sections: ### Lab X.Y: Topic Name
        lab_pattern = r"### Lab (\d+)\.(\d+): (.+?)(?:\n|$)"

        lab_matches = list(re.finditer(lab_pattern, domain_content))

        for i, match in enumerate(lab_matches):
            major = int(match.group(1))
            minor = int(match.group(2))
            topic_name = match.group(3).strip()

            skill_id = f"{major}.{minor}"

            # Extract lab content (from this header to next lab or end of section)
            start_pos = match.end()
            end_pos = lab_matches[i + 1].start() if i + 1 < len(lab_matches) else len(domain_content)
            lab_content = domain_content[start_pos:end_pos]

            # Extract commands and YAML
            commands = self.extract_commands(lab_content, skill_id)
            yaml_manifests = self.extract_yaml_manifests(lab_content, skill_id)

            # Extract prerequisites and learning objectives
            prerequisites = self._extract_prerequisites(lab_content)
            learning_objectives = self._extract_learning_objectives(topic_name, lab_content)

            # Estimate difficulty and time
            difficulty = self._estimate_difficulty(commands, yaml_manifests)
            estimated_time = self._estimate_time(commands, yaml_manifests, prerequisites, difficulty)

            skill_topic = SkillTopic(
                id=skill_id,
                name=topic_name,
                domain_number=domain_number,
                difficulty=difficulty,
                estimated_time=estimated_time,
                commands=commands,
                yaml_manifests=yaml_manifests,
                context=lab_content[:500],  # First 500 chars as context
                prerequisites=prerequisites,
                learning_objectives=learning_objectives,
            )
            skill_topics.append(skill_topic)

        return skill_topics

    def extract_commands(self, content: str, skill_topic_id: str) -> List[Command]:
        """Extract bash commands from code blocks.

        Args:
            content: Content to extract from
            skill_topic_id: Associated skill topic ID

        Returns:
            List of Command objects
        """
        commands = []

        # Pattern to match ```bash code blocks
        bash_pattern = r"```bash\n(.*?)```"

        for match in re.finditer(bash_pattern, content, re.DOTALL):
            code_block = match.group(1).strip()

            # Split into individual commands (by newline, ignoring comments)
            for line in code_block.split("\n"):
                line = line.strip()

                # Skip empty lines and comments
                if not line or line.startswith("#"):
                    continue

                # Extract description from comment above (if any)
                description = self._extract_command_description(content, match.start())

                command = Command(
                    command=line,
                    description=description,
                    context=code_block[:200],  # First 200 chars as context
                    skill_topic_id=skill_topic_id,
                )
                commands.append(command)

        return commands

    def _extract_command_description(self, content: str, position: int) -> str:
        """Extract description for a command from surrounding context.

        Args:
            content: Full content
            position: Position of code block

        Returns:
            Description text
        """
        # Look backwards for comment or text before code block
        before_content = content[max(0, position - 200):position]
        lines = before_content.split("\n")

        for line in reversed(lines):
            line = line.strip()
            if line and not line.startswith("```") and not line.startswith("#"):
                return line[:100]  # Max 100 chars

        return ""

    def extract_yaml_manifests(self, content: str, skill_topic_id: str) -> List[YAMLManifest]:
        """Extract YAML manifests from code blocks.

        Args:
            content: Content to extract from
            skill_topic_id: Associated skill topic ID

        Returns:
            List of YAMLManifest objects
        """
        manifests = []

        # Pattern to match ```yaml code blocks
        yaml_pattern = r"```yaml\n(.*?)```"

        for match in re.finditer(yaml_pattern, content, re.DOTALL):
            yaml_content = match.group(1).strip()

            # Validate YAML
            is_valid = self.validate_yaml(yaml_content)

            # Extract resource type from YAML
            resource_type = self._extract_resource_type(yaml_content)

            # Extract description from comment above
            description = self._extract_yaml_description(content, match.start())

            manifest = YAMLManifest(
                content=yaml_content,
                resource_type=resource_type,
                description=description,
                skill_topic_id=skill_topic_id,
                is_valid=is_valid,
            )
            manifests.append(manifest)

        return manifests

    def validate_yaml(self, yaml_content: str) -> bool:
        """Validate YAML syntax.

        Args:
            yaml_content: YAML content to validate

        Returns:
            True if valid, False otherwise
        """
        try:
            yaml.safe_load(yaml_content)
            return True
        except yaml.YAMLError as e:
            logger.warning(f"Invalid YAML: {e}")
            return False

    def _extract_resource_type(self, yaml_content: str) -> str:
        """Extract Kubernetes resource type from YAML.

        Args:
            yaml_content: YAML content

        Returns:
            Resource type (e.g., "Pod", "NetworkPolicy")
        """
        try:
            data = yaml.safe_load(yaml_content)
            if isinstance(data, dict) and "kind" in data:
                return data["kind"]
        except yaml.YAMLError:
            pass

        return "Unknown"

    def _extract_yaml_description(self, content: str, position: int) -> str:
        """Extract description for YAML from surrounding context.

        Args:
            content: Full content
            position: Position of code block

        Returns:
            Description text
        """
        # Look backwards for comment or text before code block
        before_content = content[max(0, position - 200):position]
        lines = before_content.split("\n")

        for line in reversed(lines):
            line = line.strip()
            if line and not line.startswith("```") and not line.startswith("#"):
                return line[:100]  # Max 100 chars

        return ""

    def _extract_prerequisites(self, content: str) -> List[str]:
        """Extract prerequisites from content.

        Args:
            content: Lab content

        Returns:
            List of prerequisites
        """
        prerequisites = ["Kubernetes cluster v1.29+", "kubectl configured"]

        # Look for tool mentions
        tools = ["trivy", "cosign", "falco", "kube-bench", "syft", "kyverno"]
        for tool in tools:
            if tool in content.lower():
                prerequisites.append(tool)

        return list(set(prerequisites))  # Remove duplicates

    def _extract_learning_objectives(self, topic_name: str, content: str) -> List[str]:
        """Extract learning objectives from topic.

        Args:
            topic_name: Topic name
            content: Lab content

        Returns:
            List of learning objectives
        """
        objectives = [f"Understand {topic_name}"]

        # Add specific objectives based on content
        if "configure" in topic_name.lower() or "configuration" in topic_name.lower():
            objectives.append(f"Configure {topic_name} correctly")

        if "security" in topic_name.lower():
            objectives.append("Apply security best practices")

        if "policy" in topic_name.lower():
            objectives.append("Create and enforce policies")

        return objectives

    def _estimate_difficulty(self, commands: List[Command], yaml_manifests: List[YAMLManifest]) -> str:
        """Estimate difficulty level based on complexity.

        Args:
            commands: List of commands
            yaml_manifests: List of YAML manifests

        Returns:
            Difficulty level: "Easy", "Medium", or "Hard"
        """
        num_commands = len(commands)
        num_yaml = len(yaml_manifests)

        # Get criteria from config
        easy_criteria = self.config.get_difficulty_criteria("easy")
        medium_criteria = self.config.get_difficulty_criteria("medium")

        if num_commands <= easy_criteria["max_commands"] and num_yaml <= easy_criteria["max_yaml_files"]:
            return "Easy"
        elif num_commands <= medium_criteria["max_commands"] and num_yaml <= medium_criteria["max_yaml_files"]:
            return "Medium"
        else:
            return "Hard"

    def _estimate_time(
        self,
        commands: List[Command],
        yaml_manifests: List[YAMLManifest],
        prerequisites: List[str],
        difficulty: str,
    ) -> int:
        """Estimate completion time in minutes.

        Args:
            commands: List of commands
            yaml_manifests: List of YAML manifests
            prerequisites: List of prerequisites
            difficulty: Difficulty level

        Returns:
            Estimated time in minutes
        """
        # Get time estimation parameters from config
        base_time = self.config.get("time_estimation.base_time", 5)
        per_command = self.config.get("time_estimation.per_command", 1)
        per_yaml = self.config.get("time_estimation.per_yaml", 2)
        per_prerequisite = self.config.get("time_estimation.per_prerequisite", 2)

        # Calculate base time
        time = base_time
        time += len(commands) * per_command
        time += len(yaml_manifests) * per_yaml
        time += len(prerequisites) * per_prerequisite

        # Apply difficulty multiplier
        multipliers = self.config.get("time_estimation.difficulty_multipliers", {})
        multiplier = multipliers.get(difficulty.lower(), 1.0)
        time = int(time * multiplier)

        return time
