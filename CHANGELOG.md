## 1.0.4

* Fix Android Kotlin compile: `onDetachedFromActivityForConfigChanges` must take
  no parameters (`ActivityAware` contract). Removes stray `binding` token that
  broke `:plaid_omni_connect:compileDebugKotlin`.

## 1.0.3

* Align example Windows registrant with `PlaidOmniConnectPluginCApi` and
  bump example path dependency lock to 1.0.3.

## 1.0.2

* Fix Windows desktop build: fetch WIL + WebView2 via NuGet in CMake so
  `#include <wil/com.h>` / `WebView2.h` resolve on clean machines.
* Fix Windows plugin registration: use `PlaidOmniConnectPluginCApi` so the
  generated registrant includes `plaid_omni_connect_plugin_c_api.h`.

## 1.0.1

* Fix Linux desktop build: GObject type macros, parent window lookup, json-glib link,
  Plaid callback channel invokes, and GTK dialog construction.

## 1.0.0

* Initial release.
* Plaid Omni Connect Link integration for iOS, Android, Web, macOS, Windows, Linux.
* Seamless inline modal UX.