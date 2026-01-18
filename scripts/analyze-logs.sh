#!/bin/bash
# Analyze recent logs for errors and debug info

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"

# Get latest log file
LATEST_LOG=$(ls -t "$LOG_DIR"/rojo-*.log 2>/dev/null | head -1)

if [ -z "$LATEST_LOG" ]; then
    echo "❌ No log files found. Run ./scripts/dev-with-logs.sh serve first"
    exit 1
fi

echo "📋 Analyzing log: $LATEST_LOG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check for errors
echo "🔴 ERRORS:"
grep -E "\[ERROR\]|❌" "$LATEST_LOG" | tail -20 || echo "  No errors found"
echo ""

# Check for warnings
echo "⚠️  WARNINGS:"
grep -E "\[WARN\]|⚠️" "$LATEST_LOG" | tail -20 || echo "  No warnings found"
echo ""

# Check for important info
echo "ℹ️  INFO (last 10):"
grep -E "\[INFO\]|ℹ️" "$LATEST_LOG" | tail -10 || echo "  No info logs"
echo ""

# Check for debug messages
echo "🔍 DEBUG (last 10):"
grep -E "\[DEBUG\]|🔍" "$LATEST_LOG" | tail -10 || echo "  No debug logs"
echo ""

# Check for movement-related logs
echo "🎮 MOVEMENT LOGS (last 20):"
grep -iE "select|move|click|square|piece" "$LATEST_LOG" | tail -20 || echo "  No movement logs"
echo ""

# Check for client connections
echo "🌐 CLIENT CONNECTIONS:"
grep -iE "client|player|connect" "$LATEST_LOG" | tail -10 || echo "  No connection logs"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 To see full log: cat $LATEST_LOG"
echo "💡 To tail live: tail -f $LATEST_LOG"
