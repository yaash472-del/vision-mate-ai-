import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

const String apiBaseUrl = 'http://10.0.2.2:8000';
// Android emulator URL. For a real phone, use your laptop LAN IP.

void main() => runApp(const VisionMateApp());

class VisionMateApp extends StatelessWidget {
  const VisionMateApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VisionMate AI',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF46C7B4),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF101820),
      useMaterial3: true,
    ),
    home: const HomeScreen(),
  );
}

class ApiService {
  static Future<String> upload(String endpoint, XFile photo,
      {Map<String, String>? fields}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl$endpoint'));
    request.fields.addAll(fields ?? {});
    request.files.add(await http.MultipartFile.fromPath('image', photo.path));
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    final dynamic data = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data is Map ? data['detail'] ?? 'Server error' : 'Server error');
    }
    if (data is Map) {
      return (data['description'] ?? data['text'] ?? data['result'] ??
          data['answer'] ?? 'No response').toString();
    }
    return data.toString();
  }
}

class AppFeature {
  final String title;
  final String subtitle;
  final IconData icon;
  const AppFeature(this.title, this.subtitle, this.icon);
}

const features = [
  AppFeature('Live Assistant', 'Describe what is around you', Icons.remove_red_eye),
  AppFeature('Road Assist', 'Road awareness safety prototype', Icons.traffic),
  AppFeature('Navigation', 'Hear your current location', Icons.navigation),
  AppFeature('Read Text', 'Read signs and documents', Icons.document_scanner),
  AppFeature('Bus Assistant', 'Read visible bus information', Icons.directions_bus),
  AppFeature('Find Objects', 'Ask about objects in a photo', Icons.search),
  AppFeature('Emergency SOS', 'Prepare a message to a trusted contact', Icons.sos),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  bool listening = false;

  Future<void> say(String message) async {
    await tts.stop();
    await tts.setSpeechRate(0.45);
    await tts.speak(message);
  }

  Future<void> voiceCommand() async {
    final available = await speech.initialize();
    if (!available) {
      await say('Voice recognition is unavailable. Please select a feature.');
      return;
    }
    setState(() => listening = true);
    await say('Listening. Say road, navigation, read text, bus, find object, live assistant, or emergency.');
    speech.listen(onResult: (result) {
      if (!result.finalResult) return;
      final command = result.recognizedWords.toLowerCase();
      setState(() => listening = false);
      final index = command.contains('road') ? 1
          : command.contains('navigation') || command.contains('location') ? 2
          : command.contains('read') ? 3
          : command.contains('bus') ? 4
          : command.contains('find') || command.contains('object') ? 5
          : command.contains('emergency') || command.contains('sos') ? 6
          : 0;
      openFeature(features[index]);
    });
  }

  void openFeature(AppFeature feature) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FeatureScreen(feature: feature, say: say),
    ));
  }

  @override
  void dispose() {
    tts.stop();
    speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('VisionMate AI', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          tooltip: 'Voice command',
          onPressed: voiceCommand,
          icon: Icon(listening ? Icons.mic : Icons.mic_none),
        ),
      ],
    ),
    body: SafeArea(child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF18384A),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(children: [
            const Icon(Icons.record_voice_over, size: 42),
            const SizedBox(height: 10),
            const Text('YOUR AI COMPANION',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: voiceCommand,
              icon: const Icon(Icons.mic),
              label: const Text('TAP TO SPEAK'),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        const Text('Choose a feature',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: features.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
            childAspectRatio: 1.08,
          ),
          itemBuilder: (context, index) {
            final feature = features[index];
            return Semantics(
              button: true,
              label: '${feature.title}. ${feature.subtitle}',
              child: Card(
                color: index == 6 ? const Color(0xFF762D36) : const Color(0xFF1D2B36),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => openFeature(feature),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(feature.icon, size: 36),
                      const SizedBox(height: 10),
                      Text(feature.title, textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(feature.subtitle, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    )),
  );
}

class FeatureScreen extends StatefulWidget {
  final AppFeature feature;
  final Future<void> Function(String) say;
  const FeatureScreen({super.key, required this.feature, required this.say});

  @override
  State<FeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends State<FeatureScreen> {
  final ImagePicker picker = ImagePicker();
  final TextEditingController question = TextEditingController();
  String output = 'Choose an action to get started.';
  bool busy = false;

  Future<XFile?> takePhoto() => picker.pickImage(
    source: ImageSource.camera, imageQuality: 75, maxWidth: 1280,
  );

  Future<void> imageFeature(String endpoint) async {
    setState(() { busy = true; output = 'Processing image. Please wait.'; });
    try {
      final photo = await takePhoto();
      if (photo == null) {
        output = 'No photo captured.';
      } else {
        output = await ApiService.upload(endpoint, photo);
      }
      if (!mounted) return;
      setState(() {});
      await widget.say(output);
    } catch (e) {
      output = 'Could not complete request: $e';
      if (mounted) setState(() {});
      await widget.say('Sorry, the request failed.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> findObject() async {
    final item = question.text.trim();
    if (item.isEmpty) {
      output = 'Please type the object name first.';
      setState(() {});
      await widget.say(output);
      return;
    }
    // Ask endpoint with an image and the user's requested object.
    setState(() { busy = true; output = 'Taking a photo and looking for $item.'; });
    try {
      final photo = await takePhoto();
      if (photo == null) {
        output = 'No photo captured.';
      } else {
        output = await ApiService.upload('/api/vision/ask', photo,
          fields: {'question': 'Can you see $item? If yes, where is it in the image?'});
      }
      if (!mounted) return;
      setState(() {});
      await widget.say(output);
    } catch (e) {
      output = 'Could not complete request: $e';
      if (mounted) setState(() {});
      await widget.say('Sorry, the request failed.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> locationAction() async {
    setState(() { busy = true; output = 'Checking location permission.'; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Please enable location services.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      output = 'Your current coordinates are latitude ${pos.latitude.toStringAsFixed(5)}, longitude ${pos.longitude.toStringAsFixed(5)}. This starter does not yet provide turn-by-turn directions.';
      setState(() {});
      await widget.say(output);
    } catch (e) {
      output = e.toString();
      setState(() {});
      await widget.say(output);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> emergencyAction() async {
    final phoneController = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trusted emergency contact'),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, phoneController.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (phone == null || phone.isEmpty) return;
    try {
      final pos = await Geolocator.getCurrentPosition();
      final body = Uri.encodeComponent(
        'I need assistance. My location: https://maps.google.com/?q=${pos.latitude},${pos.longitude}',
      );
      final uri = Uri.parse('sms:$phone?body=$body');
      if (!await launchUrl(uri)) throw Exception('Could not open SMS app.');
      output = 'SMS app opened. Please review and send the emergency message.';
      setState(() {});
      await widget.say(output);
    } catch (e) {
      output = 'Could not prepare emergency message: $e';
      setState(() {});
      await widget.say(output);
    }
  }

  Future<void> runFeature() async {
    switch (widget.feature.title) {
      case 'Live Assistant':
        await imageFeature('/api/vision/describe');
        break;
      case 'Road Assist':
        output = 'Safety notice: this prototype cannot reliably detect all vehicles, hidden hazards or traffic signals. It cannot decide when a road is safe to cross. Do not use it to cross a live road. Please use your established mobility aid and seek assistance when needed.';
        setState(() {});
        await widget.say(output);
        break;
      case 'Navigation':
        await locationAction();
        break;
      case 'Read Text':
        await imageFeature('/api/vision/read-text');
        break;
      case 'Bus Assistant':
        await imageFeature('/api/vision/bus');
        break;
      case 'Find Objects':
        await findObject();
        break;
      case 'Emergency SOS':
        await emergencyAction();
        break;
    }
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRoad = widget.feature.title == 'Road Assist';
    final isFinder = widget.feature.title == 'Find Objects';
    return Scaffold(
      appBar: AppBar(title: Text(widget.feature.title)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Icon(widget.feature.icon, size: 62, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 14),
        Text(widget.feature.subtitle, textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium),
        if (isRoad) ...[
          const SizedBox(height: 16),
          const Card(
            color: Color(0xFF69371F),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'SAFETY NOTICE\nThis is not a certified mobility aid. It cannot reliably detect all road hazards and must never be used to decide when to cross.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        if (isFinder) ...[
          const SizedBox(height: 16),
          TextField(
            controller: question,
            decoration: const InputDecoration(
              labelText: 'Object to find',
              hintText: 'Example: water bottle',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: busy ? null : runFeature,
            icon: busy
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: Text(busy ? 'Please wait...' : _actionLabel()),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1D2B36),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(output, style: const TextStyle(fontSize: 16, height: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => widget.say(output),
          icon: const Icon(Icons.volume_up),
          label: const Text('Read response aloud'),
        ),
      ]),
    );
  }

  String _actionLabel() {
    switch (widget.feature.title) {
      case 'Live Assistant': return 'Capture and describe';
      case 'Road Assist': return 'Hear safety information';
      case 'Navigation': return 'Get current location';
      case 'Read Text': return 'Capture and read text';
      case 'Bus Assistant': return 'Identify visible bus';
      case 'Find Objects': return 'Take photo and find object';
      case 'Emergency SOS': return 'Prepare emergency message';
      default: return 'Start';
    }
  }
}
