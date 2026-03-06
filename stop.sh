#!/bin/sh

echo "Stopping linkding application..."

# Stop Huey background worker
HUEY_PID_FILE="/home/chris/linkding/huey.pid"
if [ -f "$HUEY_PID_FILE" ]; then
    huey_pid=$(cat "$HUEY_PID_FILE")
    if kill -0 "$huey_pid" 2>/dev/null; then
        echo "Stopping Huey worker (pid $huey_pid)"
        kill -TERM "$huey_pid" 2>/dev/null
        sleep 2
        if kill -0 "$huey_pid" 2>/dev/null; then
            kill -KILL "$huey_pid" 2>/dev/null
        fi
    fi
    rm -f "$HUEY_PID_FILE"
fi

# Also catch any stray huey processes
pids=$(pgrep -f "manage.py run_huey")
if [ -n "$pids" ]; then
    echo "Killing remaining Huey processes: $pids"
    for pid in $pids; do
        kill -TERM "$pid" 2>/dev/null
    done
fi

# Stop Gunicorn
PID_FILE="/home/chris/linkding/linkding.pid"
if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        echo "Sending QUIT to gunicorn pid $pid"
        kill -QUIT "$pid" 2>/dev/null

        # Wait up to 10 seconds for graceful shutdown
        for i in 1 2 3 4 5 6 7 8 9 10; do
            if ! kill -0 "$pid" 2>/dev/null; then
                echo "Gunicorn stopped gracefully"
                break
            fi
            sleep 1
        done

        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            echo "Force killing gunicorn pid $pid"
            kill -KILL "$pid" 2>/dev/null
        fi
    else
        echo "PID $pid not running (stale PID file)"
    fi
    rm -f "$PID_FILE"
else
    # Fallback: find gunicorn bound to linkding's port
    pids=$(pgrep -f "gunicorn.*127.0.0.1:5003")
    if [ -n "$pids" ]; then
        echo "No PID file; falling back to pgrep. Found: $pids"
        for pid in $pids; do
            kill -QUIT "$pid" 2>/dev/null
        done
        sleep 3
        for pid in $pids; do
            kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
        done
    else
        echo "No gunicorn processes found"
    fi
fi

echo "linkding application stopped"
