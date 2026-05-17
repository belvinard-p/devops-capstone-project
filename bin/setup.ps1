Write-Host "****************************************"
Write-Host " Setting up Capstone Environment"
Write-Host "****************************************"

Write-Host "Checking the Python version..."
python --version

Write-Host "Creating a Python virtual environment"
python -m venv venv

Write-Host "Activating virtual environment..."
.\venv\Scripts\Activate.ps1

Write-Host "Installing Python dependencies..."
python -m pip install --upgrade pip wheel
pip install -r requirements.txt

Write-Host "Starting the Postgres Docker container..."
docker run -d --name postgres -p 5432:5432 -e POSTGRES_PASSWORD=belvi -e POSTGRES_DB=accounts postgres:alpine

Write-Host "Checking the Postgres Docker container..."
docker ps

Write-Host "****************************************"
Write-Host " Capstone Environment Setup Complete"
Write-Host "****************************************"
Write-Host ""
Write-Host "To activate the environment in the future, run: .\venv\Scripts\Activate.ps1"
Write-Host ""
