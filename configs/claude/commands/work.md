---
description: Pick next priority task, plan, implement, test, and commit
category: workflow
allowed-tools: Bash, Task, TodoWrite, Read, Edit, Write, Glob, Grep, mcp__plugin_beads_beads__ready, mcp__plugin_beads_beads__show, mcp__plugin_beads_beads__update, mcp__plugin_beads_beads__close, mcp__plugin_beads_beads__set_context
---

# Work: Complete Next Priority Task

Complete the highest priority ready task from start to finish.

## Process

### 1. Task Selection

First, set the beads context to the current working directory, then find the next task:

1. Call `mcp__plugin_beads_beads__set_context` with the current workspace root
2. Call `mcp__plugin_beads_beads__ready` to get tasks with no blockers, sorted by priority
3. Select the highest priority task (priority 1 is highest, 3 is lowest)
4. Call `mcp__plugin_beads_beads__show` to get full task details
5. Display the selected task to the user and confirm before proceeding

### 2. Claim the Task

1. Call `mcp__plugin_beads_beads__update` to set status to `in_progress`
2. Add yourself as assignee if not already assigned

### 3. Planning Phase

Before writing any code:

1. Read and understand the task requirements from the bead's description, design notes, and acceptance criteria
2. Explore the codebase to understand:
   - Existing patterns and conventions
   - Related code that may need modification
   - Test patterns used in the project
3. Create a clear implementation plan using TodoWrite
4. If the task is ambiguous or has multiple valid approaches, ask clarifying questions before proceeding

### 4. Implementation Phase

Execute the plan systematically:

1. Mark each todo as `in_progress` before starting it
2. Write clean, well-structured code following project conventions
3. Mark each todo as `completed` immediately when done
4. Avoid over-engineering - implement exactly what's needed

### 5. Quality Assurance

Ensure high quality before completion:

1. Run the project's test suite (`cargo test`, `npm test`, etc.)
2. Run linting/formatting checks (`cargo clippy`, `cargo fmt --check`, etc.)
3. If tests fail, fix them before proceeding
4. Add new tests if the task adds new functionality
5. Verify acceptance criteria from the bead are met

### 6. Close and Commit

Once all quality checks pass:

1. Call `mcp__plugin_beads_beads__close` with a completion reason summarizing what was done
2. Stage all relevant changes with `git add`
3. Create a conventional commit with a clear message referencing the bead ID
4. Format: `<type>(<scope>): <description>` followed by blank line and `Closes: <bead-id>`

### Important Guidelines

- Do NOT skip testing - every change must be verified
- Do NOT mark the bead closed until all acceptance criteria are met
- Do NOT commit if tests or linting fail
- Ask questions if requirements are unclear rather than guessing
- If blocked by an external dependency, update the bead status to `blocked` instead of closing
