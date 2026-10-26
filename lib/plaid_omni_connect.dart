import 'dart:async';

import 'package:flutter/services.dart';

import 'src/plaid_configuration.dart';
import 'src/plaid_link_dispatch.dart';
import 'src/plaid_link_page.dart';
import 'src/plaid_models.dart';

export 'src/plaid_configuration.dart';
export 'src/plaid_models.dart';

/// Main entry point for plaid_omni_connect
class PlaidOmniConnect {
  static const MethodChannel _channel = MethodChannel('plaid_omni_connect');

  /// Open Plaid Link with seamless inline modal UX
  ///
  /// The Link interface will appear as a native modal within your app:
  /// - Desktop: Modal dialog/panel overlay
  /// - Mobile: Full-screen modal
  /// - Web: Centered modal with backdrop
  ///
  /// Example:
  /// ```dart
  /// await PlaidOmniConnect.open(
  ///   configuration: PlaidLinkConfiguration(
  ///     linkToken: 'link-sandbox-xxx',
  ///   ),
  ///   onSuccess: (token, metadata) {
  ///     print('Connected ${metadata.institution.name}');
  ///   },
  ///   onExit: (error, metadata) {
  ///     if (error != null) {
  ///       print('Error: ${error.displayMessage}');
  ///     }
  ///   },
  /// );
  /// ```
  static Future<void> open({
    required PlaidLinkConfiguration configuration,
    required PlaidLinkOnSuccessCallback onSuccess,
    required PlaidLinkOnExitCallback onExit,
    PlaidLinkOnEventCallback? onEvent,
  }) async {
    // Set up method call handler for callbacks
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onLinkMessage') {
        return;
      }
      final raw = call.arguments;
      final json = raw is String ? raw : raw?.toString() ?? '';
      try {
        dispatchPlaidLinkMessage(
          json,
          onSuccess: onSuccess,
          onExit: onExit,
          onEvent: onEvent,
        );
      } catch (error) {
        onExit(
          LinkError(
            errorCode: 'CALLBACK',
            errorMessage: error.toString(),
            errorType: 'PLUGIN',
            displayMessage: error.toString(),
          ),
          null,
        );
      }
    });

    await _channel.invokeMethod('open', {
      'linkToken': configuration.linkToken,
      'pageHtml': buildPlaidLinkPage(configuration.linkToken),
      'documentUrl': plaidLinkDocumentUrl,
      'noLoadingState': configuration.noLoadingState,
    });
  }

  /// Close Plaid Link programmatically (if needed)
  static Future<void> close() async {
    await _channel.invokeMethod('close');
  }
}
