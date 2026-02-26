#!/usr/bin/env python3
"""
Database seeding script for RideMatch demo data.
This script creates tables and loads sample data for testing.
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
import mysql.connector

# Load environment variables
env_path = Path(__file__).resolve().parents[1] / '.env'
load_dotenv(env_path)

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "user": os.getenv("DB_USER", "ride_match_dev"),
    "password": os.getenv("DB_PASSWORD", "CSE2026?!"),
    "database": os.getenv("DB_NAME", "ride_match_db")
}

def load_sql_file(filename):
    """Load SQL commands from a file."""
    sql_path = Path(__file__).resolve().parent / filename
    with open(sql_path, 'r') as f:
        return f.read()

def execute_sql_script(sql_content):
    """Execute SQL script with proper statement splitting."""
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()
    
    # Split by semicolon and filter out empty statements
    statements = [stmt.strip() for stmt in sql_content.split(';') if stmt.strip()]
    
    try:
        for i, statement in enumerate(statements):
            print(f"Executing statement {i+1}/{len(statements)}...", end=' ')
            cursor.execute(statement)
            print("✓")
        
        conn.commit()
        print(f"\n✓ Successfully executed {len(statements)} SQL statements")
        return True
    except mysql.connector.Error as err:
        print(f"✗ Error: {err}")
        conn.rollback()
        return False
    finally:
        cursor.close()
        conn.close()

def verify_connection():
    """Verify database connection before running scripts."""
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        conn.close()
        return True
    except mysql.connector.Error as err:
        print(f"✗ Connection failed: {err}")
        print("\nMake sure MySQL is running and credentials in .env are correct:")
        print(f"  DB_HOST: {DB_CONFIG['host']}")
        print(f"  DB_USER: {DB_CONFIG['user']}")
        return False

def main():
    """Main seeding function."""
    print("=" * 60)
    print("RideMatch Database Seeding Script")
    print("=" * 60)
    
    # Verify connection
    print("\n1. Verifying database connection...")
    if not verify_connection():
        sys.exit(1)
    print("   ✓ Connection successful")
    
    # Load DDL
    print("\n2. Loading DDL script...")
    try:
        ddl_content = load_sql_file('ddl_script.sql')
        print(f"   ✓ Loaded {len(ddl_content)} characters")
    except FileNotFoundError:
        print("   ✗ ddl_script.sql not found")
        sys.exit(1)
    
    # Load DML
    print("\n3. Loading DML script...")
    try:
        dml_content = load_sql_file('dml_script.sql')
        print(f"   ✓ Loaded {len(dml_content)} characters")
    except FileNotFoundError:
        print("   ✗ dml_script.sql not found")
        sys.exit(1)
    
    # Execute DDL
    print("\n4. Creating tables...")
    if not execute_sql_script(ddl_content):
        sys.exit(1)
    
    # Execute DML
    print("\n5. Loading sample data...")
    if not execute_sql_script(dml_content):
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("✓ Database seeding completed successfully!")
    print("=" * 60)
    print("\nSample data loaded:")
    print("  - 18 accounts (3 admins + 15 users)")
    print("  - 12 drivers with various approval statuses")
    print("  - 18 riders with preferences")
    print("  - 12 vehicles")
    print("  - 20 trips with ratings")
    print("  - 16 driver reviews")
    print("\nYou can now log in with:")
    print("  Username: admin (use any admin account email)")
    print("  Password: 1234")

if __name__ == "__main__":
    main()
