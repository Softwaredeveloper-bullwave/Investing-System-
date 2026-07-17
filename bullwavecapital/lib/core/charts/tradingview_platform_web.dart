// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

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
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didUpdateWidget(covariant TradingViewPlatformChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tvSymbol != widget.tvSymbol ||
        oldWidget.interval != widget.interval ||
        oldWidget.theme != widget.theme) {
      _registerView();
    }
  }

  void _registerView() {
    _viewType = 'tradingview-${widget.tvSymbol}-${widget.interval}-${widget.theme}-${DateTime.now().microsecondsSinceEpoch}';
    final url = TradingViewEmbedUrl.build(
      symbol: widget.tvSymbol,
      interval: widget.interval,
      theme: widget.theme,
    );

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..setAttribute('allow', 'fullscreen');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (TradingViewConfig.usesChartingLibrary) {
      return TradingViewChartingLibraryPlaceholder(height: widget.height);
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
