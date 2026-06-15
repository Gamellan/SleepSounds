import 'dart:async';

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

class MixPreset {
  const MixPreset({required this.name, required this.volumes});

  final String name;
  final Map<String, double> volumes;
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
  final List<MixPreset> _presets = const [
    MixPreset(
      name: 'Baby',
      volumes: {
        'white_noise': 0.55,
        'fan': 0.35,
      },
    ),
    MixPreset(
      name: 'Study',
      volumes: {
        'rain': 0.45,
        'fan': 0.25,
      },
    ),
    MixPreset(
      name: 'Meditation',
      volumes: {
        'ocean': 0.50,
        'forest': 0.35,
      },
    ),
  ];

  Timer? _sleepTimer;
  Timer? _fadeTimer;
  DateTime? _sleepEnd;
  Duration? _remaining;
  bool _isFading = false;

  @override
  void initState() {
    super.initState();
    final audioContext = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
    );

    for (final sound in _sounds) {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.loop);
      player.setPlayerMode(PlayerMode.mediaPlayer);
      player.setAudioContext(audioContext);
      _players[sound.id] = player;
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
    await player.setVolume(_isFading ? value * _fadeFactor() : value);
    setState(() {});
  }

  Future<void> _applyPreset(MixPreset preset) async {
    for (final sound in _sounds) {
      final newVolume = preset.volumes[sound.id] ?? 0.0;
      _volumes[sound.id] = newVolume;

      if (newVolume == 0) {
        if (_playing[sound.id] == true) {
          await _players[sound.id]!.stop();
          _playing[sound.id] = false;
        }
      } else {
        await _players[sound.id]!.setVolume(newVolume);
        if (_playing[sound.id] != true) {
          await _players[sound.id]!
              .play(AssetSource(sound.assetPath.replaceFirst('assets/', '')));
          _playing[sound.id] = true;
        }
      }
    }
    setState(() {});
  }

  Future<void> _stopAll() async {
    _cancelSleepTimer();
    for (final sound in _sounds) {
      await _players[sound.id]!.stop();
      _playing[sound.id] = false;
    }
    setState(() {});
  }

  void _startSleepTimer(Duration duration) {
    _cancelSleepTimer();
    _sleepEnd = DateTime.now().add(duration);
    _remaining = duration;

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _sleepEnd!.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _remaining = Duration.zero;
        _stopAll();
        return;
      }

      _remaining = remaining;

      if (remaining <= const Duration(seconds: 20) && !_isFading) {
        _startFadeOut();
      }

      if (mounted) {
        setState(() {});
      }
    });

    setState(() {});
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEnd = null;
    _remaining = null;
    _stopFadeOut();
  }

  void _startFadeOut() {
    _isFading = true;
    _fadeTimer?.cancel();
    _fadeTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final factor = _fadeFactor();
      for (final sound in _sounds) {
        if (_playing[sound.id] == true) {
          final base = _volumes[sound.id] ?? 0;
          await _players[sound.id]!.setVolume(base * factor);
        }
      }
    });
  }

  void _stopFadeOut() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _isFading = false;
    for (final sound in _sounds) {
      final base = _volumes[sound.id] ?? 0;
      _players[sound.id]!.setVolume(base);
    }
  }

  double _fadeFactor() {
    final remaining = _remaining;
    if (remaining == null || remaining.inSeconds >= 20) {
      return 1;
    }
    return remaining.inSeconds / 20;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _cancelSleepTimer();
    for (final player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerText = _remaining == null ? 'Off' : _formatDuration(_remaining!);

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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Presets', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presets
                          .map(
                            (preset) => FilledButton.tonal(
                              onPressed: () => _applyPreset(preset),
                              child: Text(preset.name),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sleep Timer', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _startSleepTimer(const Duration(minutes: 15)),
                          child: const Text('15m'),
                        ),
                        OutlinedButton(
                          onPressed: () => _startSleepTimer(const Duration(minutes: 30)),
                          child: const Text('30m'),
                        ),
                        OutlinedButton(
                          onPressed: () => _startSleepTimer(const Duration(minutes: 60)),
                          child: const Text('60m'),
                        ),
                        TextButton(
                          onPressed: _cancelSleepTimer,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Timer: $timerText'),
                    if (_isFading && _remaining != null)
                      const Text('Fade-out active (last 20s)'),
                  ],
                ),
              ),
            ),
            ..._sounds.map((sound) {
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
            }),
            const SizedBox(height: 12),
            Text(
              'Background playback enabled. Lock screen media controls depend on platform audio session support.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
