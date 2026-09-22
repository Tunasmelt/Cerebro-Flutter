import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/tokens/app_colors.dart';
import '../../../shared/tokens/app_radius.dart';
import '../../../shared/tokens/app_spacing.dart';
import '../../../shared/tokens/app_typography.dart';
import 'widgets/playground_code_editor.dart';
import 'widgets/playground_stat_tile.dart';

/// Token Playground: an editable, re-runnable prompt-assembly screen.
///
/// Presentation-layer only — no backend exists yet for this feature, so
/// model list, stats, and the response body are static/mock local data.
/// Running the prompt simulates a call and refreshes the mock stats.
class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

enum _RunStatus { idle, running, completed }

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  // ---- Mock data -----------------------------------------------------

  static const _models = <String>[
    'cerebro-rerank-v2',
    'cerebro-embed-v3',
    'cerebro-chat-v1',
    'cerebro-chat-v1-mini',
  ];

  static const _templates = <String, String>{
    'Q&A with citations': 'You are a retrieval system assistant. Given the '
        'following user question and context documents, generate a '
        'concise, grounded answer with citations.\n\n'
        'Question: {{question}}\n'
        'Documents: {{context}}\n\n'
        'Instructions:\n'
        '- Use only the provided context.',
    'Summarization': 'You are a summarization assistant. Given the '
        'following document, produce a concise summary.\n\n'
        'Document: {{document}}\n\n'
        'Instructions:\n'
        '- Keep it under 3 sentences.',
    'Classification': 'You are a classification assistant. Given the '
        'following text, assign the most relevant label.\n\n'
        'Text: {{text}}\n'
        'Labels: {{labels}}\n\n'
        'Instructions:\n'
        '- Return only the label.',
  };

  static const _defaultPrompt =
      'You are a retrieval system assistant. Given the following user '
      'question and context documents, generate a concise, grounded '
      'answer with citations.\n\n'
      'Question: {{question}}\n'
      'Documents: {{context}}\n\n'
      'Instructions:\n'
      '- Use only the provided context.';

  static const _defaultResponse =
      'Hybrid vector search reduces reranking\nlatency by using a '
      'two-stage pipeline...\n\n'
      'Key advantages:\n'
      '• Higher recall with sparse + dense...';

  // ---- Editable state --------------------------------------------------

  late final TextEditingController _promptController =
      TextEditingController(text: _defaultPrompt);
  late final TextEditingController _responseController =
      TextEditingController(text: _defaultResponse);

  String _selectedModel = _models.first;
  double _temperature = 0.2;
  int _maxTokens = 512;
  bool _streamResponse = true;

  _RunStatus _status = _RunStatus.completed;
  String _elapsed = '1.8s';
  int _inputTokens = 824;
  int _outputTokens = 460;
  double _cost = 0.0042;
  int _latencyMs = 842;

  Timer? _runTimer;

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
  }

  @override
  void dispose() {
    _runTimer?.cancel();
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  void _onPromptChanged() => setState(() {}); // recompute live token count

  int get _totalTokens => _liveInputEstimate + _outputTokens;

  /// Very rough mock "tokenizer": ~1 token per 4 characters, matching
  /// the ballpark feel of real tokenizers without depending on one.
  int get _liveInputEstimate => (_promptController.text.length / 4).ceil();

  void _handleReset() {
    setState(() {
      _promptController.text = _defaultPrompt;
      _responseController.text = _defaultResponse;
      _selectedModel = _models.first;
      _temperature = 0.2;
      _maxTokens = 512;
      _streamResponse = true;
      _status = _RunStatus.completed;
      _elapsed = '1.8s';
      _inputTokens = 824;
      _outputTokens = 460;
      _cost = 0.0042;
      _latencyMs = 842;
    });
  }

  void _handleRunPrompt() {
    _runTimer?.cancel();
    setState(() => _status = _RunStatus.running);
    _runTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _status = _RunStatus.completed;
        _inputTokens = _liveInputEstimate;
        _outputTokens = 470 + (_maxTokens % 37);
        _cost = double.parse(
          (0.000004 * (_inputTokens + _outputTokens)).toStringAsFixed(4),
        );
        _latencyMs = 780 + (_maxTokens % 200);
        _elapsed = '${(_latencyMs / 1000).toStringAsFixed(1)}s';
        _responseController.text = _streamResponse
            ? '$_defaultResponse\n\nRe-run with temperature '
                '${_temperature.toStringAsFixed(1)} and max tokens '
                '$_maxTokens.'
            : _defaultResponse;
      });
    });
  }

  void _handleInsertTemplate(String templateKey) {
    final snippet = _templates[templateKey];
    if (snippet == null) return;
    setState(() => _promptController.text = snippet);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              tokenCount: _totalTokens,
              onReset: _handleReset,
            ),
            const Divider(height: 1, color: AppColors.borderSubtle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s4,
                  AppSpacing.s4,
                  AppSpacing.s8,
                ),
                children: [
                  _ModelCard(
                    selectedModel: _selectedModel,
                    models: _models,
                    onChanged: (model) => setState(() => _selectedModel = model),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  _StatsCard(
                    inputTokens: _inputTokens,
                    outputTokens: _outputTokens,
                    cost: _cost,
                    latencyMs: _latencyMs,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  _PromptCard(
                    controller: _promptController,
                    templates: _templates.keys.toList(),
                    onInsertTemplate: _handleInsertTemplate,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  _RunControls(
                    temperature: _temperature,
                    onTemperatureChanged: (v) => setState(() => _temperature = v),
                    maxTokens: _maxTokens,
                    onMaxTokensChanged: (v) => setState(() => _maxTokens = v),
                    streamResponse: _streamResponse,
                    onStreamChanged: (v) => setState(() => _streamResponse = v),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  _RunPromptButton(
                    running: _status == _RunStatus.running,
                    onPressed: _handleRunPrompt,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  _ResponseCard(
                    status: _status,
                    elapsed: _elapsed,
                    controller: _responseController,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tokenCount, required this.onReset});

  final int tokenCount;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s4,
        AppSpacing.s4,
      ),
      child: Row(
        children: [
          Container(
            width: AppSpacing.minTouchTarget,
            height: AppSpacing.minTouchTarget,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary,
              borderRadius: AppRadius.mdRadius,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: AppColors.textOnAccent,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Token Playground',
                  style: AppTypography.lg.copyWith(
                    fontFamily: AppTypography.fontFamilyDisplay,
                    fontWeight: AppTypography.weightSemibold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$tokenCount tokens',
                  style: AppTypography.mono(AppTypography.sm).copyWith(
                    color: AppColors.accentSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          _IconSquareButton(icon: Icons.refresh, onPressed: onReset),
          const SizedBox(width: AppSpacing.s2),
          _IconSquareButton(
            icon: Icons.more_vert,
            onPressed: () => _showOverflowMenu(context),
          ),
        ],
      ),
    );
  }

  void _showOverflowMenu(BuildContext context) {
    showMenu<void>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 16, 0),
      color: AppColors.bgElevated,
      items: const [
        PopupMenuItem(child: Text('Duplicate playground')),
        PopupMenuItem(child: Text('Export as cURL')),
        PopupMenuItem(child: Text('Clear run history')),
      ],
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  const _IconSquareButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgElevated,
      borderRadius: AppRadius.mdRadius,
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        onTap: onPressed,
        child: Container(
          width: AppSpacing.minTouchTarget,
          height: AppSpacing.minTouchTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdRadius,
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 20),
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.selectedModel,
    required this.models,
    required this.onChanged,
  });

  final String selectedModel;
  final List<String> models;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Model',
            style: AppTypography.sm.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s2),
          _Selector<String>(
            value: selectedModel,
            leading: const Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            items: models,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Selector<T> extends StatelessWidget {
  const _Selector({
    required this.value,
    required this.leading,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final Widget leading;
  final List<T> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        onTap: () async {
          final selected = await showMenu<T>(
            context: context,
            position: const RelativeRect.fromLTRB(16, 300, 16, 0),
            color: AppColors.bgElevated,
            items: [
              for (final item in items)
                PopupMenuItem<T>(
                  value: item,
                  child: Text('$item'),
                ),
            ],
          );
          if (selected != null) onChanged(selected);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdRadius,
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  '$value',
                  style: AppTypography.mono(AppTypography.base).copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.inputTokens,
    required this.outputTokens,
    required this.cost,
    required this.latencyMs,
  });

  final int inputTokens;
  final int outputTokens;
  final double cost;
  final int latencyMs;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: PlaygroundStatTile(label: 'INPUT', value: '$inputTokens'),
              ),
              Expanded(
                child: PlaygroundStatTile(label: 'OUTPUT', value: '$outputTokens'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: PlaygroundStatTile(
                  label: 'COST',
                  value: '\$${cost.toStringAsFixed(4)}',
                ),
              ),
              Expanded(
                child: PlaygroundStatTile(label: 'LATENCY', value: '${latencyMs}ms'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.controller,
    required this.templates,
    required this.onInsertTemplate,
  });

  final TextEditingController controller;
  final List<String> templates;
  final ValueChanged<String> onInsertTemplate;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Prompt',
                  style: AppTypography.md.copyWith(
                    fontWeight: AppTypography.weightSemibold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _InsertTemplateButton(
                templates: templates,
                onSelected: onInsertTemplate,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          PlaygroundCodeEditor(controller: controller),
        ],
      ),
    );
  }
}

class _InsertTemplateButton extends StatelessWidget {
  const _InsertTemplateButton({required this.templates, required this.onSelected});

  final List<String> templates;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        onTap: () async {
          final selected = await showMenu<String>(
            context: context,
            position: const RelativeRect.fromLTRB(1000, 300, 16, 0),
            color: AppColors.bgElevated,
            items: [
              for (final template in templates)
                PopupMenuItem<String>(value: template, child: Text(template)),
            ],
          );
          if (selected != null) onSelected(selected);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdRadius,
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '{}',
                style: AppTypography.mono(AppTypography.sm).copyWith(
                  color: AppColors.accentSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.s1),
              Text(
                'Insert template',
                style: AppTypography.sm.copyWith(color: AppColors.textPrimary),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunControls extends StatelessWidget {
  const _RunControls({
    required this.temperature,
    required this.onTemperatureChanged,
    required this.maxTokens,
    required this.onMaxTokensChanged,
    required this.streamResponse,
    required this.onStreamChanged,
  });

  final double temperature;
  final ValueChanged<double> onTemperatureChanged;
  final int maxTokens;
  final ValueChanged<int> onMaxTokensChanged;
  final bool streamResponse;
  final ValueChanged<bool> onStreamChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: _TemperatureControl(
            value: temperature,
            onChanged: onTemperatureChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.s4),
        Expanded(
          flex: 5,
          child: _MaxTokensControl(
            value: maxTokens,
            onChanged: onMaxTokensChanged,
            streamResponse: streamResponse,
            onStreamChanged: onStreamChanged,
          ),
        ),
      ],
    );
  }
}

class _TemperatureControl extends StatelessWidget {
  const _TemperatureControl({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Temperature',
                style: AppTypography.base.copyWith(color: AppColors.textPrimary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s2,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.smRadius,
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Text(
                value.toStringAsFixed(1),
                style: AppTypography.mono(AppTypography.sm).copyWith(
                  color: AppColors.accentSecondary,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accentPrimary,
            inactiveTrackColor: AppColors.borderDefault,
            thumbColor: AppColors.accentPrimary,
            overlayColor: AppColors.accentPrimarySubtle,
            trackHeight: 3,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 1,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0.0',
              style: AppTypography.xs.copyWith(color: AppColors.textDisabled),
            ),
            Text(
              '1.0',
              style: AppTypography.xs.copyWith(color: AppColors.textDisabled),
            ),
          ],
        ),
      ],
    );
  }
}

class _MaxTokensControl extends StatelessWidget {
  const _MaxTokensControl({
    required this.value,
    required this.onChanged,
    required this.streamResponse,
    required this.onStreamChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool streamResponse;
  final ValueChanged<bool> onStreamChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Max tokens',
                style: AppTypography.base.copyWith(color: AppColors.textPrimary),
              ),
            ),
            _StepperButton(
              icon: Icons.remove,
              onPressed: value > 1 ? () => onChanged((value - 1).clamp(1, 32000)) : null,
            ),
            const SizedBox(width: AppSpacing.s1),
            _StepperButton(
              icon: Icons.add,
              onPressed: () => onChanged((value + 1).clamp(1, 32000)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          '$value',
          style: AppTypography.mono(AppTypography.lg).copyWith(
            color: AppColors.accentSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        Row(
          children: [
            Expanded(
              child: Text(
                'Stream response',
                style: AppTypography.base.copyWith(color: AppColors.textPrimary),
              ),
            ),
            Switch(
              value: streamResponse,
              onChanged: onStreamChanged,
              activeThumbColor: AppColors.textOnAccent,
              activeTrackColor: AppColors.accentPrimary,
              inactiveThumbColor: AppColors.textSecondary,
              inactiveTrackColor: AppColors.borderDefault,
            ),
          ],
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.smRadius,
        onTap: onPressed,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.smRadius,
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Icon(
            icon,
            size: 16,
            color: onPressed == null ? AppColors.textDisabled : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RunPromptButton extends StatelessWidget {
  const _RunPromptButton({required this.running, required this.onPressed});

  final bool running;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: running ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          disabledBackgroundColor: AppColors.accentPrimary.withValues(alpha: 0.6),
          foregroundColor: AppColors.textOnAccent,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        ),
        child: running
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textOnAccent,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 20),
                  const SizedBox(width: AppSpacing.s2),
                  Text(
                    'Run prompt',
                    style: AppTypography.base.copyWith(
                      fontWeight: AppTypography.weightSemibold,
                      color: AppColors.textOnAccent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({
    required this.status,
    required this.elapsed,
    required this.controller,
  });

  final _RunStatus status;
  final String elapsed;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Response',
                  style: AppTypography.md.copyWith(
                    fontWeight: AppTypography.weightSemibold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusPill(status: status),
              const SizedBox(width: AppSpacing.s2),
              Text(
                elapsed,
                style: AppTypography.mono(AppTypography.sm).copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          PlaygroundCodeEditor(
            controller: controller,
            readOnly: true,
            highlighter: PlaygroundCodeEditor.responseHighlighter,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _RunStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      _RunStatus.completed => (AppColors.accentSuccess, 'COMPLETED'),
      _RunStatus.running => (AppColors.accentSecondary, 'RUNNING'),
      _RunStatus.idle => (AppColors.textDisabled, 'IDLE'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.xs.copyWith(
              color: color,
              fontWeight: AppTypography.weightSemibold,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: child,
    );
  }
}
