#include "plaid_omni_connect_plugin.h"

#include "../common/plaid_link_message.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <shlobj.h>
#include <shlwapi.h>

#include <memory>
#include <string>
#include <utility>
#include <variant>

namespace plaid_omni_connect {
namespace {

constexpr UINT kCloseModalMessage = WM_APP + 1;
constexpr wchar_t kWindowClassName[] = L"PlaidOmniConnectLink";

std::wstring Utf8ToWide(const std::string &utf8) {
  if (utf8.empty()) {
    return L"";
  }
  const int size = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                        static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring wide(size > 0 ? size : 0, L'\0');
  if (size > 0) {
    MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        wide.data(), size);
  }
  return wide;
}

std::string WideToUtf8(const std::wstring &wide) {
  if (wide.empty()) {
    return "";
  }
  const int size = WideCharToMultiByte(CP_UTF8, 0, wide.data(),
                                        static_cast<int>(wide.size()), nullptr, 0,
                                        nullptr, nullptr);
  std::string utf8(size > 0 ? size : 0, '\0');
  if (size > 0) {
    WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                        utf8.data(), size, nullptr, nullptr);
  }
  return utf8;
}

std::string EscapeJson(const std::string &input) {
  std::string out;
  out.reserve(input.size());
  for (const char c : input) {
    switch (c) {
      case '\\':
        out += "\\\\";
        break;
      case '"':
        out += "\\\"";
        break;
      case '\n':
        out += "\\n";
        break;
      case '\r':
        out += "\\r";
        break;
      default:
        out += c;
        break;
    }
  }
  return out;
}

std::string ErrorMessage(const std::string &message) {
  return std::string("{\"type\":\"error\",\"error\":\"") + EscapeJson(message) + "\"}";
}

void EnsureDirectoryTree(const std::wstring &path) {
  if (path.empty()) {
    return;
  }
  if (CreateDirectoryW(path.c_str(), nullptr) != 0 ||
      GetLastError() == ERROR_ALREADY_EXISTS) {
    return;
  }
  const auto slash = path.find_last_of(L'\\');
  if (slash == std::wstring::npos) {
    return;
  }
  EnsureDirectoryTree(path.substr(0, slash));
  CreateDirectoryW(path.c_str(), nullptr);
}

std::wstring WebViewUserDataFolder() {
  std::wstring root;
  PWSTR known = nullptr;
  if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_CREATE,
                                      nullptr, &known)) &&
      known != nullptr) {
    root.assign(known);
    CoTaskMemFree(known);
  }
  if (root.empty()) {
    wchar_t temp[MAX_PATH];
    const DWORD length = GetTempPathW(MAX_PATH, temp);
    if (length > 0 && length < MAX_PATH) {
      root.assign(temp, length);
    }
  }
  while (!root.empty() && (root.back() == L'\\' || root.back() == L'/')) {
    root.pop_back();
  }
  const std::wstring folder = root + L"\\WealthWinds\\PlaidWebView2";
  EnsureDirectoryTree(folder);
  return folder;
}

HWND OwnerWindow(HWND hwnd) {
  if (hwnd == nullptr) {
    return nullptr;
  }
  const HWND root = GetAncestor(hwnd, GA_ROOT);
  return root != nullptr ? root : hwnd;
}

bool SameDocumentUrl(const std::wstring &expected, const wchar_t *actual) {
  if (actual == nullptr) {
    return false;
  }
  std::wstring uri(actual);
  auto trim = [](std::wstring value) {
    while (!value.empty() && (value.back() == L'/' || value.back() == L' ')) {
      value.pop_back();
    }
    return value;
  };
  return trim(expected) == trim(uri);
}

const std::string *StringArg(const flutter::EncodableMap &arguments,
                              const char *key) {
  const auto it = arguments.find(flutter::EncodableValue(key));
  if (it == arguments.end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&it->second);
}

}  // namespace

void PlaidOmniConnectPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "plaid_omni_connect",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<PlaidOmniConnectPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

PlaidOmniConnectPlugin::PlaidOmniConnectPlugin(
    flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "plaid_omni_connect",
      &flutter::StandardMethodCodec::GetInstance());
}

PlaidOmniConnectPlugin::~PlaidOmniConnectPlugin() { CloseModal(); }

void PlaidOmniConnectPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "open") {
    const auto *arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments == nullptr) {
      result->Error("INVALID_ARGS", "Arguments must be a map");
      return;
    }

    const std::string *page_html = StringArg(*arguments, "pageHtml");
    const std::string *document_url = StringArg(*arguments, "documentUrl");
    if (page_html == nullptr || page_html->empty() || document_url == nullptr ||
        document_url->empty()) {
      result->Error("INVALID_ARGS", "Missing pageHtml or documentUrl");
      return;
    }

    OpenPlaidLink(*page_html, *document_url);
    result->Success();
  } else if (method_call.method_name() == "close") {
    CloseModal();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

void PlaidOmniConnectPlugin::OpenPlaidLink(const std::string &page_html,
                                            const std::string &document_url) {
  CloseModal();
  terminal_sent_ = false;
  page_html_ = page_html;
  document_url_ = Utf8ToWide(document_url);

  if (registrar_ == nullptr || registrar_->GetView() == nullptr) {
    ForwardMessage(ErrorMessage("Flutter window is unavailable"));
    return;
  }
  parent_hwnd_ = OwnerWindow(registrar_->GetView()->GetNativeWindow());
  if (parent_hwnd_ == nullptr) {
    ForwardMessage(ErrorMessage("Flutter window is unavailable"));
    return;
  }

  static bool registered = false;
  if (!registered) {
    WNDCLASSEX window_class = {};
    window_class.cbSize = sizeof(window_class);
    window_class.lpfnWndProc = ModalWndProc;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.lpszClassName = kWindowClassName;
    window_class.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    registered = RegisterClassEx(&window_class) != 0 ||
                 GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
  }

  RECT parent_rect{};
  if (!GetWindowRect(parent_hwnd_, &parent_rect)) {
    parent_rect = RECT{100, 100, 900, 700};
  }
  int x = parent_rect.left + (parent_rect.right - parent_rect.left - 600) / 2;
  int y = parent_rect.top + (parent_rect.bottom - parent_rect.top - 800) / 2;
  RECT work{};
  if (SystemParametersInfo(SPI_GETWORKAREA, 0, &work, 0)) {
    if (x < work.left) {
      x = work.left;
    }
    if (y < work.top) {
      y = work.top;
    }
    if (x + 600 > work.right) {
      x = work.right - 600;
    }
    if (y + 800 > work.bottom) {
      y = work.bottom - 800;
    }
  }

  modal_hwnd_ = CreateWindowEx(
      WS_EX_DLGMODALFRAME | WS_EX_TOPMOST, kWindowClassName, L"Connect Your Account",
      WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_VISIBLE, x, y, 600, 800, parent_hwnd_,
      nullptr, GetModuleHandle(nullptr), nullptr);
  if (modal_hwnd_ == nullptr) {
    ForwardMessage(ErrorMessage("Could not open the Plaid Link window"));
    return;
  }
  SetWindowLongPtr(modal_hwnd_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
  EnableWindow(parent_hwnd_, FALSE);

  static const std::wstring user_data_folder = WebViewUserDataFolder();
  CreateCoreWebView2EnvironmentWithOptions(
      nullptr, user_data_folder.c_str(), nullptr,
      Microsoft::WRL::Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [this](HRESULT result, ICoreWebView2Environment *env) -> HRESULT {
            if (FAILED(result) || env == nullptr || modal_hwnd_ == nullptr) {
              ForwardMessage(ErrorMessage("WebView2 runtime is unavailable"));
              return S_OK;
            }
            environment_ = env;
            env->CreateCoreWebView2Controller(
                modal_hwnd_,
                Microsoft::WRL::Callback<
                    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                    [this](HRESULT result, ICoreWebView2Controller *controller) -> HRESULT {
                      if (FAILED(result) || controller == nullptr || modal_hwnd_ == nullptr) {
                        ForwardMessage(ErrorMessage("WebView2 failed to start"));
                        return S_OK;
                      }
                      webview_controller_ = controller;
                      wil::com_ptr<ICoreWebView2Controller2> controller2;
                      controller->QueryInterface(IID_PPV_ARGS(&controller2));
                      if (controller2 != nullptr) {
                        const COREWEBVIEW2_COLOR background{255, 255, 255, 255};
                        controller2->put_DefaultBackgroundColor(background);
                      }
                      webview_controller_->get_CoreWebView2(&webview_);
                      if (webview_ == nullptr) {
                        ForwardMessage(ErrorMessage("WebView2 failed to start"));
                        return S_OK;
                      }
                      webview_controller_->put_IsVisible(TRUE);

                      RECT bounds;
                      GetClientRect(modal_hwnd_, &bounds);
                      webview_controller_->put_Bounds(bounds);

                      wil::com_ptr<ICoreWebView2Settings> settings;
                      webview_->get_Settings(&settings);
                      settings->put_IsScriptEnabled(TRUE);
                      settings->put_IsWebMessageEnabled(TRUE);

                      SetupWebViewHandlers();
                      webview_->AddWebResourceRequestedFilter(
                          document_url_.c_str(),
                          COREWEBVIEW2_WEB_RESOURCE_CONTEXT_DOCUMENT);
                      webview_->add_WebResourceRequested(
                          Microsoft::WRL::Callback<
                              ICoreWebView2WebResourceRequestedEventHandler>(
                              [this](ICoreWebView2 *sender,
                                     ICoreWebView2WebResourceRequestedEventArgs *args)
                                  -> HRESULT {
                                return OnWebResourceRequested(sender, args);
                              })
                              .Get(),
                          &resource_token_);
                      webview_->Navigate(document_url_.c_str());
                      ShowWindow(modal_hwnd_, SW_SHOW);
                      SetForegroundWindow(modal_hwnd_);
                      return S_OK;
                    })
                    .Get());
            return S_OK;
          })
          .Get());

  ShowWindow(modal_hwnd_, SW_SHOW);
  UpdateWindow(modal_hwnd_);
}

void PlaidOmniConnectPlugin::CloseModal() {
  if (modal_hwnd_ == nullptr) {
    webview_.reset();
    webview_controller_.reset();
    return;
  }
  const HWND hwnd = modal_hwnd_;
  modal_hwnd_ = nullptr;
  if (parent_hwnd_ != nullptr) {
    EnableWindow(parent_hwnd_, TRUE);
    SetForegroundWindow(parent_hwnd_);
  }
  webview_.reset();
  webview_controller_.reset();
  DestroyWindow(hwnd);
}

void PlaidOmniConnectPlugin::ForwardMessage(const std::string &json) {
  if (json.empty()) {
    return;
  }
  const bool terminal = plaid_link_message_is_terminal(json.c_str()) != 0;
  if (terminal) {
    if (terminal_sent_) {
      return;
    }
    terminal_sent_ = true;
  }
  if (channel_ != nullptr) {
    channel_->InvokeMethod("onLinkMessage",
                            std::make_unique<flutter::EncodableValue>(json));
  }
  if (terminal && modal_hwnd_ != nullptr) {
    PostMessage(modal_hwnd_, kCloseModalMessage, 0, 0);
  }
}

void PlaidOmniConnectPlugin::SetupWebViewHandlers() {
  webview_->add_WebMessageReceived(
      Microsoft::WRL::Callback<ICoreWebView2WebMessageReceivedEventHandler>(
          [this](ICoreWebView2 *webview,
                 ICoreWebView2WebMessageReceivedEventArgs *args) -> HRESULT {
            (void)webview;
            LPWSTR raw = nullptr;
            if (FAILED(args->TryGetWebMessageAsString(&raw)) || raw == nullptr) {
              if (raw != nullptr) {
                CoTaskMemFree(raw);
              }
              raw = nullptr;
              if (FAILED(args->get_WebMessageAsJson(&raw)) || raw == nullptr) {
                return S_OK;
              }
            }
            const std::wstring wide(raw);
            CoTaskMemFree(raw);
            ForwardMessage(WideToUtf8(wide));
            return S_OK;
          })
          .Get(),
      nullptr);
}

HRESULT PlaidOmniConnectPlugin::OnWebResourceRequested(
    ICoreWebView2 *sender, ICoreWebView2WebResourceRequestedEventArgs *args) {
  (void)sender;
  if (environment_ == nullptr) {
    return S_OK;
  }
  wil::com_ptr<ICoreWebView2WebResourceRequest> request;
  args->get_Request(&request);
  wil::unique_cotaskmem_string uri;
  request->get_Uri(&uri);
  if (!SameDocumentUrl(document_url_, uri.get())) {
    return S_OK;
  }

  wil::com_ptr<IStream> stream;
  stream.attach(SHCreateMemStream(reinterpret_cast<const BYTE *>(page_html_.data()),
                                   static_cast<UINT>(page_html_.size())));
  if (stream == nullptr) {
    return E_OUTOFMEMORY;
  }
  wil::com_ptr<ICoreWebView2WebResourceResponse> response;
  const HRESULT created = environment_->CreateWebResourceResponse(
      stream.get(), 200, L"OK", L"Content-Type: text/html; charset=utf-8\r\n",
      &response);
  if (FAILED(created) || response == nullptr) {
    return created;
  }
  args->put_Response(response.get());
  return S_OK;
}

LRESULT CALLBACK PlaidOmniConnectPlugin::ModalWndProc(HWND hwnd, UINT message,
                                                       WPARAM wparam, LPARAM lparam) {
  auto *plugin = reinterpret_cast<PlaidOmniConnectPlugin *>(
      GetWindowLongPtr(hwnd, GWLP_USERDATA));
  if (plugin == nullptr) {
    return DefWindowProc(hwnd, message, wparam, lparam);
  }
  switch (message) {
    case WM_CLOSE:
      plugin->ForwardMessage(
          "{\"type\":\"exit\",\"error\":null,\"metadata\":{\"status\":\"\"}}");
      return 0;
    case kCloseModalMessage:
      plugin->CloseModal();
      return 0;
    default:
      return DefWindowProc(hwnd, message, wparam, lparam);
  }
}

}  // namespace plaid_omni_connect
