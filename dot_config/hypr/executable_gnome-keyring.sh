#!/bin/bash
# Start gnome-keyring with all components
eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh,gpg)

# Export variables so apps in Hyprland can see them
export GNOME_KEYRING_CONTROL
export SSH_AUTH_SOCK
