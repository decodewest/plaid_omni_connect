import 'plaid_models.dart';

/// Configuration for Plaid Link
class PlaidLinkConfiguration {
  /// Link token from your backend
  final String linkToken;
  
  /// Skip loading state (show Plaid UI immediately)
  final bool noLoadingState;
  
  const PlaidLinkConfiguration({
    required this.linkToken,
    this.noLoadingState = false,
  });
}

// Callback type definitions
typedef PlaidLinkOnSuccessCallback = void Function(
  String publicToken,
  LinkSuccessMetadata metadata,
);

typedef PlaidLinkOnExitCallback = void Function(
  LinkError? error,
  LinkExitMetadata? metadata,
);

typedef PlaidLinkOnEventCallback = void Function(
  String eventName,
  LinkEventMetadata metadata,
);
