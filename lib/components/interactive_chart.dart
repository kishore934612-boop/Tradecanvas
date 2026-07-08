import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/constants/markets.dart';
import 'package:app/constants/colors.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:app/core/logging/logger.dart';

class InteractiveChart extends StatefulWidget {
  final Asset asset;
  final double currentPrice;
  final bool fullscreen;
  final double? height;

  const InteractiveChart({
    super.key,
    required this.asset,
    required this.currentPrice,
    this.fullscreen = false,
    this.height,
  });

  @override
  State<InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<InteractiveChart> {
  String _activeTab = '1h';
  bool _isCandleMode = true;
  bool _showMA = false;
  late final WebViewController _webViewController;
  bool _isWebViewInitialized = false;

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0E11))
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            Logger.instance.error('WebView error: ${error.description}');
          },
        ),
      );
    _isWebViewInitialized = true;
    _updateChart();
  }

  String _mapTradingViewSymbol(String localSymbol) {
    switch (localSymbol) {
      case 'BTC': return 'BINANCE:BTCUSDT';
      case 'ETH': return 'BINANCE:ETHUSDT';
      case 'SOL': return 'BINANCE:SOLUSDT';
      case 'BNB': return 'BINANCE:BNBUSDT';
      case 'XRP': return 'BINANCE:XRPUSDT';
      case 'DOGE': return 'BINANCE:DOGEUSDT';
      case 'ADA': return 'BINANCE:ADAUSDT';
      case 'AVAX': return 'BINANCE:AVAXUSDT';
      case 'AAPL': return 'NASDAQ:AAPL';
      case 'MSFT': return 'NASDAQ:MSFT';
      case 'GOOGL': return 'NASDAQ:GOOGL';
      case 'NVDA': return 'NASDAQ:NVDA';
      case 'META': return 'NASDAQ:META';
      case 'TSLA': return 'NASDAQ:TSLA';
      case 'AMZN': return 'NASDAQ:AMZN';
      case 'NFLX': return 'NASDAQ:NFLX';
      case 'RELIANCE': return 'NSE:RELIANCE';
      case 'TCS': return 'NSE:TCS';
      case 'INFY': return 'NSE:INFY';
      case 'HDFCBANK': return 'NSE:HDFCBANK';
      case 'ICICIBANK': return 'NSE:ICICIBANK';
      case 'TATAMOTORS': return 'NSE:TATAMOTORS';
      case 'EUR/USD': return 'FX_IDC:EURUSD';
      case 'GBP/USD': return 'FX_IDC:GBPUSD';
      case 'USD/JPY': return 'FX_IDC:USDJPY';
      case 'USD/CHF': return 'FX_IDC:USDCHF';
      case 'AUD/USD': return 'FX_IDC:AUDUSD';
      case 'USD/CAD': return 'FX_IDC:USDCAD';
      case 'XAU': return 'OANDA:XAUUSD';
      case 'XAG': return 'OANDA:XAGUSD';
      case 'WTI': return 'TVC:USOIL';
      case 'NG': return 'TVC:NG1!';
      case 'NIFTY50': return 'NSE:NIFTY';
      case 'SPX': return 'SP:SPX';
      case 'NDX': return 'NASDAQ:NDX';
      case 'DJI': return 'DJ:DJI';
      default: return 'BINANCE:${localSymbol}USDT';
    }
  }

  String _mapInterval(String localTab) {
    switch (localTab) {
      case '1m': return '1';
      case '5m': return '5';
      case '15m': return '15';
      case '1h': return '60';
      case '4h': return '240';
      case '1D': return 'D';
      case '1W': return 'W';
      case '1M': return 'M';
      default: return '60';
    }
  }

  void _updateChart() {
    if (!_isWebViewInitialized) return;
    final tvSymbol = _mapTradingViewSymbol(widget.asset.symbol);
    final tvInterval = _mapInterval(_activeTab);
    final tvStyle = _isCandleMode ? "1" : "2"; // "1" for Candlesticks, "2" for Line
    final tvStudies = _showMA ? '["MASimple@tv-basicstudies"]' : '[]';
    final hideSideToolbar = !widget.fullscreen;

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background-color: #0b0e11;
      overflow: hidden;
    }
    #tradingview_widget {
      width: 100%;
      height: 100%;
    }
  </style>
</head>
<body>
  <div id="tradingview_widget"></div>
  <script type="text/javascript" src="https://s3.tradingview.com/tv.js"></script>
  <script type="text/javascript">
    new TradingView.widget({
      "autosize": true,
      "symbol": "$tvSymbol",
      "interval": "$tvInterval",
      "timezone": "Etc/UTC",
      "theme": "dark",
      "style": "$tvStyle",
      "locale": "en",
      "enable_publishing": false,
      "hide_side_toolbar": $hideSideToolbar,
      "allow_symbol_change": false,
      "container_id": "tradingview_widget",
      "studies": $tvStudies,
      "show_popup_button": false,
      "withdateranges": false,
      "save_image": false,
      "hide_legend": false,
      "calendar": false
    });
  </script>
</body>
</html>
''';
    _webViewController.loadHtmlString(html);
  }

  @override
  void didUpdateWidget(covariant InteractiveChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.symbol != widget.asset.symbol || oldWidget.currentPrice != widget.currentPrice) {
      _updateChart();
    }
  }

  void _openFullscreen() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenChart(asset: widget.asset, currentPrice: widget.currentPrice),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isPositive = widget.currentPrice >= widget.asset.basePrice;
    final Color chartColor = isPositive ? colors.positive : colors.negative;
    final tabs = ['1m', '5m', '15m', '1h', '4h', '1D', '1W', '1M'];

    final chartHeight = widget.height
        ?? (widget.fullscreen ? MediaQuery.of(context).size.height * 0.52 : 220.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: tabs.map((t) {
                final active = _activeTab == t;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _activeTab = t;
                    });
                    _updateChart();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.0),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: active ? colors.positive : Colors.transparent,
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(
                        color: active ? Colors.transparent : colors.border,
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: active ? Colors.white : colors.mutedForeground,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            Row(
              children: [
                _toolBtn(
                  icon: Icons.timeline_rounded,
                  active: _showMA,
                  color: colors.accent,
                  tooltip: 'Moving Average',
                  onTap: () {
                    setState(() => _showMA = !_showMA);
                    _updateChart();
                  },
                ),
                const SizedBox(width: 4.0),
                _toolBtn(
                  icon: _isCandleMode ? Icons.candlestick_chart_rounded : Icons.show_chart_rounded,
                  active: true,
                  color: chartColor,
                  tooltip: _isCandleMode ? 'Line chart' : 'Candles',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _isCandleMode = !_isCandleMode);
                    _updateChart();
                  },
                ),
                if (!widget.fullscreen) ...[
                  const SizedBox(width: 4.0),
                  _toolBtn(
                    icon: Icons.open_in_full_rounded,
                    active: false,
                    color: colors.mutedForeground,
                    tooltip: 'Fullscreen',
                    onTap: _openFullscreen,
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 10.0),
        ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            height: chartHeight,
            width: double.infinity,
            color: const Color(0xFF0B0E11),
            child: WebViewWidget(controller: _webViewController),
          ),
        ),
      ],
    );
  }

  Widget _toolBtn({required IconData icon, required bool active, required Color color, required String tooltip, required VoidCallback onTap}) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.14) : colors.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(icon, color: active ? color : colors.mutedForeground, size: 20.0),
        ),
      ),
    );
  }
}

class _FullscreenChart extends StatefulWidget {
  final Asset asset;
  final double currentPrice;
  const _FullscreenChart({required this.asset, required this.currentPrice});

  @override
  State<_FullscreenChart> createState() => _FullscreenChartState();
}

class _FullscreenChartState extends State<_FullscreenChart> {
  bool _drawMode = false;
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        title: Text(
          '${widget.asset.symbol} · ${widget.asset.name}',
          style: TextStyle(color: colors.foreground, fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: colors.foreground),
        actions: [
          IconButton(
            tooltip: _drawMode ? 'Disable drawing' : 'Draw trendlines',
            icon: Icon(Icons.edit_rounded, color: _drawMode ? colors.primary : colors.mutedForeground),
            onPressed: () => setState(() => _drawMode = !_drawMode),
          ),
          IconButton(
            tooltip: 'Clear drawings',
            icon: Icon(Icons.layers_clear_rounded, color: colors.mutedForeground),
            onPressed: () => setState(() {
              _strokes.clear();
              _current = [];
            }),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: InteractiveChart(asset: widget.asset, currentPrice: widget.currentPrice, fullscreen: true),
          ),
          if (_drawMode)
            Positioned.fill(
              child: GestureDetector(
                onPanStart: (d) => setState(() => _current = [d.localPosition]),
                onPanUpdate: (d) => setState(() => _current = [..._current, d.localPosition]),
                onPanEnd: (_) => setState(() {
                  if (_current.length > 1) _strokes.add(_current);
                  _current = [];
                }),
                child: CustomPaint(
                  painter: _DrawingPainter([..._strokes, _current], colors.accent),
                  size: Size.infinite,
                ),
              ),
            )
          else if (_strokes.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _DrawingPainter(_strokes, colors.accent), size: Size.infinite),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  _DrawingPainter(this.strokes, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter old) => old.strokes != strokes;
}
