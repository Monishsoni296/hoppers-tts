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
  bool _playingAudio = false;
  bool _isProcessingQueue = false;
  bool _isAudioUnlocked = false;
  String playingText = "type a sentence or an emoji!";
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _controllerEmoji = TextEditingController();
  final TextEditingController _controllerSentence = TextEditingController();
  final Queue<(int, String)> _ttsQueue = Queue<(int, String)>();
  final Queue<(String, String)> _playbackQueue = Queue<(String, String)>();
  final String _silentWavBase64 = 'UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAIA+AAACABAAZGF0YQAAAAA=';

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
    _controllerEmoji.dispose();
    _controllerSentence.dispose();
    super.dispose();
  }

  Future<void> _unlockAudioContext() async {
    if (_isAudioUnlocked) return;
    try {
      await _audioPlayer.play(BytesSource(base64Decode(_silentWavBase64)));
      setState(() => _isAudioUnlocked = true);
    } catch (e) {
      debugPrint('Audio Unlock Error: $e');
    }
  }

  void _addToQueue(int ind, String text) {
    _ttsQueue.add((ind, text));
    if (!_isProcessingQueue) {
      _processQueue();
    }
  }

  void _addToPlaybackQueue(String base64Audio, String text) {
    _playbackQueue.add((base64Audio, text));
    if (!_playingAudio) {
      processPlaybackQueue();
    }
  }

  Future<void> _processQueue() async {
    _isProcessingQueue = true;

    while (_ttsQueue.isNotEmpty) {
      var (ind, text) = _ttsQueue.removeFirst();
      await _callTTSFunction(ind, text);
    }

    _isProcessingQueue = false;
  }

  Future<void> processPlaybackQueue() async {
    _playingAudio = true;

    while (_playbackQueue.isNotEmpty) {
      var (base64Audio, text) = _playbackQueue.removeFirst();
      await _audioPlayer.play(BytesSource(base64Decode(base64Audio)));

      setState(() => playingText = text);
      await _audioPlayer.onPlayerStateChanged.firstWhere(
        (s) => s == PlayerState.completed || s == PlayerState.stopped,
      );
      setState(() => playingText = 'type a sentence or an emoji!');
    }

    _playingAudio = false;
  }

  Future<void> _callTTSFunction(int ind, String text) async {
    setState(() => _isLoading = true);

    bool emoji = ind == 0; //condition for emoji vs sentence TTS
    final box = Hive.box('tts_cache');

    if (emoji) {
      if (box.containsKey(text)) {
        String base64Audio = box.get(text);
        _addToPlaybackQueue(base64Audio, text);

        setState(() => _isLoading = false);
        return;
      }
    }

    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        ind == 0 ? 'generate_tts' : 'sentence_tts',
      );
      final result = await callable.call({'text': text});
      String base64Audio = result.data['audioContent'];
      _addToPlaybackQueue(base64Audio, text);
      if (emoji) await box.put(text, base64Audio);
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
    _controllerEmoji.clear();
    _controllerSentence.clear();
    _ttsQueue.clear();
    _playbackQueue.clear();
    _audioPlayer.stop();
    setState(() {
      _isLoading = false;
      _isProcessingQueue = false;
      _playingAudio = false;
    });
  }

  @override
Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                child: const Text("🪵🦫", style: TextStyle(fontSize: 40)),
              ),

              const SizedBox(height: 25),

              Text(
                playingText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[400],
                ),
              ),

              const SizedBox(height: 25),

              /// INPUT CARD
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 350,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.yellow[400],
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(width: 2),
                    ),
                    child: TextField(
                      controller: _controllerSentence,
                      onTap: _unlockAudioContext,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'type a sentence...',
                        hintStyle: const TextStyle(
                          fontSize: 18,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.yellow[400],
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(width: 2),
                    ),
                    child: TextField(
                      controller: _controllerEmoji,
                      onTap: _unlockAudioContext,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                      decoration: InputDecoration(border: InputBorder.none),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          _addToQueue(0, _controllerEmoji.text.trim());
                          Future.delayed(
                            const Duration(milliseconds: 300),
                          ).whenComplete(() => _controllerEmoji.clear());
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: cancelAudio,
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: Colors.black,
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () {
                      String sentence = _controllerSentence.text.trim();
                      if (sentence.isNotEmpty) _addToQueue(1, sentence);
                      _controllerSentence.clear();
                    },
                    icon: const Icon(Icons.send_sharp, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              if (_isLoading) ...[
                const Text(
                  'loading...',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ] else if (_playingAudio) ...[
                const Text(
                  'playing audio...',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ] else if (_ttsQueue.isEmpty && _playbackQueue.isEmpty) ...[
                const Text(
                  'ready to hop!',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
