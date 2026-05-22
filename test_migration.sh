#!/bin/bash
# Production Migration Test Suite
# Tests the migration system end-to-end

set -e  # Exit on error

echo "=========================================="
echo "Production Migration Test Suite"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((TESTS_FAILED++))
}

info() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

# Test 1: Environment variables
echo "Test 1: Checking environment variables..."
if [ -f .env ]; then
    source .env
    if [ -n "$MSSQL_SA_PASSWORD" ] && [ -n "$POSTGRES_PASSWORD" ]; then
        pass "Environment variables configured"
    else
        fail "Missing required environment variables"
    fi
else
    fail ".env file not found"
fi
echo ""

# Test 2: Docker containers
echo "Test 2: Checking Docker services..."
if docker compose ps | grep -q "sqlserver.*healthy"; then
    pass "SQL Server is healthy"
else
    fail "SQL Server not healthy - run: docker compose up -d sqlserver"
fi

if docker compose ps | grep -q "postgres.*healthy"; then
    pass "PostgreSQL is healthy"
else
    fail "PostgreSQL not healthy - run: docker compose up -d postgres"
fi
echo ""

# Test 3: Python dependencies
echo "Test 3: Checking Python dependencies..."
if docker compose run --rm migration-engine python -c "import pandas, sqlalchemy, uuid6" 2>/dev/null; then
    pass "Python dependencies installed"
else
    fail "Python dependencies missing"
fi
echo ""

# Test 4: Configuration
echo "Test 4: Validating configuration..."
if docker compose run --rm migration-engine python -c "from config import config; print(config.BATCH_SIZE)" 2>/dev/null | grep -q "1000"; then
    pass "Configuration file valid"
else
    fail "Configuration validation failed"
fi
echo ""

# Test 5: Seeding
echo "Test 5: Testing database seeding..."
info "Running seed.py..."
if docker compose run --rm migration-engine python seed.py 2>&1 | grep -q "completed successfully\|already contains"; then
    pass "Database seeding successful"
else
    fail "Database seeding failed"
fi
echo ""

# Test 6: Source data verification
echo "Test 6: Verifying source data..."
SOURCE_COUNT=$(docker exec sqlserver_source /opt/mssql-tools18/bin/sqlcmd \
    -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -d source_db \
    -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM tblReferralLevel" -h -1 2>/dev/null | tr -d ' ')

if [ "$SOURCE_COUNT" -gt 0 ]; then
    pass "Source data exists ($SOURCE_COUNT records)"
else
    fail "No source data found"
fi
echo ""

# Test 7: Dry run
echo "Test 7: Testing dry-run mode..."
info "Running migration in dry-run mode..."
if DRY_RUN=true docker compose run --rm migration-engine python migrate.py 2>&1 | grep -q "DRY RUN MODE"; then
    pass "Dry-run mode works"
else
    fail "Dry-run mode failed"
fi
echo ""

# Test 8: Production migration
echo "Test 8: Testing production migration..."
info "Running production migration..."
if docker compose run --rm migration-engine python migrate.py 2>&1 | grep -q "Migration completed successfully\|already completed"; then
    pass "Production migration successful"
else
    fail "Production migration failed"
fi
echo ""

# Test 9: Migration log verification
echo "Test 9: Verifying migration log..."
LOG_COUNT=$(docker exec postgres_destination psql -U postgres_user -d destination_db \
    -t -c "SELECT COUNT(*) FROM migration_log WHERE status = 'completed'" 2>/dev/null | tr -d ' ')

if [ "$LOG_COUNT" -gt 0 ]; then
    pass "Migration log populated ($LOG_COUNT completed migrations)"
else
    fail "Migration log empty or not created"
fi
echo ""

# Test 10: Data validation
echo "Test 10: Validating migrated data..."
TARGET_COUNT=$(docker exec postgres_destination psql -U postgres_user -d destination_db \
    -t -c "SELECT COUNT(*) FROM referral_levels" 2>/dev/null | tr -d ' ')

if [ "$TARGET_COUNT" -gt 0 ]; then
    if [ "$TARGET_COUNT" -eq "$SOURCE_COUNT" ]; then
        pass "Data count matches (source: $SOURCE_COUNT, target: $TARGET_COUNT)"
    else
        fail "Data count mismatch (source: $SOURCE_COUNT, target: $TARGET_COUNT)"
    fi
else
    fail "No data in target table"
fi
echo ""

# Test 11: Idempotency
echo "Test 11: Testing idempotency..."
info "Running migration again (should detect completion)..."
if docker compose run --rm migration-engine python migrate.py 2>&1 | grep -q "already completed\|Migration completed successfully"; then
    pass "Idempotency works (duplicate run handled)"
else
    fail "Idempotency failed"
fi
echo ""

# Test 12: Data integrity spot check
echo "Test 12: Spot checking data integrity..."
SAMPLE_DATA=$(docker exec postgres_destination psql -U postgres_user -d destination_db \
    -t -c "SELECT COUNT(*) FROM referral_levels WHERE name IN ('Bronze', 'Silver', 'Gold')" 2>/dev/null | tr -d ' ')

if [ "$SAMPLE_DATA" -ge 3 ]; then
    pass "Sample data integrity verified"
else
    fail "Sample data missing or corrupted"
fi
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo "The migration system is production-ready!"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo "Please review the failures above and fix before production use."
    exit 1
fi
