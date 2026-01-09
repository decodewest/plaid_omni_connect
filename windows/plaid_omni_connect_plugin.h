#ifndef PLAID_OMNI_CONNECT_PLUGIN_H_
#define PLAID_OMNI_CONNECT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>
#include <wil/com.h>
#include <wrl.h>
#include "WebView2.h"

namespace plaid_omni_connect {

class PlaidOmniConnectPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  PlaidOmniConnectPlugin(flutter::PluginRegistrarWindows *registrar);
  virtual ~PlaidOmniConnectPlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void OpenPlaidLink(const std::string &link_token);
  void CloseModal();
  std::wstring CreatePlaidHTML(const std::string &link_token);
  void SetupWebViewHandlers();
  void HandlePlaidCallback(const wchar_t* message);

  flutter::PluginRegistrarWindows *registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND modal_hwnd_ = nullptr;
  HWND parent_hwnd_ = nullptr;
  wil::com_ptr<ICoreWebView2Controller> webview_controller_;
  wil::com_ptr<ICoreWebView2> webview_;
};

}  // namespace plaid_omni_connect

#endif  // PLAID_OMNI_CONNECT_PLUGIN_H_
