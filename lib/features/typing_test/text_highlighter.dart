library text_highlighter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'typing_engine.dart';

/// Design-system colors used by the highlighter. Kept local so the
/// widget stays self-contained and testable.
const Color kHighlightCorrect = Color(0xFF34D399);
const Color kHighlightWrongBg = Color(0xFFF87171);
const Color kHighlightMuted = Color(0xFF64748B);
const Color kHighlightCursor = Colors.white;

/// Renders the target text with per-character highlighting based on
/// what the user has typed so far.
///
/// * Correctly typed characters → green
/// * Incorrect characters → red background
/// * Not-yet-typed characters → muted slate
/// * Current cursor position → a blinking white caret
class TextHighlighter extends StatelessWidget {
  const TextHighlighter({
    super.key,
    required this.targetText,
    required this.typedText,
    this.fontSize = 24.0,
    this.fontFamily,
    this.showCursor = true,
  });

  final String targetText;
  final String typedText;
  final double fontSize;
  final String? fontFamily;
  final bool showCursor;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: fontFamily,
      height: 1.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final spans = <InlineSpan>[];
    final cursorIndex = typedText.length;

    for (var i = 0; i < targetText.length; i++) {
      final char = targetText[i];

      // Inject the blinking cursor right before the character the user
      // is about to type.
      if (showCursor && i == cursorIndex) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: BlinkingCursor(
            height: fontSize * 1.2,
            color: kHighlightCursor,
          ),
        ));
      }

      if (i < typedText.length) {
        final isCorrect = typedText[i] == char;
        if (isCorrect) {
          spans.add(TextSpan(
            text: char,
            style: baseStyle.copyWith(color: kHighlightCorrect),
          ));
        } else {
          // Render wrong characters with a red background – show the
          // *expected* char so the user can see what they should have
          // typed (a common convention in typing tests).
          spans.add(TextSpan(
            text: char,
            style: baseStyle.copyWith(
              color: Colors.white,
              backgroundColor: kHighlightWrongBg,
            ),
          ));
        }
      } else {
        spans.add(TextSpan(
          text: char,
          style: baseStyle.copyWith(color: kHighlightMuted),
        ));
      }
    }

    // Trailing cursor when the caret sits past the last character.
    if (showCursor && cursorIndex >= targetText.length) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: BlinkingCursor(
          height: fontSize * 1.2,
          color: kHighlightCursor,
        ),
      ));
    }

    return RichText(
      textAlign: TextAlign.left,
      softWrap: true,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}

/// An invisible [TextField] that feeds keystrokes into a [TypingEngine].
///
/// Stacked on top (or underneath) of the visual highlighter so mobile
/// keyboards can be summoned without exposing the actual text widget.
class HiddenTypingField extends StatefulWidget {
  const HiddenTypingField({
    super.key,
    required this.engine,
    this.autofocus = true,
    this.focusNode,
  });

  final TypingEngine engine;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<HiddenTypingField> createState() => _HiddenTypingFieldState();
}

class _HiddenTypingFieldState extends State<HiddenTypingField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.engine.typedText);
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    widget.engine.addListener(_onEngineChanged);
  }

  void _onEngineChanged() {
    // Keep the hidden field in sync if the engine is reset externally.
    if (_controller.text != widget.engine.typedText) {
      _controller.value = TextEditingValue(
        text: widget.engine.typedText,
        selection: TextSelection.collapsed(
          offset: widget.engine.typedText.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineChanged);
    _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        textCapitalization: TextCapitalization.none,
        maxLines: 1,
        cursorWidth: 0,
        style: const TextStyle(color: Colors.transparent),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: widget.engine.onTextChanged,
        // Block the iOS predictive bar from inserting weird strings.
        inputFormatters: const <TextInputFormatter>[],
      ),
    );
  }
}

/// A simple blinking caret. Uses a 500ms AnimationController and
/// fades between opaque and transparent.
class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({
    super.key,
    this.width = 2.0,
    this.height = 24.0,
    this.color = Colors.white,
  });

  final double width;
  final double height;
  final Color color;

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
