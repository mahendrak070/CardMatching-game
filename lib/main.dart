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
    return const MaterialApp(
      home: GameScreen(),
      debugShowCheckedModeBanner: false,
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
        title: const Text('Card Matching Game'),
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
              color: Colors.black54,
              child: Center(
                child: Consumer<GameState>(
                  builder: (context, gameState, child) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'You Win!',
                        style: TextStyle(fontSize: 30, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => gameState.resetGame(),
                        child: const Text('Restart Game'),
                      ),
                    ],
                  ),
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
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 4x4 grid
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
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
        // Use a unique key based on face-up state so that AnimatedSwitcher animates correctly.
        child: card.isFaceUp
            ? Container(
                key: const ValueKey(true),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueAccent),
                ),
                child: Center(
                  child: Text(
                    card.front,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            : Container(
                key: const ValueKey(false),
                decoration: BoxDecoration(
                  color: Colors.blueGrey,
                  borderRadius: BorderRadius.circular(8),
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
  bool isMatched; // Marks whether a card has been matched
  
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
  
  // Generates 8 pairs (16 cards total) and shuffles them.
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
    // Ignore tap if the card is already face-up or matched, or if two cards are already face-up.
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
      // When a match is found, mark cards as matched.
      card1.isMatched = true;
      card2.isMatched = true;
      score += 10;
      // Do not shuffle matched cards so they remain in their original positions.
    } else {
      // If not a match, flip both cards back over and deduct score.
      card1.isFaceUp = false;
      card2.isFaceUp = false;
      score = max(score - 5, 0);
      // Shuffle only the unmatched cards while preserving the positions of matched ones.
      _shuffleUnmatched();
    }
    faceUpCards.clear();
    notifyListeners();
    
    if (isGameWon()) {
      _stopTimer();
    }
  }
  
  // Shuffle only the cards that haven't been matched.
  void _shuffleUnmatched() {
    // Extract unmatched cards.
    List<CardModel> unmatched = cards.where((card) => !card.isMatched).toList();
    unmatched.shuffle();
    int unmatchedIndex = 0;
    // Reassign the positions for only unmatched cards.
    for (int i = 0; i < cards.length; i++) {
      if (!cards[i].isMatched) {
        cards[i] = unmatched[unmatchedIndex];
        unmatchedIndex++;
      }
    }
  }
  
  bool isGameWon() {
    // The game is won when all cards are matched.
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
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Time: ${gameState.elapsedSeconds} sec',
            style: const TextStyle(fontSize: 20),
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
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Score: ${gameState.score}',
            style: const TextStyle(fontSize: 20),
          ),
        );
      },
    );
  }
}
