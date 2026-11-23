#!/bin/bash
# TigerVNC compatibility wrapper for Open OnDemand's VNC batch-connect
# template.
#
# OnDemand's ood_core VNC template starts a desktop with a TurboVNC-style
# command:
#
#   vncserver -log vnc.log -rfbauth vnc.passwd -nohttpd -noxstartup \
#             -name OnDemand Desktop -geometry 1280x720
#
# The vncserver wrapper shipped by TigerVNC on Rocky Linux 9 does not accept
# -log or -rfbauth, and it prints its desktop announcement in a format that
# ood_core cannot parse. This wrapper accepts the OnDemand option set, starts
# /usr/bin/Xvnc directly, and prints the
# "Desktop '...' is <host>:<display>" line that ood_core expects.
#
# Notes for ood_core compatibility:
#   * The Xvnc process is started in the background of the calling session,
#     not in a new one: ood_core locates it with `pgrep -s 0 Xvnc`.
#   * All Xvnc output goes to the log file so the calling command
#     substitution does not wait on a pipe the background Xvnc would hold.
#   * The PID file is recorded where the distribution wrapper looks, so
#     `vncserver -list` and `vncserver -kill` (delegated below) manage the
#     session.
#
# Install as /usr/local/bin/vncserver so it is selected before /usr/bin.
set -u

real_vncserver=/usr/bin/vncserver
real_xvnc=/usr/bin/Xvnc

log_file=""
passwd_file=""
geometry="1280x720"
depth="24"
desktop_name="OnDemand Desktop"
display_number=""
extra_args=()

usage() {
    cat <<'EOF'
usage: vncserver [:<display>] [options]

TigerVNC compatibility wrapper for Open OnDemand. Accepts the TurboVNC-style
options used by the OnDemand VNC template and starts Xvnc directly.

Options: -log FILE -rfbauth FILE -geometry WxH -depth D -name NAME
         -noxstartup -nohttpd -idletimeout SECONDS -list -kill :DISPLAY
EOF
}

port_in_use() {
    ( exec 3<>"/dev/tcp/127.0.0.1/$1" ) 2>/dev/null
}

while (( $# > 0 )); do
    case "$1" in
        -log)
            log_file=${2:-}
            shift 2
            ;;
        -rfbauth)
            passwd_file=${2:-}
            shift 2
            ;;
        -geometry)
            geometry=${2:-}
            shift 2
            ;;
        -depth)
            depth=${2:-}
            shift 2
            ;;
        -name)
            # TurboVNC (and ood_core) allow the desktop name to span several
            # unquoted words. Collect words until the next option.
            name_words=()
            shift
            while (( $# > 0 )) && [[ $1 != -* ]]; do
                name_words+=( "$1" )
                shift
            done
            desktop_name=${name_words[*]:-OnDemand Desktop}
            ;;
        -noxstartup)
            # The OnDemand job script starts the desktop session itself.
            shift
            ;;
        -nohttpd)
            # TurboVNC-only option; TigerVNC has no built-in web server.
            shift
            ;;
        -idletimeout)
            # TigerVNC calls this parameter IdleTimeout and leaves it at zero.
            shift 2
            ;;
        -dpi)
            shift 2
            ;;
        -fp)
            extra_args+=( -fp "${2:-}" )
            shift 2
            ;;
        -h|-help|--help)
            usage
            exit 0
            ;;
        -list|-kill)
            exec "$real_vncserver" "$@"
            ;;
        :[0-9]*)
            display_number=${1#:}
            shift
            ;;
        *)
            extra_args+=( "$1" )
            shift
            ;;
    esac
done

if [[ -z $display_number ]]; then
    for candidate in $(seq 1 99); do
        if [[ -e "/tmp/.X${candidate}-lock" || -e "/tmp/.X11-unix/X${candidate}" ]]; then
            continue
        fi
        port_in_use $(( 5900 + candidate )) && continue
        port_in_use $(( 6000 + candidate )) && continue
        display_number=$candidate
        break
    done
fi

if [[ -z $display_number ]]; then
    echo "vncserver: no free display number" >&2
    exit 1
fi

# ood_core passes a relative password file inside the session directory.
[[ -n $passwd_file ]] || passwd_file="${HOME}/.vnc/passwd"
[[ $passwd_file == /* ]] || passwd_file="${PWD}/${passwd_file}"
if [[ ! -r $passwd_file ]]; then
    echo "vncserver: cannot read VNC password file ${passwd_file}" >&2
    exit 1
fi

[[ -n $log_file ]] || log_file="${HOME}/.vnc/$(hostname):${display_number}.log"
[[ $log_file == /* ]] || log_file="${PWD}/${log_file}"

# Keep an X authority cookie so that other local users cannot attach to this
# display, matching what the distribution wrapper would set up.
xauth_file="${XAUTHORITY:-${HOME}/.Xauthority}"
touch "$xauth_file" 2>/dev/null || true
cookie=$(mcookie 2>/dev/null || true)
if [[ -n $cookie ]]; then
    xauth -f "$xauth_file" add "$(hostname):${display_number}" . "$cookie" 2>/dev/null || true
    xauth -f "$xauth_file" add "$(hostname)/unix:${display_number}" . "$cookie" 2>/dev/null || true
fi

mkdir -p "${HOME}/.vnc" 2>/dev/null || true

"$real_xvnc" ":${display_number}" \
    -auth "$xauth_file" \
    -rfbauth "$passwd_file" \
    -geometry "$geometry" \
    -depth "$depth" \
    -desktop "$desktop_name" \
    -SecurityTypes VncAuth \
    -localhost \
    -rfbport "$(( 5900 + display_number ))" \
    -pn \
    "${extra_args[@]}" \
    >> "$log_file" 2>&1 < /dev/null &
xvnc_pid=$!

for _ in $(seq 1 100); do
    if ! kill -0 "$xvnc_pid" 2>/dev/null; then
        echo "vncserver: Xvnc failed to start on :${display_number}" >&2
        tail -n 40 "$log_file" >&2 2>/dev/null || true
        exit 1
    fi
    if port_in_use $(( 5900 + display_number )); then
        printf '%s\n' "$xvnc_pid" > "${HOME}/.vnc/$(hostname):${display_number}.pid"
        echo "Desktop '${desktop_name}' is $(hostname):${display_number}"
        exit 0
    fi
    sleep 0.1
done

echo "vncserver: timed out waiting for Xvnc on :${display_number}" >&2
kill -TERM "$xvnc_pid" 2>/dev/null || true
exit 1
