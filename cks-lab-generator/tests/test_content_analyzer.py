"""Tests for ContentAnalyzer."""

import pytest

from cks_lab_generator.config import Config
from cks_lab_generator.content_analyzer import ContentAnalyzer


class TestContentAnalyzer:
    """Test ContentAnalyzer class."""

    def test_init(self):
        """Test ContentAnalyzer initialization."""
        config = Config()
        analyzer = ContentAnalyzer(config)
        assert analyzer.config == config

    def test_domain_info(self):
        """Test domain information mapping."""
        assert len(ContentAnalyzer.DOMAIN_INFO) == 6
        assert ContentAnalyzer.DOMAIN_INFO[1]["name"] == "Cluster Setup"
        assert ContentAnalyzer.DOMAIN_INFO[1]["weight"] == 15
        assert ContentAnalyzer.DOMAIN_INFO[4]["weight"] == 20

    def test_validate_yaml_valid(self):
        """Test YAML validation with valid YAML."""
        config = Config()
        analyzer = ContentAnalyzer(config)

        valid_yaml = """
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: nginx
    image: nginx:latest
"""
        assert analyzer.validate_yaml(valid_yaml) is True

    def test_validate_yaml_invalid(self):
        """Test YAML validation with invalid YAML."""
        config = Config()
        analyzer = ContentAnalyzer(config)

        # Use truly invalid YAML (tab character which is not allowed in YAML)
        invalid_yaml = "apiVersion: v1\nkind:\tPod"  # Tab character
        assert analyzer.validate_yaml(invalid_yaml) is False

    def test_extract_resource_type(self):
        """Test extracting resource type from YAML."""
        config = Config()
        analyzer = ContentAnalyzer(config)

        yaml_content = """
apiVersion: v1
kind: NetworkPolicy
metadata:
  name: test-policy
"""
        resource_type = analyzer._extract_resource_type(yaml_content)
        assert resource_type == "NetworkPolicy"

    def test_estimate_difficulty_easy(self):
        """Test difficulty estimation for easy labs."""
        config = Config()
        analyzer = ContentAnalyzer(config)

        # Easy: 2 commands, 1 YAML
        commands = [None, None]  # Mock commands
        yaml_manifests = [None]  # Mock YAML

        difficulty = analyzer._estimate_difficulty(commands, yaml_manifests)
        assert difficulty == "Easy"

    def test_estimate_difficulty_medium(self):
        """Test difficulty estimation for medium labs."""
        config = Config()
        analyzer = ContentAnalyzer(config)

        # Medium: 5 commands, 2 YAMLs
        commands = [None] * 5
        yaml_manifests = [None] * 2

        difficulty = analyzer._estimate_difficulty(commands, yaml_manifests)
        assert difficulty == "Medium"

    def test_estimate_difficulty_hard(self):
        """Test difficulty estimation for hard labs."""
        config = Config()
        analyzer = ContentAnalyzer(config)

        # Hard: 10 commands, 4 YAMLs
        commands = [None] * 10
        yaml_manifests = [None] * 4

        difficulty = analyzer._estimate_difficulty(commands, yaml_manifests)
        assert difficulty == "Hard"

    def test_estimate_time(self):
        """Test time estimation."""
        config = Config()
        analyzer = ContentAnalyzer(config)

        commands = [None] * 3
        yaml_manifests = [None] * 2
        prerequisites = ["kubectl", "trivy"]

        time = analyzer._estimate_time(commands, yaml_manifests, prerequisites, "Medium")
        assert time > 0
        assert isinstance(time, int)
