#!/bin/bash
cd /Users/chanderbhushan/stockmkt

echo "🔄 ROLLBACK SCRIPT - RESTORE FROM SAFETY BACKUP"
echo "================================================"

# Find the most recent safety backup
latest_backup=$(ls -t safety_backup_*.sql 2>/dev/null | head -1)

if [ -z "$latest_backup" ]; then
    echo "❌ No safety backup found!"
    echo "Available files:"
    ls -la safety_backup_*.sql 2>/dev/null || echo "No backup files found"
    exit 1
fi

echo "Found safety backup: $latest_backup"
echo "This will completely replace your current database."
echo "Are you sure you want to proceed? (y/N)"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Rollback cancelled."
    exit 0
fi

echo "🔄 Restoring database from $latest_backup..."
psql -U stockuser -d stockdb -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
psql -U stockuser -d stockdb < "$latest_backup"

echo "✅ Database restored successfully from $latest_backup"
echo "Current state:"
psql -U stockuser -d stockdb -c "SELECT COUNT(*) FROM companies;" 