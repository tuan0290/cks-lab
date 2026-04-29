"""Data models for CKS Lab Generator."""

import json
from dataclasses import dataclass, field, asdict
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional


@dataclass
class Domain:
    """Represents one of 6 CKS exam domains."""

    number: int  # 1-6
    name: str  # e.g., "Cluster Setup"
    weight: int  # Exam weight percentage (10-20%)
    description: str
    skill_topics: List["SkillTopic"] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "number": self.number,
            "name": self.name,
            "weight": self.weight,
            "description": self.description,
            "skill_topics": [topic.to_dict() for topic in self.skill_topics],
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Domain":
        """Create from dictionary."""
        skill_topics = [SkillTopic.from_dict(t) for t in data.get("skill_topics", [])]
        return cls(
            number=data["number"],
            name=data["name"],
            weight=data["weight"],
            description=data["description"],
            skill_topics=skill_topics,
        )


@dataclass
class Command:
    """A bash command extracted from the guide."""

    command: str
    description: str
    context: str
    skill_topic_id: str

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Command":
        """Create from dictionary."""
        return cls(**data)


@dataclass
class YAMLManifest:
    """A Kubernetes YAML manifest."""

    content: str
    resource_type: str  # e.g., "Pod", "NetworkPolicy"
    description: str
    skill_topic_id: str
    is_valid: bool = True

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "YAMLManifest":
        """Create from dictionary."""
        return cls(**data)


@dataclass
class SkillTopic:
    """A specific skill or topic within a domain."""

    id: str  # e.g., "1.1"
    name: str  # e.g., "NetworkPolicy Configuration"
    domain_number: int
    difficulty: str  # "Easy", "Medium", "Hard"
    estimated_time: int  # minutes
    commands: List[Command] = field(default_factory=list)
    yaml_manifests: List[YAMLManifest] = field(default_factory=list)
    context: str = ""
    prerequisites: List[str] = field(default_factory=list)
    learning_objectives: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "id": self.id,
            "name": self.name,
            "domain_number": self.domain_number,
            "difficulty": self.difficulty,
            "estimated_time": self.estimated_time,
            "commands": [cmd.to_dict() for cmd in self.commands],
            "yaml_manifests": [yaml.to_dict() for yaml in self.yaml_manifests],
            "context": self.context,
            "prerequisites": self.prerequisites,
            "learning_objectives": self.learning_objectives,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "SkillTopic":
        """Create from dictionary."""
        commands = [Command.from_dict(c) for c in data.get("commands", [])]
        yaml_manifests = [YAMLManifest.from_dict(y) for y in data.get("yaml_manifests", [])]
        return cls(
            id=data["id"],
            name=data["name"],
            domain_number=data["domain_number"],
            difficulty=data["difficulty"],
            estimated_time=data["estimated_time"],
            commands=commands,
            yaml_manifests=yaml_manifests,
            context=data.get("context", ""),
            prerequisites=data.get("prerequisites", []),
            learning_objectives=data.get("learning_objectives", []),
        )


@dataclass
class ContentMap:
    """Complete structured representation of CKS guide content."""

    domains: List[Domain]
    total_topics: int
    extraction_date: str
    guide_version: str

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "domains": [domain.to_dict() for domain in self.domains],
            "total_topics": self.total_topics,
            "extraction_date": self.extraction_date,
            "guide_version": self.guide_version,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ContentMap":
        """Create from dictionary."""
        domains = [Domain.from_dict(d) for d in data["domains"]]
        return cls(
            domains=domains,
            total_topics=data["total_topics"],
            extraction_date=data["extraction_date"],
            guide_version=data["guide_version"],
        )

    def save_to_json(self, path: str) -> None:
        """Save content map to JSON file."""
        output_path = Path(path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(self.to_dict(), f, indent=2, ensure_ascii=False)

    @classmethod
    def load_from_json(cls, path: str) -> "ContentMap":
        """Load content map from JSON file."""
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return cls.from_dict(data)


@dataclass
class ExistingLab:
    """Represents an existing lab in the repository."""

    lab_id: str
    domain_number: int
    lab_number: int
    topic_name: str
    directory_path: str
    has_readme: bool
    has_setup: bool
    has_cleanup: bool
    has_verify: bool
    has_solution: bool
    covered_skill_topics: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return asdict(self)


@dataclass
class MissingTopic:
    """A skill topic that needs a lab."""

    skill_topic: SkillTopic
    priority: int  # 1-10 (based on exam weight and difficulty)
    reason: str  # Why it's missing

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "skill_topic": self.skill_topic.to_dict(),
            "priority": self.priority,
            "reason": self.reason,
        }


@dataclass
class CoverageReport:
    """Coverage analysis report."""

    overall_coverage: float  # 0-100%
    domain_coverage: Dict[int, float]  # domain_number -> coverage%
    covered_topics: List[SkillTopic]
    missing_topics: List[MissingTopic]
    partially_covered_topics: List[SkillTopic]
    report_date: str

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "overall_coverage": self.overall_coverage,
            "domain_coverage": self.domain_coverage,
            "covered_topics": [topic.to_dict() for topic in self.covered_topics],
            "missing_topics": [topic.to_dict() for topic in self.missing_topics],
            "partially_covered_topics": [topic.to_dict() for topic in self.partially_covered_topics],
            "report_date": self.report_date,
        }


@dataclass
class LabExercise:
    """A complete lab exercise."""

    lab_id: str  # e.g., "lab-1.1-network-policy"
    domain_number: int
    skill_topic: SkillTopic
    directory_path: str
    readme_content: str
    solution_content: str
    setup_script: str
    cleanup_script: str
    verify_script: str
    created_date: str

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "lab_id": self.lab_id,
            "domain_number": self.domain_number,
            "skill_topic": self.skill_topic.to_dict(),
            "directory_path": self.directory_path,
            "readme_content": self.readme_content,
            "solution_content": self.solution_content,
            "setup_script": self.setup_script,
            "cleanup_script": self.cleanup_script,
            "verify_script": self.verify_script,
            "created_date": self.created_date,
        }


@dataclass
class GeneratorConfig:
    """Configuration for lab generator."""

    output_directory: str = "cks-lab-exercises/labs"
    naming_convention: str = "lab-{domain}.{number}-{topic}"
    difficulty_criteria: Dict[str, Dict[str, int]] = field(default_factory=dict)
    time_estimation_formula: str = "base + commands + yaml + prerequisites"
    script_templates: Dict[str, str] = field(default_factory=dict)
    required_tools: List[str] = field(default_factory=list)
    kubernetes_version: str = "v1.29+"

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return asdict(self)
