enum Experience { beginner, intermediate, advanced }

enum TradingStyle { scalping, dayTrading, swingTrading, positionTrading }

extension ExperienceX on Experience {
  String get label {
    switch (this) {
      case Experience.beginner:
        return 'Beginner';
      case Experience.intermediate:
        return 'Intermediate';
      case Experience.advanced:
        return 'Advanced';
    }
  }
}

extension TradingStyleX on TradingStyle {
  String get label {
    switch (this) {
      case TradingStyle.scalping:
        return 'Scalping';
      case TradingStyle.dayTrading:
        return 'Day Trading';
      case TradingStyle.swingTrading:
        return 'Swing Trading';
      case TradingStyle.positionTrading:
        return 'Position Trading';
    }
  }
}

class UserProfile {
  bool onboarded;
  Experience experience;
  Set<String> markets; // MarketType ids the user is interested in
  TradingStyle style;
  double startingCapital;
  String currencySymbol;
  bool hapticsEnabled;
  bool journalPromptsEnabled;

  UserProfile({
    this.onboarded = false,
    this.experience = Experience.beginner,
    Set<String>? markets,
    this.style = TradingStyle.dayTrading,
    this.startingCapital = 100000.0,
    this.currencySymbol = '\$',
    this.hapticsEnabled = true,
    this.journalPromptsEnabled = true,
  }) : markets = markets ?? {'crypto'};

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'experience': experience.index,
        'markets': markets.toList(),
        'style': style.index,
        'startingCapital': startingCapital,
        'currencySymbol': currencySymbol,
        'hapticsEnabled': hapticsEnabled,
        'journalPromptsEnabled': journalPromptsEnabled,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        onboarded: j['onboarded'] ?? false,
        experience: Experience.values[(j['experience'] ?? 0) as int],
        markets: Set<String>.from(j['markets'] ?? ['crypto']),
        style: TradingStyle.values[(j['style'] ?? 1) as int],
        startingCapital: (j['startingCapital'] as num?)?.toDouble() ?? 100000.0,
        currencySymbol: j['currencySymbol'] ?? '\$',
        hapticsEnabled: j['hapticsEnabled'] ?? true,
        journalPromptsEnabled: j['journalPromptsEnabled'] ?? true,
      );
}
