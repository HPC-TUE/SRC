#!/bin/bash
# Start an XFCE session inside the VNC display. Derived from the OSC bc_desktop
# launcher with two changes for Rocky Linux: the session runs under a private
# D-Bus session bus, and a runtime directory is provided for XDG clients.

# Re-exec inside a private session bus so xfconf, xfce4-session, and the
# desktop components can talk to each other. dbus-run-session exports
# DBUS_SESSION_BUS_ADDRESS and tears the bus down when the session exits.
if [[ -z ${DBUS_SESSION_BUS_ADDRESS} ]]; then
    exec dbus-run-session -- "${BASH_SOURCE[0]}" "$@"
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${HOME}/.xdg-runtime}"
if [[ ! -d ${XDG_RUNTIME_DIR} ]]; then
    mkdir -p "${XDG_RUNTIME_DIR}"
    chmod 700 "${XDG_RUNTIME_DIR}"
fi

# Remove any preconfigured monitors
if [[ -f "${HOME}/.config/monitors.xml" ]]; then
    mv "${HOME}/.config/monitors.xml" "${HOME}/.config/monitors.xml.bak"
fi

# Copy over the default panel if it does not exist yet; otherwise XFCE prompts
# the user to choose a default panel layout.
PANEL_CONFIG="${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
if [[ ! -e "${PANEL_CONFIG}" && -f /etc/xdg/xfce4/panel/default.xml ]]; then
    mkdir -p "$(dirname "${PANEL_CONFIG}")"
    cp /etc/xdg/xfce4/panel/default.xml "${PANEL_CONFIG}"
fi

# Disable startup services that need a system-wide session
xfconf-query -c xfce4-session -p /startup/ssh-agent/enabled -n -t bool -s false || true
xfconf-query -c xfce4-session -p /startup/gpg-agent/enabled -n -t bool -s false || true

# Disable services that are not useful in a training desktop
AUTOSTART="${HOME}/.config/autostart"
rm -rf "${AUTOSTART}"
mkdir -p "${AUTOSTART}"
for service in pulseaudio rhsm-icon spice-vdagent tracker-extract \
    tracker-miner-apps tracker-miner-user-guides xfce4-power-manager xfce-polkit; do
    printf '[Desktop Entry]\nHidden=true\n' > "${AUTOSTART}/${service}.desktop"
done

# Run xfce4-terminal as a login shell so TERM and the environment are set
TERM_CONFIG="${HOME}/.config/xfce4/terminal/terminalrc"
if [[ ! -e "${TERM_CONFIG}" ]]; then
    mkdir -p "$(dirname "${TERM_CONFIG}")"
    printf '[Configuration]\nCommandLoginShell=TRUE\n' > "${TERM_CONFIG}"
elif grep -q '^CommandLoginShell=' "${TERM_CONFIG}"; then
    sed -i 's/^CommandLoginShell=.*/CommandLoginShell=TRUE/' "${TERM_CONFIG}"
else
    printf 'CommandLoginShell=TRUE\n' >> "${TERM_CONFIG}"
fi

# Start XFCE and block until the user logs out of the desktop
exec xfce4-session
