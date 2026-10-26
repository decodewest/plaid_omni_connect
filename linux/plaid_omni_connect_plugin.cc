#include "include/plaid_omni_connect/plaid_omni_connect_plugin.h"

#include "../common/plaid_link_message.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <webkit2/webkit2.h>

struct _PlaidOmniConnectPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  FlMethodChannel* channel;
  GtkWidget* dialog;
  WebKitWebView* web_view;
};

G_DEFINE_TYPE(PlaidOmniConnectPlugin, plaid_omni_connect_plugin, G_TYPE_OBJECT)

static void open_plaid_link(PlaidOmniConnectPlugin* self, const gchar* page_html);
static void on_script_message_received(WebKitUserContentManager* manager,
                                       WebKitJavascriptResult* js_result,
                                       gpointer user_data);
static void forward_link_message(PlaidOmniConnectPlugin* self, const gchar* json);
static void close_dialog(PlaidOmniConnectPlugin* self);
static void invoke_dart_callback(PlaidOmniConnectPlugin* self,
                                 const gchar* method, FlValue* args);
static GtkWindow* parent_window_for_plugin(PlaidOmniConnectPlugin* self);

static void invoke_dart_callback(PlaidOmniConnectPlugin* self,
                                 const gchar* method, FlValue* args) {
  if (self->channel == nullptr) {
    return;
  }
  fl_method_channel_invoke_method(self->channel, method, args, nullptr, nullptr,
                                  nullptr);
}

static GtkWindow* parent_window_for_plugin(PlaidOmniConnectPlugin* self) {
  if (self->registrar == nullptr) {
    return nullptr;
  }

  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr) {
    return nullptr;
  }

  GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
  if (!GTK_IS_WINDOW(toplevel)) {
    return nullptr;
  }

  return GTK_WINDOW(toplevel);
}

static void method_call_handler(FlMethodChannel* channel, FlMethodCall* method_call,
                                gpointer user_data) {
  PlaidOmniConnectPlugin* self = PLAID_OMNI_CONNECT_PLUGIN(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "open") == 0) {
    FlValue* page_html_value = fl_value_lookup_string(args, "pageHtml");
    if (page_html_value == nullptr ||
        fl_value_get_type(page_html_value) != FL_VALUE_TYPE_STRING ||
        fl_value_get_string(page_html_value)[0] == '\0') {
      fl_method_call_respond_error(method_call, "INVALID_ARGS", "Missing pageHtml",
                                  nullptr, nullptr);
      return;
    }

    open_plaid_link(self, fl_value_get_string(page_html_value));
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "close") == 0) {
    close_dialog(self);
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static gboolean close_dialog_later(gpointer user_data) {
  PlaidOmniConnectPlugin* self = PLAID_OMNI_CONNECT_PLUGIN(user_data);
  close_dialog(self);
  g_object_unref(self);
  return G_SOURCE_REMOVE;
}

static void forward_link_message(PlaidOmniConnectPlugin* self, const gchar* json) {
  if (json == nullptr) {
    return;
  }
  g_autoptr(FlValue) message = fl_value_new_string(json);
  invoke_dart_callback(self, "onLinkMessage", message);
  if (plaid_link_message_is_terminal(json)) {
    g_idle_add(close_dialog_later, g_object_ref(self));
  }
}

static void open_plaid_link(PlaidOmniConnectPlugin* self,
                            const gchar* page_html) {
  GtkWindow* parent = parent_window_for_plugin(self);

  self->dialog = gtk_dialog_new();
  gtk_window_set_title(GTK_WINDOW(self->dialog), "Connect Your Account");
  if (parent != nullptr) {
    gtk_window_set_transient_for(GTK_WINDOW(self->dialog), parent);
  }
  gtk_window_set_modal(GTK_WINDOW(self->dialog), TRUE);
  gtk_window_set_destroy_with_parent(GTK_WINDOW(self->dialog), TRUE);
  gtk_window_set_default_size(GTK_WINDOW(self->dialog), 600, 800);
  gtk_window_set_resizable(GTK_WINDOW(self->dialog), FALSE);

  self->web_view = WEBKIT_WEB_VIEW(webkit_web_view_new());

  WebKitSettings* settings = webkit_web_view_get_settings(self->web_view);
  webkit_settings_set_enable_javascript(settings, TRUE);
  webkit_settings_set_javascript_can_open_windows_automatically(settings, TRUE);

  GtkWidget* content_area = gtk_dialog_get_content_area(GTK_DIALOG(self->dialog));
  gtk_container_add(GTK_CONTAINER(content_area), GTK_WIDGET(self->web_view));

  WebKitUserContentManager* manager =
      webkit_web_view_get_user_content_manager(self->web_view);
  webkit_user_content_manager_register_script_message_handler(manager,
                                                              "plaidLinkHandler");
  g_signal_connect(manager, "script-message-received::plaidLinkHandler",
                   G_CALLBACK(on_script_message_received), self);

  webkit_web_view_load_html(self->web_view, page_html, "https://cdn.plaid.com");

  gtk_widget_show_all(self->dialog);
}

static void on_script_message_received(WebKitUserContentManager* manager,
                                       WebKitJavascriptResult* js_result,
                                       gpointer user_data) {
  (void)manager;
  PlaidOmniConnectPlugin* self = PLAID_OMNI_CONNECT_PLUGIN(user_data);

  JSCValue* value = webkit_javascript_result_get_js_value(js_result);
  gchar* str_value = jsc_value_to_string(value);
  forward_link_message(self, str_value);
  g_free(str_value);
}

static void close_dialog(PlaidOmniConnectPlugin* self) {
  if (self->dialog != nullptr) {
    gtk_widget_destroy(self->dialog);
    self->dialog = nullptr;
    self->web_view = nullptr;
  }
}

static void plaid_omni_connect_plugin_dispose(GObject* object) {
  PlaidOmniConnectPlugin* self = PLAID_OMNI_CONNECT_PLUGIN(object);
  close_dialog(self);
  g_clear_object(&self->channel);
  g_clear_object(&self->registrar);
  G_OBJECT_CLASS(plaid_omni_connect_plugin_parent_class)->dispose(object);
}

static void plaid_omni_connect_plugin_class_init(PlaidOmniConnectPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = plaid_omni_connect_plugin_dispose;
}

static void plaid_omni_connect_plugin_init(PlaidOmniConnectPlugin* self) {}

PlaidOmniConnectPlugin* plaid_omni_connect_plugin_new(FlPluginRegistrar* registrar) {
  PlaidOmniConnectPlugin* self = PLAID_OMNI_CONNECT_PLUGIN(
      g_object_new(plaid_omni_connect_plugin_get_type(), nullptr));
  self->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));
  self->channel = fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                                        "plaid_omni_connect",
                                        FL_METHOD_CODEC(fl_standard_method_codec_new()));
  fl_method_channel_set_method_call_handler(self->channel, method_call_handler, self,
                                          nullptr);
  return self;
}

void plaid_omni_connect_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  g_autoptr(PlaidOmniConnectPlugin) plugin = plaid_omni_connect_plugin_new(registrar);
}
