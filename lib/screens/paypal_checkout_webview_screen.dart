// lib/screens/paypal_checkout_webview_screen.dart
// PayPal one-time checkout in a WebView – same flow as Next.js.
// All API calls (client token, create order, capture) are done from Flutter to avoid CORS in WebView.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/config/api_constants.dart';
import '../data/models/subscription_plan_model.dart';
import '../providers/api_providers.dart';
import '../widgets/loading_widget.dart';

class PayPalCheckoutWebViewScreen extends ConsumerStatefulWidget {
  final SubscriptionPlanModel plan;
  final VoidCallback? onSuccess;
  final void Function(String message)? onError;

  const PayPalCheckoutWebViewScreen({
    super.key,
    required this.plan,
    this.onSuccess,
    this.onError,
  });

  @override
  ConsumerState<PayPalCheckoutWebViewScreen> createState() =>
      _PayPalCheckoutWebViewScreenState();
}

class _PayPalCheckoutWebViewScreenState
    extends ConsumerState<PayPalCheckoutWebViewScreen> {
  WebViewController? _controller;
  bool _loading = true;
  String? _loadError;

  // No fetch() in HTML – Flutter does all API calls to avoid CORS (WebView origin is null).
  static const String _htmlContent = r'''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>PayPal Checkout</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; margin: 0; }
    #paypal-container { margin: 20px 0; min-height: 50px; }
    #status { margin-top: 16px; color: #666; }
    .error { color: #c00; }
  </style>
</head>
<body>
  <h2>Pay securely</h2>
  <p id="status">Loading...</p>
  <div id="paypal-container"></div>
  <script>
    (function() {
      var config = null;
      function setStatus(msg, isError) {
        var el = document.getElementById('status');
        if (el) { el.textContent = msg; el.className = isError ? 'error' : ''; }
      }
      function notifyFlutter(result) {
        try {
          if (window.PayPalResult && typeof window.PayPalResult.postMessage === 'function') {
            window.PayPalResult.postMessage(JSON.stringify(result));
          }
        } catch (e) { console.error(e); }
      }
      function makeCreateOrderPromise() {
        return new Promise(function(resolve, reject) {
          window.__resolveOrder = function(orderId) {
            if (orderId) resolve({ orderId: orderId }); else reject(new Error('No order ID'));
          };
          if (window.FlutterBridge && typeof window.FlutterBridge.postMessage === 'function') {
            window.FlutterBridge.postMessage(JSON.stringify({ action: 'createOrder' }));
          } else {
            setStatus('Bridge error.', true);
            reject(new Error('Bridge error'));
          }
        });
      }
      window.addEventListener('paypal-config-ready', function() {
        config = window.__PAYPAL_CONFIG__;
        if (!config || !config.clientToken) {
          setStatus('Missing configuration.', true);
          return;
        }
        var scriptUrl = (config.mode === 'sandbox')
          ? 'https://www.sandbox.paypal.com/web-sdk/v6/core'
          : 'https://www.paypal.com/web-sdk/v6/core';
        setStatus('Loading PayPal...');
        var script = document.createElement('script');
        script.src = scriptUrl;
        script.async = true;
        script.onload = function() {
          if (!window.paypal || !window.paypal.createInstance) {
            setStatus('PayPal SDK failed to load.', true);
            return;
          }
          window.paypal.createInstance({
            clientToken: config.clientToken,
            components: ['paypal-payments', 'paypal-guest-payments'],
            pageType: 'checkout'
          }).then(function(sdkInstance) {
            setStatus('Choose how to pay:');
            var container = document.getElementById('paypal-container');
            if (!container) return;
            var captureToFlutter = function(data) {
              setStatus('Completing payment...');
              if (window.FlutterBridge && typeof window.FlutterBridge.postMessage === 'function') {
                window.FlutterBridge.postMessage(JSON.stringify({ action: 'capture', orderId: data.orderId }));
              } else {
                setStatus('Bridge error.', true);
                notifyFlutter({ success: false, error: 'Bridge error' });
              }
            };
            var payPalSession = sdkInstance.createPayPalOneTimePaymentSession({
              onApprove: captureToFlutter,
              onCancel: function() { setStatus('Payment cancelled.'); notifyFlutter({ success: false, cancelled: true }); },
              onError: function(err) { var msg = (err && err.message) || 'Payment error'; setStatus(msg, true); notifyFlutter({ success: false, error: msg }); }
            });
            var guestSession = null;
            if (typeof sdkInstance.createPayPalGuestOneTimePaymentSession === 'function') {
              guestSession = sdkInstance.createPayPalGuestOneTimePaymentSession({
                onApprove: captureToFlutter,
                onCancel: function() { setStatus('Payment cancelled.'); notifyFlutter({ success: false, cancelled: true }); },
                onError: function(err) { var msg = (err && err.message) || 'Card payment error'; setStatus(msg, true); notifyFlutter({ success: false, error: msg }); }
              });
            }
            container.innerHTML = '';
            if (guestSession) {
              var cardWrapper = document.createElement('paypal-basic-card-container');
              var cardButton = document.createElement('paypal-basic-card-button');
              cardButton.id = 'paypal-guest-card-' + (config.planId || 'default') + '-' + Math.random().toString(36).slice(2, 9);
              cardButton.addEventListener('click', function(e) {
                e.preventDefault();
                if (config.disabled) return;
                setStatus('Opening card form...');
                var createOrderPromise = makeCreateOrderPromise();
                guestSession.start({ presentationMode: 'auto', targetElement: cardButton }, createOrderPromise).catch(function(err) {
                  var msg = (err && err.message) || 'Failed to create order';
                  setStatus(msg, true);
                  notifyFlutter({ success: false, error: msg });
                });
              });
              cardWrapper.appendChild(cardButton);
              container.appendChild(cardWrapper);
            }
            var btnPayPal = document.createElement('button');
            btnPayPal.type = 'button';
            btnPayPal.textContent = 'Pay with PayPal account';
            btnPayPal.style.cssText = 'width:100%;padding:12px 16px;font-size:16px;font-weight:600;background:#ffc439;color:#1a1a2e;border:1px solid #e6b84c;border-radius:8px;cursor:pointer;';
            btnPayPal.onclick = function() {
              if (config.disabled) return;
              setStatus('Redirecting to PayPal...');
              var createOrderPromise = makeCreateOrderPromise();
              payPalSession.start({ presentationMode: 'auto' }, createOrderPromise).catch(function(err) {
                var msg = (err && err.message) || 'Failed to create order';
                setStatus(msg, true);
                notifyFlutter({ success: false, error: msg });
              });
            };
            container.appendChild(btnPayPal);
          }).catch(function(err) {
            var msg = (err && err.message) || 'Failed to init PayPal';
            setStatus(msg, true);
            notifyFlutter({ success: false, error: msg });
          });
        };
        script.onerror = function() {
          setStatus('PayPal script failed to load.', true);
          notifyFlutter({ success: false, error: 'Script load failed' });
        };
        document.body.appendChild(script);
      });
    })();
  </script>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final service = ref.read(subscriptionServiceProvider);

    // Fetch client token from Flutter (no CORS – native HTTP)
    final tokenResult = await service.getPayPalClientToken();
    if (!mounted) return;
    tokenResult.when(
      success: (clientToken) {
        _buildWebView(clientToken);
      },
      failure: (message) {
        setState(() {
          _loading = false;
          _loadError = message;
        });
      },
    );
  }

  Future<void> _buildWebView(String clientToken) async {
    String mode = 'sandbox';
    final configResult = await ref.read(subscriptionServiceProvider).getPayPalConfig();
    configResult.when(
      success: (data) {
        if (data['mode'] != null) mode = data['mode'].toString();
      },
      failure: (_) {},
    );

    final config = {
      'clientToken': clientToken,
      'planId': widget.plan.id,
      'amount': widget.plan.price,
      'currency': 'USD',
      'description': widget.plan.name,
      'mode': mode,
      'disabled': false,
    };

    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _onBridgeMessage(message.message);
        },
      )
      ..addJavaScriptChannel(
        'PayPalResult',
        onMessageReceived: (JavaScriptMessage message) {
          _onPayPalResult(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (!mounted) return;
            final configJson = jsonEncode(config);
            _controller?.runJavaScript(
              "window.__PAYPAL_CONFIG__ = $configJson; window.dispatchEvent(new Event('paypal-config-ready'));",
            );
            setState(() => _loading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _loadError = error.description;
              });
            }
          },
        ),
      )
      ..loadHtmlString(
        _htmlContent,
        baseUrl: '${Uri.parse(ApiConstants.baseUrl).origin}/',
      );

    setState(() => _controller = ctrl);
  }

  Future<void> _onBridgeMessage(String message) async {
    try {
      final map = jsonDecode(message) as Map<String, dynamic>;
      final action = map['action']?.toString();

      if (action == 'createOrder') {
        final service = ref.read(subscriptionServiceProvider);
        final result = await service.createPayPalOrder(
          amount: widget.plan.price,
          currency: 'USD',
          planId: widget.plan.id,
          description: widget.plan.name,
        );
        if (!mounted) return;
        result.when(
          success: (orderId) {
            final escaped = jsonEncode(orderId);
            _controller?.runJavaScript(
              "if(window.__resolveOrder) window.__resolveOrder($escaped);",
            );
          },
          failure: (msg) {
            _controller?.runJavaScript(
              "if(window.__resolveOrder) window.__resolveOrder(null);",
            );
            _controller?.runJavaScript(
              "if(window.PayPalResult) window.PayPalResult.postMessage(JSON.stringify({ success: false, error: ${jsonEncode(msg)} }));",
            );
          },
        );
        return;
      }

      if (action == 'capture') {
        final orderId = map['orderId']?.toString();
        if (orderId == null || orderId.isEmpty) {
          widget.onError?.call('Invalid order');
          if (mounted) Navigator.of(context).pop(false);
          return;
        }
        final service = ref.read(subscriptionServiceProvider);
        final result = await service.capturePayPalOrder(
          orderId: orderId,
          planId: widget.plan.id,
        );
        if (!mounted) return;
        result.when(
          success: (_) {
            widget.onSuccess?.call();
            Navigator.of(context).pop(true);
          },
          failure: (msg) {
            widget.onError?.call(msg);
            Navigator.of(context).pop(false);
          },
        );
      }
    } catch (e) {
      widget.onError?.call('Error: $e');
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  void _onPayPalResult(String message) {
    try {
      final map = jsonDecode(message) as Map<String, dynamic>;
      final success = map['success'] == true;
      if (success) {
        widget.onSuccess?.call();
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final cancelled = map['cancelled'] == true;
        final error = map['error']?.toString() ?? 'Payment failed';
        if (cancelled) {
          if (mounted) Navigator.of(context).pop(false);
        } else {
          widget.onError?.call(error);
          if (mounted) Navigator.of(context).pop(false);
        }
      }
    } catch (_) {
      widget.onError?.call('Invalid response');
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('PayPal Checkout')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement sécurisé'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.green.shade50,
            child: Row(
              children: [
                Icon(Icons.verified_user_rounded,
                    size: 22, color: Colors.green.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vos données sont sauvegardées. L\'accès à votre cabinet sera restauré dès la validation du paiement.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (_controller != null)
                  WebViewWidget(controller: _controller!),
                if (_loading)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LoadingWidget(),
                        SizedBox(height: 16),
                        Text('Chargement du paiement...'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
