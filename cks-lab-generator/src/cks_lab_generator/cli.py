"""Command-line interface for CKS Lab Generator."""

import sys
from pathlib import Path
from typing import Optional

import click

from cks_lab_generator.config import Config, get_logger
from cks_lab_generator.content_analyzer import ContentAnalyzer
from cks_lab_generator.coverage_tracker import CoverageTracker
from cks_lab_generator.lab_generator import LabGenerator
from cks_lab_generator.script_generator import ScriptGenerator

logger = get_logger(__name__)


@click.group()
@click.version_option(version="1.0.0", prog_name="cks-lab-gen")
@click.option(
    "--config",
    "-c",
    type=click.Path(exists=True),
    help="Path to configuration file (YAML)",
)
@click.pass_context
def cli(ctx: click.Context, config: Optional[str]) -> None:
    """CKS Lab Exercises Generator.

    Automated tool to generate complete lab exercises for CKS exam preparation.
    """
    ctx.ensure_object(dict)
    ctx.obj["config"] = Config(config) if config else Config()


@cli.command()
@click.argument("guide_path", type=click.Path(exists=True))
@click.option(
    "--output",
    "-o",
    type=click.Path(),
    default=".kiro/specs/cks-lab-exercises-generator/content-map.json",
    help="Output path for content map JSON",
)
@click.pass_context
def analyze(ctx: click.Context, guide_path: str, output: str) -> None:
    """Analyze CKS guide and generate content map.

    GUIDE_PATH: Path to CKS_2026_Lab_Guide.md file
    """
    config = ctx.obj["config"]
    logger.info(f"Analyzing CKS guide: {guide_path}")

    try:
        analyzer = ContentAnalyzer(config)
        content_map = analyzer.parse_guide(guide_path)

        # Save content map
        output_path = Path(output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        content_map.save_to_json(str(output_path))

        click.echo(f"✓ Content map generated: {output}")
        click.echo(f"  Total domains: {len(content_map.domains)}")
        click.echo(f"  Total topics: {content_map.total_topics}")

    except Exception as e:
        logger.error(f"Failed to analyze guide: {e}")
        click.echo(f"✗ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option(
    "--output",
    "-o",
    type=click.Path(),
    default=".kiro/specs/cks-lab-exercises-generator/coverage-report.md",
    help="Output path for coverage report",
)
@click.pass_context
def coverage(ctx: click.Context, output: str) -> None:
    """Scan existing labs and generate coverage report."""
    config = ctx.obj["config"]
    logger.info("Analyzing lab coverage")

    try:
        # Load content map
        content_map_path = ".kiro/specs/cks-lab-exercises-generator/content-map.json"
        if not Path(content_map_path).exists():
            click.echo("✗ Content map not found. Run 'analyze' command first.", err=True)
            sys.exit(1)

        tracker = CoverageTracker(config)
        report = tracker.generate_coverage_report(content_map_path)

        # Save report
        output_path = Path(output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(report, encoding="utf-8")

        click.echo(f"✓ Coverage report generated: {output}")

    except Exception as e:
        logger.error(f"Failed to generate coverage report: {e}")
        click.echo(f"✗ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option("--domain", "-d", type=int, help="Generate labs for specific domain (1-6)")
@click.option(
    "--difficulty",
    type=click.Choice(["easy", "medium", "hard"], case_sensitive=False),
    help="Generate labs by difficulty level",
)
@click.option(
    "--output-dir",
    "-o",
    type=click.Path(),
    help="Custom output directory for labs",
)
@click.option("--dry-run", is_flag=True, help="Preview without creating files")
@click.option("--force", is_flag=True, help="Overwrite existing labs")
@click.pass_context
def generate(
    ctx: click.Context,
    domain: Optional[int],
    difficulty: Optional[str],
    output_dir: Optional[str],
    dry_run: bool,
    force: bool,
) -> None:
    """Generate missing labs to achieve 100% coverage."""
    config = ctx.obj["config"]
    
    # Override output directory if specified
    if output_dir:
        config.config["output_directory"] = output_dir
    
    logger.info("Generating labs")

    try:
        from cks_lab_generator.models import ContentMap

        # Load content map
        content_map_path = ".kiro/specs/cks-lab-exercises-generator/content-map.json"
        if not Path(content_map_path).exists():
            click.echo("✗ Content map not found. Run 'analyze' command first.", err=True)
            sys.exit(1)

        content_map = ContentMap.load_from_json(content_map_path)
        
        # Get missing topics
        tracker = CoverageTracker(config)
        labs_dir = str(config.get_output_directory())
        existing_labs = tracker.scan_existing_labs(labs_dir)
        coverage = tracker.calculate_coverage(content_map, existing_labs)
        
        # Filter missing topics
        missing_topics = coverage.missing_topics
        
        if domain:
            missing_topics = [mt for mt in missing_topics if mt.skill_topic.domain_number == domain]
        
        if difficulty:
            missing_topics = [mt for mt in missing_topics if mt.skill_topic.difficulty.lower() == difficulty.lower()]
        
        if not missing_topics:
            click.echo("✓ No missing topics found with the specified filters")
            return
        
        click.echo(f"Found {len(missing_topics)} missing topics to generate")
        
        if dry_run:
            click.echo("\n📋 Dry run - would generate:")
            for mt in missing_topics:
                topic = mt.skill_topic
                click.echo(f"  - {topic.id}: {topic.name} ({topic.difficulty})")
            return
        
        # Generate labs
        generator = LabGenerator(config)
        script_gen = ScriptGenerator(config)
        
        # Build domains dict
        domains_dict = {d.number: d for d in content_map.domains}
        
        successful = []
        failed = []
        
        for mt in missing_topics:
            topic = mt.skill_topic
            domain_obj = domains_dict.get(topic.domain_number)
            
            if not domain_obj:
                failed.append((topic, f"Domain {topic.domain_number} not found"))
                continue
            
            try:
                # Generate lab
                lab = generator.generate_lab(topic, domain_obj, output_dir)
                
                # Generate scripts
                setup_script = script_gen.generate_setup_script(topic)
                cleanup_script = script_gen.generate_cleanup_script(topic)
                verify_script = script_gen.generate_verify_script(topic)
                
                # Write scripts
                lab_path = Path(lab.directory_path)
                (lab_path / "setup.sh").write_text(setup_script, encoding="utf-8")
                (lab_path / "cleanup.sh").write_text(cleanup_script, encoding="utf-8")
                (lab_path / "verify.sh").write_text(verify_script, encoding="utf-8")
                
                # Make executable
                for script in ["setup.sh", "cleanup.sh", "verify.sh"]:
                    (lab_path / script).chmod(0o755)
                
                successful.append(lab)
                click.echo(f"✓ Generated: {lab.lab_id}")
                
            except Exception as e:
                failed.append((topic, str(e)))
                click.echo(f"✗ Failed: {topic.id} - {e}")
        
        click.echo(f"\n✓ Generation completed")
        click.echo(f"  Successful: {len(successful)}")
        click.echo(f"  Failed: {len(failed)}")

    except Exception as e:
        logger.error(f"Failed to generate labs: {e}")
        click.echo(f"✗ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option("--domain", "-d", multiple=True, type=int, help="Generate labs for specific domains")
@click.option(
    "--output-dir",
    "-o",
    type=click.Path(),
    help="Custom output directory for labs",
)
@click.pass_context
def batch_generate(ctx: click.Context, domain: tuple, output_dir: Optional[str]) -> None:
    """Generate multiple labs at once."""
    config = ctx.obj["config"]
    
    # Override output directory if specified
    if output_dir:
        config.config["output_directory"] = output_dir
    
    domains = list(domain) if domain else list(range(1, 7))
    logger.info(f"Batch generating labs for domains: {domains}")

    try:
        from cks_lab_generator.models import ContentMap

        # Load content map
        content_map_path = ".kiro/specs/cks-lab-exercises-generator/content-map.json"
        if not Path(content_map_path).exists():
            click.echo("✗ Content map not found. Run 'analyze' command first.", err=True)
            sys.exit(1)

        content_map = ContentMap.load_from_json(content_map_path)
        
        # Get missing topics for specified domains
        tracker = CoverageTracker(config)
        labs_dir = str(config.get_output_directory())
        existing_labs = tracker.scan_existing_labs(labs_dir)
        coverage = tracker.calculate_coverage(content_map, existing_labs)
        
        # Filter by domains
        missing_topics = [mt for mt in coverage.missing_topics if mt.skill_topic.domain_number in domains]
        
        if not missing_topics:
            click.echo("✓ No missing topics found for specified domains")
            return
        
        click.echo(f"Generating {len(missing_topics)} labs across {len(domains)} domains")
        
        # Generate labs
        generator = LabGenerator(config)
        script_gen = ScriptGenerator(config)
        
        # Build domains dict
        domains_dict = {d.number: d for d in content_map.domains}
        
        successful = []
        failed = []
        
        with click.progressbar(missing_topics, label="Generating labs") as bar:
            for mt in bar:
                topic = mt.skill_topic
                domain_obj = domains_dict.get(topic.domain_number)
                
                if not domain_obj:
                    failed.append((topic, f"Domain {topic.domain_number} not found"))
                    continue
                
                try:
                    # Generate lab
                    lab = generator.generate_lab(topic, domain_obj, output_dir)
                    
                    # Generate scripts
                    setup_script = script_gen.generate_setup_script(topic)
                    cleanup_script = script_gen.generate_cleanup_script(topic)
                    verify_script = script_gen.generate_verify_script(topic)
                    
                    # Write scripts
                    lab_path = Path(lab.directory_path)
                    (lab_path / "setup.sh").write_text(setup_script, encoding="utf-8")
                    (lab_path / "cleanup.sh").write_text(cleanup_script, encoding="utf-8")
                    (lab_path / "verify.sh").write_text(verify_script, encoding="utf-8")
                    
                    # Make executable
                    for script in ["setup.sh", "cleanup.sh", "verify.sh"]:
                        (lab_path / script).chmod(0o755)
                    
                    successful.append(lab)
                    
                except Exception as e:
                    failed.append((topic, str(e)))

        click.echo(f"\n✓ Batch generation completed")
        click.echo(f"  Successful: {len(successful)}")
        click.echo(f"  Failed: {len(failed)}")

        if failed:
            click.echo("\n✗ Failed labs:")
            for topic, error in failed:
                click.echo(f"  - {topic.id}: {error}")

    except Exception as e:
        logger.error(f"Failed to batch generate labs: {e}")
        click.echo(f"✗ Error: {e}", err=True)
        sys.exit(1)


def main() -> None:
    """Main entry point for CLI."""
    cli(obj={})


if __name__ == "__main__":
    main()
