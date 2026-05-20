#include "include/plaid_omni_connect/plaid_omni_connect_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <json-glib/json-glib.h>
#include <webkit2/webkit2.h>

struct _PlaidOmniConnectPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  FlMethodChannel* channel;
  GtkWidget* dialog;
  WebKitWebView* web_view;
};

G_DEFINE_TYPE(PlaidOmniConnectPlugin, plaid_omni_connect_plugin, G_TYPE_OBJECT)

static void open_plaid_link(PlaidOmniConnectPlugin* self, const gchar* link_token);
static gchar* create_plaid_html(const gchar* link_token);
static void on_script_message_received(WebKitUserContentManager* manager,
                                       WebKitJavascriptResult* js_result,
                                       gpointer user_data);
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
    FlValue* link_token_value = fl_value_lookup_string(args, "linkToken");
    if (link_token_value == nullptr ||
        fl_value_get_type(link_token_value) != FL_VALUE_TYPE_STRING) {
      fl_method_call_respond_error(method_call, "INVALID_ARGS", "Missing linkToken",
                                  nullptr, nullptr);
      return;
    }

    open_plaid_link(self, fl_value_get_string(link_token_value));
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else if (strcmp(method, "close") == 0) {
    close_dialog(self);
    fl_method_call_respond_success(method_call, nullptr, nullptr);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

static void open_plaid_link(PlaidOmniConnectPlugin* self,
                            const gchar* link_token) {
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
  g_signal_connect(manager, "script-message-received::plaidLink",
                   G_CALLBACK(on_script_message_received), self);
  webkit_user_content_manager_register_script_message_handler(manager, "plaidLink");

  gchar* html = create_plaid_html(link_token);
  webkit_web_view_load_html(self->web_view, html, "https://cdn.plaid.com");
  g_free(html);

  gtk_widget_show_all(self->dialog);
}

static gchar* create_plaid_html(const gchar* link_token) {
  return g_strdup_printf(
      "<!DOCTYPE html>"
      "<html><head>"
      "<script "
      "src='https://cdn.plaid.com/link/v2/stable/link-initialize.js'></script>"
      "<style>"
      "body { margin: 0; font-family: sans-serif; overflow: hidden; }"
      "#container { width: 100%%; height: 100vh; }"
      ".loading { display: flex; align-items: center; justify-content: center; "
      "height: 100vh; }"
      "</style>"
      "</head><body>"
      "<div id='container'><div class='loading'>Loading...</div></div>"
      "<script>"
      "const handler = Plaid.create({"
      "  token: '%s',"
      "  onSuccess: (publicToken, metadata) => {"
      "    window.webkit.messageHandlers.plaidLink.postMessage({"
      "      type: 'success', publicToken: publicToken, metadata: metadata"
      "    });"
      "  },"
      "  onExit: (err, metadata) => {"
      "    window.webkit.messageHandlers.plaidLink.postMessage({"
      "      type: 'exit', error: err, metadata: metadata"
      "    });"
      "  },"
      "  onEvent: (eventName, metadata) => {"
      "    window.webkit.messageHandlers.plaidLink.postMessage({"
      "      type: 'event', eventName: eventName, metadata: metadata"
      "    });"
      "  },"
      "  onLoad: () => {"
      "    document.querySelector('.loading').style.display = 'none';"
      "  }"
      "});"
      "handler.open();"
      "</script></body></html>",
      link_token);
}

static FlValue* json_object_to_fl_value(JsonObject* object) {
  g_autoptr(FlValue) map = fl_value_new_map();
  if (object == nullptr) {
    return fl_value_ref(map);
  }

  JsonObjectIter iter;
  json_object_iter_init(&iter, object);
  const gchar* member_name = nullptr;
  JsonNode* member_value = nullptr;
  while (json_object_iter_next(&iter, &member_name, &member_value)) {
    if (member_name == nullptr || member_value == nullptr) {
      continue;
    }
    if (JSON_NODE_HOLDS_VALUE(member_value)) {
      GValue gvalue = G_VALUE_INIT;
      json_node_get_value(member_value, &gvalue);
      if (G_VALUE_HOLDS_STRING(&gvalue)) {
        fl_value_set_string_take(
            map, member_name,
            fl_value_new_string(g_value_get_string(&gvalue)));
      }
      g_value_unset(&gvalue);
    }
  }
  return fl_value_ref(map);
}

static void on_script_message_received(WebKitUserContentManager* manager,
                                       WebKitJavascriptResult* js_result,
                                       gpointer user_data) {
  PlaidOmniConnectPlugin* self = PLAID_OMNI_CONNECT_PLUGIN(user_data);

  JSCValue* value = webkit_javascript_result_get_js_value(js_result);
  gchar* str_value = jsc_value_to_string(value);

  JsonParser* parser = json_parser_new();
  if (json_parser_load_from_data(parser, str_value, -1, nullptr)) {
    JsonNode* root = json_parser_get_root(parser);
    JsonObject* obj = json_node_get_object(root);
    const gchar* type = json_object_get_string_member(obj, "type");

    if (g_strcmp0(type, "success") == 0) {
      const gchar* public_token =
          json_object_get_string_member(obj, "publicToken");
      JsonObject* metadata =
          json_object_get_object_member(obj, "metadata");
      g_autoptr(FlValue) args = fl_value_new_map();
      fl_value_set_string_take(
          args, "publicToken",
          fl_value_new_string(public_token != nullptr ? public_token : ""));
      fl_value_set_string_take(args, "metadata",
                               json_object_to_fl_value(metadata));
      invoke_dart_callback(self, "onSuccess", args);
      close_dialog(self);
    } else if (g_strcmp0(type, "exit") == 0) {
      JsonObject* metadata =
          json_object_get_object_member(obj, "metadata");
      g_autoptr(FlValue) args = fl_value_new_map();
      fl_value_set_string(args, "error", fl_value_new_null());
      fl_value_set_string_take(args, "metadata",
                               json_object_to_fl_value(metadata));
      invoke_dart_callback(self, "onExit", args);
      close_dialog(self);
    } else if (g_strcmp0(type, "event") == 0) {
      const gchar* event_name =
          json_object_get_string_member(obj, "eventName");
      JsonObject* metadata =
          json_object_get_object_member(obj, "metadata");
      g_autoptr(FlValue) args = fl_value_new_map();
      fl_value_set_string_take(
          args, "eventName",
          fl_value_new_string(event_name != nullptr ? event_name : ""));
      fl_value_set_string_take(args, "metadata",
                               json_object_to_fl_value(metadata));
      invoke_dart_callback(self, "onEvent", args);
    }
  }

  g_object_unref(parser);
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
