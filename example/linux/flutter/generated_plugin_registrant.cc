//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <plaid_omni_connect/plaid_omni_connect_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) plaid_omni_connect_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "PlaidOmniConnectPlugin");
  plaid_omni_connect_plugin_register_with_registrar(plaid_omni_connect_registrar);
}
