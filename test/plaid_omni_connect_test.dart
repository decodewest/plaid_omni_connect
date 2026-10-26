import 'package:flutter_test/flutter_test.dart';
import 'package:plaid_omni_connect/plaid_omni_connect_method_channel.dart';
import 'package:plaid_omni_connect/plaid_omni_connect_platform_interface.dart';

void main() {
  test('method channel is the default platform', () {
    expect(
      PlaidOmniConnectPlatform.instance,
      isInstanceOf<MethodChannelPlaidOmniConnect>(),
    );
  });
}
