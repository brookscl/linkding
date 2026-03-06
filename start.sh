#!/bin/sh

set -x  # Enable shell tracing for debug

cd /home/chris/linkding

# Activate virtual environment
. /home/chris/linkding/.venv/bin/activate

export PYTHONUNBUFFERED=1
export DJANGO_SETTINGS_MODULE=bookmarks.settings.prod

# Load environment variables from .env if present
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Start Huey background task worker as a daemon
python manage.py run_huey -f &
HUEY_PID=$!
echo "$HUEY_PID" > /home/chris/linkding/huey.pid
echo "Started Huey worker (pid $HUEY_PID)"

# Run Gunicorn as the WSGI server
exec gunicorn bookmarks.wsgi:application \
  --pid /home/chris/linkding/linkding.pid \
  --bind 127.0.0.1:5003 \
  --workers 2 \
  --threads 2 \
  --log-level=info \
  --access-logfile - \
  --error-logfile -
