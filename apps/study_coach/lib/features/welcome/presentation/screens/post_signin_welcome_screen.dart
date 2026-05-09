import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/onboarding/post_signin_welcome_store.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/pillar_theme.dart';

/// One-time welcome after first sign-in for this account. "Get started" opens home (dashboard).
class PostSigninWelcomeScreen extends ConsumerStatefulWidget {
  const PostSigninWelcomeScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<PostSigninWelcomeScreen> createState() =>
      _PostSigninWelcomeScreenState();
}

class _PostSigninWelcomeScreenState extends ConsumerState<PostSigninWelcomeScreen> {
  bool _busy = false;

  Future<void> _onGetStarted() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await PostSigninWelcomeStore.setCompleted(widget.uid);
      ref.invalidate(postSigninWelcomeCompletedProvider(widget.uid));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final titleStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: colorScheme.onSurface,
    );
    final highlightStyle = titleStyle?.copyWith(
      color: PillarColors.primary,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text.rich(
                TextSpan(
                  style: titleStyle,
                  children: [
                    TextSpan(text: '${strings.welcomeTitleLine1}\n'),
                    TextSpan(
                      text: strings.welcomeTitleHighlight,
                      style: highlightStyle,
                    ),
                    TextSpan(text: '\n${strings.welcomeTitleLine3}'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                height: 220,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _CoachOrb(),
                        const SizedBox(height: 18),
                        Container(
                          width: 120,
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.35),
                                blurRadius: 28,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: -2,
                      left: isRtl ? null : 0,
                      right: isRtl ? 18 : null,
                      child: _HelloBubble(text: strings.welcomeHello),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                strings.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _onGetStarted,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.onSurface,
                    elevation: 1.5,
                    shadowColor: colorScheme.shadow,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.9),
                    ),
                  ),
                  child: _busy
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colorScheme.primary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              strings.welcomeGetStarted,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 22,
                              color: colorScheme.onSurface,
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelloBubble extends StatelessWidget {
  const _HelloBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _CoachOrb extends StatelessWidget {
  const _CoachOrb();

  @override
  Widget build(BuildContext context) {
    const size = 148.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                startAngle: -math.pi / 3,
                endAngle: math.pi * 1.4,
                colors: [
                  Color(0xFFFF71CD),
                  Color(0xFF8B5CF6),
                  Color(0xFF6366F1),
                  Color(0xFFFB923C),
                  Color(0xFFFF71CD),
                ],
                stops: [0.0, 0.28, 0.52, 0.78, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x408B5CF6),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
          ),
          // Soft inner glow
          Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
          // "Eyes"
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 22),
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
