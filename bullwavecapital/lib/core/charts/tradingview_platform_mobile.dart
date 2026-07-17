import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'tradingview_charting_library_placeholder.dart';
import 'tradingview_config.dart';
import 'tradingview_embed_url.dart';

class TradingViewPlatformChart extends StatefulWidget {
  final String tvSymbol;
  final String interval;
  final double height;
  final String theme;

  const TradingViewPlatformChart({
    super.key,
    required this.tvSymbol,
    required this.interval,
    required this.height,
    this.theme = 'dark',
  });

  @override
  State<TradingViewPlatformChart> createState() => _TradingViewPlatformChartState();
}

class _TradingViewPlatformChartState extends State<TradingViewPlatformChart> {
  WebViewController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant TradingViewPlatformChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tvSymbol != widget.tvSymbol ||
        oldWidget.interval != widget.interval ||
        oldWidget.theme != widget.theme) {
      _loadChart();
    }
  }

  void _initController() {
    if (TradingViewConfig.usesChartingLibrary) return;

    final url = TradingViewEmbedUrl.build(
      symbol: widget.tvSymbol,
      interval: widget.interval,
      theme: widget.theme,
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.theme == 'light' ? const Color(0xFFF4F4F0) : const Color(0xFF050503))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _ready = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {});
  }

  void _loadChart() {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _ready = false);
    final url = TradingViewEmbedUrl.build(
      symbol: widget.tvSymbol,
      interval: widget.interval,
      theme: widget.theme,
    );
    controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    if (TradingViewConfig.usesChartingLibrary) {
      return TradingViewChartingLibraryPlaceholder(height: widget.height);
    }

    final controller = _controller;
    if (controller == null) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: WebViewWidget(controller: controller),
          ),
          if (!_ready)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.2),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
