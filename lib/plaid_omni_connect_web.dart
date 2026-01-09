import 'dart:convert';
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// A web implementation of the PlaidOmniConnect plugin.
class PlaidOmniConnectWeb {
  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'plaid_omni_connect',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = PlaidOmniConnectWeb(channel);
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  final MethodChannel _channel;

  PlaidOmniConnectWeb(this._channel);

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'open':
        final String linkToken = call.arguments['linkToken'];
        _openPlaidLink(linkToken);
        return null;
      case 'close':
        // Plaid Link Web handles its own closing usually, or we can destroy the handler.
        // For inline implementation, closing might mean removing the iframe?
        // Plaid JS SDK 'open()' creates an iframe. 'exit()' closes it.
        // We can try to call exit on the handler if we stored it.
        return null;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'plaid_omni_connect for web doesn\'t implement \'${call.method}\'',
        );
    }
  }

  void _openPlaidLink(String linkToken) {
    // Check if Plaid script is loaded
    if (!js.context.hasProperty('Plaid')) {
      // Dynamically load Plaid script if not present
      final script = html.ScriptElement()
        ..src = 'https://cdn.plaid.com/link/v2/stable/link-initialize.js'
        ..async = true
        ..onLoad.listen((_) => _initializePlaid(linkToken));
      html.document.head!.append(script);
    } else {
      _initializePlaid(linkToken);
    }
  }

  void _initializePlaid(String linkToken) {
    final plaidOptions = js.JsObject.jsify({
      'token': linkToken,
      'onSuccess': (publicToken, metadata) {
        _channel.invokeMethod('onSuccess', {
          'publicToken': publicToken,
          'metadata': _jsObjectToMap(metadata),
        });
      },
      'onExit': (error, metadata) {
         _channel.invokeMethod('onExit', {
          'error': error != null ? _jsObjectToMap(error) : null,
          'metadata': _jsObjectToMap(metadata),
        });
      },
      'onEvent': (eventName, metadata) {
        _channel.invokeMethod('onEvent', {
          'eventName': eventName,
          'metadata': _jsObjectToMap(metadata),
        });
      },
    });

    final handler = js.context.callMethod('Plaid', ['create', plaidOptions]);
    handler.callMethod('open');
  }

  Map<String, dynamic> _jsObjectToMap(dynamic jsObject) {
    if (jsObject == null) return {};
    if (jsObject is! js.JsObject) return {'value': jsObject};
    
    // Simple recursive converter for basic Plaid metadata
    // Plaid metadata is usually flat or simple nested objects.
    // dart:js JsObject conversion is manual.
    // We can use context['JSON']['stringify'] and then jsonDecode in Dart for safety
    try {
      final jsonString = js.context['JSON'].callMethod('stringify', [jsObject]);
      if (jsonString == null) return {};
      return jsonDecode(jsonString);
    } catch (e) {
      return {};
    }
  }
}
