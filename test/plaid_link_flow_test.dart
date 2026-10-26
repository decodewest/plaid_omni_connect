import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plaid_omni_connect/plaid_omni_connect.dart';
import 'package:plaid_omni_connect/src/plaid_link_dispatch.dart';
import 'package:plaid_omni_connect/src/plaid_link_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sandboxToken = 'link-sandbox-first-platypus';
  const successMetadata = <String, dynamic>{
    'institution': {
      'institution_id': 'ins_109508',
      'name': 'First Platypus Bank',
    },
    'accounts': [
      {
        'id': 'acc_checking',
        'name': 'Plaid Checking',
        'mask': '0000',
        'type': 'depository',
        'subtype': 'checking',
      },
    ],
    'link_session_id': 'session-1',
  };

  test('page keeps a hostile token inside the script', () {
    const hostile = "</script><script>throw 'xss'";
    final page = buildPlaidLinkPage(hostile);
    expect(page.contains(hostile), isFalse);
    expect(page, contains(plaidLinkScriptUrl));
    expect(page, contains('handler.open()'));
    expect(page, contains('postToHost'));
    expect(
      plaidLinkInlineScript(sandboxToken),
      contains(jsonEncode(sandboxToken)),
    );
  });

  test('each host posts success, event, and exit for a sandbox bank', () async {
    for (final host in ['windows', 'webkit', 'android']) {
      final result = await _runLinkScript(sandboxToken, host);
      expect(result.token, sandboxToken, reason: host);
      expect(result.messages.map((message) => message['type']), [
        'success',
        'event',
        'exit',
      ], reason: host);

      String? publicToken;
      String? institutionName;
      var events = 0;
      String? exitStatus;
      for (final message in result.messages) {
        dispatchPlaidLinkMessage(
          jsonEncode(message),
          onSuccess: (token, metadata) {
            publicToken = token;
            institutionName = metadata.institution.name;
            expect(metadata.institution.id, 'ins_109508');
            expect(metadata.accounts.single.name, 'Plaid Checking');
            expect(metadata.accounts.single.subtype, 'checking');
            expect(metadata.linkSessionId, 'session-1');
          },
          onExit: (error, metadata) {
            expect(error, isNull);
            exitStatus = metadata?.status;
            expect(metadata?.institutionName, 'First Platypus Bank');
          },
          onEvent: (eventName, metadata) {
            events += 1;
            expect(eventName, 'OPEN');
            expect(metadata.viewName, 'CONSENT');
            expect(metadata.institutionName, 'First Platypus Bank');
          },
        );
      }
      expect(publicToken, 'public-sandbox-token', reason: host);
      expect(institutionName, 'First Platypus Bank', reason: host);
      expect(events, 1, reason: host);
      expect(exitStatus, '', reason: host);
    }
  });

  test('a page that cannot start Link reports an error', () async {
    final result = await _runLinkScript(
      sandboxToken,
      'windows',
      plaidDefined: false,
    );
    expect(result.messages.single['type'], 'error');
    dispatchPlaidLinkMessage(
      jsonEncode(result.messages.single),
      onSuccess: (token, metadata) => fail('success'),
      onExit: (error, metadata) {
        expect(error?.displayMessage, contains('Plaid'));
      },
    );
  });

  test(
    'dispatch reads nested metadata and a double-encoded WebView message',
    () {
      final once = jsonEncode({
        'type': 'success',
        'publicToken': 'public-sandbox-token',
        'metadata': successMetadata,
      });
      dispatchPlaidLinkMessage(
        jsonEncode(once),
        onSuccess: (token, metadata) {
          expect(token, 'public-sandbox-token');
          expect(metadata.institution.name, 'First Platypus Bank');
          expect(metadata.accounts.single.mask, '0000');
        },
        onExit: (error, metadata) => fail('exit'),
      );
    },
  );

  test('exit error and unrecognized results reach onExit', () {
    dispatchPlaidLinkMessage(
      jsonEncode({
        'type': 'exit',
        'error': {
          'error_code': 'INVALID_LINK_TOKEN',
          'error_message': 'expired',
          'error_type': 'INVALID_INPUT',
          'display_message': 'This link has expired',
        },
        'metadata': {
          'status': 'requires_credentials',
          'institution_name': 'Tartan Bank',
          'institution_id': 'ins_109511',
          'link_session_id': 'session-2',
        },
      }),
      onSuccess: (token, metadata) => fail('success'),
      onExit: (error, metadata) {
        expect(error?.errorCode, 'INVALID_LINK_TOKEN');
        expect(error?.displayMessage, 'This link has expired');
        expect(metadata?.institutionName, 'Tartan Bank');
        expect(metadata?.status, 'requires_credentials');
      },
    );

    dispatchPlaidLinkMessage(
      jsonEncode({'type': 'nope'}),
      onSuccess: (token, metadata) => fail('success'),
      onExit: (error, metadata) {
        expect(error?.errorCode, 'LINK_PAGE');
      },
    );
  });

  test(
    'open sends the shared page and returns host messages to callbacks',
    () async {
      const channel = MethodChannel('plaid_omni_connect');
      Map<dynamic, dynamic>? openArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'open') {
              openArgs = Map<dynamic, dynamic>.from(call.arguments as Map);
            }
            return null;
          });

      String? institution;
      String? outcome;
      final opened = PlaidOmniConnect.open(
        configuration: const PlaidLinkConfiguration(linkToken: sandboxToken),
        onSuccess: (token, metadata) {
          institution = metadata.institution.name;
          outcome = 'success:$token';
        },
        onExit: (error, metadata) {
          outcome = 'exit:${error?.displayMessage}';
        },
      );

      await untilCalled(() => openArgs != null);
      expect(openArgs!['linkToken'], sandboxToken);
      expect(openArgs!['documentUrl'], plaidLinkDocumentUrl);
      final page = openArgs!['pageHtml'] as String;
      expect(page, contains(plaidLinkScriptUrl));
      expect(page, contains('handler.open()'));
      expect(page, contains(jsonEncode(sandboxToken)));

      final codec = const StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        'plaid_omni_connect',
        codec.encodeMethodCall(
          MethodCall(
            'onLinkMessage',
            jsonEncode({
              'type': 'success',
              'publicToken': 'public-sandbox-token',
              'metadata': successMetadata,
            }),
          ),
        ),
        (_) {},
      );
      await untilCalled(() => outcome != null);
      expect(outcome, 'success:public-sandbox-token');
      expect(institution, 'First Platypus Bank');

      outcome = null;
      await messenger.handlePlatformMessage(
        'plaid_omni_connect',
        codec.encodeMethodCall(MethodCall('onLinkMessage', '{')),
        (_) {},
      );
      await untilCalled(() => outcome != null);
      expect(outcome, contains('exit:'));

      await opened;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  test('native hosts load the shared page and forward terminal messages', () {
    final hosts = <String, String>{
      'android/src/main/kotlin/com/decodewest/plaid_omni_connect/PlaidOmniConnectPlugin.kt':
          'android',
      'ios/plaid_omni_connect/Sources/plaid_omni_connect/PlaidOmniConnectPlugin.swift':
          'ios',
      'macos/plaid_omni_connect/Sources/plaid_omni_connect/PlaidLinkHandler.swift':
          'macos',
      'linux/plaid_omni_connect_plugin.cc': 'linux',
      'windows/plaid_omni_connect_plugin.cpp': 'windows',
      'lib/plaid_omni_connect_web.dart': 'web',
    };

    for (final entry in hosts.entries) {
      final source = File(entry.key).readAsStringSync();
      expect(source, contains('onLinkMessage'), reason: entry.value);
      if (entry.value != 'windows') {
        expect(source, contains('https://cdn.plaid.com'), reason: entry.value);
      }
      if (entry.value != 'web') {
        expect(source, contains('pageHtml'), reason: entry.value);
      }
    }

    final windows = File('windows/plaid_omni_connect_plugin.cpp')
        .readAsStringSync();
    expect(windows, contains('AddWebResourceRequestedFilter'));
    expect(windows, contains('Navigate(document_url_.c_str())'));
    expect(windows, isNot(contains('NavigateToString')));
    expect(windows, contains('onLinkMessage'));

    final android = File(
      'android/src/main/kotlin/com/decodewest/plaid_omni_connect/PlaidOmniConnectPlugin.kt',
    ).readAsStringSync();
    expect(android, contains('loadDataWithBaseURL'));
    expect(android, contains('fun postMessage'));
    expect(android, isNot(contains('parseJson')));

    final linux = File('linux/plaid_omni_connect_plugin.cc').readAsStringSync();
    expect(linux, contains('plaidLinkHandler'));
    expect(linux, contains('script-message-received::plaidLinkHandler'));
    expect(linux, contains('webkit_web_view_load_html'));

    for (final path in [
      'ios/plaid_omni_connect/Sources/plaid_omni_connect/PlaidOmniConnectPlugin.swift',
      'macos/plaid_omni_connect/Sources/plaid_omni_connect/PlaidLinkHandler.swift',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('loadHTMLString'));
      expect(source, contains('plaidLinkHandler'));
      expect(source, contains('isTerminalLinkMessage'));
    }

    final web = File('lib/plaid_omni_connect_web.dart').readAsStringSync();
    expect(web, contains("'type': 'success'"));
    expect(web, contains("'type': 'exit'"));
    expect(web, contains("'type': 'event'"));

    final opener = File('lib/plaid_omni_connect.dart').readAsStringSync();
    expect(opener, contains('dispatchPlaidLinkMessage'));
    expect(opener, contains('plaidLinkDocumentUrl'));
  });
}

Future<void> untilCalled(bool Function() ready) async {
  final started = DateTime.now();
  while (!ready()) {
    if (DateTime.now().difference(started) > const Duration(seconds: 2)) {
      fail('timed out waiting for the Plaid callback');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

class _ScriptRun {
  _ScriptRun(this.token, this.messages);

  final String? token;
  final List<Map<String, dynamic>> messages;
}

Future<_ScriptRun> _runLinkScript(
  String linkToken,
  String host, {
  bool plaidDefined = true,
}) async {
  final script = plaidLinkInlineScript(linkToken);
  final directory = await Directory.systemTemp.createTemp('plaid_link_');
  final scriptFile = File('${directory.path}/link.js');
  await scriptFile.writeAsString(script);
  final harness = File('${directory.path}/harness.js');
  await harness.writeAsString('''
const fs = require('fs');
const vm = require('vm');
const host = process.argv[2];
const plaidDefined = process.argv[3] === '1';
const messages = [];
const window = {};
if (host === 'windows') {
  window.chrome = { webview: { postMessage(message) { messages.push(JSON.parse(message)); } } };
} else if (host === 'webkit') {
  window.webkit = { messageHandlers: { plaidLinkHandler: { postMessage(message) { messages.push(JSON.parse(message)); } } } };
} else if (host === 'android') {
  window.Android = { postMessage(message) { messages.push(JSON.parse(message)); } };
} else {
  throw new Error('unknown host ' + host);
}
const document = { querySelector() { return { style: {} }; } };
let seenToken = null;
const Plaid = {
  create(options) {
    seenToken = options.token;
    return {
      open() {
        options.onLoad();
        options.onSuccess('public-sandbox-token', {
          institution: { institution_id: 'ins_109508', name: 'First Platypus Bank' },
          accounts: [{ id: 'acc_checking', name: 'Plaid Checking', mask: '0000', type: 'depository', subtype: 'checking' }],
          link_session_id: 'session-1'
        });
        options.onEvent('OPEN', {
          view_name: 'CONSENT',
          link_session_id: 'session-1',
          institution_id: 'ins_109508',
          institution_name: 'First Platypus Bank'
        });
        options.onExit(null, {
          status: '',
          link_session_id: 'session-1',
          institution_id: 'ins_109508',
          institution_name: 'First Platypus Bank'
        });
      }
    };
  }
};
const sandbox = { window, document, console };
if (plaidDefined) sandbox.Plaid = Plaid;
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(process.argv[4], 'utf8'), sandbox);
process.stdout.write(JSON.stringify({ token: seenToken, messages }));
''');

  final node = await Process.run('node', [
    harness.path,
    host,
    plaidDefined ? '1' : '0',
    scriptFile.path,
  ]);
  if (node.exitCode != 0) {
    fail('node ${node.exitCode}\n${node.stdout}\n${node.stderr}');
  }
  final decoded = jsonDecode(node.stdout as String) as Map<String, dynamic>;
  final messages = (decoded['messages'] as List)
      .map((message) => Map<String, dynamic>.from(message as Map))
      .toList();
  await directory.delete(recursive: true);
  return _ScriptRun(decoded['token'] as String?, messages);
}
