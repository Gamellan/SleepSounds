import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const SleepSoundsApp());
}

class SleepSoundsApp extends StatelessWidget {
  const SleepSoundsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.dmSansTextTheme();

    return MaterialApp(
      title: 'Sleep Sounds',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: textTheme,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8EA8FF),
          secondary: Color(0xFF72E6C8),
          surface: Color(0xFF151B36),
          onPrimary: Colors.white,
          onSecondary: Color(0xFF0D1026),
          onSurface: Colors.white,
        ),
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
    required this.color,
  });

  final String id;
  final String name;
  final String assetPath;
  final IconData icon;
  final Color color;
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
      color: const Color(0xFF78A6FF),
    ),
    SleepSound(
      id: 'ocean',
      name: 'Ocean',
      assetPath: 'assets/audio/ocean.wav',
      icon: Icons.waves,
      color: const Color(0xFF4FD8DA),
    ),
    SleepSound(
      id: 'forest',
      name: 'Forest',
      assetPath: 'assets/audio/forest.wav',
      icon: Icons.park,
      color: const Color(0xFF7ED67E),
    ),
    SleepSound(
      id: 'fan',
      name: 'Fan',
      assetPath: 'assets/audio/fan.wav',
      icon: Icons.toys,
      color: const Color(0xFFB9A5FF),
    ),
    SleepSound(
      id: 'white_noise',
      name: 'White Noise',
      assetPath: 'assets/audio/white_noise.wav',
      icon: Icons.graphic_eq,
      color: const Color(0xFFE2DBFF),
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

  int get _activeCount => _playing.values.where((isOn) => isOn).length;

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
      backgroundColor: const Color(0xFF0C1022),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sleep Sounds'),
        actions: [
          IconButton(
            onPressed: _stopAll,
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: 'Stop all',
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned(
            top: -70,
            right: -40,
            child: _GlowBlob(size: 230, color: Color(0x664C6FFF)),
          ),
          const Positioned(
            bottom: -80,
            left: -50,
            child: _GlowBlob(size: 250, color: Color(0x6654E3C2)),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            children: [
              _PremiumHeader(
                activeCount: _activeCount,
                timerText: timerText,
                fading: _isFading,
              ),
              const SizedBox(height: 12),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Presets', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presets
                          .map(
                            (preset) => FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0x332A3A72),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: () => _applyPreset(preset),
                              child: Text(preset.name),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sleep Timer', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TimerChip(
                          label: '15m',
                          onTap: () => _startSleepTimer(const Duration(minutes: 15)),
                        ),
                        _TimerChip(
                          label: '30m',
                          onTap: () => _startSleepTimer(const Duration(minutes: 30)),
                        ),
                        _TimerChip(
                          label: '60m',
                          onTap: () => _startSleepTimer(const Duration(minutes: 60)),
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
              const SizedBox(height: 12),
              ..._sounds.map((sound) {
                final isPlaying = _playing[sound.id] ?? false;
                final volume = _volumes[sound.id] ?? 0.4;

                return _SoundCard(
                  sound: sound,
                  isPlaying: isPlaying,
                  volume: volume,
                  onToggle: () => _toggleSound(sound),
                  onVolumeChanged: (value) => _setVolume(sound, value),
                );
              }),
              const SizedBox(height: 12),
              Text(
                'Background playback enabled. Lock screen media controls depend on platform audio session support.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFBAC1E8),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({
    required this.activeCount,
    required this.timerText,
    required this.fading,
  });

  final int activeCount;
  final String timerText;
  final bool fading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xCC1B2451), Color(0xCC27346D)],
        ),
        border: Border.all(color: const Color(0x66AAB8FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Night Studio',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Blend soundscapes for sleep, focus and meditation.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFD4D9F5),
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.graphic_eq, text: '$activeCount active'),
              _InfoPill(icon: Icons.schedule, text: 'Timer $timerText'),
              if (fading)
                const _InfoPill(icon: Icons.nights_stay, text: 'Fading out'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x339FB1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFF3F6FF)),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x44172048),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x4DAAB8FF)),
      ),
      child: child,
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0x66B3BEFF)),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: Text(label),
    );
  }
}

class _SoundCard extends StatelessWidget {
  const _SoundCard({
    required this.sound,
    required this.isPlaying,
    required this.volume,
    required this.onToggle,
    required this.onVolumeChanged,
  });

  final SleepSound sound;
  final bool isPlaying;
  final double volume;
  final VoidCallback onToggle;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPlaying ? const Color(0x55202B58) : const Color(0x40161E3D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlaying ? sound.color.withValues(alpha: 0.85) : const Color(0x4DAAB8FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sound.color.withValues(alpha: 0.2),
                ),
                child: Icon(sound.icon, color: sound.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sound.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onToggle,
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
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: sound.color,
                    thumbColor: sound.color,
                    inactiveTrackColor: Colors.white24,
                  ),
                  child: Slider(
                    value: volume,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    onChanged: onVolumeChanged,
                  ),
                ),
              ),
              const Icon(Icons.volume_up, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}
