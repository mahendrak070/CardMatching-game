import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => GameState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Matching',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        scaffoldBackgroundColor: Colors.grey[200],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFB3E5FC),
          elevation: 4,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF81D4FA),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(30)),
            ),
          ),
        ),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Matching'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => gameState.resetGame(),
          )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: const [
              TimerWidget(),
              ScoreWidget(),
              Expanded(child: CardGrid()),
            ],
          ),
          if (gameState.isGameWon())
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'You Win!',
                      style: TextStyle(
                        fontSize: 36,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Consumer<GameState>(
                      builder: (context, gameState, child) {
                        return ElevatedButton(
                          onPressed: () => gameState.resetGame(),
                          child: const Text('Restart Game'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CardGrid extends StatelessWidget {
  const CardGrid({super.key});
  
  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 4x4 grid => 16 cards total
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: gameState.cards.length,
      itemBuilder: (context, index) {
        return CardWidget(card: gameState.cards[index]);
      },
    );
  }
}

class CardWidget extends StatelessWidget {
  final CardModel card;
  
  const CardWidget({super.key, required this.card});
  
  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context, listen: false);
    return GestureDetector(
      onTap: () {
        gameState.flipCard(card);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) {
          final rotateAnim = Tween(begin: pi, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotateAnim,
            child: child,
            builder: (context, child) {
              return Transform(
                transform: Matrix4.rotationY(rotateAnim.value),
                alignment: Alignment.center,
                child: child,
              );
            },
          );
        },
        // Using a unique key based on card state ensures proper animation.
        child: card.isFaceUp
            ? Container(
                key: const ValueKey(true),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF9C4), Color(0xFFFFF59D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.4),
                      offset: const Offset(2, 4),
                      blurRadius: 4,
                    )
                  ],
                  border: Border.all(color: const Color(0xFFFFF176)),
                ),
                child: Center(
                  child: Text(
                    card.front,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              )
            : Container(
                key: const ValueKey(false),
                decoration: BoxDecoration(
                  color: const Color(0xFF81D4FA),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.4),
                      offset: const Offset(2, 4),
                      blurRadius: 4,
                    )
                  ],
                ),
                child: const Center(
                  child: Text(
                    '🃏',
                    style: TextStyle(fontSize: 30),
                  ),
                ),
              ),
      ),
    );
  }
}

class CardModel {
  final String front;
  final String back;
  bool isFaceUp;
  bool isMatched;
  
  CardModel({
    required this.front,
    required this.back,
    this.isFaceUp = false,
    this.isMatched = false,
  });
}

class GameState extends ChangeNotifier {
  List<CardModel> cards = [];
  List<CardModel> faceUpCards = [];
  int score = 0;
  Timer? gameTimer;
  int elapsedSeconds = 0;
  bool timerRunning = false;
  
  GameState() {
    _initializeCards();
    _startTimer();
  }
  
  // Initialize exactly 16 cards (8 pairs)
  void _initializeCards() {
    cards.clear();
    faceUpCards.clear();
    score = 0;
    elapsedSeconds = 0;
    timerRunning = true;
    List<String> cardValues = List.generate(8, (index) => '${index + 1}');
    for (String value in cardValues) {
      cards.add(CardModel(front: value, back: '🃏'));
      cards.add(CardModel(front: value, back: '🃏'));
    }
    cards.shuffle();
    notifyListeners();
  }
  
  void flipCard(CardModel card) {
    if (card.isFaceUp || card.isMatched || faceUpCards.length == 2) return;
    
    card.isFaceUp = true;
    faceUpCards.add(card);
    notifyListeners();
    
    if (faceUpCards.length == 2) {
      Future.delayed(const Duration(milliseconds: 800), _checkMatch);
    }
  }
  
  void _checkMatch() {
    if (faceUpCards.length < 2) return;
    CardModel card1 = faceUpCards[0];
    CardModel card2 = faceUpCards[1];
    
    if (card1.front == card2.front) {
      // Leave matched cards face up.
      card1.isMatched = true;
      card2.isMatched = true;
      score += 10;
    } else {
      // Flip back and deduct points.
      card1.isFaceUp = false;
      card2.isFaceUp = false;
      score = max(score - 5, 0);
      _shuffleUnmatched();
    }
    faceUpCards.clear();
    notifyListeners();
    
    if (isGameWon()) {
      _stopTimer();
    }
  }
  
  // Shuffle only unmatched cards to keep matched ones fixed.
  void _shuffleUnmatched() {
    List<CardModel> unmatched = cards.where((card) => !card.isMatched).toList();
    unmatched.shuffle();
    int unmatchedIndex = 0;
    for (int i = 0; i < cards.length; i++) {
      if (!cards[i].isMatched) {
        cards[i] = unmatched[unmatchedIndex];
        unmatchedIndex++;
      }
    }
  }
  
  bool isGameWon() {
    return cards.every((card) => card.isMatched);
  }
  
  void resetGame() {
    _stopTimer();
    _initializeCards();
    _startTimer();
    notifyListeners();
  }
  
  void _startTimer() {
    gameTimer?.cancel();
    timerRunning = true;
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsedSeconds++;
      if (isGameWon()) {
        _stopTimer();
      }
      notifyListeners();
    });
  }
  
  void _stopTimer() {
    timerRunning = false;
    gameTimer?.cancel();
  }
}

class TimerWidget extends StatelessWidget {
  const TimerWidget({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, gameState, child) {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'Time: ${gameState.elapsedSeconds} sec',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        );
      },
    );
  }
}

class ScoreWidget extends StatelessWidget {
  const ScoreWidget({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, gameState, child) {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'Score: ${gameState.score}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        );
      },
    );
  }
}
