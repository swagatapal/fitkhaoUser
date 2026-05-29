import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AnimEntrance
// ─────────────────────────────────────────────────────────────────────────────
//
// A self-contained entrance animation widget.
// Wrap any child to animate it in on first render with a fade + slide.
//
// ── Standalone section ───────────────────────────────────────────────────────
//   AnimEntrance(
//     delay: const Duration(milliseconds: 150),
//     child: MySummaryCard(),
//   )
//
// ── List items (staggered) ───────────────────────────────────────────────────
//   AnimEntrance(
//     delay: AnimEntrance.stagger(index),
//     child: MyCard(item: items[index]),
//   )
//
// ── Re-animate on content change ────────────────────────────────────────────
//   AnimEntrance(
//     key: ValueKey(selectedDay),   // key change triggers fresh animation
//     delay: const Duration(milliseconds: 100),
//     child: MyWidget(),
//   )
// ─────────────────────────────────────────────────────────────────────────────

class AnimEntrance extends StatefulWidget {
  const AnimEntrance({
    super.key,
    required this.child,
    this.delay     = Duration.zero,
    this.duration  = const Duration(milliseconds: 420),
    this.slideFrom = const Offset(0.0, 0.08),
    this.fade      = true,
    this.curve     = Curves.easeOutCubic,
  });

  /// The widget to animate.
  final Widget child;

  /// Wait this long before starting the animation. Use [stagger] for lists.
  final Duration delay;

  /// Total duration of the entrance animation.
  final Duration duration;

  /// Starting offset, expressed as a fraction of the widget's own size.
  /// `Offset(0, 0.08)` = slides up 8% of its own height (default, very subtle).
  /// `Offset(0, 0.20)` = more dramatic upward slide.
  /// `Offset(0.12, 0)` = slides in from the right.
  final Offset slideFrom;

  /// Whether to combine a fade-in with the slide. Defaults to true.
  final bool fade;

  /// Easing curve applied to both fade and slide.
  final Curve curve;

  // ── Static helpers ──────────────────────────────────────────────────────────

  /// Returns a [Duration] suitable for staggering list items.
  ///
  /// ```dart
  /// // index 0 → 60ms, index 1 → 115ms, index 2 → 170ms …
  /// AnimEntrance(delay: AnimEntrance.stagger(index), child: card)
  /// ```
  ///
  /// [baseMs] — delay before the first item animates.
  /// [stepMs] — additional delay per index increment.
  static Duration stagger(
      int index, {
        int baseMs = 60,
        int stepMs = 55,
      }) =>
      Duration(milliseconds: baseMs + index * stepMs);

  /// Returns a [Duration] for section-level stagger (coarser gaps).
  ///
  /// ```dart
  /// AnimEntrance(delay: AnimEntrance.section(0), child: header)
  /// AnimEntrance(delay: AnimEntrance.section(1), child: summary)
  /// AnimEntrance(delay: AnimEntrance.section(2), child: list)
  /// ```
  static Duration section(int index, {int baseMs = 60, int stepMs = 80}) =>
      Duration(milliseconds: baseMs + index * stepMs);

  @override
  State<AnimEntrance> createState() => _AnimEntranceState();
}

class _AnimEntranceState extends State<AnimEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset>  _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slide   = Tween<Offset>(begin: widget.slideFrom, end: Offset.zero)
        .animate(curved);

    _play();
  }

  Future<void> _play() async {
    if (widget.delay != Duration.zero) {
      await Future.delayed(widget.delay);
    }
    if (mounted) _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = SlideTransition(position: _slide, child: widget.child);

    if (widget.fade) {
      result = FadeTransition(opacity: _opacity, child: result);
    }

    return result;
  }
}
