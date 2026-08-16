/// Globally configurable currency symbol, set from the user's profile during
/// onboarding (e.g. '\$').
String appCurrency = '\$';

void setAppCurrency(String symbol) {
  appCurrency = symbol;
}

String _withCommas(double value, int decimals) {
  final isNegative = value < 0;
  final absValue = value.abs();
  final parts = absValue.toStringAsFixed(decimals);
  final split = parts.split('.');
  final whole = split[0];
  final fraction = split.length > 1 ? '.${split[1]}' : '';

  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  final result = whole.replaceAllMapped(reg, (Match m) => '${m[1]},');
  return '${isNegative ? '-' : ''}$result$fraction';
}

String formatCurrency(double value) {
  final double absVal = value.abs();
  final String sign = value < 0 ? '-' : '';
  if (absVal >= 10000000) {
    return '$sign$appCurrency${(absVal / 10000000).toStringAsFixed(2)}Cr';
  }
  if (absVal >= 1000000) {
    return '$sign$appCurrency${(absVal / 1000000).toStringAsFixed(2)}M';
  }
  if (absVal >= 1000) {
    return '$sign$appCurrency${_withCommas(absVal, 2)}';
  }
  return '$sign$appCurrency${absVal.toStringAsFixed(2)}';
}

String formatCurrencyExact(double value) {
  final String sign = value < 0 ? '-' : '';
  return '$sign$appCurrency${_withCommas(value.abs(), 2)}';
}

String formatPct(double value) {
  return '${value.toStringAsFixed(2)}%';
}

String formatSignedPct(double value) {
  return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%';
}

String formatQty(double qty) {
  if (qty >= 1000) return _withCommas(qty, 2);
  if (qty >= 1) return qty.toStringAsFixed(4);
  return qty.toStringAsFixed(6);
}

String formatDate(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';

  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}';
}

/// Formats a duration given in milliseconds into a compact human string.
String formatDuration(int millis) {
  if (millis <= 0) return '—';
  final d = Duration(milliseconds: millis);
  if (d.inDays >= 1) {
    return '${d.inDays}d ${d.inHours % 24}h';
  }
  if (d.inHours >= 1) {
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }
  if (d.inMinutes >= 1) {
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
  return '${d.inSeconds}s';
}

String dayKey(int timestamp) {
  final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String? getAssetLogoUrl(String symbol) {
  final lower = symbol.toLowerCase();
  if (lower == 'btc' || lower == 'eth' || lower == 'sol' || lower == 'bnb' || lower == 'xrp' || lower == 'doge' || lower == 'ada' || lower == 'avax') {
    return 'https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/$lower.png';
  }
  
  // US Stocks
  if (lower == 'aapl') return 'https://logo.clearbit.com/apple.com';
  if (lower == 'msft') return 'https://logo.clearbit.com/microsoft.com';
  if (lower == 'googl') return 'https://logo.clearbit.com/google.com';
  if (lower == 'nvda') return 'https://logo.clearbit.com/nvidia.com';
  if (lower == 'meta') return 'https://logo.clearbit.com/meta.com';
  if (lower == 'tsla') return 'https://logo.clearbit.com/tesla.com';
  if (lower == 'amzn') return 'https://logo.clearbit.com/amazon.com';
  if (lower == 'nflx') return 'https://logo.clearbit.com/netflix.com';
  
  // Indian Stocks
  if (lower == 'reliance') return 'https://logo.clearbit.com/ril.com';
  if (lower == 'tcs') return 'https://logo.clearbit.com/tcs.com';
  if (lower == 'infy') return 'https://logo.clearbit.com/infosys.com';
  if (lower == 'hdfcbank') return 'https://logo.clearbit.com/hdfcbank.com';
  if (lower == 'icicibank') return 'https://logo.clearbit.com/icicibank.com';
  if (lower == 'tatamotors') return 'https://logo.clearbit.com/tatamotors.com';
  
  // Forex
  if (lower == 'eur/usd' || lower == 'eurusd') return 'https://logo.clearbit.com/europa.eu';
  if (lower == 'gbp/usd' || lower == 'gbpusd') return 'https://logo.clearbit.com/gov.uk';
  if (lower == 'usd/jpy' || lower == 'usdjpy') return 'https://logo.clearbit.com/japan.go.jp';
  if (lower == 'usd/chf' || lower == 'usdchf') return 'https://logo.clearbit.com/admin.ch';
  if (lower == 'aud/usd' || lower == 'audusd') return 'https://logo.clearbit.com/australia.gov.au';
  if (lower == 'usd/cad' || lower == 'usdcad') return 'https://logo.clearbit.com/canada.ca';

  return null;
}

