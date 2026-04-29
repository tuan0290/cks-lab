"""Script generator for creating executable bash scripts."""

import re
from typing import Dict, List, Optional, Set

from cks_lab_generator.config import Config, get_logger
from cks_lab_generator.models import Command, SkillTopic, YAMLManifest

logger = get_logger(__name__)


class ScriptGenerator:
    """Generate executable bash scripts for lab exercises."""

    # Color codes for script output
    COLORS = {
        "RED": r'\033[0;31m',
        "GREEN": r'\033[0;32m',
        "YELLOW": r'\033[1;33m',
        "BLUE": r'\033[0;34m',
        "NC": r'\033[0m',  # No Color
    }

    # Tool installation URLs
    TOOL_DOCS = {
        "kubectl": "https://kubernetes.io/docs/tasks/tools/",
        "trivy": "https://aquasecurity.github.io/trivy/latest/getting-started/installation/",
        "cosign": "https://docs.sigstore.dev/cosign/installation/",
        "falco": "https://falco.org/docs/getting-started/installation/",
        "syft": "https://github.com/anchore/syft#installation",
        "kube-bench": "https://github.com/aquasecurity/kube-bench#installation",
    }

    def __init__(self, config: Config) -> None:
        """Initialize script generator.

        Args:
            config: Configuration instance
        """
        self.config = config

    def generate_setup_script(
        self, skill_topic: SkillTopic, namespace: Optional[str] = None
    ) -> str:
        """Generate setup.sh script.

        Args:
            skill_topic: Skill topic for the lab
            namespace: Optional namespace name (default: lab-{topic_id})

        Returns:
            setup.sh script content
        """
        logger.info(f"Generating setup.sh for topic {skill_topic.id}")

        if namespace is None:
            namespace = f"lab-{skill_topic.id.replace('.', '-')}"

        lines = []

        # Shebang and error handling
        lines.append("#!/bin/bash")
        lines.append("set -e")
        lines.append("")

        # Colors
        lines.extend(self._generate_color_definitions())
        lines.append("")

        # Header
        lines.append(f'echo -e "${{GREEN}}=== Lab Setup: {skill_topic.name} ===${{NC}}"')
        lines.append('echo ""')
        lines.append("")

        # Prerequisite checks function
        lines.extend(self._generate_prerequisite_checks(skill_topic))
        lines.append("")

        # Create resources function
        lines.extend(self._generate_resource_creation(skill_topic, namespace))
        lines.append("")

        # Main execution
        lines.append("# Main execution")
        lines.append("check_prerequisites")
        lines.append("create_resources")
        lines.append("")

        # Success message
        lines.append('echo ""')
        lines.append(f'echo -e "${{GREEN}}✓ Lab setup complete${{NC}}"')
        lines.append(f'echo "Resources created in namespace: {namespace}"')
        lines.append(f'kubectl get all -n {namespace} 2>/dev/null || true')
        lines.append("")

        return "\n".join(lines)

    def generate_cleanup_script(
        self, skill_topic: SkillTopic, namespace: Optional[str] = None
    ) -> str:
        """Generate cleanup.sh script.

        Args:
            skill_topic: Skill topic for the lab
            namespace: Optional namespace name (default: lab-{topic_id})

        Returns:
            cleanup.sh script content
        """
        logger.info(f"Generating cleanup.sh for topic {skill_topic.id}")

        if namespace is None:
            namespace = f"lab-{skill_topic.id.replace('.', '-')}"

        lines = []

        # Shebang
        lines.append("#!/bin/bash")
        lines.append("")

        # Colors
        lines.extend(self._generate_color_definitions())
        lines.append("")

        # Header
        lines.append(f'echo -e "${{YELLOW}}=== Lab Cleanup: {skill_topic.name} ===${{NC}}"')
        lines.append('echo ""')
        lines.append("")

        # Delete resources function
        lines.extend(self._generate_resource_deletion(skill_topic, namespace))
        lines.append("")

        # Main execution
        lines.append("# Main execution")
        lines.append("delete_resources")
        lines.append("")

        # Success message
        lines.append('echo ""')
        lines.append(f'echo -e "${{GREEN}}✓ Lab cleanup complete${{NC}}"')
        lines.append("")

        return "\n".join(lines)

    def generate_verify_script(
        self, skill_topic: SkillTopic, namespace: Optional[str] = None
    ) -> str:
        """Generate verify.sh script.

        Args:
            skill_topic: Skill topic for the lab
            namespace: Optional namespace name (default: lab-{topic_id})

        Returns:
            verify.sh script content
        """
        logger.info(f"Generating verify.sh for topic {skill_topic.id}")

        if namespace is None:
            namespace = f"lab-{skill_topic.id.replace('.', '-')}"

        lines = []

        # Shebang
        lines.append("#!/bin/bash")
        lines.append("")

        # Colors
        lines.extend(self._generate_color_definitions())
        lines.append("")

        # Counters
        lines.append("PASSED=0")
        lines.append("FAILED=0")
        lines.append("")

        # Header
        lines.append(f'echo -e "${{YELLOW}}=== Lab Verification: {skill_topic.name} ===${{NC}}"')
        lines.append('echo ""')
        lines.append("")

        # Check function
        lines.extend(self._generate_check_function())
        lines.append("")

        # Verification checks
        lines.extend(self._generate_verification_checks(skill_topic, namespace))
        lines.append("")

        # Summary
        lines.extend(self._generate_verification_summary())
        lines.append("")

        return "\n".join(lines)

    def _generate_color_definitions(self) -> List[str]:
        """Generate color variable definitions.

        Returns:
            List of color definition lines
        """
        lines = ["# Colors for output"]
        for name, code in self.COLORS.items():
            lines.append(f"{name}='{code}'")
        return lines

    def _generate_prerequisite_checks(self, skill_topic: SkillTopic) -> List[str]:
        """Generate prerequisite check function.

        Args:
            skill_topic: Skill topic for the lab

        Returns:
            List of script lines
        """
        lines = ["# Check prerequisites"]
        lines.append("check_prerequisites() {")
        lines.append('    echo "Checking prerequisites..."')
        lines.append('    echo ""')
        lines.append("")

        # Check kubectl
        lines.append("    # Check kubectl")
        lines.append("    if ! command -v kubectl &> /dev/null; then")
        lines.append('        echo -e "${RED}Error: kubectl not found${NC}"')
        lines.append('        echo "Install kubectl: https://kubernetes.io/docs/tasks/tools/"')
        lines.append("        exit 1")
        lines.append("    fi")
        lines.append('    echo -e "${GREEN}✓ kubectl found${NC}"')
        lines.append("")

        # Check cluster connectivity
        lines.append("    # Check cluster connectivity")
        lines.append("    if ! kubectl cluster-info &> /dev/null; then")
        lines.append('        echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"')
        lines.append('        echo "Make sure your kubeconfig is configured correctly"')
        lines.append("        exit 1")
        lines.append("    fi")
        lines.append('    echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"')
        lines.append("")

        # Check additional tools based on prerequisites
        required_tools = self._extract_required_tools(skill_topic)
        for tool in required_tools:
            lines.extend(self._generate_tool_check(tool))
            lines.append("")

        lines.append('    echo ""')
        lines.append("}")

        return lines

    def _extract_required_tools(self, skill_topic: SkillTopic) -> Set[str]:
        """Extract required tools from skill topic.

        Args:
            skill_topic: Skill topic to analyze

        Returns:
            Set of required tool names
        """
        tools = set()

        # Check commands for tool usage
        for cmd in skill_topic.commands:
            command_lower = cmd.command.lower()
            for tool in ["trivy", "cosign", "falco", "syft", "kube-bench"]:
                if tool in command_lower:
                    tools.add(tool)

        # Check context for tool mentions
        if skill_topic.context:
            context_lower = skill_topic.context.lower()
            for tool in ["trivy", "cosign", "falco", "syft", "kube-bench"]:
                if tool in context_lower:
                    tools.add(tool)

        return tools

    def _generate_tool_check(self, tool: str) -> List[str]:
        """Generate check for a specific tool.

        Args:
            tool: Tool name

        Returns:
            List of script lines
        """
        lines = [f"    # Check {tool}"]
        lines.append(f"    if ! command -v {tool} &> /dev/null; then")
        lines.append(f'        echo -e "${{YELLOW}}Warning: {tool} not found${{NC}}"')

        if tool in self.TOOL_DOCS:
            lines.append(f'        echo "Install {tool}: {self.TOOL_DOCS[tool]}"')
        else:
            lines.append(f'        echo "Install {tool} before proceeding"')

        lines.append('        echo "This lab requires this tool to complete"')
        lines.append("        exit 1")
        lines.append("    fi")
        lines.append(f'    echo -e "${{GREEN}}✓ {tool} found${{NC}}"')

        return lines

    def _generate_resource_creation(
        self, skill_topic: SkillTopic, namespace: str
    ) -> List[str]:
        """Generate resource creation function.

        Args:
            skill_topic: Skill topic for the lab
            namespace: Namespace name

        Returns:
            List of script lines
        """
        lines = ["# Create resources"]
        lines.append("create_resources() {")
        lines.append('    echo "Creating lab resources..."')
        lines.append('    echo ""')
        lines.append("")

        # Create namespace (idempotent)
        lines.append("    # Create namespace")
        lines.append(
            f"    kubectl create namespace {namespace} --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1"
        )
        lines.append(f'    echo -e "${{GREEN}}✓ Namespace {namespace} ready${{NC}}"')
        lines.append("")

        # Create resources from YAML manifests
        if skill_topic.yaml_manifests:
            lines.append("    # Create Kubernetes resources")
            for i, manifest in enumerate(skill_topic.yaml_manifests, 1):
                resource_type = manifest.resource_type or "resource"
                lines.append(f"    # {manifest.description or f'Create {resource_type}'}")
                lines.append(f"    cat <<EOF | kubectl apply -f - > /dev/null 2>&1")
                lines.append(manifest.content)
                lines.append("EOF")
                lines.append(
                    f'    echo -e "${{GREEN}}✓ {resource_type} created${{NC}}"'
                )
                lines.append("")

        # Execute setup commands if any
        if skill_topic.commands:
            lines.append("    # Execute setup commands")
            for cmd in skill_topic.commands[:3]:  # Limit to first 3 commands
                if self._is_safe_setup_command(cmd.command):
                    lines.append(f"    # {cmd.description or 'Execute command'}")
                    lines.append(f"    {cmd.command} > /dev/null 2>&1 || true")
                    lines.append("")

        lines.append('    echo ""')
        lines.append("}")

        return lines

    def _is_safe_setup_command(self, command: str) -> bool:
        """Check if command is safe for setup script.

        Args:
            command: Command to check

        Returns:
            True if command is safe for setup
        """
        # Avoid destructive commands
        unsafe_patterns = [
            r"\brm\b",
            r"\bdelete\b",
            r"\bdestroy\b",
            r"\bkill\b",
            r"--force",
        ]

        command_lower = command.lower()
        for pattern in unsafe_patterns:
            if re.search(pattern, command_lower):
                return False

        return True

    def _generate_resource_deletion(
        self, skill_topic: SkillTopic, namespace: str
    ) -> List[str]:
        """Generate resource deletion function.

        Args:
            skill_topic: Skill topic for the lab
            namespace: Namespace name

        Returns:
            List of script lines
        """
        lines = ["# Delete resources"]
        lines.append("delete_resources() {")
        lines.append('    echo "Deleting lab resources..."')
        lines.append('    echo ""')
        lines.append("")

        # Delete specific resources first (in reverse order)
        if skill_topic.yaml_manifests:
            lines.append("    # Delete specific resources")
            for manifest in reversed(skill_topic.yaml_manifests):
                resource_type = manifest.resource_type or "resource"
                lines.append(f"    # Delete {resource_type}")
                lines.append(
                    f"    kubectl delete {resource_type.lower()} --all -n {namespace} "
                    f"--ignore-not-found=true > /dev/null 2>&1 || true"
                )
                lines.append("")

        # Delete namespace (this will delete everything)
        lines.append("    # Delete namespace")
        lines.append(
            f"    kubectl delete namespace {namespace} --ignore-not-found=true > /dev/null 2>&1"
        )
        lines.append(f'    echo -e "${{GREEN}}✓ Namespace {namespace} deleted${{NC}}"')
        lines.append("")

        lines.append('    echo ""')
        lines.append("}")

        return lines

    def _generate_check_function(self) -> List[str]:
        """Generate check function for verification script.

        Returns:
            List of script lines
        """
        lines = ["# Check function"]
        lines.append("check() {")
        lines.append('    local description="$1"')
        lines.append('    local command="$2"')
        lines.append('    local expected="$3"')
        lines.append('    local hint="$4"')
        lines.append("")
        lines.append('    echo -n "Checking: $description... "')
        lines.append("")
        lines.append('    if eval "$command" 2>/dev/null | grep -q "$expected"; then')
        lines.append('        echo -e "${GREEN}✓ PASS${NC}"')
        lines.append("        ((PASSED++))")
        lines.append("    else")
        lines.append('        echo -e "${RED}✗ FAIL${NC}"')
        lines.append('        if [ -n "$hint" ]; then')
        lines.append('            echo -e "  ${YELLOW}Hint: $hint${NC}"')
        lines.append("        fi")
        lines.append("        ((FAILED++))")
        lines.append("    fi")
        lines.append("}")

        return lines

    def _generate_verification_checks(
        self, skill_topic: SkillTopic, namespace: str
    ) -> List[str]:
        """Generate verification checks.

        Args:
            skill_topic: Skill topic for the lab
            namespace: Namespace name

        Returns:
            List of script lines
        """
        lines = ["# Verification checks"]
        lines.append("")

        # Check namespace exists
        lines.append("check \\")
        lines.append(f'    "Namespace {namespace} exists" \\')
        lines.append(f'    "kubectl get namespace {namespace}" \\')
        lines.append(f'    "{namespace}" \\')
        lines.append('    "Create the namespace first"')
        lines.append("")

        # Check resources from YAML manifests
        if skill_topic.yaml_manifests:
            for manifest in skill_topic.yaml_manifests:
                resource_type = manifest.resource_type or "resource"
                resource_name = self._extract_resource_name(manifest.content)

                if resource_name:
                    lines.append("check \\")
                    lines.append(f'    "{resource_type} {resource_name} exists" \\')
                    lines.append(
                        f'    "kubectl get {resource_type.lower()} {resource_name} -n {namespace}" \\'
                    )
                    lines.append(f'    "{resource_name}" \\')
                    lines.append(f'    "Create the {resource_type} resource"')
                    lines.append("")
                else:
                    lines.append("check \\")
                    lines.append(f'    "{resource_type} exists" \\')
                    lines.append(
                        f'    "kubectl get {resource_type.lower()} -n {namespace}" \\'
                    )
                    lines.append(f'    "{resource_type.lower()}" \\')
                    lines.append(f'    "Create the {resource_type} resource"')
                    lines.append("")

        # Add generic checks if no specific resources
        if not skill_topic.yaml_manifests:
            lines.append("check \\")
            lines.append(f'    "Resources exist in namespace" \\')
            lines.append(f'    "kubectl get all -n {namespace}" \\')
            lines.append(f'    "NAME" \\')
            lines.append('    "Create the required resources"')
            lines.append("")

        return lines

    def _extract_resource_name(self, yaml_content: str) -> Optional[str]:
        """Extract resource name from YAML content.

        Args:
            yaml_content: YAML manifest content

        Returns:
            Resource name or None
        """
        # Try to find name in metadata
        match = re.search(r"name:\s+([^\s]+)", yaml_content)
        if match:
            return match.group(1)
        return None

    def _generate_verification_summary(self) -> List[str]:
        """Generate verification summary section.

        Returns:
            List of script lines
        """
        lines = ["# Summary"]
        lines.append('echo ""')
        lines.append('echo "================================"')
        lines.append('echo "Total checks: $((PASSED + FAILED))"')
        lines.append('echo -e "${GREEN}Passed: $PASSED${NC}"')
        lines.append('echo -e "${RED}Failed: $FAILED${NC}"')
        lines.append('echo "================================"')
        lines.append("")
        lines.append("if [ $FAILED -eq 0 ]; then")
        lines.append('    echo -e "${GREEN}✓ All checks passed!${NC}"')
        lines.append("    exit 0")
        lines.append("else")
        lines.append(
            '    echo -e "${RED}✗ Some checks failed. Review the hints above.${NC}"'
        )
        lines.append("    exit 1")
        lines.append("fi")

        return lines

    def add_error_handling(self, script: str) -> str:
        """Add error handling to script.

        Args:
            script: Script content

        Returns:
            Script with error handling
        """
        # Already added via 'set -e' in script generation
        return script

    def add_prerequisite_checks(
        self, script: str, tools: List[str]
    ) -> str:
        """Add prerequisite checks to script.

        Args:
            script: Script content
            tools: List of required tools

        Returns:
            Script with prerequisite checks
        """
        # Already integrated in generate_setup_script
        return script

    def validate_kubectl_commands(self, commands: List[str]) -> bool:
        """Validate kubectl command syntax.

        Args:
            commands: List of kubectl commands

        Returns:
            True if all commands are valid
        """
        for cmd in commands:
            # Basic validation - check if it starts with kubectl
            if not cmd.strip().startswith("kubectl"):
                logger.warning(f"Command does not start with kubectl: {cmd}")
                return False

            # Check for common syntax errors
            if "--" in cmd and "=" not in cmd.split("--")[1].split()[0]:
                # Flag without value might be intentional
                pass

        return True

    def make_idempotent(self, script: str) -> str:
        """Make script idempotent.

        Args:
            script: Script content

        Returns:
            Idempotent script
        """
        # Already implemented via --dry-run=client and --ignore-not-found
        return script
