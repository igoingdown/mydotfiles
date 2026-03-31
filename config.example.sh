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

# Dev Machine Configuration
export DEV_USER_NAME="your.username"
export DEV_IP="10.0.0.1"
export NEW_DEV_IP="10.0.0.2"
export ONLINE_DEV_IP="10.0.0.3"

# Proxy Configuration
export PROXY_IP="10.0.0.4"
export PROXY_PORT="3128"

# Xray Proxy Configuration
export XRAY_PROXY_IP="127.0.0.1"
export XRAY_PROXY_PORT="8080"


# API Keys and Secrets
export TCE_API_KEY="your_tce_api_key"
export METRICS_APP="your_metrics_app_name"
export METRICS_KEY="your_metrics_key"

# Consul Configuration
export CONSUL_HTTP_HOST=$DEV_IP
export CONSUL_HTTP_PORT="2280"

# Kinit/Kerberos
export KINIT_USER="your.username@EXAMPLE.COM"

# IDs and Personal Numbers (Desensitized)
export MY_DID="your_did"
export MY_UID="your_uid"
export MY_EID="your_eid"
export MY_ALARMID="your_alarmid"
export MY_FCID="your_fcid"
export MY_PHONE="your_phone_number"
