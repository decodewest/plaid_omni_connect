import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'plaid_omni_connect_platform_interface.dart';

/// An implementation of [PlaidOmniConnectPlatform] that uses method channels.
class MethodChannelPlaidOmniConnect extends PlaidOmniConnectPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('plaid_omni_connect');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
