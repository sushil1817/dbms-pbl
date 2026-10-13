"""Database connection settings, read from environment variables only.

No password is ever hardcoded. Set these before running the server or the
seed script (PowerShell: $env:CAMPUS_DB_PASSWORD = '...'):

  CAMPUS_DB_HOST      default 127.0.0.1
  CAMPUS_DB_PORT      default 3306
  CAMPUS_DB_USER      default root
  CAMPUS_DB_PASSWORD  required, no default
  CAMPUS_DB_NAME      default CampusMaintenanceDB
"""
import os
import sys

DB_HOST = os.environ.get("CAMPUS_DB_HOST", "127.0.0.1")
DB_PORT = int(os.environ.get("CAMPUS_DB_PORT", "3306"))
DB_USER = os.environ.get("CAMPUS_DB_USER", "root")
DB_PASSWORD = os.environ.get("CAMPUS_DB_PASSWORD")
DB_NAME = os.environ.get("CAMPUS_DB_NAME", "CampusMaintenanceDB")

if not DB_PASSWORD:
    sys.stderr.write(
        "ERROR: CAMPUS_DB_PASSWORD is not set. Set it in the environment before "
        "starting the server, e.g. (PowerShell): $env:CAMPUS_DB_PASSWORD = 'yourpassword'\n"
    )
    sys.exit(1)
