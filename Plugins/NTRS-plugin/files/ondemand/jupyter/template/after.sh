# Do not report a running session until JupyterLab is actually accepting
# connections. Stop a failed job instead of leaving a broken session card.
echo "Waiting for JupyterLab to open port ${port}..."
echo "TIMING - Starting wait at: $(date)"
if wait_until_port_used "${host}:${port}" 60; then
  echo "Discovered JupyterLab listening on port ${port}!"
  echo "TIMING - Wait ended at: $(date)"
else
  echo "Timed out waiting for JupyterLab to open port ${port}!" >&2
  pkill -P "${SCRIPT_PID}"
  clean_up 1
fi
sleep 2
