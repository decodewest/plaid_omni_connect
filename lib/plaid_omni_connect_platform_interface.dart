import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'plaid_omni_connect_method_channel.dart';

abstract class PlaidOmniConnectPlatform extends PlatformInterface {
  /// Constructs a PlaidOmniConnectPlatform.
  PlaidOmniConnectPlatform() : super(token: _token);

  static final Object _token = Object();

  static PlaidOmniConnectPlatform _instance = MethodChannelPlaidOmniConnect();

  /// The default instance of [PlaidOmniConnectPlatform] to use.
  ///
  /// Defaults to [MethodChannelPlaidOmniConnect].
  static PlaidOmniConnectPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PlaidOmniConnectPlatform] when
  /// they register themselves.
  static set instance(PlaidOmniConnectPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
