#!/bin/bash
# Configuration file template
# Copy this file to 'secrets.sh' and fill in your actual values.
# 'secrets.sh' is git-ignored to protect your privacy.

# Git Configuration
export GIT_USER_NAME="your_name"
export GIT_USER_EMAIL="your_email@example.com"

# Github Configuration
export GITHUB_USER_NAME="your_github_name"
export GITHUB_USER_EMAIL="your_github_email@example.com"

# Proxy Configuration
# Optional. Only for a plain upstream HTTP proxy (e.g. a corporate one), used by
# the `proxy` function. Leave empty unless you actually have one.
export PROXY_IP=""
export PROXY_PORT=""

# Xray Proxy Configuration
# REQUIRED per machine, and deliberately left empty: there is no default in the
# shared code, so a wrong value fails loudly instead of silently routing every
# CLI into a dead port. Fill these in from your local xray inbounds:
#   jq '.inbounds[] | {protocol, port}' /opt/homebrew/etc/xray/config.json
# Convention: SOCKS on 1080, HTTP on 1087. Avoid 8080 for the HTTP inbound --
# local dev servers claim it constantly, and the resulting failure is opaque.
export XRAY_PROXY_IP="127.0.0.1"
export XRAY_PROXY_PORT=""
export XRAY_SOCKS_IP="127.0.0.1"
export XRAY_SOCKS_PORT=""


# API Keys and Secrets
export TCE_API_KEY="your_tce_api_key"

# Kinit/Kerberos
export KINIT_USER="your.username@EXAMPLE.COM"

# IDs and Personal Numbers (Desensitized)
export MY_DID="your_did"
export MY_UID="your_uid"
export MY_EID="your_eid"
export MY_ALARMID="your_alarmid"
export MY_FCID="your_fcid"
export MY_PHONE="your_phone_number"
