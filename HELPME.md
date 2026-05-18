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

## Activate env file 

```
.\venv\Scripts\Activate.ps1
```

And all flags are picked up automatically from `setup.cfg`.

### Git Workflow

1. Created branch `dev-setup`.
2. Edited `setup.cfg` with the nosetests configuration.
3. Committed with message: `"added nose arguments"`.
4. Pushed branch and created a Pull Request into `main`.
5. Merged the PR and deleted the branch.

---

## Exercise 2: Create a REST API with Flask

We implemented the 4 remaining REST API endpoints (Read, List, Update, Delete) following TDD principles.

### Problems We Solved

#### Problem 1: `psycopg2-binary` Failed to Install

`psycopg2-binary==2.9.3` has no pre-built wheel for Python 3.13 on Windows. Pip tried to compile from source and failed because Microsoft Visual C++ Build Tools were not installed.

**Fix:** Updated `requirements.txt` to use a version with Python 3.13 wheels:

```
psycopg2-binary==2.9.3  →  psycopg2-binary==2.9.10
```

#### Problem 2: `nosetests` Incompatible with Python 3.13

The `nose` package uses the `imp` module which was removed in Python 3.12+. Running `nosetests` throws `ModuleNotFoundError: No module named 'imp'`.

**Fix:** Switched to `pytest` with coverage:

```powershell
pip install pytest pytest-cov
pytest --verbose --cov=service --cov-report=term-missing
```

#### Problem 3: PostgreSQL Connection Failed

The default `DATABASE_URI` in the code is `postgresql://postgres:postgres@localhost:5432/postgres`, but our local setup uses password `belvi` and database `accounts`.

**Fix:** Set the environment variable in the same terminal session where tests run:

```powershell
$env:DATABASE_URI = "postgresql://postgres:belvi@localhost:5432/accounts"
```

> **Important:** `$env:` variables only exist in the PowerShell session where they are set. You must set this every time you open a new terminal.

### What We Implemented

#### Routes (`service/routes.py`)

| Endpoint | Method | Function | Behavior |
|----------|--------|----------|----------|
| `/accounts` | GET | `list_accounts()` | Returns all accounts as JSON list, always 200 |
| `/accounts/<id>` | GET | `read_account()` | Returns account or 404 |
| `/accounts/<id>` | PUT | `update_account()` | Finds, deserializes, updates, returns 200 or 404 |
| `/accounts/<id>` | DELETE | `delete_account()` | Finds and deletes, always returns 204 |

Also updated:
- `create_accounts()` → proper `location_url` using `url_for("read_account", account_id=account.id, _external=True)`
- `index()` → uncommented `paths=url_for("list_accounts", _external=True)`

#### Test Cases (`tests/test_routes.py`)

| Test | What It Verifies |
|------|------------------|
| `test_read_an_account` | GET existing account returns 200 + correct data |
| `test_account_not_found` | GET non-existent account returns 404 |
| `test_list_all_accounts` | GET /accounts returns all 5 created accounts |
| `test_list_accounts_empty` | GET /accounts with no data returns empty list + 200 |
| `test_update_account` | PUT with new data returns 200 + updated data |
| `test_update_account_not_found` | PUT non-existent account returns 404 |
| `test_delete_account` | DELETE returns 204, subsequent GET returns 404 |

### How to Run Tests

```powershell
.\venv\Scripts\Activate.ps1
$env:DATABASE_URI = "postgresql://postgres:belvi@localhost:5432/accounts"
pytest --verbose --cov=service --cov-report=term-missing
```

### Result

All 24 tests pass with 95%+ code coverage.

### Git Workflow (Repeat for Each Story)

```powershell
git checkout main
git pull
git branch -d <old_branch>
git checkout -b <new_branch>   # e.g., "read-account"
# ... implement tests + code ...
git commit -am "implemented read account"
git push --set-upstream origin <new_branch>
# Create PR on GitHub → Merge → Delete branch
```
pip install flask-talisman
$env:DATABASE_URI = "postgresql://postgres:belvi@localhost:5432/accounts"
pytest tests/test_routes.py -v


git add requirements.txt service/__init__.py
git commit -m "added flask-talisman for security headers"
git push

