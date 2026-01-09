#include "include/plaid_omni_connect/plaid_omni_connect_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "plaid_omni_connect_plugin.h"

void PlaidOmniConnectPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  plaid_omni_connect::PlaidOmniConnectPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
