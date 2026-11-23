# Desktop interactive app

This is a managed copy of Open OnDemand's `bc_desktop` app, configured for the
single-node Snellius training cluster.

- **Interactive Apps → Desktops → Desktop** launches an XFCE session on the
  training node as a Slurm job in `rome`, limited to one hour.
- The session appears in **My Interactive Sessions**. The **Launch Desktop**
  button opens the bundled noVNC client, so no local VNC client is required.
- The desktop uses OnDemand's VNC batch-connect template, which creates a
  random per-session password, starts Xvnc, starts websockify, and writes
  `connection.yml` in the session's output directory.

## Rocky Linux / TigerVNC notes

OnDemand's VNC template is written for TurboVNC. It calls `vncserver` with
`-log` and `-rfbauth` and parses a TurboVNC-style `Desktop ...` announcement.
Rocky Linux ships the TigerVNC `vncserver` wrapper, which rejects those options
and prints a different announcement, so the playbook installs
`/usr/local/bin/vncserver` (from `../vncserver-shim.sh`). The wrapper:

- accepts the OnDemand option set and starts `/usr/bin/Xvnc` directly with
  VncAuth, a private X authority cookie, and a localhost-only listener;
- prints the announcement line that `ood_core` parses;
- records the PID file used by `vncserver -kill`, and delegates `-list` and
  `-kill` to the distribution wrapper.

Because `ood_core` locates the server with `pgrep -s 0 Xvnc`, the wrapper does
not start Xvnc in a new session. Because `ood_core` captures the wrapper's
output with `$(...)`, Xvnc's standard input and output are redirected to the
session's `vnc.log`.

The batch-connect job environment inherits the PUN environment through
`copy_environment: true`. That PATH does not reliably include `/usr/local/bin`,
so `submit.yml.erb` sets a `header` that prepends it before `ood_core` starts
the VNC server. The PATH is set in the job script rather than through
`script.job_environment` (`--export=ALL,PATH=...`): this Slurm 25.11 build
aborts slurmd when `sbatch` receives an explicit environment list in an
unprivileged container, and script-level control is independent of the PUN
environment on any host.

`template/desktops/xfce.sh` starts the session under `dbus-run-session` so
xfconf and the XFCE components have a session bus.

The OSC MIT license and the stock app layout are preserved.

## Files

- `form.yml.j2` — launch form (XFCE, `rome`, one hour, CPU count)
- `submit.yml.erb` — `template: vnc`, desktop name, geometry,
  `copy_environment`, and the PATH `header`
- `template/before.sh.erb` — waits for the VNC server before starting XFCE
- `template/script.sh.erb` — main job process that starts the XFCE session
- `template/desktops/xfce.sh` — XFCE profile setup and session start
