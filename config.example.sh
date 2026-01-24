#!/bin/bash
# Configuration file template
# Copy this file to 'secrets.sh' and fill in your actual values.
# 'secrets.sh' is git-ignored to protect your privacy.

# Git Configuration
export GIT_USER_NAME="your_name"
export GIT_USER_EMAIL="your_email@example.com"

# Dev Machine Configuration
export DEV_USER_NAME="your.username"
export DEV_IP="10.0.0.1"
export NEW_DEV_IP="10.0.0.2"
export ONLINE_DEV_IP="10.0.0.3"

# Proxy Configuration
export PROXY_IP="10.0.0.4"
export PROXY_PORT="3128"

# API Keys and Secrets
export TCE_API_KEY="your_tce_api_key"
export METRICS_APP="your_metrics_app_name"
export METRICS_KEY="your_metrics_key"

# Consul Configuration
export CONSUL_HOST_DEV="10.0.0.5"
export CONSUL_PORT_DEV="2280"
export CONSUL_HOST_MOCK="10.0.0.6"

# Kinit/Kerberos
export KINIT_USER="your.username@EXAMPLE.COM"

# BBS / Personal Info
# Use single quotes to avoid expansion issues if special chars are present
export BBS_INTRO='Your introduction text here'
export BBS_THANK='Your thank you message here'

# IDs and Personal Numbers (Desensitized)
export MY_DID="your_did"
export MY_UID="your_uid"
export MY_EID="your_eid"
export MY_ALARMID="your_alarmid"
export MY_FCID="your_fcid"
export MY_PHONE="your_phone_number"
