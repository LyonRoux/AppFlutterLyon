import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const PomodoroApp());
}

// ─────────────────────────────────────────────
// COMPANION STATE
// ─────────────────────────────────────────────
enum CompanionState {
  idle,
  workTransitionIn,
  working,
  workTransitionOut,
  restTransitionIn,
  resting,
  restTransitionOut,
}

// Modo de sesión — independiente del companion
enum SessionMode { work, rest }

// ─────────────────────────────────────────────
// SPRITE CONFIG — edita aquí para mapear tus PNGs
// Pon tus imágenes en assets/sprites/ y actualiza las listas
// ─────────────────────────────────────────────
class SpriteConfig {
  static const List<String> idleFrames = [
    'assets/sprites/shime5.png',
    'assets/sprites/shime6.png',
    'assets/sprites/shime7.png',
    'assets/sprites/shime8.png',
    'assets/sprites/shime9.png',
    'assets/sprites/shime10.png',
    'assets/sprites/shime9.png',
    'assets/sprites/shime8.png',
    'assets/sprites/shime7.png',
    'assets/sprites/shime6.png',
  ];

  // Transición al iniciar Work (one-shot → working)
  static const List<String> workTransitionInFrames = [
    'assets/sprites/shime19.png',
    'assets/sprites/shime4.png',
    'assets/sprites/shime1.png',
  ];

  static const List<String> workingFrames = [
    'assets/sprites/shime2.png',
    'assets/sprites/shime3.png',
  ];

  // Transición al salir de Work (one-shot → idle)
  static const List<String> workTransitionOutFrames = [
    'assets/sprites/shime1.png',
    'assets/sprites/shime22.png',
  ];

  // Transición al iniciar Rest (one-shot → resting)
  static const List<String> restTransitionInFrames = [
    'assets/sprites/shime19.png',
    'assets/sprites/shime4.png',
    'assets/sprites/shime1.png',
    'assets/sprites/shime11.png',
  ];

  static const List<String> restingFrames = [
    'assets/sprites/shime15.png',
    'assets/sprites/shime16.png',
    'assets/sprites/shime17.png',
    'assets/sprites/shime15.png',
    'assets/sprites/shime26.png',
    'assets/sprites/shime27.png',
  ];

  // Transición al salir de Rest (one-shot → idle)
  static const List<String> restTransitionOutFrames = [
    'assets/sprites/shime28.png',
    'assets/sprites/shime29.png',
    'assets/sprites/shime49.png',
    'assets/sprites/shime28.png',
    'assets/sprites/shime29.png',
    'assets/sprites/shime11.png',
    'assets/sprites/shime1.png',
    'assets/sprites/shime22.png',
  ];

  // Velocidad de animación (ms entre frames)
  static const int frameIntervalMs = 300;
}

// ─────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────
class AppTheme {
  static const Color bg = Color(0xFFF7F4EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1C1C1C);
  static const Color inkLight = Color(0xFF8A8580);
  static const Color accent = Color(0xFFD4573C);
  static const Color accentSoft = Color(0xFFFAEDE9);
  static const Color rest = Color(0xFF4A7C6F);
  static const Color restSoft = Color(0xFFE6F2EF);
  static const Color border = Color(0xFFE8E4DD);
  static const Color timerRing = Color(0xFFEDE9E2);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.light(
          primary: accent,
          surface: surface,
          onPrimary: Colors.white,
          onSurface: ink,
        ),
        fontFamily: 'Georgia',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w300,
            letterSpacing: -2,
            color: ink,
            fontFamily: 'Georgia',
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: ink,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: inkLight,
            height: 1.6,
          ),
        ),
      );
}

// ─────────────────────────────────────────────
// ROOT APP
// ─────────────────────────────────────────────
class PomodoroApp extends StatelessWidget {
  const PomodoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const PomodoroScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────
class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
  // Timer state
  int _totalSeconds = 25 * 60;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  bool _isPaused = false;
  Timer? _timer;

  // Session mode (work vs rest) — separado del companion
  SessionMode _sessionMode = SessionMode.work;

  // Pomodoro counter (0-4: cuántos work completados en el ciclo actual)
  int _completedPomodoros = 0;

  // Session state
  CompanionState _companionState = CompanionState.idle;
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _minutesController =
      TextEditingController(text: '25');
  final TextEditingController _restController =
      TextEditingController(text: '5');

  // Sprite animation
  int _currentFrame = 0;
  Timer? _spriteTimer;

  // Progress ring animation
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _startSpriteAnimation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spriteTimer?.cancel();
    _ringController.dispose();
    _taskController.dispose();
    _minutesController.dispose();
    _restController.dispose();
    super.dispose();
  }

  // ── Sprite animation ──────────────────────

  // Estados one-shot — avanzan solos al terminar
  bool get _isTransitionState =>
      _companionState == CompanionState.workTransitionIn ||
      _companionState == CompanionState.workTransitionOut ||
      _companionState == CompanionState.restTransitionIn ||
      _companionState == CompanionState.restTransitionOut;

  // Qué estado sigue después de cada transición
  CompanionState _nextStateAfterTransition() {
    switch (_companionState) {
      case CompanionState.workTransitionIn:
        return CompanionState.working;
      case CompanionState.workTransitionOut:
        return CompanionState.idle;
      case CompanionState.restTransitionIn:
        return CompanionState.resting;
      case CompanionState.restTransitionOut:
        return CompanionState.idle;
      default:
        return CompanionState.idle;
    }
  }

  void _startSpriteAnimation() {
    _spriteTimer?.cancel();
    _spriteTimer = Timer.periodic(
      Duration(milliseconds: SpriteConfig.frameIntervalMs),
      (_) {
        final frames = _getFramesForState(_companionState);
        if (frames.isEmpty) return;

        final nextFrame = _currentFrame + 1;

        if (_isTransitionState && nextFrame >= frames.length) {
          _setCompanionState(_nextStateAfterTransition());
        } else {
          setState(() {
            _currentFrame = nextFrame % frames.length;
          });
        }
      },
    );
  }

  List<String> _getFramesForState(CompanionState state) {
    switch (state) {
      case CompanionState.idle:
        return SpriteConfig.idleFrames;
      case CompanionState.workTransitionIn:
        return SpriteConfig.workTransitionInFrames;
      case CompanionState.working:
        return SpriteConfig.workingFrames;
      case CompanionState.workTransitionOut:
        return SpriteConfig.workTransitionOutFrames;
      case CompanionState.restTransitionIn:
        return SpriteConfig.restTransitionInFrames;
      case CompanionState.resting:
        return SpriteConfig.restingFrames;
      case CompanionState.restTransitionOut:
        return SpriteConfig.restTransitionOutFrames;
    }
  }

  void _setCompanionState(CompanionState state) {
    setState(() {
      _companionState = state;
      _currentFrame = 0;
    });
  }

  // ── Timer logic ───────────────────────────
  void _applyCustomTime() {
    final mins = int.tryParse(_minutesController.text);
    if (mins == null || mins <= 0) return;
    setState(() {
      _totalSeconds = mins * 60;
      _remainingSeconds = mins * 60;
      _isRunning = false;
      _isPaused = false;
    });
    _timer?.cancel();
    _setCompanionState(CompanionState.idle);
  }

  void _startTimer() {
    if (_remainingSeconds == 0) return;
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });
    // Siempre inicia con la transición de entrada del modo actual
    _setCompanionState(
      _sessionMode == SessionMode.rest
          ? CompanionState.restTransitionIn
          : CompanionState.workTransitionIn,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds <= 0) {
        t.cancel();
        _onTimerComplete();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
    // Transición de salida del modo actual → idle
    _setCompanionState(
      _sessionMode == SessionMode.rest
          ? CompanionState.restTransitionOut
          : CompanionState.workTransitionOut,
    );
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _totalSeconds;
      _isRunning = false;
      _isPaused = false;
      _sessionMode = SessionMode.work;
    });
    _setCompanionState(CompanionState.idle);
  }

  void _onTimerComplete() {
    if (_sessionMode == SessionMode.work) {
      // Work terminó → incrementa pomodoro, precarga rest
      final restMins = int.tryParse(_restController.text) ?? 5;
      setState(() {
        _isRunning = false;
        _isPaused = false;
        _sessionMode = SessionMode.rest;
        _totalSeconds = restMins * 60;
        _remainingSeconds = restMins * 60;
        if (_completedPomodoros < 4) _completedPomodoros++;
      });
      _setCompanionState(CompanionState.workTransitionOut);
    } else {
      // Rest terminó → si era el 4to descanso, resetea contador
      final mins = int.tryParse(_minutesController.text) ?? 25;
      setState(() {
        _isRunning = false;
        _isPaused = false;
        _sessionMode = SessionMode.work;
        _totalSeconds = mins * 60;
        _remainingSeconds = mins * 60;
        if (_completedPomodoros >= 4) _completedPomodoros = 0;
      });
      _setCompanionState(CompanionState.restTransitionOut);
    }
  }

  // ── Helpers ───────────────────────────────
  double get _progress =>
      _totalSeconds > 0 ? _remainingSeconds / _totalSeconds : 0;

  String get _timeString {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _accentColor =>
      _sessionMode == SessionMode.rest ? AppTheme.rest : AppTheme.accent;

  Color get _accentSoftColor =>
      _sessionMode == SessionMode.rest ? AppTheme.restSoft : AppTheme.accentSoft;

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildCompanion(),
              const SizedBox(height: 32),
              _buildTimerCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'focus.',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: AppTheme.ink,
                fontFamily: 'Georgia',
              ),
            ),
            Text(
              _statusLabel,
              style: TextStyle(
                fontSize: 12,
                color: _accentColor,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        _buildStatusBadge(),
      ],
    );
  }

  String get _statusLabel {
    if (_companionState == CompanionState.resting) return 'BREAK TIME';
    if (_isRunning) return 'IN SESSION';
    if (_isPaused) return 'PAUSED';
    return 'READY';
  }

  Widget _buildStatusBadge() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _accentSoftColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _isRunning ? _accentColor : AppTheme.inkLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isRunning ? 'live' : 'idle',
            style: TextStyle(
              fontSize: 12,
              color: _isRunning ? _accentColor : AppTheme.inkLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Companion ─────────────────────────────
  Widget _buildCompanion() {
    final frames = _getFramesForState(_companionState);
    final hasSprites = frames.isNotEmpty;

    return Center(
      child: SizedBox(
        width: 128,
        height: 128,
        child: hasSprites
            ? Image.asset(
                frames[_currentFrame % frames.length],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _placeholderCompanion(),
              )
            : _placeholderCompanion(),
      ),
    );
  }

  Widget _placeholderCompanion() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _companionEmoji,
          style: const TextStyle(fontSize: 52),
        ),
        const SizedBox(height: 4),
        Text(
          _companionStateLabel,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.inkLight,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  String get _companionEmoji {
    switch (_companionState) {
      case CompanionState.idle:
        return '🐾';
      case CompanionState.workTransitionIn:
        return '⚡';
      case CompanionState.working:
        return '✏️';
      case CompanionState.workTransitionOut:
        return '😮‍💨';
      case CompanionState.restTransitionIn:
        return '🌙';
      case CompanionState.resting:
        return '💤';
      case CompanionState.restTransitionOut:
        return '🌅';
    }
  }

  String get _companionStateLabel {
    switch (_companionState) {
      case CompanionState.idle:
        return 'idle';
      case CompanionState.workTransitionIn:
        return 'starting...';
      case CompanionState.working:
        return 'working';
      case CompanionState.workTransitionOut:
        return 'wrapping up...';
      case CompanionState.restTransitionIn:
        return 'winding down...';
      case CompanionState.resting:
        return 'resting';
      case CompanionState.restTransitionOut:
        return 'waking up...';
    }
  }

  // ── Timer Card ────────────────────────────
  void _showTimerConfigDialog() {
    final workTemp = TextEditingController(text: _minutesController.text);
    final restTemp = TextEditingController(text: _restController.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Set durations',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogTimeRow(
              label: 'Work',
              icon: Icons.edit_rounded,
              color: AppTheme.accent,
              softColor: AppTheme.accentSoft,
              controller: workTemp,
            ),
            const SizedBox(height: 16),
            _DialogTimeRow(
              label: 'Rest',
              icon: Icons.coffee_rounded,
              color: AppTheme.rest,
              softColor: AppTheme.restSoft,
              controller: restTemp,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.inkLight)),
          ),
          TextButton(
            onPressed: () {
              final mins = int.tryParse(workTemp.text);
              final rest = int.tryParse(restTemp.text);
              if (mins != null && mins > 0) {
                _minutesController.text = workTemp.text;
                if (_sessionMode == SessionMode.work) {
                  setState(() {
                    _totalSeconds = mins * 60;
                    _remainingSeconds = mins * 60;
                  });
                }
              }
              if (rest != null && rest > 0) {
                _restController.text = restTemp.text;
                if (_sessionMode == SessionMode.rest) {
                  setState(() {
                    _totalSeconds = rest * 60;
                    _remainingSeconds = rest * 60;
                  });
                }
              }
              Navigator.pop(ctx);
            },
            child: Text('Save',
                style: TextStyle(
                    color: _accentColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress ring + time (tappable para configurar duración)
          GestureDetector(
            onTap: _isRunning ? null : _showTimerConfigDialog,
            child: _buildProgressRing(),
          ),
          const SizedBox(height: 20),
          // Pomodoro tracker
          _buildPomodoroTracker(),
          const SizedBox(height: 20),
          // Divider
          Container(height: 1, color: AppTheme.border),
          const SizedBox(height: 20),
          // Controls
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildProgressRing() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 8,
              color: AppTheme.timerRing,
            ),
          ),
          // Progress ring
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 8,
              color: _accentColor,
              strokeCap: StrokeCap.round,
            ),
          ),
          // Time display
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _timeString,
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -2,
                  color: AppTheme.ink,
                  fontFamily: 'Georgia',
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _taskController,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  minLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.inkLight,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'working on...',
                    hintStyle: TextStyle(
                      color: AppTheme.inkLight.withOpacity(0.35),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (!_isRunning) ...[
                const SizedBox(height: 6),
                Text(
                  'tap to set time',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.inkLight.withOpacity(0.3),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInput() {
    // Solo muestra el chip del modo activo
    if (_sessionMode == SessionMode.rest) {
      return _TimeInputChip(
        label: 'Rest',
        controller: _restController,
        enabled: !_isRunning,
        color: AppTheme.rest,
        softColor: AppTheme.restSoft,
        icon: Icons.coffee_rounded,
        onSubmitted: _applyCustomTime,
      );
    }
    return _TimeInputChip(
      label: 'Work',
      controller: _minutesController,
      enabled: !_isRunning,
      color: AppTheme.accent,
      softColor: AppTheme.accentSoft,
      icon: Icons.edit_rounded,
      onSubmitted: _applyCustomTime,
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Work — izquierda
        _ControlButton(
          icon: Icons.edit_rounded,
          onTap: () {
            if (!_isRunning) {
              _timer?.cancel();
              final mins = int.tryParse(_minutesController.text) ?? 25;
              setState(() {
                _sessionMode = SessionMode.work;
                _totalSeconds = mins * 60;
                _remainingSeconds = mins * 60;
                _isPaused = false;
              });
              _setCompanionState(CompanionState.idle);
            }
          },
          color: _sessionMode == SessionMode.work
              ? AppTheme.accent
              : AppTheme.inkLight,
          bgColor: _sessionMode == SessionMode.work
              ? AppTheme.accentSoft
              : AppTheme.bg,
          size: 48,
          tooltip: 'Work mode',
        ),
        const SizedBox(width: 16),
        // Play / Pause (primary)
        _ControlButton(
          icon: _isRunning
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          onTap: _isRunning ? _pauseTimer : _startTimer,
          color: Colors.white,
          bgColor: _accentColor,
          size: 64,
          iconSize: 32,
        ),
        const SizedBox(width: 16),
        // Break — derecha
        _ControlButton(
          icon: Icons.coffee_rounded,
          onTap: () {
            if (!_isRunning) {
              _timer?.cancel();
              setState(() {
                _sessionMode = SessionMode.rest;
                _totalSeconds = (int.tryParse(_restController.text) ?? 5) * 60;
                _remainingSeconds = (int.tryParse(_restController.text) ?? 5) * 60;
                _isPaused = false;
                // companion se mantiene en idle — solo cambia al play
              });
            }
          },
          color: _sessionMode == SessionMode.rest
              ? AppTheme.rest
              : AppTheme.inkLight,
          bgColor: _sessionMode == SessionMode.rest
              ? AppTheme.restSoft
              : AppTheme.bg,
          size: 48,
          tooltip: 'Break mode',
        ),
      ],
    );
  }

  // ── Pomodoro tracker ──────────────────────
  Widget _buildPomodoroTracker() {
    // Paths — reemplaza con tus PNGs cuando los tengas
    // 'assets/pomodoro_empty.png' y 'assets/pomodoro_filled.png'
    const emptyAsset = 'assets/emptycat.png';
    const filledAsset = 'assets/filledcat.png';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(4, (i) {
          final filled = i < _completedPomodoros;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: emptyAsset.isEmpty
                ? _PomodoroSlot(filled: filled)
                : Image.asset(
                    filled ? filledAsset : emptyAsset,
                    width: 32,
                    height: 32,
                  ),
          );
        }),
        const SizedBox(width: 12),
        // Reset manual
        GestureDetector(
          onTap: () => setState(() => _completedPomodoros = 0),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(Icons.refresh_rounded,
                size: 14, color: AppTheme.inkLight),
          ),
        ),
      ],
    );
  }

  // ── Debug ─────────────────────────────────
  Widget _buildDebugButton() {
    return GestureDetector(
      onTap: () {
        _timer?.cancel();
        setState(() {
          _totalSeconds = 3;
          _remainingSeconds = 3;
          _isRunning = false;
          _isPaused = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withOpacity(0.4)),
        ),
        child: const Text(
          '⚠️ debug: 3s',
          style: TextStyle(fontSize: 11, color: Colors.orange),
        ),
      ),
    );
  }

  // ── Task field ────────────────────────────
  Widget _buildTaskField() {
    return TextField(
      controller: _taskController,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        color: AppTheme.inkLight,
        fontStyle: FontStyle.italic,
      ),
      decoration: InputDecoration(
        hintText: 'working on...',
        hintStyle: TextStyle(
          color: AppTheme.inkLight.withOpacity(0.4),
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}

// ─────────────────────────────────────────────
// POMODORO SLOT PLACEHOLDER
// Reemplaza con Image.asset cuando tengas los PNGs
// ─────────────────────────────────────────────
class _PomodoroSlot extends StatelessWidget {
  final bool filled;
  const _PomodoroSlot({required this.filled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: filled ? AppTheme.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: filled
              ? AppTheme.accent
              : AppTheme.inkLight.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          '🍅',
          style: TextStyle(
            fontSize: filled ? 16 : 14,
            color: filled ? Colors.white : AppTheme.inkLight.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DIALOG TIME ROW
// ─────────────────────────────────────────────
class _DialogTimeRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color softColor;
  final TextEditingController controller;

  const _DialogTimeRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.softColor,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: softColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.ink,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 56,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
              filled: true,
              fillColor: softColor,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('min',
            style: TextStyle(fontSize: 12, color: AppTheme.inkLight)),
      ],
    );
  }
}
class _TimeInputChip extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final Color color;
  final Color softColor;
  final IconData icon;
  final VoidCallback onSubmitted;

  const _TimeInputChip({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.color,
    required this.softColor,
    required this.icon,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: TextField(
              controller: controller,
              enabled: enabled,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onSubmitted: (_) => onSubmitted(),
            ),
          ),
          Text(
            'm',
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE CONTROL BUTTON
// ─────────────────────────────────────────────
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color bgColor;
  final double size;
  final double iconSize;
  final String? tooltip;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.bgColor,
    this.size = 48,
    this.iconSize = 22,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}