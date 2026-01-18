#!/bin/bash
# Development script with log capture

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/rojo-$(date +%Y%m%d-%H%M%S).log"

# Create logs directory
mkdir -p "$LOG_DIR"

# Ensure Rojo is in PATH
export PATH="$HOME/.cargo/bin:$PATH"

case "$1" in
    serve)
        echo "🚀 Starting Rojo server with log capture..."
        echo "📋 Logs will be saved to: $LOG_FILE"
        echo "📺 Press Ctrl+C to stop"
        echo ""

        # Run Rojo and capture output
        rojo serve --address 0.0.0.0 default.project.json 2>&1 | tee "$LOG_FILE"
        ;;

    build)
        echo "🔨 Building project..."
        mkdir -p "$PROJECT_ROOT/build"
        rojo build default.project.json -o "$PROJECT_ROOT/build/ClawsAndPaws.rbxl" 2>&1 | tee "$LOG_FILE"
        echo "✅ Build complete: build/ClawsAndPaws.rbxl"
        ;;

    logs)
        # Show recent logs
        if [ -z "$2" ]; then
            # Show most recent log file
            LATEST_LOG=$(ls -t "$LOG_DIR"/rojo-*.log 2>/dev/null | head -1)
            if [ -n "$LATEST_LOG" ]; then
                echo "📋 Showing latest log: $LATEST_LOG"
                tail -n 50 "$LATEST_LOG"
            else
                echo "❌ No log files found in $LOG_DIR"
            fi
        else
            # Show specific log file or tail live
            if [ "$2" = "live" ]; then
                LATEST_LOG=$(ls -t "$LOG_DIR"/rojo-*.log 2>/dev/null | head -1)
                if [ -n "$LATEST_LOG" ]; then
                    echo "📋 Tailing log: $LATEST_LOG"
                    tail -f "$LATEST_LOG"
                else
                    echo "❌ No log files found"
                fi
            else
                cat "$LOG_DIR/$2"
            fi
        fi
        ;;

    clean-logs)
        echo "🧹 Cleaning old logs..."
        rm -f "$LOG_DIR"/rojo-*.log
        echo "✅ Logs cleaned"
        ;;

    *)
        echo "Claws & Paws Development Script (with logging)"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  serve        Start Rojo server (with log capture)"
        echo "  build        Build .rbxl file"
        echo "  logs         Show recent logs"
        echo "  logs live    Tail logs in real-time"
        echo "  clean-logs   Remove old log files"
        echo ""
        echo "Logs are saved to: $LOG_DIR"
        ;;
esac
