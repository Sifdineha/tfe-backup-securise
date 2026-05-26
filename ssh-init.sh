#!/bin/sh
cp -r /root/.ssh-keys /root/.ssh
chmod 700 /root/.ssh
chmod 600 /root/.ssh/config
chmod 600 /root/.ssh/id_hetzner_tfe
exec /init
