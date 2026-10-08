@echo off
cd /d "C:\Users\f736406\Downloads\B2B-personal-ia\backend"
.\.venv\Scripts\python.exe -m pytest -q --tb=short --maxfail=1 tests/test_webhook_leases.py > pytest_webhook_leases.txt 2>&1
exit /b %ERRORLEVEL%
