# Prime Context for Linux Sysadmin Portfolio

Initialize your understanding of this Linux system administrator portfolio project.

## Instructions

Execute these steps in order to build context:

### Step 1: Project Structure
Run `tree -L 2 -a --noreport -I '.git'` to visualize the repository structure.

### Step 2: Project Guidelines
Read the following files to understand project standards:
- `CLAUDE.md` - Project context and coding standards
- `README.md` - Portfolio overview and skills matrix
- `plans/00-start_plan.md` - Detailed implementation specifications

### Step 3: Existing Commands & Agents
Review what's available:
- List files in `.claude/commands/` - available slash commands
- List files in `.claude/agents/` - available specialized agents
- Check `.claude/templates/` if it exists - boilerplate files

### Step 4: Project Status
Identify which portfolio projects exist vs are planned:
- `project-01-lamp-monitoring/` - LAMP Stack with Monitoring
- `project-02-mail-server/` - Dockerized Mail Server
- `project-03-infra-automation/` - Infrastructure Automation Toolkit

For each existing project, check:
- Does `docker-compose.yml` exist?
- Are there scripts in `scripts/` directory?
- Is `README.md` present?

## Output

After gathering context, explain back:

1. **Repository Structure**
   - Current directory layout
   - Which projects exist vs planned

2. **Coding Standards**
   - Bash scripting requirements (error handling, shellcheck)
   - Docker/Compose conventions
   - Documentation format (bilingual EN/HU)

3. **Available Tools**
   - List all slash commands and their purposes
   - List all agents and what they do

4. **Current State**
   - What's implemented vs what's planned
   - Any issues or incomplete items noticed

5. **Ready to Help**
   - Confirm you understand the project
   - Ask what task the user wants to work on

## Example Output Format

```
## Linux Sysadmin Portfolio - Context Loaded

### Structure
- Repository has X directories, Y files
- Projects: [list status of each]

### Standards
- Bash: set -euo pipefail, shellcheck compliant
- Docker: version 3.8+, health checks required
- Docs: Bilingual (English/Hungarian)

### Available Commands
- /primer - This command
- /test-project - Run Docker tests
- [etc...]

### Current State
- Project 01: [status]
- Project 02: [status]
- Project 03: [status]

### Ready
I understand this is a Linux sysadmin portfolio project. What would you like to work on?
```
