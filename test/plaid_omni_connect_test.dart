import 'package:flutter_test/flutter_test.dart';
import 'package:plaid_omni_connect/plaid_omni_connect.dart';
import 'package:plaid_omni_connect/plaid_omni_connect_platform_interface.dart';
import 'package:plaid_omni_connect/plaid_omni_connect_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPlaidOmniConnectPlatform
    with MockPlatformInterfaceMixin
    implements PlaidOmniConnectPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final PlaidOmniConnectPlatform initialPlatform = PlaidOmniConnectPlatform.instance;

  test('$MethodChannelPlaidOmniConnect is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPlaidOmniConnect>());
  });

  test('getPlatformVersion', () async {
    PlaidOmniConnect plaidOmniConnectPlugin = PlaidOmniConnect();
    MockPlaidOmniConnectPlatform fakePlatform = MockPlaidOmniConnectPlatform();
    PlaidOmniConnectPlatform.instance = fakePlatform;

    expect(await plaidOmniConnectPlugin.getPlatformVersion(), '42');
  });
}
