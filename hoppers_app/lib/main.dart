import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
//import 'package:flutter/foundation.dart' show kDebugMode, defaultTargetPlatform;
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hoppers_app/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // if (kDebugMode) {
  //   String host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
  //   await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  //   FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  // }

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
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  int _previousLength = 0;

  Future<void> _callTTSFunction(String text) async {

    setState(() => _isLoading = true);

    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('generate_tts');

      final result = await callable.call({'text': text});
      String base64Audio = result.data['audioContent'];  
      Uint8List audioBytes = base64Decode(base64Audio);

      await _audioPlayer.play(BytesSource(audioBytes));

    } catch (e) {
      _showErrorPopup('Error calling TTS function: $e');
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
      ),
      backgroundColor: Colors.yellow[600],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _controller,
              onChanged: (value) {
                if (value.isNotEmpty && value.length > _previousLength) {
                  _callTTSFunction(value.characters.last);
                }
                _previousLength = value.length;
              },
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                suffixIcon: IconButton(icon: Icon(Icons.clear, color: Colors.white), onPressed: () => _controller.clear()),
                hintText: 'Type here',
                hintStyle: TextStyle(fontSize: 18, color: Colors.white),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 10),
              const CircularProgressIndicator(),
            ]
          ],
        ),
      ),
    );
  }
}
