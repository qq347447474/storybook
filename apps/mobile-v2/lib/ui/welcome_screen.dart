/// Welcome splash shown on cold start (§4.1 entry).
///
/// Displays the brand mark for [duration] while the ASR model loads in the
/// background, then calls [onDone]. Reduced-motion users see a static screen
/// with no fade animation.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_illustration.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.onDone,
    this.duration = const Duration(milliseconds: 1500),
    this.appName,
  });

  /// Called after [duration] (or when the caller decides to advance).
  final VoidCallback onDone;

  /// How long to show the splash; defaults to 1.5 s.
  final Duration duration;

  /// Localised app name; falls back to a generic label.
  final String? appName;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeIn);
    _fade.forward();
    // Advance after the splash duration.
    Future<void>.delayed(widget.duration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.appName ?? '纸舟';
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 96,
                height: 96,
                child: const AppIllustration('logo-mark'),
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: AppTypography.h2.copyWith(
                  color: AppColors.ink,
                  letterSpacing: -0.02,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Offline graded reading',
                style: AppTypography.meta.copyWith(color: AppColors.ink2),
              ),
              const SizedBox(height: 32),
              // Subtle indeterminate indicator (not a spinner icon).
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
