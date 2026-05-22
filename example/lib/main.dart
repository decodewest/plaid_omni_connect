import 'package:flutter/material.dart';
import 'package:plaid_omni_connect/plaid_omni_connect.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plaid Omni Connect Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final TextEditingController _linkTokenController = TextEditingController(
    text: 'link-sandbox-YOUR-GENERATED-TOKEN', // Replace with valid token
  );
  String _status = 'Ready to connect';
  final List<String> _connectedAccounts = [];
  bool _isLoading = false;

  Future<void> _connectAccount() async {
    setState(() {
      _isLoading = true;
      _status = 'Opening Plaid Link...';
    });

    // Link tokens expire after 4 hours.
    // For testing, generate one via Plaid Dashboard or API and paste it here/in the UI.
    final linkToken = _linkTokenController.text.trim();

    if (linkToken.isEmpty) {
       setState(() {
         _status = 'Please enter a valid Link Token';
         _isLoading = false;
       });
       return;
    }

    try {
      await PlaidOmniConnect.open(
        configuration: PlaidLinkConfiguration(
          linkToken: linkToken,
        ),
        onSuccess: (publicToken, metadata) {
          setState(() {
            _status = 'Successfully connected!';
            _connectedAccounts.add(
              '${metadata.institution.name} (${metadata.accounts.length} accounts)',
            );
            _isLoading = false;
          });

          // In production: send publicToken to your backend to exchange for access_token
          debugPrint('Public Token: ${publicToken.substring(0, 20)}...');
          debugPrint('Institution: ${metadata.institution.name}');
          debugPrint('Accounts: ${metadata.accounts.length}');
          
          _showSuccessDialog(metadata);
        },
        onExit: (error, metadata) {
          setState(() {
            if (error != null) {
              _status = 'Error: ${error.displayMessage}';
            } else {
              _status = 'User cancelled';
            }
            _isLoading = false;
          });
        },
        onEvent: (eventName, metadata) {
          debugPrint('Plaid Event: $eventName');
        },
      );
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(LinkSuccessMetadata metadata) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Account Connected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Institution: ${metadata.institution.name}'),
            const SizedBox(height: 8),
            const Text('Connected Accounts:'),
            ...metadata.accounts.map(
              (account) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• ${account.name} (${account.type})'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plaid Omni Connect'),
        elevation: 2,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              Text(
                _status,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                child: TextField(
                  controller: _linkTokenController,
                  decoration: const InputDecoration(
                    labelText: 'Plaid Link Token',
                    hintText: 'Paste link-sandbox-... here',
                    border: OutlineInputBorder(),
                    helperText: 'Generate via Plaid Dashboard or API',
                  ),
                ),
              ),
              if (_connectedAccounts.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Connected Accounts:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ..._connectedAccounts.map(
                  (account) => Chip(
                    label: Text(account),
                    avatar: const Icon(Icons.check_circle, size: 18),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _connectAccount,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_link),
                label: Text(
                  _connectedAccounts.isEmpty
                      ? 'Connect Bank Account'
                      : 'Connect Another Account',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: Seamless inline modal experience\nNever leaves your app!',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
