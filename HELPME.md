# Project Documentation

## What We Did: Created `bin/setup.ps1`

We created a PowerShell setup script (`bin/setup.ps1`) as a Windows equivalent of the existing `bin/setup.sh` bash script.

### Purpose

Automates the local development environment setup on Windows machines.

### What It Does

1. Checks the installed Python version.
2. Creates a Python virtual environment (`venv/`).
3. Activates the virtual environment.
4. Upgrades pip/wheel and installs dependencies from `requirements.txt`.
5. Starts a PostgreSQL Docker container (port 5432, database: `accounts`).
6. Verifies the container is running with `docker ps`.

### Usage

```powershell
.\bin\setup.ps1
```

To reactivate the environment later:

```powershell
.\venv\Scripts\Activate.ps1
```

---

## Exercise 1: Configured `setup.cfg` for Nosetests

We updated the `setup.cfg` file to include all the necessary nosetests flags so that running `nosetests` alone (without any command-line arguments) will automatically:

- Show verbose output (`verbosity=2`)
- Use the spec plugin for readable test names (`with-spec=1`)
- Display results in color (`spec-color=1`)
- Run code coverage analysis (`with-coverage=1`)
- Erase previous coverage data before each run (`cover-erase=1`)
- Measure coverage only for the `service` package (`cover-package=service`)

### Why

This is the "Set up the development environment" user story (technical debt). Instead of typing the full command every time:

```bash
nosetests -vv --with-spec --spec-color --with-coverage --cover-erase --cover-package=service
```

We just run:

```bash
nosetests
```

And all flags are picked up automatically from `setup.cfg`.

### Git Workflow

1. Created branch `dev-setup`.
2. Edited `setup.cfg` with the nosetests configuration.
3. Committed with message: `"added nose arguments"`.
4. Pushed branch and created a Pull Request into `main`.
5. Merged the PR and deleted the branch.
