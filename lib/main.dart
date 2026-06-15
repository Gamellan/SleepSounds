import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        textTheme: GoogleFonts.dmSansTextTheme(),
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

class VisualPalette {
  const VisualPalette({
    required this.name,
    required this.bgTop,
    required this.bgBottom,
    required this.surface,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.mutedText,
  });

  final String name;
  final Color bgTop;
  final Color bgBottom;
  final Color surface;
  final Color border;
  final Color primary;
  final Color secondary;
  final Color mutedText;
}

class SleepSoundsHomePage extends StatefulWidget {
  const SleepSoundsHomePage({super.key});

  @override
  State<SleepSoundsHomePage> createState() => _SleepSoundsHomePageState();
}

class _SleepSoundsHomePageState extends State<SleepSoundsHomePage>
    with SingleTickerProviderStateMixin {
  static const String _paletteKey = 'sleep_palette_idx';
  static const String _playingIdsKey = 'sleep_playing_ids';
  static const String _volumePrefix = 'sleep_volume_';

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

  final List<VisualPalette> _palettes = const [
    VisualPalette(
      name: 'Aurora',
      bgTop: Color(0xFF0B1023),
      bgBottom: Color(0xFF171F45),
      surface: Color(0x55202B58),
      border: Color(0x66AAB8FF),
      primary: Color(0xFF8EA8FF),
      secondary: Color(0xFF72E6C8),
      mutedText: Color(0xFFBAC1E8),
    ),
    VisualPalette(
      name: 'Sunset',
      bgTop: Color(0xFF20112A),
      bgBottom: Color(0xFF3E1C36),
      surface: Color(0x55B24671),
      border: Color(0x66FFB58A),
      primary: Color(0xFFFF9D7A),
      secondary: Color(0xFFFFD082),
      mutedText: Color(0xFFF4C9BF),
    ),
    VisualPalette(
      name: 'Forest Night',
      bgTop: Color(0xFF0C1A1A),
      bgBottom: Color(0xFF153230),
      surface: Color(0x55396F63),
      border: Color(0x668BE4CC),
      primary: Color(0xFF7ADBBE),
      secondary: Color(0xFFB8F28A),
      mutedText: Color(0xFFC6EADF),
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

  late final AnimationController _breathingController;

  Timer? _sleepTimer;
  Timer? _fadeTimer;
  DateTime? _sleepEnd;
  Duration? _remaining;
  bool _isFading = false;
  int _selectedPaletteIndex = 0;

  VisualPalette get _palette => _palettes[_selectedPaletteIndex];

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

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

    unawaited(_restorePreferences());
  }

  int get _activeCount => _playing.values.where((isOn) => isOn).length;

  Future<void> _toggleSound(SleepSound sound) async {
    final player = _players[sound.id]!;
    final isPlaying = _playing[sound.id] ?? false;

    if (isPlaying) {
      await player.stop();
      setState(() {
        _playing[sound.id] = false;
      });
      unawaited(_persistPreferences());
      return;
    }

    await player.setVolume(_volumes[sound.id] ?? 0.4);
    await player.play(AssetSource(sound.assetPath.replaceFirst('assets/', '')));
    setState(() {
      _playing[sound.id] = true;
    });
    unawaited(_persistPreferences());
  }

  Future<void> _setVolume(SleepSound sound, double value) async {
    final player = _players[sound.id]!;
    _volumes[sound.id] = value;
    await player.setVolume(_isFading ? value * _fadeFactor() : value);
    setState(() {});
    unawaited(_persistPreferences());
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
    unawaited(_persistPreferences());
  }

  Future<void> _stopAll() async {
    _cancelSleepTimer();
    for (final sound in _sounds) {
      await _players[sound.id]!.stop();
      _playing[sound.id] = false;
    }
    setState(() {});
    unawaited(_persistPreferences());
  }

  void _startSleepTimer(Duration duration) {
    _cancelSleepTimer();
    _sleepEnd = DateTime.now().add(duration);
    _remaining = duration;
    _syncBreathingCadence();

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _sleepEnd!.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _remaining = Duration.zero;
        _stopAll();
        return;
      }

      _remaining = remaining;
      _syncBreathingCadence();

      if (remaining <= const Duration(seconds: 20) && !_isFading) {
        _startFadeOut();
      }

      if (mounted) {
        setState(() {});
      }
    });

    setState(() {});
    unawaited(_persistPreferences());
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEnd = null;
    _remaining = null;
    _stopFadeOut();
    _syncBreathingCadence();
    unawaited(_persistPreferences());
  }

  Future<void> _quickSleep() async {
    final quickPreset = const MixPreset(
      name: 'Sleep now',
      volumes: {
        'rain': 0.40,
        'white_noise': 0.50,
      },
    );
    await _applyPreset(quickPreset);
    _startSleepTimer(const Duration(minutes: 30));
  }

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final storedPalette = prefs.getInt(_paletteKey);
    if (storedPalette != null && storedPalette >= 0 && storedPalette < _palettes.length) {
      _selectedPaletteIndex = storedPalette;
    }

    for (final sound in _sounds) {
      final savedVolume = prefs.getDouble('$_volumePrefix${sound.id}');
      if (savedVolume != null) {
        _volumes[sound.id] = savedVolume.clamp(0.0, 1.0);
      }
    }

    if (mounted) {
      setState(() {});
    }

    final playingIds = prefs.getStringList(_playingIdsKey) ?? const <String>[];
    for (final id in playingIds) {
      SleepSound? sound;
      for (final item in _sounds) {
        if (item.id == id) {
          sound = item;
          break;
        }
      }
      if (sound != null) {
        await _startSoundIfNeeded(sound);
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startSoundIfNeeded(SleepSound sound) async {
    if (_playing[sound.id] == true) {
      return;
    }

    final player = _players[sound.id]!;
    await player.setVolume(_volumes[sound.id] ?? 0.4);
    await player.play(AssetSource(sound.assetPath.replaceFirst('assets/', '')));
    _playing[sound.id] = true;
  }

  Future<void> _persistPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_paletteKey, _selectedPaletteIndex);

    for (final sound in _sounds) {
      await prefs.setDouble('$_volumePrefix${sound.id}', _volumes[sound.id] ?? 0.4);
    }

    final playingIds = _playing.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList(growable: false);
    await prefs.setStringList(_playingIdsKey, playingIds);
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

  void _syncBreathingCadence() {
    final remaining = _remaining;
    Duration nextDuration;

    if (remaining == null) {
      nextDuration = const Duration(seconds: 4);
    } else {
      final clampedSeconds = remaining.inSeconds.clamp(20, 3600);
      final ms = 1800 + ((clampedSeconds / 3600) * 3600).round();
      nextDuration = Duration(milliseconds: ms);
    }

    if (_breathingController.duration != nextDuration) {
      _breathingController.duration = nextDuration;
      if (_breathingController.isAnimating) {
        _breathingController
          ..reset()
          ..repeat(reverse: true);
      }
    }
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

  void _openNowPlaying() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NowPlayingPage(
          palette: _palette,
          sounds: _sounds,
          playing: _playing,
          volumes: _volumes,
          onToggle: _toggleSound,
          onSetVolume: _setVolume,
          breathing: _breathingController,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cancelSleepTimer();
    _breathingController.dispose();
    for (final player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerText = _remaining == null ? 'Off' : _formatDuration(_remaining!);

    return Scaffold(
      backgroundColor: _palette.bgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sleep Sounds'),
        actions: [
          IconButton(
            onPressed: _openNowPlaying,
            icon: const Icon(Icons.dark_mode_outlined),
            tooltip: 'Now Playing',
          ),
          IconButton(
            onPressed: _stopAll,
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: 'Stop all',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: -70,
            right: -40,
            child: _GlowBlob(size: 230, color: _palette.primary.withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: _GlowBlob(size: 250, color: _palette.secondary.withValues(alpha: 0.35)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_palette.bgTop, _palette.bgBottom],
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: [
                _PremiumHeader(
                  activeCount: _activeCount,
                  timerText: timerText,
                  fading: _isFading,
                  breathing: _breathingController,
                  palette: _palette,
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  palette: _palette,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_palettes.length, (index) {
                          final palette = _palettes[index];
                          final selected = index == _selectedPaletteIndex;
                          return ChoiceChip(
                            label: Text(palette.name),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _selectedPaletteIndex = index);
                              unawaited(_persistPreferences());
                            },
                            backgroundColor: _palette.surface,
                            selectedColor: palette.primary.withValues(alpha: 0.35),
                            labelStyle: const TextStyle(color: Colors.white),
                            side: BorderSide(
                              color: selected ? palette.primary : _palette.border,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  palette: _palette,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick Start', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _quickSleep,
                        icon: const Icon(Icons.hotel_outlined),
                        label: const Text('Sleep now (30m)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _palette.secondary.withValues(alpha: 0.82),
                          foregroundColor: const Color(0xFF121421),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  palette: _palette,
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
                                  backgroundColor: _palette.primary.withValues(alpha: 0.25),
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
                  palette: _palette,
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
                            palette: _palette,
                            onTap: () => _startSleepTimer(const Duration(minutes: 15)),
                          ),
                          _TimerChip(
                            label: '30m',
                            palette: _palette,
                            onTap: () => _startSleepTimer(const Duration(minutes: 30)),
                          ),
                          _TimerChip(
                            label: '60m',
                            palette: _palette,
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
                    palette: _palette,
                    onToggle: () => _toggleSound(sound),
                    onVolumeChanged: (value) => _setVolume(sound, value),
                  );
                }),
                const SizedBox(height: 12),
                Text(
                  'Background playback enabled. Lock screen media controls depend on platform audio session support.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _palette.mutedText,
                      ),
                ),
              ],
            ),
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
    required this.breathing,
    required this.palette,
  });

  final int activeCount;
  final String timerText;
  final bool fading;
  final Animation<double> breathing;
  final VisualPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            palette.surface,
            palette.bgBottom.withValues(alpha: 0.85),
          ],
        ),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BreathingOrb(animation: breathing, palette: palette),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Night Studio',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'Breathing pulse synced with timer cadence',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.mutedText,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.graphic_eq, text: '$activeCount active', palette: palette),
              _InfoPill(icon: Icons.schedule, text: 'Timer $timerText', palette: palette),
              if (fading)
                _InfoPill(icon: Icons.nights_stay, text: 'Fading out', palette: palette),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreathingOrb extends StatelessWidget {
  const _BreathingOrb({required this.animation, required this.palette});

  final Animation<double> animation;
  final VisualPalette palette;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = 0.86 + (animation.value * 0.22);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  palette.secondary,
                  palette.primary,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text, required this.palette});

  final IconData icon;
  final String text;
  final VisualPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.palette});

  final Widget child;
  final VisualPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({
    required this.label,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final VoidCallback onTap;
  final VisualPalette palette;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: palette.border),
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
    required this.palette,
    required this.onToggle,
    required this.onVolumeChanged,
  });

  final SleepSound sound;
  final bool isPlaying;
  final double volume;
  final VisualPalette palette;
  final VoidCallback onToggle;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPlaying ? palette.surface : palette.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlaying ? sound.color.withValues(alpha: 0.85) : palette.border,
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
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primary.withValues(alpha: 0.22),
                  foregroundColor: Colors.white,
                ),
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

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({
    super.key,
    required this.palette,
    required this.sounds,
    required this.playing,
    required this.volumes,
    required this.onToggle,
    required this.onSetVolume,
    required this.breathing,
  });

  final VisualPalette palette;
  final List<SleepSound> sounds;
  final Map<String, bool> playing;
  final Map<String, double> volumes;
  final Future<void> Function(SleepSound sound) onToggle;
  final Future<void> Function(SleepSound sound, double value) onSetVolume;
  final Animation<double> breathing;

  @override
  Widget build(BuildContext context) {
    final active = sounds.where((sound) => playing[sound.id] == true).toList();

    return StatefulBuilder(
      builder: (context, setInnerState) {
        return Scaffold(
          backgroundColor: palette.bgTop,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Now Playing'),
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.bgTop, palette.bgBottom],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _BreathingOrb(animation: breathing, palette: palette),
                  const SizedBox(height: 12),
                  Text(
                    active.isEmpty ? 'Silence mode' : 'Deep focus mode',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    active.isEmpty
                        ? 'Start a sound mix from the main screen.'
                        : '${active.length} ambient tracks active',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.mutedText,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: active.isEmpty
                        ? Center(
                            child: Text(
                              'No active tracks',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          )
                        : ListView(
                            children: active.map((sound) {
                              final volume = volumes[sound.id] ?? 0.4;
                              return _SoundCard(
                                sound: sound,
                                isPlaying: true,
                                volume: volume,
                                palette: palette,
                                onToggle: () async {
                                  await onToggle(sound);
                                  setInnerState(() {});
                                },
                                onVolumeChanged: (value) async {
                                  await onSetVolume(sound, value);
                                  setInnerState(() {});
                                },
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
