# /publish - Smart Publish to GitHub

You are a meticulous code publisher that ensures quality before any code reaches the remote repository. Follow ALL steps below in order. Do NOT skip any step.

## Step 1: Analyze Changes

Run these commands in parallel to understand the current state:

1. `git status` (never use `-uall` flag)
2. `git diff` (unstaged changes)
3. `git diff --cached` (staged changes)
4. `git log --oneline -5` (recent commits for style reference)
5. `git branch --show-current` (current branch)
6. `git rev-parse --abbrev-ref @{upstream} 2>/dev/null` (tracking branch)

If there are NO changes (no untracked, no modified, no staged files), inform the user and stop.

## Step 2: Code Review

Review ALL modified and staged files for:

### 2.1 Security Check
- [ ] No hardcoded secrets, API keys, tokens, or passwords
- [ ] No `.env` files or credential files being committed
- [ ] No sensitive data in logs or comments
- [ ] No SQL injection, XSS, or command injection vulnerabilities

### 2.2 Code Quality Check
- [ ] Python follows PEP 8 conventions
- [ ] Type hints present on new/modified functions
- [ ] No debug statements left behind (`print()`, `breakpoint()`, `TODO/FIXME` that should be resolved)
- [ ] No commented-out code blocks that should be removed
- [ ] Import statements are clean (no unused imports)
- [ ] No overly complex functions (cyclomatic complexity)

### 2.3 Data Engineering Check (if applicable)
- [ ] Spark operations use appropriate optimizations (broadcast joins for small tables)
- [ ] Delta Lake operations follow project patterns
- [ ] No hardcoded paths or connection strings
- [ ] Pipeline configurations are parameterized

### 2.4 File Check
- [ ] No large binary files being committed
- [ ] No temporary files (`.pyc`, `__pycache__`, `.DS_Store`)
- [ ] `.gitignore` covers necessary exclusions

If issues are found, present them categorized by severity:
- **BLOCK** (must fix before push): Security issues, broken code, secrets
- **WARN** (should fix): Quality issues, missing type hints, dead code
- **INFO** (nice to have): Style suggestions, minor improvements

If there are BLOCK issues, show them and STOP. Ask the user to fix before continuing.
If there are only WARN/INFO, show them but continue to Step 3.

## Step 3: Stage Files

- Stage all relevant modified files individually by name (NOT `git add -A` or `git add .`)
- NEVER stage files that contain secrets (`.env`, credentials, keys)
- NEVER stage temporary files, caches, or build artifacts
- Show which files will be staged and ask for confirmation before staging

## Step 4: Generate Commit Message

Analyze all staged changes and create a commit message following these rules:

### Commit Message Format
```
<type>(<scope>): <short description>

<detailed body explaining WHY the change was made>

<list of key changes if multiple files affected>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

### Types
- `feat`: New feature or functionality
- `fix`: Bug fix
- `refactor`: Code restructuring without behavior change
- `docs`: Documentation changes
- `test`: Test additions or modifications
- `chore`: Maintenance tasks, config changes
- `perf`: Performance improvements
- `style`: Formatting, linting fixes
- `ci`: CI/CD pipeline changes
- `build`: Build system or dependency changes

### Scope Examples
- `pipeline`, `bronze`, `silver`, `gold` (data layers)
- `spark`, `delta`, `lakeflow` (technologies)
- `api`, `auth`, `config` (components)
- `agents`, `kb`, `docs` (project areas)

### Rules
- First line max 72 characters
- Body wraps at 80 characters
- Focus on WHY, not WHAT (the diff shows WHAT)
- Use imperative mood ("add feature" not "added feature")
- Reference issue numbers if applicable

Show the proposed commit message and ask for user approval. Allow editing.

## Step 5: Create Commit

Create the commit using a HEREDOC format:
```bash
git commit -m "$(cat <<'EOF'
<commit message here>
EOF
)"
```

IMPORTANT: Do NOT add `Co-Authored-By`, `Signed-off-by`, or any other trailer that attributes authorship to Claude or AI. The user is the sole author of all commits.

If a pre-commit hook fails:
1. Show the error clearly
2. Fix the issue if possible
3. Re-stage the files
4. Create a NEW commit (never `--amend`)

## Step 6: Pre-Push Summary

Before pushing, show a comprehensive summary:

```
============================================================
  PUBLISH SUMMARY
============================================================

  Branch:        <current-branch> → <remote>/<branch>
  Commits:       <number> commit(s) to push

  FILES CHANGED:
  ├── <file1>  (+X -Y lines)  <brief description>
  ├── <file2>  (+X -Y lines)  <brief description>
  └── <file3>  (+X -Y lines)  <brief description>

  STATS:
  • Files changed:  <count>
  • Insertions:     +<count>
  • Deletions:      -<count>

  REVIEW RESULT:
  • Security:       PASS ✓
  • Code Quality:   <PASS ✓ / X warnings>
  • Data Patterns:  <PASS ✓ / N/A>

  COMMIT(S):
  <hash> <commit message first line>

============================================================
```

Generate this summary by running:
- `git diff --stat @{upstream}..HEAD` (or `git diff --stat origin/<branch>..HEAD`)
- `git log --oneline @{upstream}..HEAD` (commits to be pushed)

## Step 7: Confirm and Push

Ask the user for explicit confirmation before pushing:

"Ready to push to <remote>/<branch>. Proceed?"

- If YES → `git push` (or `git push -u origin <branch>` if no upstream)
- If NO → Inform user the commit is saved locally and can be pushed later

After successful push, show:
- The remote URL
- Total commits pushed
- A brief success message

## Important Rules

- NEVER force push (`--force`, `--force-with-lease`) unless explicitly requested
- NEVER push to `main` or `master` without explicit user confirmation and a warning
- NEVER use `--no-verify` to skip hooks
- NEVER amend published commits
- If pushing to main/master, add an extra warning: "You are pushing directly to the main branch. This is usually discouraged. Are you sure?"
- If the branch doesn't exist on remote yet, use `git push -u origin <branch>` to set up tracking
