"""Configuration management for CKS Lab Generator."""

import logging
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("cks-lab-generator.log"),
    ],
)

logger = logging.getLogger(__name__)


class Config:
    """Configuration manager for CKS Lab Generator."""

    DEFAULT_CONFIG = {
        "output_directory": "cks-lab-exercises/labs",
        "naming_convention": "lab-{domain}.{number}-{topic}",
        "kubernetes_version": "v1.29+",
        "difficulty_criteria": {
            "easy": {"max_commands": 3, "max_yaml_files": 1, "max_steps": 3},
            "medium": {"max_commands": 7, "max_yaml_files": 3, "max_steps": 6},
            "hard": {"max_commands": 15, "max_yaml_files": 5, "max_steps": 10},
        },
        "required_tools": ["kubectl", "trivy", "cosign", "falco", "syft", "kube-bench"],
        "script_templates": {
            "setup": "templates/setup.sh.j2",
            "cleanup": "templates/cleanup.sh.j2",
            "verify": "templates/verify.sh.j2",
        },
        "domain_weights": {
            1: 15,  # Cluster Setup
            2: 15,  # Cluster Hardening
            3: 10,  # System Hardening
            4: 20,  # Microservice Vulnerabilities
            5: 20,  # Supply Chain Security
            6: 20,  # Monitoring & Runtime Security
        },
    }

    def __init__(self, config_path: Optional[str] = None) -> None:
        """Initialize configuration.

        Args:
            config_path: Path to custom configuration file (YAML)
        """
        self.config: Dict[str, Any] = self.DEFAULT_CONFIG.copy()

        if config_path:
            self.load_config(config_path)

    def load_config(self, config_path: str) -> None:
        """Load configuration from YAML file.

        Args:
            config_path: Path to configuration file

        Raises:
            FileNotFoundError: If config file doesn't exist
            yaml.YAMLError: If config file is invalid YAML
        """
        path = Path(config_path)
        if not path.exists():
            logger.error(f"Configuration file not found: {config_path}")
            raise FileNotFoundError(f"Configuration file not found: {config_path}")

        try:
            with open(path, "r", encoding="utf-8") as f:
                custom_config = yaml.safe_load(f)

            if custom_config:
                self.config.update(custom_config)
                logger.info(f"Loaded configuration from {config_path}")
        except yaml.YAMLError as e:
            logger.error(f"Invalid YAML in configuration file: {e}")
            raise

    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value.

        Args:
            key: Configuration key (supports dot notation for nested keys)
            default: Default value if key not found

        Returns:
            Configuration value or default
        """
        keys = key.split(".")
        value = self.config

        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default

        return value

    def get_output_directory(self) -> Path:
        """Get output directory path.

        Returns:
            Path to output directory
        """
        return Path(self.get("output_directory", "cks-lab-exercises/labs"))

    def get_naming_convention(self) -> str:
        """Get lab naming convention.

        Returns:
            Naming convention template string
        """
        return self.get("naming_convention", "lab-{domain}.{number}-{topic}")

    def get_difficulty_criteria(self, difficulty: str) -> Dict[str, int]:
        """Get difficulty criteria.

        Args:
            difficulty: Difficulty level (easy, medium, hard)

        Returns:
            Dictionary with max_commands, max_yaml_files, max_steps
        """
        criteria = self.get(f"difficulty_criteria.{difficulty.lower()}")
        if not criteria:
            logger.warning(f"No criteria found for difficulty '{difficulty}', using medium")
            criteria = self.get("difficulty_criteria.medium")
        return criteria

    def get_required_tools(self) -> List[str]:
        """Get list of required tools.

        Returns:
            List of tool names
        """
        return self.get("required_tools", [])

    def get_domain_weight(self, domain_number: int) -> int:
        """Get exam weight for domain.

        Args:
            domain_number: Domain number (1-6)

        Returns:
            Weight percentage (10-20)
        """
        return self.get(f"domain_weights.{domain_number}", 15)

    def validate(self) -> bool:
        """Validate configuration.

        Returns:
            True if configuration is valid

        Raises:
            ValueError: If configuration is invalid
        """
        # Validate output directory
        output_dir = self.get_output_directory()
        if not output_dir.parent.exists():
            raise ValueError(f"Parent directory does not exist: {output_dir.parent}")

        # Validate difficulty criteria
        for difficulty in ["easy", "medium", "hard"]:
            criteria = self.get_difficulty_criteria(difficulty)
            if not all(k in criteria for k in ["max_commands", "max_yaml_files", "max_steps"]):
                raise ValueError(f"Invalid difficulty criteria for '{difficulty}'")

        # Validate domain weights
        total_weight = sum(self.get_domain_weight(i) for i in range(1, 7))
        if total_weight != 100:
            raise ValueError(f"Domain weights must sum to 100, got {total_weight}")

        logger.info("Configuration validated successfully")
        return True


def get_logger(name: str) -> logging.Logger:
    """Get logger instance.

    Args:
        name: Logger name (usually __name__)

    Returns:
        Logger instance
    """
    return logging.getLogger(name)
