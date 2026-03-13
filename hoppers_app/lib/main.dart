import 'dart:convert';
import 'dart:collection';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode, defaultTargetPlatform;
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hoppers_app/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kDebugMode) {
    String host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  }

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('tts_cache');

  await FirebaseAuth.instance.signInAnonymously();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '#hoppers',
      home: const MyHomePage(title: 'HOPPERS'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.light,
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = false;
  bool _isProcessingQueue = false;
  int _previousLength = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _controller = TextEditingController();
  final Queue<String> _ttsQueue = Queue();

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _addToQueue(String text) {
    _ttsQueue.add(text);
    if (!_isProcessingQueue) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    _isProcessingQueue = true;
    while (_ttsQueue.isNotEmpty) {
      String text = _ttsQueue.removeFirst();
      await _callTTSFunction(text);
    }
    _isProcessingQueue = false;
  }

  Future<void> _callTTSFunction(String text) async {
    setState(() => _isLoading = true);

    final box = Hive.box('tts_cache');

    if (box.containsKey(text)) {
      String base64Audio = box.get(text);
      await _audioPlayer.play(BytesSource(base64Decode(base64Audio)));

      // Wait for audio to finish before moving to next character in queue
      await _audioPlayer.onPlayerStateChanged.firstWhere((s) => s == PlayerState.completed || s == PlayerState.stopped);
      return;
    }

    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('generate_tts');
      final result = await callable.call({'text': text});
      String base64Audio = result.data['audioContent'];
      await box.put(text, base64Audio);
      
      await _audioPlayer.play(BytesSource(base64Decode(base64Audio)));
      await _audioPlayer.onPlayerStateChanged.firstWhere((s) => s == PlayerState.completed || s == PlayerState.stopped);
    } catch (e) {
      debugPrint('TTS Error: $e');
      _showErrorPopup(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🫠 Something went wrong!'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void cancelAudio() {
    _controller.clear();
    _ttsQueue.clear();
    _audioPlayer.stop();
    setState(() {
      _isLoading = false;
      _previousLength = 0;
      _isProcessingQueue = false;
    });
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFFD93D),
            Color(0xFFFFC107),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              /// TITLE
              const Text(
              "HOPPERS",
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                color: Colors.black,
              ),
              ),

              const SizedBox(height: 8),

              /// TAGLINE
              const Text(
              "ACT NATURAL",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.black87,
              ),
              ),

              const SizedBox(height: 40),

              /// MASCOT AREA
              AnimatedScale(
              scale: _isLoading ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: const Text(
                "🪵🦫",
                style: TextStyle(fontSize: 40),
              ),
              ),

              const SizedBox(height: 50),

              /// INPUT CARD
              Container(
              width: 350,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.yellow[400],
                borderRadius: BorderRadius.circular(18),
                border: Border.all(width: 2),
              ),
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
                onChanged: (value) {
                if (value.isNotEmpty && value.length > _previousLength) {
                  _addToQueue(value.characters.last);
                }
                _previousLength = value.length;
                },
                decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Type something...",
                hintStyle: const TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: cancelAudio,
                ),
                ),
              ),
              ),
              if (_isLoading) ...[
              const Text(
                'loading...',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              )
              ] else ...[
              const SizedBox(height: 20),
              ]
            ]
          ),
        ),
      ),
    ),
  );
}
}
