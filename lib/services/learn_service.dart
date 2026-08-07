import 'package:app/core/di/service_locator.dart';
import 'package:app/domain/repositories/learning_repository.dart';
import 'package:app/services/sync/sync_coordinator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/models/learn_models.dart';

class LearnService {
  final List<Lesson> _lessons = [];
  final List<Quiz> _quizzes = [];

  LearnService() {
    _initStaticData();
  }

  List<Lesson> get lessons => _lessons;
  List<Quiz> get quizzes => _quizzes;

  Future<void> loadProgress() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
      final repo = serviceLocator<LearningRepository>();
      final data = await repo.getProgress(userId);
      
      final Map<String, dynamic> lessonData = data['lessons'] as Map<String, dynamic>? ?? {};
      final Map<String, dynamic> quizData = data['quizzes'] as Map<String, dynamic>? ?? {};

      for (final lesson in _lessons) {
        if (lessonData.containsKey(lesson.id)) {
          lesson.loadProgress(lessonData[lesson.id]);
        }
      }
      for (final quiz in _quizzes) {
        if (quizData.containsKey(quiz.id)) {
          quiz.loadProgress(quizData[quiz.id]);
        }
      }
    } catch (_) {}
  }

  Future<void> saveProgress() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
      final repo = serviceLocator<LearningRepository>();

      for (final lesson in _lessons) {
        if (lesson.isCompleted) {
          final payload = {
            'user_id': userId,
            'lesson_id': lesson.id,
            'completed': 1,
            'completion_time': lesson.estimatedTimeMinutes,
            'last_opened': DateTime.fromMillisecondsSinceEpoch(lesson.lastReadTimestamp ?? DateTime.now().millisecondsSinceEpoch).toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
          await repo.saveProgress(
            userId,
            lesson.id,
            completed: true,
            completionTime: lesson.estimatedTimeMinutes,
            lastOpened: payload['last_opened'] as String,
          );
          
          await serviceLocator<SyncCoordinator>().enqueue(
            'learning_progress',
            'INSERT',
            lesson.id,
            payload,
          );
        }
      }

      for (final quiz in _quizzes) {
        if (quiz.isCompleted) {
          final payload = {
            'user_id': userId,
            'lesson_id': quiz.id,
            'completed': 1,
            'quiz_score': quiz.highestScore,
            'updated_at': DateTime.now().toIso8601String(),
          };
          await repo.saveProgress(
            userId,
            quiz.id,
            completed: true,
            quizScore: quiz.highestScore,
          );
          
          await serviceLocator<SyncCoordinator>().enqueue(
            'learning_progress',
            'INSERT',
            quiz.id,
            payload,
          );
        }
      }
    } catch (_) {}
  }

  void _initStaticData() {
    _lessons.addAll([
      // --- BEGINNER ---
      Lesson(
        id: 'beg_what_is_crypto',
        title: 'What is Cryptocurrency?',
        category: LessonCategory.beginner,
        estimatedTimeMinutes: 5,
        icon: LessonCategory.beginner.icon,
        content: '''# What is Cryptocurrency?

A **cryptocurrency** is a digital or virtual currency that is secured by cryptography, making it nearly impossible to counterfeit or double-spend. 

Key characteristics include:
1. **Decentralization**: Most cryptocurrencies are decentralized networks based on blockchain technology—a distributed ledger enforced by a disparate network of computers.
2. **Cryptographic Security**: Algorithms ensure security and ownership.
3. **Permissionless & Borderless**: Anyone with an internet connection can send crypto globally in minutes without intermediation.

## Why Cryptocurrency?
Traditional fiat currencies (like the US Dollar or Euro) are controlled by central banks. When central banks print money, it creates inflation. Bitcoin and many other cryptos have a **fixed supply** (for example, Bitcoin has a hard limit of 21 million coins), making them inherently deflationary store-of-value assets.
''',
      ),
      Lesson(
        id: 'beg_blockchain',
        title: 'Understanding Blockchain',
        category: LessonCategory.beginner,
        estimatedTimeMinutes: 6,
        icon: LessonCategory.beginner.icon,
        content: '''# Understanding Blockchain Technology

A **blockchain** is a decentralized, distributed ledger that records the provenance of a digital asset. 

## How it Works
1. **Blocks**: Data is stored in files called blocks.
2. **Chaining**: Blocks contain a cryptographic hash of the previous block, timestamped data, and transaction details. This links blocks in chronological order, forming a "chain".
3. **Consensus**: Networks use mechanism algorithms (like Proof of Work (PoW) or Proof of Stake (PoS)) to agree on the state of the ledger.

Once a block is recorded, it is **immutable**—it cannot be modified retroactively without changing all subsequent blocks and gaining consensus of the majority of the network. This eliminates trust-requirements and intermediate parties.
''',
      ),
      Lesson(
        id: 'beg_wallets',
        title: 'Crypto Wallets: Hot vs. Cold',
        category: LessonCategory.beginner,
        estimatedTimeMinutes: 5,
        icon: LessonCategory.beginner.icon,
        content: '''# Crypto Wallets: Hot vs. Cold

To transact in crypto, you need a wallet. A crypto wallet does not store the coins themselves; it stores your **private key** (which gives ownership of address balances) and **public key** (your address).

## Hot Wallets
- **Connected to the Internet**: Mobile apps, web plugins, exchange accounts.
- **Pros**: Extremely convenient, fast for active trading.
- **Cons**: Vulnerable to online hacks, malware, phishing.

## Cold Wallets
- **Offline Storage**: Hardware devices (like Ledger or Trezor), paper wallets.
- **Pros**: Maximum security, immune to remote cyberattacks.
- **Cons**: Less convenient for daily trading, physically losing the device/seed phrase can result in permanent loss.
''',
      ),
      Lesson(
        id: 'beg_exchanges',
        title: 'Exchanges: CEX vs. DEX',
        category: LessonCategory.beginner,
        estimatedTimeMinutes: 5,
        icon: LessonCategory.beginner.icon,
        content: '''# Crypto Exchanges: CEX vs. DEX

Exchanges are platforms where you trade assets. They come in two primary configurations:

## Centralized Exchanges (CEX)
- **Examples**: Binance, Coinbase.
- **How it works**: Operated by a company acting as an intermediary. They hold custody of your funds and match buyers/sellers via order books.
- **Pros**: High liquidity, fast execution, fiat deposits (on/off ramps).
- **Cons**: "Not your keys, not your coins." Subject to hacks, regulatory lockdowns, KYC requirements.

## Decentralized Exchanges (DEX)
- **Examples**: Uniswap, PancakeSwap.
- **How it works**: Uses Smart Contracts and Automated Market Makers (AMM) to execute trades directly between peer-to-peer wallets.
- **Pros**: Self-custodial, private, no KYC.
- **Cons**: Higher network fees, slippage, no fiat gateways.
''',
      ),

      // --- TECHNICAL ANALYSIS ---
      Lesson(
        id: 'ta_candlesticks',
        title: 'Anatomy of Candlesticks',
        category: LessonCategory.technicalAnalysis,
        estimatedTimeMinutes: 7,
        icon: LessonCategory.technicalAnalysis.icon,
        content: '''# Anatomy of Candlesticks

Candlestick charts show price movements over a specific timeframe (e.g. 1 hour, 1 day).

## Components of a Candle:
- **Body**: The filled/colored part representing the open and close price range.
  - Green (Bullish): Close is higher than open.
  - Red (Bearish): Close is lower than open.
- **Wicks (Shadows)**: The thin lines above and below the body indicating the High and Low prices reached during that period.

## Common Candlestick Patterns:
1. **Doji**: Open and close are almost equal; indicates market indecision.
2. **Hammer**: Small body, long lower wick; signifies bullish reversal.
3. **Shooting Star**: Small body, long upper wick; signals bearish exhaustion.
''',
      ),
      Lesson(
        id: 'ta_support_resistance',
        title: 'Support and Resistance',
        category: LessonCategory.technicalAnalysis,
        estimatedTimeMinutes: 6,
        icon: LessonCategory.technicalAnalysis.icon,
        content: '''# Support and Resistance

Support and Resistance are price levels where historical buying or selling pressures pause price movement.

- **Support (Floor)**: A price level where buying demand is strong enough to prevent the price from falling further. 
- **Resistance (Ceiling)**: A price level where selling pressure overcomes buying power, pausing upward movement.

*Pro Tip*: A broken resistance often flips to become support, and a broken support level turns into resistance.
''',
      ),

      // --- STRATEGIES ---
      Lesson(
        id: 'strat_breakout',
        title: 'Breakout Trading',
        category: LessonCategory.tradingStrategies,
        estimatedTimeMinutes: 8,
        icon: LessonCategory.tradingStrategies.icon,
        content: '''# Breakout Trading Strategy

A **Breakout** occurs when price moves outside of a defined support or resistance boundary with strong volume.

## Rules of Execution:
1. **Identify Pattern**: Look for consolidation patterns like triangles, ranges, or flags.
2. **Wait for Close**: Never buy the wick. Wait for a candle to close *outside* the boundary.
3. **Volume Confirmation**: Verify that breakout volume is significantly higher than average to avoid "fakeouts".
4. **Set Risk**: Place a stop loss just inside the broken structure.
''',
      ),
      Lesson(
        id: 'strat_ema',
        title: 'EMA Cross System',
        category: LessonCategory.tradingStrategies,
        estimatedTimeMinutes: 6,
        icon: LessonCategory.tradingStrategies.icon,
        content: '''# Exponential Moving Average (EMA) Cross

Moving Averages smooth out price data to form trend indicators. EMA reacts faster to recent price fluctuations than Simple Moving Average (SMA).

## System Rules:
- **Fast EMA**: e.g., 9 periods.
- **Slow EMA**: e.g., 21 periods.
- **Bullish Entry (Golden Cross)**: Buy when Fast EMA crosses *above* Slow EMA.
- **Bearish Entry (Death Cross)**: Short/Sell when Fast EMA crosses *below* Slow EMA.
''',
      ),

      // --- RISK MANAGEMENT ---
      Lesson(
        id: 'risk_pos_sizing',
        title: 'Position Sizing & Risk rules',
        category: LessonCategory.riskManagement,
        estimatedTimeMinutes: 8,
        icon: LessonCategory.riskManagement.icon,
        content: '''# Position Sizing: The 1% Rule

Never risk your entire account on a single trade. The gold standard rule is the **1% Risk Rule**.

## The Formula:
Risk Amount = Account Equity × 1%

For example, if your balance is \$100,000, your maximum loss on a single trade should be \$1,000.

## Calculating Position Size:
Position Size = Risk Amount / (Entry Price - Stop Loss Price)

This ensures that even if your trade triggers a stop loss, you only lose 1% of your total balance. Correct position sizing keeps you in the game long term.
''',
      ),

      // --- PSYCHOLOGY ---
      Lesson(
        id: 'psych_fomo',
        title: 'Conquering FOMO & Revenge Trading',
        category: LessonCategory.tradingPsychology,
        estimatedTimeMinutes: 7,
        icon: LessonCategory.tradingPsychology.icon,
        content: '''# Conquering FOMO and Revenge Trading

Successful trading is 20% strategy and 80% psychology.

## FOMO (Fear of Missing Out)
FOMO is the psychological impulse to buy an asset just because the price is skyrocketing, fearing you will miss the profits. This often results in buying the absolute top right before a correction.
- **Antidote**: Always stick to your entry triggers. If you miss a move, wait for the next setup. Market opportunities are infinite.

## Revenge Trading
After taking a loss, a trader often feels angry and places another trade immediately to "make the money back" with larger size. This triggers double losses and liquidation.
- **Antidote**: Close your terminal after 2 consecutive losses. Walk away, clear your mind.
''',
      ),
    ]);

    // --- QUIZZES ---
    _quizzes.addAll([
      Quiz(
        id: 'q_beginner',
        title: 'Crypto Beginner Quiz',
        category: LessonCategory.beginner,
        questions: [
          QuizQuestion(
            id: 'qb_1',
            questionText: 'What is the maximum supply limit of Bitcoin?',
            options: ['21 Million', '100 Million', 'Infinity', '50 Million'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            id: 'qb_2',
            questionText: 'Which wallet is offline and provides the highest security?',
            options: ['Hot Wallet', 'Exchange Account', 'Cold Wallet', 'Metamask'],
            correctAnswerIndex: 2,
          ),
          QuizQuestion(
            id: 'qb_3',
            questionText: 'What does "Not your keys, not your coins" refer to?',
            options: [
              'Leaving crypto on centralized exchanges',
              'Writing down keys in public',
              'Using hardware wallets',
              'Having strong security passwords'
            ],
            correctAnswerIndex: 0,
          ),
        ],
      ),
      Quiz(
        id: 'q_technical',
        title: 'Technical Analysis Quiz',
        category: LessonCategory.technicalAnalysis,
        questions: [
          QuizQuestion(
            id: 'qt_1',
            questionText: 'In a bullish green candle, what does the bottom of the solid body represent?',
            options: ['Lowest Price', 'Opening Price', 'Closing Price', 'Highest Price'],
            correctAnswerIndex: 1,
          ),
          QuizQuestion(
            id: 'qt_2',
            questionText: 'What happens when resistance is broken with high volume?',
            options: [
              'It flips to become support',
              'It falls immediately',
              'Volume decreases',
              'It turns into leverage'
            ],
            correctAnswerIndex: 0,
          ),
        ],
      ),
      Quiz(
        id: 'q_risk',
        title: 'Risk & Strategy Quiz',
        category: LessonCategory.riskManagement,
        questions: [
          QuizQuestion(
            id: 'qr_1',
            questionText: 'Under the standard rule, how much should you risk on a single trade?',
            options: ['1% of account equity', '10% of account equity', '50% of account equity', '100%'],
            correctAnswerIndex: 0,
          ),
          QuizQuestion(
            id: 'qr_2',
            questionText: 'What is revenge trading?',
            options: [
              'Placing emotional trades after a loss to recover funds quickly',
              'Executing trades on behalf of friends',
              'Shorting the market when it falls',
              'A premium API trade strategy'
            ],
            correctAnswerIndex: 0,
          ),
        ],
      ),
    ]);
  }
}
