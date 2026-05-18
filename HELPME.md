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
---

## Exercise 3: Write a Security Headers Test Case (TDD)

Following TDD practices, we wrote a test **before** implementing the feature.

### What We Did

1. Added `HTTPS_ENVIRON` variable in `tests/test_routes.py`:
   ```python
   HTTPS_ENVIRON = {'wsgi.url_scheme': 'https'}
   ```

2. Added `test_security_headers` test case that:
   - Calls `GET /` with HTTPS enabled via `environ_overrides=HTTPS_ENVIRON`
   - Asserts HTTP 200 response
   - Checks for 4 security headers:
     - `X-Frame-Options: SAMEORIGIN`
     - `X-Content-Type-Options: nosniff`
     - `Content-Security-Policy: default-src 'self'; object-src 'none'`
     - `Referrer-Policy: strict-origin-when-cross-origin`

### Result

The test **failed** as expected (AssertionError: None != 'SAMEORIGIN') because Flask-Talisman was not yet implemented. This is correct TDD — write the test first, then make it pass.

---

## Exercise 4: Add Security Headers with Flask-Talisman

We implemented Flask-Talisman to make the security headers test pass.

### What We Did

1. Added `flask-talisman==1.1.0` to `requirements.txt`.
2. Installed it: `pip install flask-talisman`
3. Updated `service/__init__.py`:
   ```python
   from flask_talisman import Talisman
   talisman = Talisman(app)
   ```

### What Flask-Talisman Does

- Automatically adds security headers to all responses
- Forces HTTPS by redirecting HTTP requests (302 → HTTPS)
- Protects against clickjacking (`X-Frame-Options`)
- Prevents MIME-type sniffing (`X-Content-Type-Options`)
- Restricts resource loading (`Content-Security-Policy`)
- Controls referrer information (`Referrer-Policy`)

---

## Exercise 5: Disable Forced HTTPS in Tests

Talisman forces all requests to use HTTPS, which caused all tests to fail with `302 != expected_status` because the test client uses HTTP.

### What We Did

1. Imported `talisman` in `tests/test_routes.py`:
   ```python
   from service import talisman
   ```

2. Added `talisman.force_https = False` in `setUpClass()`:
   ```python
   @classmethod
   def setUpClass(cls):
       # ... other setup ...
       talisman.force_https = False
   ```

### Why

- **Production:** Talisman forces HTTPS (secure)
- **Testing:** We disable forced HTTPS so the test client can use HTTP without getting 302 redirects
- The `test_security_headers` test still works because it explicitly uses `HTTPS_ENVIRON`

---

## Exercise 6: Validate Security Headers (Verification)

We verified that Talisman works correctly in production mode by running the Flask app and using `curl`.

### What We Did

1. Started the Flask app: `flask run` (runs on port 8000)
2. In a second terminal: `curl.exe -I http://localhost:8000`

### Result

```
HTTP/1.1 302 FOUND
Location: https://localhost:8000/
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
Content-Security-Policy: default-src 'self'; object-src 'none'
Referrer-Policy: strict-origin-when-cross-origin
```

- **302 FOUND** confirms Talisman is redirecting HTTP → HTTPS
- All security headers are present in the response

### How to Run

```powershell
.\venv\Scripts\Activate.ps1
$env:DATABASE_URI = "postgresql://postgres:belvi@localhost:5432/accounts"
flask run
# In another terminal:
curl.exe -I http://localhost:8000
```

### How to Run Tests

```powershell
.\venv\Scripts\Activate.ps1
$env:DATABASE_URI = "postgresql://postgres:belvi@localhost:5432/accounts"
pytest tests/test_routes.py -v --cov=service --cov-report=term-missing
```

---

## Exercise 7: Add CORS Policies

We added Cross-Origin Resource Sharing (CORS) support using Flask-Cors, allowing other microservices/frontends to call our REST API from different origins.

### What We Did

1. Added `test_cors_security` test case in `tests/test_routes.py`:
   ```python
   def test_cors_security(self):
       """It should return a CORS header"""
       response = self.client.get('/', environ_overrides=HTTPS_ENVIRON)
       self.assertEqual(response.status_code, status.HTTP_200_OK)
       self.assertEqual(response.headers.get('Access-Control-Allow-Origin'), '*')
   ```

2. Added `flask-cors==3.0.10` to `requirements.txt`.

3. Updated `service/__init__.py`:
   ```python
   from flask_cors import CORS
   CORS(app)
   ```

### What Flask-CORS Does

- Adds `Access-Control-Allow-Origin: *` header to all responses
- Allows browsers to make cross-origin requests to our API
- Required for microservice architectures where the frontend and backend are on different domains

### How to Run Tests

```powershell
.\venv\Scripts\Activate.ps1
$env:DATABASE_URI = "postgresql://postgres:belvi@localhost:5432/accounts"
pytest tests/test_routes.py -v --cov=service --cov-report=term-missing
```

### Save Test Output (for evidence)

```powershell
pytest tests/test_routes.py -v --cov=service --cov-report=term-missing > security-headers-done.txt 2>&1
```

---

## Sprint 3, Exercise 1–2: Containerize the Microservice with Docker

We created a `Dockerfile` to containerize the Account microservice for repeatable, portable deployments.

### What We Did

1. Created branch `add-docker`.
2. Created `Dockerfile` in the project root with the following structure:

```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY service/ ./service/

RUN useradd --uid 1000 theia && chown -R theia /app
USER theia

EXPOSE 8080
CMD ["gunicorn", "--bind=0.0.0.0:8080", "--log-level=info", "service:app"]
```

### Key Design Decisions

| Requirement | Implementation |
|-------------|----------------|
| Base image | `python:3.9-slim` (small footprint) |
| Install dependencies | `pip install --no-cache-dir` (keeps image small) |
| Non-root user | Created `theia` user with UID 1000 |
| Entry point | `gunicorn` WSGI server on port 8080 |
| Copy only what's needed | `requirements.txt` first (layer caching), then `service/` |

### How to Build and Run

```powershell
# Build the image
docker build -t accounts .

# Run the container (using --link to connect to postgres container)
docker run --rm -p 8080:8080 --link postgres -e DATABASE_URI="postgresql://postgres:postgres@postgres:5432/postgres" accounts
```

Alternatively, use `host.docker.internal` to reach PostgreSQL on the host:

```powershell
docker run --rm -p 8080:8080 -e DATABASE_URI="postgresql://postgres:belvi@host.docker.internal:5432/accounts" accounts
```

### How to Verify

```powershell
# In another terminal
curl.exe -I http://localhost:8080
```

### Accessing in Browser

By default, Talisman forces HTTPS which causes a 302 redirect. Since there's no SSL certificate locally, the browser can't follow the redirect.

**Fix:** We temporarily set `force_https=False` in `service/__init__.py`:

```python
talisman = Talisman(app, force_https=False)
```

Then rebuild and run:

```powershell
docker build -t accounts .
docker run --rm -p 8080:8080 --link postgres -e DATABASE_URI="postgresql://postgres:postgres@postgres:5432/postgres" accounts
```

Now open browser to: **http://localhost:8080** — the JSON output is visible.

> **Important:** Remember to revert back to `talisman = Talisman(app)` after taking the screenshot for production security.

### Troubleshooting

- **Port already allocated:** Stop the old container first with `docker stop <container_id>` (use `docker ps` to find it)
- **Password authentication failed:** The postgres container uses password `postgres` (not `belvi`). Use `docker inspect postgres | findstr POSTGRES_PASSWORD` to verify.

### Result

```
HTTP/1.1 302 FOUND
Server: gunicorn
Location: https://localhost:8080/
Access-Control-Allow-Origin: *
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
Content-Security-Policy: default-src 'self'; object-src 'none'
Referrer-Policy: strict-origin-when-cross-origin
```

- gunicorn is serving the app on port 8080 ✓
- Security headers present ✓
- CORS header present ✓

- 302 redirect (Talisman forcing HTTPS) ✓

---

## Exercise 6–7: Deploy to Kubernetes (Local)

We created Kubernetes manifests to deploy the Account microservice locally, simulating what would be done on OpenShift in the Cloud IDE.

### What We Did

1. Created branch `add-kubernetes`.
2. Created 4 manifest files in the `deploy/` folder:

| File | Purpose |
|------|--------|
| `deploy/secret.yaml` | Stores PostgreSQL credentials as a Kubernetes Secret |
| `deploy/postgresql.yaml` | Deploys PostgreSQL + its internal Service |
| `deploy/deployment.yaml` | Deploys the accounts microservice (3 replicas) |
| `deploy/service.yaml` | Exposes the accounts service via NodePort |

### How It Works

#### Secret (`deploy/secret.yaml`)

Stores database credentials securely in Kubernetes:
- `database-name: accounts`
- `database-user: postgres`
- `database-password: pgs3cr3t`

Other manifests reference these values using `secretKeyRef` instead of hardcoding passwords.

#### PostgreSQL (`deploy/postgresql.yaml`)

- Deploys `postgres:alpine` image (1 replica)
- Reads credentials from the `postgresql` secret
- Creates an internal ClusterIP Service on port 5432 so the accounts app can reach it via hostname `postgresql`

#### Accounts Deployment (`deploy/deployment.yaml`)

- Deploys the `accounts:latest` image with **3 replicas** for high availability
- Injects environment variables from the secret:
  - `DATABASE_HOST=postgresql` (the PostgreSQL service hostname)
  - `DATABASE_NAME` from secret key `database-name`
  - `DATABASE_USER` from secret key `database-user`
  - `DATABASE_PASSWORD` from secret key `database-password`

#### Accounts Service (`deploy/service.yaml`)

- Exposes the accounts deployment externally via **NodePort** on port 8080
- Allows access from outside the cluster

### How to Deploy Locally

Prerequisite: Docker Desktop with Kubernetes enabled (Settings → Kubernetes → Enable Kubernetes).

```powershell
# 1. Build the Docker image
docker build -t accounts:latest .

# 2. Create the secret
kubectl apply -f deploy/secret.yaml

# 3. Deploy PostgreSQL
kubectl apply -f deploy/postgresql.yaml

# 4. Deploy the accounts microservice
kubectl apply -f deploy/deployment.yaml

# 5. Expose the service
kubectl apply -f deploy/service.yaml

# 6. Verify everything is running
kubectl get all -l app=accounts
kubectl get all -l app=postgresql
```

### How to Access the Service

```powershell
# Get the NodePort assigned
kubectl get svc accounts

# Access the service (replace <NodePort> with actual port)
curl.exe http://localhost:<NodePort>
```

### Useful Commands

```powershell
# View secret keys (equivalent of oc describe secret postgresql)
kubectl describe secret postgresql

# View pod logs
kubectl logs -l app=accounts

# Check pod status
kubectl get pods

# Delete everything
kubectl delete -f deploy/
```

### Key Concepts

| Concept | Explanation |
|---------|-------------|
| **Secret** | Stores sensitive data (passwords) encoded in base64, referenced by pods |
| **Deployment** | Manages pod replicas, handles rolling updates and self-healing |
| **Service** | Provides stable networking (DNS name + port) to reach pods |
| **NodePort** | Exposes a service on a static port on each node for external access |
| **secretKeyRef** | Injects a specific key from a Secret as an environment variable |

### OpenShift vs Local Kubernetes Equivalents

| OpenShift (`oc`) | Local Kubernetes (`kubectl`) |
|------------------|-----------------------------|
| `oc create -f file.yaml` | `kubectl apply -f file.yaml` |
| `oc get all -l app=accounts` | `kubectl get all -l app=accounts` |
| `oc describe secret postgresql` | `kubectl describe secret postgresql` |
| `oc create route edge accounts --service=accounts` | Use NodePort or `kubectl port-forward svc/accounts 8080:8080` |
| `oc new-app postgresql-ephemeral` | `kubectl apply -f deploy/postgresql.yaml` |


kubectl apply -f deploy/secret.yaml
kubectl apply -f deploy/postgresql.yaml
kubectl apply -f deploy/deployment.yaml
kubectl apply -f deploy/service.yaml

kubectl port-forward svc/accounts 8080:8080

kubectl get svc accounts

# Rebuild the image
docker build -t accounts:1 .

# Restart the deployment to pick up the new image
kubectl rollout restart deployment accounts
kubectl port-forward svc/accounts 8080:8080


curl.exe http://localhost:8080


- App accessible in browser at http://localhost:8080 (with force_https=False) ✓

---

## Exercise 8: Create a CD Pipeline with Tekton (Local)

We set up a Tekton-based Continuous Delivery (CD) pipeline locally to automate deployment to Kubernetes.

### Story

**"Create a CD pipeline to automate deployment to Kubernetes"**

- Use Tekton to define the pipeline
- Pipeline stages: clone → lint → test → build → deploy
- Manual trigger for this MVP

### What Is Tekton?

Tekton is a Kubernetes-native CI/CD framework. It runs pipeline tasks as pods inside your cluster. Key resources:

| Resource | Purpose |
|----------|--------|
| **Task** | A reusable unit of work (like a function) |
| **Pipeline** | Defines the order of tasks to execute |
| **PipelineRun** | A single execution of a pipeline |
| **PersistentVolumeClaim (PVC)** | Shared storage between tasks (workspace) |

### What We Did

1. Created branch `cd-pipeline`.
2. Modified `tekton/pvc.yaml` for local Kubernetes (removed IBM Cloud-specific `storageClassName`).
3. Used the existing starter files in `tekton/`:

| File | Purpose |
|------|--------|
| `tekton/pvc.yaml` | PersistentVolumeClaim — shared workspace for pipeline tasks |
| `tekton/tasks.yaml` | Custom tasks: `echo` (prints messages) and `cleanup` (clears workspace) |
| `tekton/pipeline.yaml` | Pipeline definition with `init` and `clone` tasks |

### Pipeline Structure

The pipeline executes tasks in this order:

```
init (cleanup workspace) → clone (git-clone repo) → lint → tests → build → deploy
```

| Task | Runs After | What It Does |
|------|-----------|-------------|
| `init` | — | Cleans the workspace (deletes old files) |
| `clone` | init | Clones the repo from GitHub using `git-clone` catalog task |
| `lint` | clone | Runs flake8 linter on the code |
| `tests` | clone | Runs unit tests with nosetests |
| `build` | lint, tests | Builds the Docker image |
| `deploy` | build | Deploys to Kubernetes |

### Files Explained

#### `tekton/pvc.yaml` — Workspace Storage

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pipelinerun-pvc
spec:
  resources:
    requests:
      storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
```

- Creates 1Gi of storage shared between all pipeline tasks
- Tasks use this to pass the cloned source code between stages
- `ReadWriteOnce` — can be mounted by one node at a time (sufficient for local)

#### `tekton/tasks.yaml` — Custom Tasks

**`echo` task:** Simply prints a message (used as placeholder for future tasks)

**`cleanup` task:** Deletes all files in the workspace before a new pipeline run starts (ensures a clean slate)

#### `tekton/pipeline.yaml` — Pipeline Definition

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: cd-pipeline
spec:
  workspaces:
    - name: pipeline-workspace
  params:
    - name: repo-url
    - name: branch
      default: main
  tasks:
    - name: init
      taskRef:
        name: cleanup
    - name: clone
      taskRef:
        name: git-clone
      runAfter:
        - init
```

- **params:** `repo-url` and `branch` are passed when triggering the pipeline
- **workspaces:** All tasks share `pipeline-workspace` (backed by the PVC)
- **taskRef:** References either custom tasks or Tekton Catalog tasks
- **runAfter:** Controls execution order

### How to Set Up Locally

#### Prerequisites

- Docker Desktop with Kubernetes enabled
- `kubectl` CLI
- `tkn` CLI (Tekton CLI)

#### Step 1: Install Tekton on your cluster

```powershell
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
```

Wait for pods to be ready:

```powershell
kubectl get pods -n tekton-pipelines --watch
```

#### Step 2: Install Tekton CLI (`tkn`)

Download from: https://github.com/tektoncd/cli/releases

Or with Chocolatey:

```powershell
choco install tektoncd-cli
```

#### Step 3: Install the `git-clone` task from Tekton Catalog

```powershell
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml
```

#### Step 4: Apply Tekton resources

```powershell
kubectl apply -f tekton/pvc.yaml
kubectl apply -f tekton/tasks.yaml
kubectl apply -f tekton/pipeline.yaml
```

#### Step 5: Run the pipeline

```powershell
tkn pipeline start cd-pipeline `
    -p repo-url="https://github.com/belvinard-p/devops-capstone-project.git" `
    -p branch="main" `
    -w name=pipeline-workspace,claimName=pipelinerun-pvc `
    --showlog
```

### Useful Tekton Commands

```powershell
# List pipeline runs
tkn pipelinerun ls

# View logs of a specific run
tkn pipelinerun logs <run-name>

# List tasks
tkn task ls

# List pipelines
tkn pipeline ls

# Delete a pipeline run
tkn pipelinerun delete <run-name>
```

### Key Concepts

| Concept | Explanation |
|---------|-------------|
| **Tekton** | Kubernetes-native CI/CD — runs pipelines as pods |
| **Task** | A single unit of work (e.g., clone, lint, test) |
| **Pipeline** | Ordered collection of tasks |
| **PipelineRun** | One execution of a pipeline (like clicking "Run") |
| **Workspace** | Shared storage (PVC) passed between tasks |
| **Tekton Catalog** | Library of reusable tasks (git-clone, buildah, etc.) |
| **runAfter** | Defines task dependencies (execution order) |
| **params** | Input parameters passed to the pipeline at runtime |

### OpenShift vs Local Equivalents

| OpenShift | Local Kubernetes |
|-----------|------------------|
| `oc apply -f tekton/pipeline.yaml` | `kubectl apply -f tekton/pipeline.yaml` |
| `tkn pipeline start ...` | Same command (tkn works with any Kubernetes) |
| `tkn pipelinerun ls` | Same command |
| Uses OpenShift internal registry | Uses local Docker images |

```
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```
```
Invoke-WebRequest -Uri "https://github.com/tektoncd/cli/releases/download/v0.39.0/tkn_0.39.0_Windows_x86_64.zip" -OutFile "$env:TEMP\tkn.zip"
Expand-Archive -Path "$env:TEMP\tkn.zip" -DestinationPath "$env:TEMP\tkn" -Force
Copy-Item "$env:TEMP\tkn\tkn.exe" -Destination ".\venv\Scripts\tkn.exe"
tkn version
```

---

## Exercise 9: Add the Lint Task to the CD Pipeline

We added a `lint` task to the Tekton pipeline that uses the `flake8` catalog task to check code quality.

### What We Did

1. Installed the `flake8` task from the Tekton Catalog:
   ```powershell
   kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/flake8/0.1/flake8.yaml
   ```

2. Added the `lint` task to `tekton/pipeline.yaml`:
   ```yaml
   - name: lint
     workspaces:
       - name: source
         workspace: pipeline-workspace
     taskRef:
       name: flake8
     params:
     - name: image
       value: "python:3.9-slim"
     - name: args
       value: ["--count","--max-complexity=10","--max-line-length=127","--statistics"]
     runAfter:
       - clone
   ```

### How It Works

- **`taskRef: flake8`** — References the flake8 task installed from Tekton Catalog
- **`workspace: source`** — The flake8 task expects a workspace named `source` (where the cloned code lives)
- **`image: python:3.9-slim`** — The container image used to run flake8
- **`args`** — Flake8 arguments:
  - `--count` — Show total number of errors
  - `--max-complexity=10` — Maximum allowed cyclomatic complexity
  - `--max-line-length=127` — Maximum line length
  - `--statistics` — Show summary of errors by type
- **`runAfter: clone`** — Lint only runs after the code has been cloned

### Pipeline Flow After This Change

```
init → clone → lint
```

### How to Apply and Run

```powershell
# Install flake8 task
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/flake8/0.1/flake8.yaml

# Apply updated pipeline
kubectl apply -f tekton/pipeline.yaml

# Run the pipeline
tkn pipeline start cd-pipeline `
    -p repo-url="https://github.com/belvinard-p/devops-capstone-project.git" `
    -p branch="main" `
    -w name=pipeline-workspace,claimName=pipelinerun-pvc `
    --showlog
```

# Apply to cluster
kubectl apply -f tekton/tasks.yaml

# Apply the updated pipeline
kubectl apply -f tekton/pipeline.yaml

# Run the pipeline
tkn pipeline start cd-pipeline `
    -p repo-url="https://github.com/belvinard-p/devops-capstone-project.git" `
-p branch="main" `
    -w name=pipeline-workspace,claimName=pipelinerun-pvc `
--showlog

---

## Exercise 10: Add Test, Build, and Deploy Tasks to the Pipeline

We completed the full CD pipeline by adding the `tests`, `build`, and `deploy` tasks.

### What We Did

#### 1. Created the `nose` Task (`tekton/tasks.yaml`)

Since there's no Tekton Catalog task for nosetests, we wrote a custom one:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: nose
spec:
  description: This task will run nosetests on the provided input.
  workspaces:
    - name: source
  params:
    - name: args
      description: Arguments to pass to nose
      type: string
      default: "-v"
    - name: database_uri
      description: Database connection string
      type: string
      default: "sqlite:///test.db"
  steps:
    - name: nosetests
      image: python:3.9-slim
      workingDir: $(workspaces.source.path)
      env:
        - name: DATABASE_URI
          value: $(params.database_uri)
      script: |
        #!/bin/bash
        set -e
        echo "***** Installing dependencies *****"
        python -m pip install --upgrade pip wheel
        pip install -qr requirements.txt
        echo "***** Running nosetests with: $(params.args)"
        nosetests $(params.args)
```

#### 2. Added `tests` Task to Pipeline

```yaml
- name: tests
  workspaces:
    - name: source
      workspace: pipeline-workspace
  taskRef:
    name: nose
  params:
  - name: database_uri
    value: "sqlite:///test.db"
  - name: args
    value: "-v --with-spec --spec-color"
  runAfter:
    - clone
```

- Runs **in parallel** with `lint` (both depend only on `clone`)
- Uses SQLite for testing (no external database needed)

#### 3. Added `build` Task to Pipeline

```yaml
- name: build
  workspaces:
    - name: source
      workspace: pipeline-workspace
  taskRef:
    name: buildah
    kind: ClusterTask
  params:
  - name: IMAGE
    value: "$(params.build-image)"
  runAfter:
    - tests
    - lint
```

- Waits for **both** `lint` and `tests` to pass before building
- Uses `buildah` ClusterTask (OpenShift) to build the Docker image
- `build-image` parameter added to pipeline spec

#### 4. Added `deploy` Task to Pipeline

```yaml
- name: deploy
  workspaces:
    - name: manifest-dir
      workspace: pipeline-workspace
  taskRef:
    name: openshift-client
    kind: ClusterTask
  params:
  - name: SCRIPT
    value: |
      echo "Updating manifest..."
      sed -i "s|IMAGE_NAME_HERE|$(params.build-image)|g" deploy/deployment.yaml
      cat deploy/deployment.yaml
      echo "Deploying to OpenShift..."
      oc apply -f deploy/
      oc get pods -l app=accounts
  runAfter:
    - build
```

- Uses `sed` to replace `IMAGE_NAME_HERE` placeholder in `deploy/deployment.yaml` with the actual built image name
- Applies all manifests in `deploy/` folder
- Verifies pods are running

#### 5. Updated `deploy/deployment.yaml`

Changed the image to a placeholder:

```yaml
containers:
  - name: accounts
    image: IMAGE_NAME_HERE
```

The pipeline's deploy task substitutes this at runtime with the actual image name.

### Final Pipeline Flow

```
init → clone → lint  ─┐
             → tests ─┼→ build → deploy
```

### How to Run (OpenShift)

```bash
tkn pipeline start cd-pipeline \
    -p repo-url="https://github.com/belvinard-p/devops-capstone-project.git" \
    -p branch="cd-pipeline" \
    -p build-image=image-registry.openshift-image-registry.svc:5000/$SN_ICR_NAMESPACE/accounts:1 \
    -w name=pipeline-workspace,claimName=pipelinerun-pvc \
    -s pipeline \
    --showlog
```

---

## Exercise 11: Local-Compatible CD Pipeline (No OpenShift Required)

The OpenShift pipeline uses `buildah` and `openshift-client` ClusterTasks which don't exist on local Kubernetes. We created local alternatives.

### Problem

| OpenShift ClusterTask | Issue on Local K8s |
|----------------------|--------------------|
| `buildah` | Not installed — OpenShift-specific |
| `openshift-client` | Not installed — requires `oc` CLI |
| OpenShift internal registry | Doesn't exist locally |

### Solution: Local-Compatible Files

We created 3 new files:

| File | Purpose |
|------|--------|
| `tekton/tasks-local.yaml` | Local build (`kaniko`) and deploy (`kubectl`) tasks |
| `tekton/pipeline-local.yaml` | Pipeline using local tasks instead of ClusterTasks |
| `tekton/registry.yaml` | In-cluster Docker registry for storing built images |

### `tekton/tasks-local.yaml` — Local Tasks

#### `docker-build` Task (replaces `buildah`)

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: docker-build
spec:
  description: Builds a Docker image using Kaniko and pushes to a local registry.
  workspaces:
    - name: source
  params:
    - name: IMAGE
      type: string
    - name: DOCKERFILE
      type: string
      default: "Dockerfile"
  steps:
    - name: build-and-push
      image: gcr.io/kaniko-project/executor:latest
      workingDir: $(workspaces.source.path)
      args:
        - --dockerfile=$(params.DOCKERFILE)
        - --context=$(workspaces.source.path)
        - --destination=$(params.IMAGE)
        - --insecure
        - --skip-tls-verify
```

**Why Kaniko?** It builds Docker images inside a container without needing a Docker daemon (which isn't available inside Kubernetes pods).

#### `kubectl-deploy` Task (replaces `openshift-client`)

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: kubectl-deploy
spec:
  description: Deploys manifests to Kubernetes using kubectl.
  workspaces:
    - name: manifest-dir
  params:
    - name: script
      type: string
  steps:
    - name: deploy
      image: bitnami/kubectl:latest
      workingDir: $(workspaces.manifest-dir.path)
      securityContext:
        runAsUser: 0
      script: |
        #!/bin/sh
        set -e
        $(params.script)
```

**Why bitnami/kubectl?** It provides `kubectl` in a container so we can run deployment commands inside the pipeline.

### `tekton/pipeline-local.yaml` — Local Pipeline

Same structure as the OpenShift pipeline but references local tasks:

```yaml
- name: build
  taskRef:
    name: docker-build      # instead of buildah ClusterTask

- name: deploy
  taskRef:
    name: kubectl-deploy    # instead of openshift-client ClusterTask
```

### `tekton/registry.yaml` — In-Cluster Registry

Kaniko needs somewhere to push the built image. We deploy a `registry:2` container inside the cluster:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
spec:
  containers:
    - name: registry
      image: registry:2
      ports:
        - containerPort: 5000
---
apiVersion: v1
kind: Service
metadata:
  name: registry
spec:
  ports:
    - port: 5000
```

Images are pushed to `registry:5000/accounts:1` (accessible within the cluster).

### How to Deploy and Run Locally

```powershell
# 1. Deploy the in-cluster registry
kubectl apply -f tekton/registry.yaml

# 2. Wait for registry to be ready
kubectl get pods -l app=registry --watch

# 3. Install catalog tasks
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/flake8/0.1/flake8.yaml

# 4. Apply all tasks and pipeline
kubectl apply -f tekton/tasks.yaml
kubectl apply -f tekton/tasks-local.yaml
kubectl apply -f tekton/pvc.yaml
kubectl apply -f tekton/pipeline-local.yaml

# 5. Run the local pipeline
tkn pipeline start cd-pipeline-local `
    -p repo-url="https://github.com/belvinard-p/devops-capstone-project.git" `
    -p branch="main" `
    -p build-image="registry:5000/accounts:1" `
    -w name=pipeline-workspace,claimName=pipelinerun-pvc `
    --showlog
```

### Comparison: OpenShift vs Local Pipeline

| Component | OpenShift (`pipeline.yaml`) | Local (`pipeline-local.yaml`) |
|-----------|---------------------------|------------------------------|
| Build task | `buildah` ClusterTask | `docker-build` Task (Kaniko) |
| Deploy task | `openshift-client` ClusterTask | `kubectl-deploy` Task |
| Image registry | `image-registry.openshift-image-registry.svc:5000` | `registry:5000` (in-cluster) |
| Deploy command | `oc apply -f deploy/` | `kubectl apply -f deploy/` |
| Pipeline name | `cd-pipeline` | `cd-pipeline-local` |

### Save Pipeline Logs (Evidence)

```powershell
tkn pipelinerun logs -L > pipelinerun.txt
```

### Verify Deployment

```powershell
kubectl get all -l app=accounts
```

