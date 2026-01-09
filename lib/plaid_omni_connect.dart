import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'src/plaid_configuration.dart';
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
      try {
        switch (call.method) {
          case 'onSuccess':
            final publicToken = call.arguments['publicToken'] as String;
            final metadata = LinkSuccessMetadata.fromJson(
              Map<String, dynamic>.from(call.arguments['metadata'] ?? {})
            );
            onSuccess(publicToken, metadata);
            break;
            
          case 'onExit':
            LinkError? error;
            if (call.arguments['error'] != null) {
              // Handle link error mapping
              final errorMap = call.arguments['error'];
              if (errorMap is Map) {
                 error = LinkError.fromJson(Map<String, dynamic>.from(errorMap));
              } else if (errorMap is String) {
                 // Creating a wrapper for string errors just in case
                 error = LinkError(
                   errorCode: 'UNKNOWN',
                   errorMessage: errorMap,
                   errorType: 'UNKNOWN',
                   displayMessage: errorMap,
                 );
              }
            }
            LinkExitMetadata? metadata;
            if (call.arguments['metadata'] != null) {
              metadata = LinkExitMetadata.fromJson(
                Map<String, dynamic>.from(call.arguments['metadata'] ?? {})
              );
            }
            onExit(error, metadata);
            break;
            
          case 'onEvent':
            if (onEvent != null) {
              final eventName = call.arguments['eventName'] as String;
              final metadata = LinkEventMetadata.fromJson(
                Map<String, dynamic>.from(call.arguments['metadata'] ?? {})
              );
              onEvent(eventName, metadata);
            }
            break;
            
          case 'onError':
            debugPrint('Plaid Link Error: ${call.arguments['error']}');
            break;
        }
      } catch (e) {
        debugPrint('Error handling Plaid callback: $e');
      }
    });
    
    // Invoke native platform method to open modal
    await _channel.invokeMethod('open', {
      'linkToken': configuration.linkToken,
      'noLoadingState': configuration.noLoadingState,
    });
  }
  
  /// Close Plaid Link programmatically (if needed)
  static Future<void> close() async {
    await _channel.invokeMethod('close');
  }
}
