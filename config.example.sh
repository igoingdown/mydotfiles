#!/bin/bash
# Configuration file template
# Copy this file to 'secrets.sh' and fill in your actual values.
# 'secrets.sh' is git-ignored to protect your privacy.

# Note: git identity (user.name / user.email) is managed by your global
# ~/.gitconfig, not here. Do not duplicate it in secrets.sh.

# Proxy Configuration
export PROXY_IP="127.0.0.1"
export PROXY_PORT="8080"

# Xray Proxy Configuration
export XRAY_PROXY_IP="127.0.0.1"
export XRAY_PROXY_PORT="1087"
export XRAY_SOCKS_IP="127.0.0.1"
export XRAY_SOCKS_PORT="1080"


# Hexo Blog Configuration (used by the `hdeploy` function)
# Both are OPTIONAL and have sane defaults — uncomment only to override.
#   HEXO_BLOG_DIR:     path to the blog source repo
#                      (default: $HOME/github/igoingdown/hexo-posts)
#   HEXO_NODE_VERSION: nvm Node version used to build the blog. The old Hexo
#                      toolchain breaks on Node 26+ (util.isDate removed), so
#                      18 is the known-good version. (default: 18)
# export HEXO_BLOG_DIR="$HOME/github/igoingdown/hexo-posts"
# export HEXO_NODE_VERSION="18"


# API Keys and Secrets
export TCE_API_KEY="your_tce_api_key"
export METRICS_APP="your_metrics_app_name"
export METRICS_KEY="your_metrics_key"

# Kinit/Kerberos
export KINIT_USER="your.username@EXAMPLE.COM"

# IDs and Personal Numbers (Desensitized)
export MY_DID="your_did"
export MY_UID="your_uid"
export MY_EID="your_eid"
export MY_ALARMID="your_alarmid"
export MY_FCID="your_fcid"
export MY_PHONE="your_phone_number"
