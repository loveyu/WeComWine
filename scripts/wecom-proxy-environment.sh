#!/usr/bin/env bash

# WeCom has its own proxy configuration and connection routing.  Do not let
# generic process-environment proxy settings silently override that behavior.
# This file must be sourced so the unsets affect the eventual WeCom process.
case "${FORCE_ENABLE_PROXY_WECOM:-}" in
    1|true|TRUE|yes|YES|on|ON)
        ;;
    *)
        unset \
            http_proxy https_proxy ftp_proxy all_proxy no_proxy socks_proxy \
            HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY SOCKS_PROXY
        ;;
esac
