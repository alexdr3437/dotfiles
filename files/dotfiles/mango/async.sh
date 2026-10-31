#!/usr/bin/env sh
# Run a command detached and return immediately. Every eww click handler goes through this:
# eww waits for the handler to exit, and a handler that calls `eww update`/`eww close` itself
# deadlocks with the daemon until eww's timeout kills it (freezing all popups meanwhile).
exec setsid -f "$@" >/dev/null 2>&1 </dev/null
