import 'dart:convert';

/// Document URL the Windows host navigates to. The host serves [buildPlaidLinkPage]
/// for this URL so Link's origin is https://cdn.plaid.com, matching the other platforms.
const String plaidLinkDocumentUrl =
    'https://cdn.plaid.com/plaid-omni-connect/link.html';

const String plaidLinkScriptUrl =
    'https://cdn.plaid.com/link/v2/stable/link-initialize.js';

/// Base origin passed to iOS, Android, macOS, and Linux web views.
const String plaidLinkBaseUrl = 'https://cdn.plaid.com';

String _jsonForScript(Object value) {
  return jsonEncode(value)
      .replaceAll('<', r'\u003c')
      .replaceAll('>', r'\u003e')
      .replaceAll('&', r'\u0026');
}

/// Inline script that opens Link and posts one JSON object per callback.
///
/// Windows receives the object through `chrome.webview.postMessage` after
/// `JSON.stringify`, so every host sees the same text. WebKit and Android
/// receive that text as a string.
String plaidLinkInlineScript(String linkToken) {
  final tokenLiteral = _jsonForScript(linkToken);
  return '''
function postToHost(message) {
  const json = JSON.stringify(message);
  if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
    window.chrome.webview.postMessage(json);
    return;
  }
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plaidLinkHandler) {
    window.webkit.messageHandlers.plaidLinkHandler.postMessage(json);
    return;
  }
  if (window.Android && window.Android.postMessage) {
    window.Android.postMessage(json);
  }
}
try {
  const handler = Plaid.create({
    token: $tokenLiteral,
    onSuccess: (publicToken, metadata) => {
      postToHost({ type: 'success', publicToken: publicToken, metadata: metadata });
    },
    onExit: (err, metadata) => {
      postToHost({ type: 'exit', error: err, metadata: metadata });
    },
    onEvent: (eventName, metadata) => {
      postToHost({ type: 'event', eventName: eventName, metadata: metadata });
    },
    onLoad: () => {
      const loading = document.querySelector('.loading');
      if (loading) loading.style.display = 'none';
    }
  });
  handler.open();
} catch (error) {
  postToHost({ type: 'error', error: String(error && error.message ? error.message : error) });
}
''';
}

String buildPlaidLinkPage(String linkToken) {
  final script = plaidLinkInlineScript(linkToken);
  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script src="$plaidLinkScriptUrl"></script>
  <style>
    html, body { margin: 0; background: #fff; color: #111; font-family: sans-serif; overflow: hidden; }
    #container { width: 100%; height: 100vh; }
    .loading { display: flex; align-items: center; justify-content: center; height: 100vh; }
  </style>
</head>
<body>
  <div id="container"><div class="loading">Loading...</div></div>
  <script>
$script
  </script>
</body>
</html>
''';
}
