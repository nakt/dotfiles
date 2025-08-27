---
allowed-tools: Read(*), Glob(*), LS(*), Grep(*), Write(*)
description: Generate and update project README.md by analyzing codebase structure
---

Analyze project structure and codebase to generate and update README.md with a consistent format.

## Analysis Targets

1. **Configuration files**: pyproject.toml, package.json, Cargo.toml, requirements.txt, setup.py ...
2. **Project structure**: src/, lib/, tests/
3. **Main files**: Entry points, configuration files
4. **Existing README**: Consistency check between current content and implementation

## Generated/Updated README Structure

### Required Sections
- # Project Name
- ## Overview
- ## Tech Stack
- ## Directory Structure
- ## Setup
- ## Usage

### Conditional Sections
- ## Development Environment Setup (when dev dependencies exist)
- ## Running Tests (when tests/ directory exists)
- ## CLI Usage (for command-line tools)
- ## API Documentation (when web framework is detected)

## Tasks

1. Analyze existing README.md content (if exists)
2. Auto-detect project type (Python/Node.js/Rust etc.)
3. Extract dependencies and basic information from configuration files
4. Analyze project structure to understand module composition
5. Identify entry points
6. Check test configuration
7. **Identify discrepancies between existing content and implementation, ensure consistency**
8. Generate/update README.md with unified format, focusing on current implementation state

## Constraints

- When existing README.md exists, preserve content while updating based on implementation comparison
- Communicate in Japanese, generate README in English
- Extract information from appropriate configuration files based on project type
- Preserve manually added sections (contributing guidelines, etc.) as much as possible
- Focus solely on describing current implementation state, avoid change history or feature announcements
- Document what the code actually does, not what has been added or updated
- Avoid using emojis as much as possible
- Minimize use of bold formatting (** **)
- Do not include troubleshooting or FAQ sections