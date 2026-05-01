#!/usr/bin/env python3
"""Validate .ipynb files: structure, metadata, and cleanliness."""

import json
import pathlib
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent

KERNEL_RULES: dict[str, str] = {
    "05-golang": "gophernotes",
}
DEFAULT_KERNEL = "python3"


def lint_notebook(path: pathlib.Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    rel = path.relative_to(REPO_ROOT)

    try:
        nb = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        errors.append(f"{rel}: invalid JSON — {exc}")
        return errors, warnings

    if nb.get("nbformat") != 4:
        errors.append(f"{rel}: expected nbformat 4, got {nb.get('nbformat')}")

    expected_kernel = DEFAULT_KERNEL
    for prefix, kernel in KERNEL_RULES.items():
        if str(rel).startswith(prefix):
            expected_kernel = kernel
            break

    actual_kernel = nb.get("metadata", {}).get("kernelspec", {}).get("name")
    if actual_kernel != expected_kernel:
        errors.append(
            f"{rel}: kernel should be '{expected_kernel}', got '{actual_kernel}'"
        )

    for idx, cell in enumerate(nb.get("cells", [])):
        if cell.get("cell_type") != "code":
            continue

        source = cell.get("source", [])
        if not "".join(source).strip():
            errors.append(f"{rel}: cell {idx} is an empty code cell")

        if cell.get("execution_count") is not None:
            warnings.append(f"{rel}: cell {idx} has execution_count set")

        if cell.get("outputs"):
            warnings.append(f"{rel}: cell {idx} has leftover outputs")

    return errors, warnings


def main() -> int:
    notebooks = sorted(REPO_ROOT.rglob("*.ipynb"))
    if not notebooks:
        print("No .ipynb files found")
        return 1

    all_errors: list[str] = []
    all_warnings: list[str] = []

    for nb_path in notebooks:
        if ".ipynb_checkpoints" in nb_path.parts:
            continue
        errs, warns = lint_notebook(nb_path)
        all_errors.extend(errs)
        all_warnings.extend(warns)

    for w in all_warnings:
        print(f"  WARN  {w}")
    for e in all_errors:
        print(f"  FAIL  {e}")

    total = len(notebooks)
    if all_errors:
        print(f"\n{len(all_errors)} error(s) in {total} notebook(s)")
        return 1

    label = "warning(s)" if all_warnings else "issues"
    count = len(all_warnings)
    print(f"\nAll {total} notebook(s) OK" + (f" ({count} {label})" if count else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
