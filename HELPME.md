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

# Run the container
docker run --rm -p 8080:8080 -e DATABASE_URI="postgresql://postgres:belvi@host.docker.internal:5432/accounts" accounts
```

Note: `host.docker.internal` allows the container to reach PostgreSQL running on the host machine.

### How to Verify

```powershell
# In another terminal
curl.exe -I http://localhost:8080
```

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



