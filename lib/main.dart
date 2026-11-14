import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const Octo21App());
}

class Octo21App extends StatelessWidget {
  const Octo21App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Octo21',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const Octo21Home(),
    );
  }
}

class Octo21Home extends StatefulWidget {
  const Octo21Home({super.key});

  @override
  State<Octo21Home> createState() => _Octo21HomeState();
}

class _Octo21HomeState extends State<Octo21Home> {
  late final WebViewController _ctrl;
  final TextEditingController _urlCtrl = TextEditingController();
  bool _loading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;

  // 10.0.2.2 = Android emulator-এর host machine (localhost)
  static const _home = 'https://octo21.onrender.com';

  static String get _userAgent {
    if (Platform.isAndroid) {
      return 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
    } else if (Platform.isMacOS) {
      return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
    } else if (Platform.isWindows) {
      return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
    } else if (Platform.isIOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';
    }
    return 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  }

  static const _knownDomains = [
    'youtube.com', 'instagram.com', 'google.com', 'facebook.com',
    'twitter.com', 'x.com', 'whatsapp.com', 'gmail.com',
    'amazon.in', 'amazon.com', 'flipkart.com', 'github.com',
    'wikipedia.org', 'reddit.com', 'netflix.com', 'linkedin.com',
    'snapchat.com', 'telegram.org', 'octo21.onrender.com',
  ];

  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final d = List.generate(
      a.length + 1, (i) => List.filled(b.length + 1, 0));
    for (int i = 0; i <= a.length; i++) d[i][0] = i;
    for (int j = 0; j <= b.length; j++) d[0][j] = j;
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        d[i][j] = [d[i-1][j]+1, d[i][j-1]+1, d[i-1][j-1]+cost]
            .reduce((x, y) => x < y ? x : y);
      }
    }
    return d[a.length][b.length];
  }

  static String _correctDomain(String typed) {
    final raw = typed.replaceFirst(RegExp(r'^https?://'), '').split('/').first.toLowerCase();
    final typedBase = raw.split('.').first;
    if (typedBase.length < 3) return typed;
    String? best;
    int bestDist = 3;
    for (final known in _knownDomains) {
      final knownBase = known.split('.').first;
      final dist = _editDistance(typedBase, knownBase);
      if (dist > 0 && dist < bestDist) {
        bestDist = dist;
        best = known;
      }
    }
    return best ?? typed;
  }

  String _resolveInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return _home;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (!trimmed.contains(' ') && trimmed.contains('.')) {
      final corrected = _correctDomain(trimmed);
      return 'https://$corrected';
    }
    return '$_home/?q=${Uri.encodeComponent(trimmed)}';
  }

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = _home;
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_userAgent)
      ..setBackgroundColor(const Color(0xFF05040C))
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.parse(request.url);
          if (uri.host.contains('accounts.google.com') ||
              uri.host.contains('oauth2.googleapis.com') ||
              (uri.host.contains('google.com') &&
                  uri.path.contains('/o/oauth2'))) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageStarted: (url) {
          setState(() {
            _loading = true;
            _urlCtrl.text = url;
          });
          _updateNavState();
        },
        onPageFinished: (url) {
          setState(() => _loading = false);
          _updateNavState();
        },
        onWebResourceError: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(_home));
  }

  Future<void> _updateNavState() async {
    final back = await _ctrl.canGoBack();
    final forward = await _ctrl.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    }
  }

  void _navigate(String input) {
    final url = _resolveInput(input);
    _ctrl.loadRequest(Uri.parse(url));
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _ctrl.canGoBack()) {
          await _ctrl.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF05040C),
        body: SafeArea(
          child: Column(
            children: [
              _AddressBar(
                controller: _urlCtrl,
                loading: _loading,
                canGoBack: _canGoBack,
                canGoForward: _canGoForward,
                onNavigate: _navigate,
                onBack: () => _ctrl.goBack(),
                onForward: () => _ctrl.goForward(),
                onRefresh: () => _ctrl.reload(),
                onHome: () => _ctrl.loadRequest(Uri.parse(_home)),
              ),
              Expanded(child: WebViewWidget(controller: _ctrl)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressBar extends StatelessWidget {
  const _AddressBar({
    required this.controller,
    required this.loading,
    required this.canGoBack,
    required this.canGoForward,
    required this.onNavigate,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onHome,
  });

  final TextEditingController controller;
  final bool loading;
  final bool canGoBack;
  final bool canGoForward;
  final ValueChanged<String> onNavigate;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh;
  final VoidCallback onHome;

  static const _cyan = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D1A),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: canGoBack ? onBack : null,
            color: _cyan,
            disabledColor: Colors.white24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: canGoForward ? onForward : null,
            color: _cyan,
            disabledColor: Colors.white24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onNavigate,
              textInputAction: TextInputAction.go,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                hintText: 'Search or enter URL',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: loading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _cyan,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh,
                            size: 18, color: Colors.white38),
                        onPressed: onRefresh,
                        padding: EdgeInsets.zero,
                      ),
              ),
              onTap: () => controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined, size: 20),
            color: _cyan,
            onPressed: onHome,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
