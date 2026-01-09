# plaid_omni_connect

Plaid Omni Connect Link integration for Flutter with seamless inline UX across **all platforms**: iOS, Android, Web, macOS, Windows, and Linux.

[![pub package](https://img.shields.io/pub/v/plaid_omni_connect.svg)](https://pub.dev/packages/plaid_omni_connect)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ✨ Features

- 🎯 **Seamless inline modal UX** - Never leaves your app
- 📱 **Universal platform support** - iOS, Android, Web, macOS, Windows, Linux
- 🔒 **Secure by design** - No tokens stored in package
- 🎨 **Native look and feel** - Platform-specific modal implementations
- 🚀 **Easy to integrate** - Simple, consistent API
- ⚡ **Production ready** - Based on Plaid's official Link SDK

## 🏗️ Architecture & Security

This package handles the **client-side** UI integration of Plaid Link. In a production environment, it works in tandem with your backend server:

1.  **Server**: Calls Plaid API (`/link/token/create`) to generate a `link_token`.
2.  **App**: Fetches `link_token` from your server and passes it to `PlaidOmniConnect.open()`.
3.  **App**: User completes the flow; plugin returns a `public_token`.
4.  **App**: Sends `public_token` back to your server.
5.  **Server**: Exchanges `public_token` for an `access_token` (`/item/public_token/exchange`) to fetch data.

> 🔒 **Security Note**: Never store your Plaid `client_id` or `secret` inside your Flutter app or this package. All sensitive API calls must happen on your backend.

## 🚀 Getting Started

### Installation

Add to your `pubspec.yaml`:
```yaml
dependencies:
  plaid_omni_connect: ^1.0.0
```

Run:
```bash
flutter pub get
```

### Platform Setup

#### iOS & Android
No additional setup required! ✅

#### macOS
No additional setup required! ✅
**Note**: Ensure your app has `com.apple.security.network.client` entitlement.

#### Windows
Requires WebView2 runtime (pre-installed on Windows 11).

For Windows 10, download: [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/)

#### Linux
Install WebKitGTK:

**Ubuntu/Debian:**
```bash
sudo apt-get install libwebkit2gtk-4.0-dev
```

**Fedora:**
```bash
sudo dnf install webkit2gtk3-devel
```

**Arch:**
```bash
sudo pacman -S webkit2gtk
```

#### Web
No additional setup required! ✅

### Usage
```dart
import 'package:plaid_omni_connect/plaid_omni_connect.dart';

// 1. Get link token from your backend
final linkToken = await getPlaidLinkToken();

// 2. Open Plaid Link with inline modal
await PlaidOmniConnect.open(
  configuration: PlaidLinkConfiguration(
    linkToken: linkToken,
  ),
  onSuccess: (publicToken, metadata) {
    print('✅ Connected: ${metadata.institution.name}');
    print('Accounts: ${metadata.accounts.length}');
    
    // Send publicToken to your backend to exchange for access_token
    await exchangePublicToken(publicToken);
  },
  onExit: (error, metadata) {
    if (error != null) {
      print('❌ Error: ${error.displayMessage}');
    } else {
      print('User cancelled');
    }
  },
  onEvent: (eventName, metadata) {
    print('📊 Event: $eventName');
  },
);
```

## 📖 API Reference

### PlaidOmniConnect.open()

Opens Plaid Link as an inline modal within your app.

**Parameters:**
- `configuration` (required): PlaidLinkConfiguration with your link token
- `onSuccess` (required): Callback when user successfully connects account
- `onExit` (required): Callback when user exits or encounters error
- `onEvent` (optional): Callback for tracking user events

### PlaidLinkConfiguration
```dart
PlaidLinkConfiguration({
  required String linkToken,  // From your backend
  bool noLoadingState = false,
})
```

### Callbacks

**onSuccess:**
```dart
void Function(String publicToken, LinkSuccessMetadata metadata)
```

**onExit:**
```dart
void Function(LinkError? error, LinkExitMetadata? metadata)
```

**onEvent:**
```dart
void Function(String eventName, LinkEventMetadata metadata)
```

## 🎨 UX Behavior

### Desktop (macOS, Windows, Linux)
- **Modal dialog** (600x800px) centered in your app window
- **Blocks parent window** - true modal behavior
- **Smooth animations** - 300ms fade in/out
- **Native styling** - Follows platform design guidelines

### Mobile (iOS, Android)
- **Full-screen modal** with native transitions
- **Gesture support** - Swipe to dismiss

### Web
- **Centered modal** with backdrop blur
- **Responsive** - Adapts to screen size
- **Keyboard accessible** - ESC to close

## 📚 Complete Example

See the [example](https://github.com/decodewest/plaid_omni_connect/tree/main/example) directory for a full working demo app.

## 📄 License

MIT License - see [LICENSE](LICENSE) file

Copyright (c) 2025 DecodeWest
