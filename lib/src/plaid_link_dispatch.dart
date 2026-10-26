import 'dart:convert';

import 'plaid_configuration.dart';
import 'plaid_models.dart';

/// Delivers one host message to the Flutter callbacks.
///
/// [rawJson] is the JSON object posted by the Link page, or that object encoded
/// a second time as a JSON string (WebView2's JSON form of a string message).
void dispatchPlaidLinkMessage(
  String rawJson, {
  required PlaidLinkOnSuccessCallback onSuccess,
  required PlaidLinkOnExitCallback onExit,
  PlaidLinkOnEventCallback? onEvent,
}) {
  final decoded = _decodeObject(rawJson);
  final type = decoded['type']?.toString() ?? '';
  switch (type) {
    case 'success':
      onSuccess(
        decoded['publicToken']?.toString() ?? '',
        LinkSuccessMetadata.fromJson(_map(decoded['metadata'])),
      );
      return;
    case 'exit':
      onExit(_linkError(decoded['error']), _exitMetadata(decoded['metadata']));
      return;
    case 'event':
      final eventName = decoded['eventName']?.toString() ?? '';
      if (onEvent != null) {
        onEvent(
          eventName,
          LinkEventMetadata.fromJson(_map(decoded['metadata'])),
        );
      }
      return;
    case 'error':
      final message = decoded['error']?.toString() ?? 'Plaid Link failed';
      onExit(
        LinkError(
          errorCode: 'LINK_PAGE',
          errorMessage: message,
          errorType: 'LINK',
          displayMessage: message,
        ),
        _exitMetadataOrNull(decoded['metadata']),
      );
      return;
    default:
      onExit(
        LinkError(
          errorCode: 'LINK_PAGE',
          errorMessage: 'Unrecognized Plaid Link result',
          errorType: 'LINK',
          displayMessage: 'Unrecognized Plaid Link result',
        ),
        null,
      );
  }
}

Map<String, dynamic> _decodeObject(String rawJson) {
  dynamic decoded = jsonDecode(rawJson);
  if (decoded is String) {
    decoded = jsonDecode(decoded);
  }
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  throw const FormatException('Plaid Link message was not an object');
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

LinkExitMetadata? _exitMetadataOrNull(Object? value) {
  if (value is! Map) {
    return null;
  }
  return LinkExitMetadata.fromJson(Map<String, dynamic>.from(value));
}

LinkExitMetadata _exitMetadata(Object? value) {
  return _exitMetadataOrNull(value) ?? LinkExitMetadata(status: '');
}

LinkError? _linkError(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map) {
    return LinkError.fromJson(Map<String, dynamic>.from(value));
  }
  final message = value.toString();
  if (message.isEmpty) {
    return null;
  }
  return LinkError(
    errorCode: 'LINK',
    errorMessage: message,
    errorType: 'LINK',
    displayMessage: message,
  );
}
