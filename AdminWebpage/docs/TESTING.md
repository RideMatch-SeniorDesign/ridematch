# Testing

The admin web test suite uses `pytest` and an injected in-memory repository, so it does not require MySQL.

## Local setup

1. Create a virtual environment:

   ```powershell
   python -m venv venv
   ```

2. Activate it:

   ```powershell
   .\venv\Scripts\Activate.ps1
   ```

3. Install dependencies:

   ```powershell
   pip install -r requirements-dev.txt
   ```

4. Run the tests:

   ```powershell
   pytest -q
   ```

## What the tests covers

- Authentication and login redirects
- Dashboard, drivers, rider management, analytics, and settings tests
- Driver filtering behavior with seeded data
- Driver verification approve/deny actions
- Settings validation and persistence calls


