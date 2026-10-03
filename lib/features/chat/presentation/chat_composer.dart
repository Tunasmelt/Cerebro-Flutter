import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';

/// The message box. Send while idle; Stop while an answer is on its way.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.busy,
    required this.onSend,
    required this.onStop,
  });

  final bool busy;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend => !widget.busy && _controller.text.trim().isNotEmpty;

  void _send() {
    if (!_canSend) return;
    final text = _controller.text;
    _controller.clear();
    widget.onSend(text);
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: AppRadius.lgRadius,
    borderSide: BorderSide(color: color),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s2,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgBase,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('chat_input'),
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              style: AppTypography.base.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Ask your documents…',
                hintStyle: AppTypography.base.copyWith(
                  color: AppColors.textDisabled,
                ),
                filled: true,
                fillColor: AppColors.bgElevated,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4,
                  vertical: AppSpacing.s3,
                ),
                border: _border(AppColors.borderDefault),
                enabledBorder: _border(AppColors.borderDefault),
                focusedBorder: _border(AppColors.accentPrimaryBorder),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          if (widget.busy)
            IconButton.filled(
              key: const Key('chat_stop'),
              tooltip: 'Stop',
              onPressed: widget.onStop,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(AppSpacing.s12),
                backgroundColor: AppColors.bgRaised,
                foregroundColor: AppColors.textPrimary,
              ),
              icon: const Icon(Icons.stop_rounded),
            )
          else
            IconButton.filled(
              key: const Key('chat_send'),
              tooltip: 'Send',
              onPressed: _canSend ? _send : null,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(AppSpacing.s12),
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: AppColors.textOnAccent,
                disabledBackgroundColor: AppColors.bgRaised,
                disabledForegroundColor: AppColors.textDisabled,
              ),
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
        ],
      ),
    );
  }
}
