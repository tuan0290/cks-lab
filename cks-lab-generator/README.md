# CKS Lab Exercises Generator

Automated tool to generate complete, production-ready lab exercises for Certified Kubernetes Security Specialist (CKS) exam preparation.

## Features

- **Automated Content Analysis**: Parse CKS_2026_Lab_Guide.md and extract all skill topics from 6 security domains
- **100% Coverage Tracking**: Monitor and report coverage of all CKS exam topics
- **Complete Lab Generation**: Create fully functional lab exercises with:
  - README.md (objectives, instructions, verification steps)
  - setup.sh (environment initialization)
  - cleanup.sh (resource removal)
  - verify.sh (automated checking)
  - solution/solution.md (detailed answers)
- **Exam-Realistic Quality**: Generate labs that mirror actual CKS exam scenarios
- **Batch Generation**: Create multiple labs at once for efficient coverage

## Installation

### Prerequisites

- Python 3.10 or higher
- pip or uv package manager

### Install from source

```bash
# Clone the repository
cd cks-lab-generator

# Install dependencies
pip install -e .

# For development
pip install -e ".[dev]"
```

## Usage

### Analyze CKS Guide

Parse the CKS guide and generate a content map:

```bash
cks-lab-gen analyze /path/to/CKS_2026_Lab_Guide.md
```

### Check Coverage

Scan existing labs and generate coverage report:

```bash
cks-lab-gen coverage
```

### Generate Labs

Generate missing labs to achieve 100% coverage:

```bash
# Generate all missing labs
cks-lab-gen generate

# Generate labs for specific domain
cks-lab-gen generate --domain 1

# Generate labs by difficulty
cks-lab-gen generate --difficulty medium

# Dry run (preview without creating files)
cks-lab-gen generate --dry-run
```

### Batch Generation

Generate multiple labs at once:

```bash
cks-lab-gen batch-generate --domain 4,5,6
```

## Configuration

Create a `generator-config.yaml` file to customize generation:

```yaml
output_directory: "cks-lab-exercises/labs"
naming_convention: "lab-{domain}.{number}-{topic}"
kubernetes_version: "v1.29+"

difficulty_criteria:
  easy:
    max_commands: 3
    max_yaml_files: 1
  medium:
    max_commands: 7
    max_yaml_files: 3
  hard:
    max_commands: 15
    max_yaml_files: 5

required_tools:
  - kubectl
  - trivy
  - cosign
  - falco
  - syft
  - kube-bench
```

## Project Structure

```
cks-lab-generator/
├── src/
│   └── cks_lab_generator/
│       ├── __init__.py
│       ├── cli.py                    # CLI entry point
│       ├── models.py                 # Data models
│       ├── content_analyzer.py       # Content extraction
│       ├── coverage_tracker.py       # Coverage analysis
│       ├── lab_generator.py          # Lab generation
│       ├── script_generator.py       # Script generation
│       ├── config.py                 # Configuration management
│       └── utils.py                  # Utility functions
├── tests/
│   ├── test_content_analyzer.py
│   ├── test_coverage_tracker.py
│   ├── test_lab_generator.py
│   └── test_script_generator.py
├── templates/
│   ├── setup.sh.j2
│   ├── cleanup.sh.j2
│   ├── verify.sh.j2
│   ├── README.md.j2
│   └── solution.md.j2
├── pyproject.toml
└── README.md
```

## Development

### Run Tests

```bash
pytest
```

### Code Formatting

```bash
black src/ tests/
ruff check src/ tests/
```

### Type Checking

```bash
mypy src/
```

## Target Lab Distribution

Based on CKS exam weights (~60 labs total):

- **Domain 1** (Cluster Setup - 15%): ~9 labs
- **Domain 2** (Cluster Hardening - 15%): ~9 labs
- **Domain 3** (System Hardening - 10%): ~6 labs
- **Domain 4** (Microservice Vulnerabilities - 20%): ~12 labs
- **Domain 5** (Supply Chain Security - 20%): ~12 labs
- **Domain 6** (Monitoring & Runtime Security - 20%): ~12 labs

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
