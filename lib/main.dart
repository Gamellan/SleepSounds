import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const SleepSoundsApp());
}

class SleepSoundsApp extends StatelessWidget {
  const SleepSoundsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sleep Sounds',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6FA5)),
      ),
      home: const SleepSoundsHomePage(),
    );
  }
}

class SleepSound {
  SleepSound({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.icon,
  });

  final String id;
  final String name;
  final String assetPath;
  final IconData icon;
}

class SleepSoundsHomePage extends StatefulWidget {
  const SleepSoundsHomePage({super.key});

  @override
  State<SleepSoundsHomePage> createState() => _SleepSoundsHomePageState();
}

class _SleepSoundsHomePageState extends State<SleepSoundsHomePage> {
  final List<SleepSound> _sounds = [
    SleepSound(
      id: 'rain',
      name: 'Rain',
      assetPath: 'assets/audio/rain.wav',
      icon: Icons.umbrella,
    ),
    SleepSound(
      id: 'ocean',
      name: 'Ocean',
      assetPath: 'assets/audio/ocean.wav',
      icon: Icons.waves,
    ),
    SleepSound(
      id: 'forest',
      name: 'Forest',
      assetPath: 'assets/audio/forest.wav',
      icon: Icons.park,
    ),
    SleepSound(
      id: 'fan',
      name: 'Fan',
      assetPath: 'assets/audio/fan.wav',
      icon: Icons.toys,
    ),
    SleepSound(
      id: 'white_noise',
      name: 'White Noise',
      assetPath: 'assets/audio/white_noise.wav',
      icon: Icons.graphic_eq,
    ),
  ];

  final Map<String, AudioPlayer> _players = {};
  final Map<String, bool> _playing = {};
  final Map<String, double> _volumes = {};

  @override
  void initState() {
    super.initState();
    for (final sound in _sounds) {
      _players[sound.id] = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      _playing[sound.id] = false;
      _volumes[sound.id] = 0.4;
    }
  }

  Future<void> _toggleSound(SleepSound sound) async {
    final player = _players[sound.id]!;
    final isPlaying = _playing[sound.id] ?? false;

    if (isPlaying) {
      await player.stop();
      setState(() => _playing[sound.id] = false);
      return;
    }

    await player.setVolume(_volumes[sound.id] ?? 0.4);
    await player.play(AssetSource(sound.assetPath.replaceFirst('assets/', '')));
    setState(() => _playing[sound.id] = true);
  }

  Future<void> _setVolume(SleepSound sound, double value) async {
    final player = _players[sound.id]!;
    _volumes[sound.id] = value;
    await player.setVolume(value);
    setState(() {});
  }

  Future<void> _stopAll() async {
    for (final sound in _sounds) {
      await _players[sound.id]!.stop();
      _playing[sound.id] = false;
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Sounds'),
        actions: [
          IconButton(
            onPressed: _stopAll,
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: 'Stop all',
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6EEF8), Color(0xFFF9FBFF)],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _sounds.length,
          itemBuilder: (context, index) {
            final sound = _sounds[index];
            final isPlaying = _playing[sound.id] ?? false;
            final volume = _volumes[sound.id] ?? 0.4;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(sound.icon, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sound.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _toggleSound(sound),
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                          label: Text(isPlaying ? 'Pause' : 'Play'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.volume_down, size: 18),
                        Expanded(
                          child: Slider(
                            value: volume,
                            min: 0,
                            max: 1,
                            divisions: 20,
                            onChanged: (value) => _setVolume(sound, value),
                          ),
                        ),
                        const Icon(Icons.volume_up, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
