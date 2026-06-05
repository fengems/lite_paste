#!/usr/bin/env bash

litepaste_configure_flavor() {
  local raw_flavor="${LITEPASTE_FLAVOR:-stable}"

  case "${raw_flavor}" in
    ""|stable|release|production)
      LITEPASTE_FLAVOR="stable"
      LITEPASTE_APP_DISPLAY_NAME="Lite Paste"
      LITEPASTE_BUNDLE_IDENTIFIER="com.fengems.LitePaste"
      LITEPASTE_APP_BUNDLE_BASENAME="LitePaste"
      LITEPASTE_APPLICATION_SUPPORT_DIR_NAME="LitePaste"
      LITEPASTE_DEFAULT_PANEL_HOTKEY="command+shift+v"
      ;;
    dev|development)
      LITEPASTE_FLAVOR="dev"
      LITEPASTE_APP_DISPLAY_NAME="Lite Paste Dev"
      LITEPASTE_BUNDLE_IDENTIFIER="com.fengems.LitePaste.dev"
      LITEPASTE_APP_BUNDLE_BASENAME="LitePasteDev"
      LITEPASTE_APPLICATION_SUPPORT_DIR_NAME="LitePaste-Dev"
      LITEPASTE_DEFAULT_PANEL_HOTKEY="command+option+shift+v"
      ;;
    *)
      printf '未知构建通道：%s。可选值：stable、dev。\n' "${raw_flavor}" >&2
      return 64
      ;;
  esac

  LITEPASTE_PRODUCT_NAME="LitePaste"
  LITEPASTE_APP_BUNDLE_NAME="${LITEPASTE_APP_BUNDLE_BASENAME}.app"
  LITEPASTE_ARCHIVE_PRODUCT_NAME="${LITEPASTE_APP_BUNDLE_BASENAME}"
  LITEPASTE_VOLUME_NAME="${LITEPASTE_APP_DISPLAY_NAME}"
}
