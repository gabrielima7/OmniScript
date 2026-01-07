#!/usr/bin/env python3
"""
OmniScript - Module Validator
Validate OmniScript modules for correctness and best practices.
"""

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class ValidationResult:
    """Result of a validation check."""
    name: str
    passed: bool
    message: str
    severity: str = "error"  # error, warning, info

@dataclass
class ModuleValidation:
    """Complete validation results for a module."""
    path: Path
    results: list[ValidationResult] = field(default_factory=list)

    @property
    def has_errors(self) -> bool:
        return any(r.severity == "error" and not r.passed for r in self.results)

    @property
    def has_warnings(self) -> bool:
        return any(r.severity == "warning" and not r.passed for r in self.results)

    def summary(self) -> str:
        errors = sum(1 for r in self.results if r.severity == "error" and not r.passed)
        warnings = sum(1 for r in self.results if r.severity == "warning" and not r.passed)
        passed = sum(1 for r in self.results if r.passed)
        return f"✓ {passed} passed, ✗ {errors} errors, ⚠ {warnings} warnings"


class ModuleValidator:
    """Validate OmniScript modules."""

    REQUIRED_METADATA = [
        'OS_MODULE_NAME',
        'OS_MODULE_VERSION',
        'OS_MODULE_DESCRIPTION',
        'OS_MODULE_CATEGORY'
    ]

    OPTIONAL_METADATA = [
        'OS_MODULE_SERVICE',
        'OS_MODULE_DATA_DIRS',
        'OS_MODULE_CONFIG_FILES'
    ]

    REQUIRED_FUNCTIONS = {
        'docker': 'os_module_compose',
        'baremetal': 'os_module_baremetal'
    }

    def __init__(self, strict: bool = False):
        self.strict = strict

    def validate_file(self, path: Path) -> ModuleValidation:
        """Validate a single module file."""
        validation = ModuleValidation(path=path)

        if not path.exists():
            validation.results.append(ValidationResult(
                name="file_exists",
                passed=False,
                message=f"File not found: {path}"
            ))
            return validation

        content = path.read_text()

        # Check shebang
        validation.results.append(self._check_shebang(content))

        # Check metadata
        for meta in self.REQUIRED_METADATA:
            validation.results.append(self._check_metadata(content, meta, required=True))

        for meta in self.OPTIONAL_METADATA:
            if self.strict:
                validation.results.append(self._check_metadata(content, meta, required=False))

        # Check for at least one deployment function
        validation.results.append(self._check_deployment_functions(content))

        # Check shellcheck
        validation.results.append(self._check_shellcheck(path))

        # Check syntax
        validation.results.append(self._check_bash_syntax(path))

        # Security checks
        validation.results.extend(self._security_checks(content))

        return validation

    def _check_shebang(self, content: str) -> ValidationResult:
        """Check for proper shebang."""
        if content.startswith('#!/usr/bin/env bash') or content.startswith('#!/bin/bash'):
            return ValidationResult("shebang", True, "Valid bash shebang")
        return ValidationResult("shebang", False, "Missing or invalid shebang (use #!/usr/bin/env bash)")

    def _check_metadata(self, content: str, name: str, required: bool) -> ValidationResult:
        """Check for metadata variable."""
        pattern = rf'^{name}='
        if re.search(pattern, content, re.MULTILINE):
            return ValidationResult(f"metadata_{name.lower()}", True, f"{name} defined")

        severity = "error" if required else "warning"
        return ValidationResult(
            f"metadata_{name.lower()}",
            False,
            f"{'Required' if required else 'Optional'} metadata missing: {name}",
            severity=severity
        )

    def _check_deployment_functions(self, content: str) -> ValidationResult:
        """Check for at least one deployment function."""
        found = []
        for target, func in self.REQUIRED_FUNCTIONS.items():
            if f'{func}()' in content or f'{func} ()' in content:
                found.append(target)

        if found:
            return ValidationResult(
                "deployment_functions",
                True,
                f"Supports targets: {', '.join(found)}"
            )

        return ValidationResult(
            "deployment_functions",
            False,
            f"No deployment functions found. Need at least one of: {', '.join(self.REQUIRED_FUNCTIONS.values())}"
        )

    def _check_shellcheck(self, path: Path) -> ValidationResult:
        """Run ShellCheck on the file."""
        try:
            result = subprocess.run(
                ['shellcheck', '-S', 'error', str(path)],
                check=False, capture_output=True,
                text=True
            )
            if result.returncode == 0:
                return ValidationResult("shellcheck", True, "ShellCheck passed")

            # Extract first error
            error_lines = result.stdout.strip().split('\n')[:3]
            return ValidationResult(
                "shellcheck",
                False,
                f"ShellCheck errors: {error_lines[0] if error_lines else 'Unknown'}"
            )
        except FileNotFoundError:
            return ValidationResult(
                "shellcheck",
                True,
                "ShellCheck not installed (skipped)",
                severity="warning"
            )

    def _check_bash_syntax(self, path: Path) -> ValidationResult:
        """Check bash syntax."""
        result = subprocess.run(
            ['bash', '-n', str(path)],
            check=False, capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return ValidationResult("bash_syntax", True, "Valid bash syntax")

        return ValidationResult(
            "bash_syntax",
            False,
            f"Syntax error: {result.stderr.strip()[:100]}"
        )

    def _security_checks(self, content: str) -> list[ValidationResult]:
        """Perform security checks."""
        results = []

        # Check for hardcoded passwords
        password_patterns = [
            r'password\s*=\s*["\'][^$][^"\']+["\']',
            r'PASSWORD\s*=\s*["\'][^$][^"\']+["\']',
        ]
        for pattern in password_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                results.append(ValidationResult(
                    "hardcoded_password",
                    False,
                    "Possible hardcoded password detected",
                    severity="warning"
                ))
                break
        else:
            results.append(ValidationResult(
                "hardcoded_password",
                True,
                "No hardcoded passwords detected"
            ))

        # Check for use of 'latest' tag
        if ':latest' in content and 'latest_tag' not in content:
            results.append(ValidationResult(
                "latest_tag",
                False,
                "Using 'latest' tag detected. Prefer specific versions.",
                severity="warning"
            ))
        else:
            results.append(ValidationResult("latest_tag", True, "No 'latest' tag usage"))

        # Check for proper quoting
        if re.search(r'\$[A-Za-z_][A-Za-z0-9_]*[^"\'}\s]', content):
            results.append(ValidationResult(
                "variable_quoting",
                False,
                "Unquoted variables detected. Use quotes around variables.",
                severity="warning"
            ))

        return results

    def validate_directory(self, directory: Path) -> dict[str, ModuleValidation]:
        """Validate all modules in a directory."""
        results = {}

        for module_file in directory.rglob('*.sh'):
            if module_file.is_file():
                results[str(module_file)] = self.validate_file(module_file)

        return results


def print_validation(validation: ModuleValidation, verbose: bool = False) -> None:
    """Print validation results."""
    status = "✓" if not validation.has_errors else "✗"
    print(f"\n{status} {validation.path}")
    print(f"  {validation.summary()}")

    if verbose or validation.has_errors:
        for result in validation.results:
            if not result.passed or verbose:
                icon = "✓" if result.passed else ("✗" if result.severity == "error" else "⚠")
                color = ""
                if not result.passed:
                    color = "\033[91m" if result.severity == "error" else "\033[93m"
                reset = "\033[0m" if color else ""
                print(f"    {color}{icon} {result.name}: {result.message}{reset}")


def main():
    parser = argparse.ArgumentParser(description='OmniScript Module Validator')
    parser.add_argument('path', nargs='?', default='modules',
                       help='Module file or directory to validate')
    parser.add_argument('-s', '--strict', action='store_true',
                       help='Enable strict validation')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Show all checks, not just failures')
    parser.add_argument('--json', action='store_true',
                       help='Output as JSON')

    args = parser.parse_args()

    validator = ModuleValidator(strict=args.strict)
    path = Path(args.path)

    if path.is_file():
        results = {str(path): validator.validate_file(path)}
    elif path.is_dir():
        results = validator.validate_directory(path)
    else:
        print(f"Error: {path} not found")
        sys.exit(1)

    if args.json:
        import json
        output = {}
        for path_str, validation in results.items():
            output[path_str] = {
                'has_errors': validation.has_errors,
                'has_warnings': validation.has_warnings,
                'results': [
                    {'name': r.name, 'passed': r.passed, 'message': r.message, 'severity': r.severity}
                    for r in validation.results
                ]
            }
        print(json.dumps(output, indent=2))
    else:
        has_errors = False
        for validation in results.values():
            print_validation(validation, args.verbose)
            if validation.has_errors:
                has_errors = True

        print()
        if has_errors:
            print("❌ Validation failed")
            sys.exit(1)
        else:
            print("✅ All validations passed")


if __name__ == '__main__':
    main()
