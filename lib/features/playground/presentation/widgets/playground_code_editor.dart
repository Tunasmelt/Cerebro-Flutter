import 'package:flutter/material.dart';

import '../../../../shared/tokens/app_colors.dart';
import '../../../../shared/tokens/app_spacing.dart';
import '../../../../shared/tokens/app_typography.dart';

/// Code-editor-styled text block: line numbers gutter + monospace body.
///
/// Used for both the (editable, re-runnable) Prompt body and the
/// (read-only) Response body. Syntax highlighting is faked with manually
/// colored [TextSpan]s rather than a real highlighter package, per the
/// no-new-dependencies constraint. When [readOnly] is false, an
/// invisible-text [TextField] is stacked on top of the highlighted
/// backdrop so the surface is genuinely editable while still showing
/// violet/teal highlighting underneath.
class PlaygroundCodeEditor extends StatefulWidget {
  const PlaygroundCodeEditor({
    super.key,
    required this.controller,
    this.readOnly = false,
    this.highlighter = defaultHighlighter,
    this.minLines = 3,
  });

  final TextEditingController controller;
  final bool readOnly;
  final List<InlineSpan> Function(String text, TextStyle base) highlighter;
  final int minLines;

  /// {{template_var}} -> teal, a handful of prompt-scaffolding keywords
  /// -> violet, everything else -> primary text color. Good enough to
  /// read as "syntax highlighting" without a real tokenizer.
  static List<InlineSpan> defaultHighlighter(String text, TextStyle base) {
    final keywords = <String>[
      'retrieval system assistant',
      'grounded',
      'Question:',
      'Documents:',
      'Instructions:',
    ];
    final violet = base.copyWith(color: AppColors.accentPrimaryHover);
    final teal = base.copyWith(color: AppColors.accentSecondary);

    final spans = <InlineSpan>[];
    var cursor = 0;

    // Build a combined match list: {{...}} spans and keyword spans, then
    // walk the text emitting default/violet/teal runs in order.
    final matches = <_Match>[];
    final templateVarPattern = RegExp(r'\{\{[^}]*\}\}');
    for (final m in templateVarPattern.allMatches(text)) {
      matches.add(_Match(m.start, m.end, teal));
    }
    for (final kw in keywords) {
      var start = 0;
      while (true) {
        final idx = text.indexOf(kw, start);
        if (idx == -1) break;
        matches.add(_Match(idx, idx + kw.length, violet));
        start = idx + kw.length;
      }
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    for (final match in matches) {
      if (match.start < cursor) continue; // overlap guard
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start), style: base));
      }
      spans.add(TextSpan(text: text.substring(match.start, match.end), style: match.style));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: base));
    }
    return spans;
  }

  /// Highlighter for the Response body: bullets get a violet marker,
  /// a trailing "Key advantages:"-style label line is bolded.
  static List<InlineSpan> responseHighlighter(String text, TextStyle base) {
    final bold = base.copyWith(fontWeight: AppTypography.weightSemibold);
    final violetDot = base.copyWith(color: AppColors.accentPrimaryHover);
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('•')) {
        final indent = line.substring(0, line.indexOf('•'));
        spans.add(TextSpan(text: '$indent•', style: violetDot));
        spans.add(TextSpan(text: line.substring(line.indexOf('•') + 1), style: base));
      } else if (line.trimRight().endsWith(':') && line.trim().isNotEmpty) {
        spans.add(TextSpan(text: line, style: bold));
      } else {
        spans.add(TextSpan(text: line, style: base));
      }
      if (i != lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  @override
  State<PlaygroundCodeEditor> createState() => _PlaygroundCodeEditorState();
}

class _Match {
  _Match(this.start, this.end, this.style);
  final int start;
  final int end;
  final TextStyle style;
}

class _PlaygroundCodeEditorState extends State<PlaygroundCodeEditor> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.mono(AppTypography.sm).copyWith(
      color: AppColors.textPrimary,
      height: 22 / 13,
    );
    final lineCount = widget.controller.text.isEmpty
        ? widget.minLines
        : widget.controller.text.split('\n').length.clamp(widget.minLines, 999);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.bgBase,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LineNumbers(count: lineCount, style: base),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: widget.readOnly
                ? RichText(
                    text: TextSpan(
                      style: base,
                      children: widget.highlighter(widget.controller.text, base),
                    ),
                  )
                : Stack(
                    children: [
                      // Invisible-text field underneath: owns focus, the
                      // cursor, selection, and editing — painted first so
                      // nothing sits on top of it and hides it.
                      TextField(
                        controller: widget.controller,
                        maxLines: null,
                        minLines: widget.minLines,
                        style: base.copyWith(color: Colors.transparent),
                        cursorColor: AppColors.accentPrimary,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      // Highlighted text on top, purely visual — taps
                      // pass through to the TextField beneath it.
                      IgnorePointer(
                        child: RichText(
                          text: TextSpan(
                            style: base,
                            children: widget.highlighter(widget.controller.text, base),
                          ),
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

class _LineNumbers extends StatelessWidget {
  const _LineNumbers({required this.count, required this.style});

  final int count;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= count; i++)
          Text(
            '$i',
            style: style.copyWith(color: AppColors.textDisabled),
          ),
      ],
    );
  }
}
