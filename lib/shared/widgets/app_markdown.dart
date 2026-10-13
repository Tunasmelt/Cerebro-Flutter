import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_typography.dart';

/// Renders Markdown (chat answers, file previews) in the app's type and colours.
///
/// Inline widgets use a delimiter absent from source text. Source Markdown
/// cannot forge trusted citations by spelling our internal placeholders.
class AppMarkdown extends StatelessWidget {
  const AppMarkdown({
    super.key,
    required this.data,
    this.inlineWidgets = const {},
    this.delimiter = '',
  });
  final String data;
  final Map<int, Widget> inlineWidgets;
  final String delimiter;

  String _plain(String text) => delimiter.isEmpty
      ? text
      : text.replaceAllMapped(
          RegExp('${RegExp.escape(delimiter)}(\\d+)\uE001'),
          (match) => '[${match[1]}]',
        );

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: MarkdownBody(
      data: data,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: AppTypography.base.copyWith(
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        code: AppTypography.mono(AppTypography.base).copyWith(
          color: AppColors.accentSecondary,
          backgroundColor: AppColors.bgRaised,
        ),
        a: AppTypography.base.copyWith(color: AppColors.accentSecondary),
        blockquoteDecoration: const BoxDecoration(
          color: AppColors.bgRaised,
          borderRadius: AppRadius.mdRadius,
        ),
        tableBorder: TableBorder.all(color: AppColors.borderDefault),
      ),
      inlineSyntaxes: [if (delimiter.isNotEmpty) _InlineSyntax(delimiter)],
      builders: {
        'trusted-citation': _InlineBuilder(inlineWidgets),
        'pre': _CodeBuilder(_plain, block: true),
        'code': _CodeBuilder(_plain),
      },
      // Model-supplied image links must not fetch remote tracking URLs on render.
      imageBuilder: (uri, title, alt) =>
          Text(alt ?? 'Image link', style: AppTypography.sm),
      onTapLink: (_, href, _) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri == null ||
            !{'https', 'http'}.contains(uri.scheme) ||
            uri.host.isEmpty) {
          return;
        }
        await Clipboard.setData(ClipboardData(text: href));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Link copied')));
        }
      },
    ),
  );
}

class _InlineSyntax extends md.InlineSyntax {
  _InlineSyntax(String delimiter)
    : super('${RegExp.escape(delimiter)}(\\d+)\uE001');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('trusted-citation', match[1]!);
    element.attributes['offset'] = match.start.toString();
    parser.addNode(element);
    return true;
  }
}

class _InlineBuilder extends MarkdownElementBuilder {
  _InlineBuilder(this.widgets);
  final Map<int, Widget> widgets;
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => KeyedSubtree(
    key: ValueKey('citation-${element.attributes['offset']}'),
    child:
        widgets[int.tryParse(element.textContent)] ?? const SizedBox.shrink(),
  );
}

class _CodeBuilder extends MarkdownElementBuilder {
  _CodeBuilder(this.plain, {this.block = false});
  final String Function(String) plain;
  final bool block;
  @override
  bool isBlockElement() => block;
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = plain(element.textContent);
    if (!block) {
      return Text(text, style: AppTypography.mono(AppTypography.base));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.bgRaised,
        borderRadius: AppRadius.mdRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Copy code',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Code copied')));
                }
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(text, style: AppTypography.mono(AppTypography.base)),
          ),
        ],
      ),
    );
  }
}
