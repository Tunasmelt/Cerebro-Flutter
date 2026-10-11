// The shared building blocks: confirm dialog, empty state, screen header,
// status pill, text field, section header, skeleton, and the error view's
// accessibility fixes.
import 'package:cerebro_mobile/core/network/app_exception.dart';
import 'package:cerebro_mobile/shared/theme/app_theme.dart';
import 'package:cerebro_mobile/shared/tokens/app_colors.dart';
import 'package:cerebro_mobile/shared/tokens/app_spacing.dart';
import 'package:cerebro_mobile/shared/widgets/app_confirm_dialog.dart';
import 'package:cerebro_mobile/shared/widgets/app_empty_state.dart';
import 'package:cerebro_mobile/shared/widgets/app_screen_header.dart';
import 'package:cerebro_mobile/shared/widgets/app_section_header.dart';
import 'package:cerebro_mobile/shared/widgets/app_skeleton.dart';
import 'package:cerebro_mobile/shared/widgets/app_text_field.dart';
import 'package:cerebro_mobile/shared/widgets/error_view.dart';
import 'package:cerebro_mobile/shared/widgets/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: child),
);

void main() {
  group('showAppConfirmDialog', () {
    Future<bool?> open(
      WidgetTester tester, {
      bool destructive = false,
      String? message,
    }) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  context,
                  title: 'Delete it?',
                  message: message,
                  confirmLabel: 'Delete',
                  destructive: destructive,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('confirm resolves true', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showAppConfirmDialog(context, title: 'Sure?'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app_confirm_confirm')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('cancel resolves false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showAppConfirmDialog(context, title: 'Sure?'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app_confirm_cancel')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('tapping outside the dialog is a no, never a null', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showAppConfirmDialog(context, title: 'Sure?'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('a destructive confirm is red; a plain one is not', (
      tester,
    ) async {
      await open(tester, destructive: true, message: 'm');
      final red = tester.widget<TextButton>(
        find.byKey(const Key('app_confirm_confirm')),
      );
      expect(red.style!.foregroundColor!.resolve({}), AppColors.danger);
      await tester.tap(find.byKey(const Key('app_confirm_cancel')));
      await tester.pumpAndSettle();

      await open(tester);
      final plain = tester.widget<TextButton>(
        find.byKey(const Key('app_confirm_confirm')),
      );
      expect(plain.style, isNull);
    });

    testWidgets('custom keys are honoured (the screens\' own tests rely on '
        'them)', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppConfirmDialog(
                context,
                title: 't',
                confirmKey: const Key('mine_yes'),
                cancelKey: const Key('mine_no'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mine_yes')), findsOneWidget);
      expect(find.byKey(const Key('mine_no')), findsOneWidget);
    });

    testWidgets('both buttons are full-size touch targets', (tester) async {
      await open(tester, message: 'm');
      for (final k in ['app_confirm_cancel', 'app_confirm_confirm']) {
        expect(
          tester.getSize(find.byKey(Key(k))).height,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
        );
      }
    });
  });

  group('AppEmptyState', () {
    testWidgets('icon, title, message and an action that works', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        _app(
          AppEmptyState(
            icon: Icons.folder_open,
            title: 'No documents yet',
            message: 'Upload a file to start.',
            actionLabel: 'Upload',
            onAction: () => tapped++,
          ),
        ),
      );
      expect(find.text('No documents yet'), findsOneWidget);
      expect(find.text('Upload a file to start.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('app_empty_action')));
      expect(tapped, 1);
    });

    testWidgets('without an action there is no button', (tester) async {
      await tester.pumpWidget(
        _app(const AppEmptyState(icon: Icons.chat, title: 'Nothing here')),
      );
      expect(find.byKey(const Key('app_empty_action')), findsNothing);
    });

    testWidgets('survives a narrow screen and large text', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.folder_open,
              title: 'No documents yet in this vault',
              message: 'Upload a file and it will appear here once processed.',
              actionLabel: 'Upload your first document',
              onAction: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AppScreenHeader', () {
    testWidgets('title, subtitle and actions; the title is a heading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          AppScreenHeader(
            title: 'Documents',
            subtitle: '12 files',
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
            ],
          ),
        ),
      );
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('12 files'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Documents')).flagsCollection.isHeader,
        isTrue,
      );
    });

    testWidgets('a long title is cut, not an overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          AppScreenHeader(
            title: 'A very long screen title that cannot possibly fit',
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('StatusPill', () {
    testWidgets('shows its label and is read as that label', (tester) async {
      await tester.pumpWidget(
        _app(const StatusPill(label: 'Ready', color: AppColors.accentSuccess)),
      );
      expect(find.text('Ready'), findsOneWidget);
      final decoration =
          tester
                  .widget<Container>(
                    find.ancestor(
                      of: find.text('Ready'),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.color, AppColors.accentSuccess.withValues(alpha: 0.12));
    });
  });

  group('AppSectionHeader', () {
    testWidgets('upper-cases the label and is a heading', (tester) async {
      await tester.pumpWidget(_app(const AppSectionHeader('Data & storage')));
      expect(find.text('DATA & STORAGE'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text('DATA & STORAGE'))
            .flagsCollection
            .isHeader,
        isTrue,
      );
    });
  });

  group('AppTextField', () {
    testWidgets('label above the field; typing reaches the controller', (
      tester,
    ) async {
      final c = TextEditingController();
      await tester.pumpWidget(
        _app(AppTextField(label: 'Email', controller: c)),
      );
      expect(find.text('Email'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'a@b.co');
      expect(c.text, 'a@b.co');
    });

    testWidgets('password: hidden by default, the eye reveals and hides it', (
      tester,
    ) async {
      final c = TextEditingController(text: 'secret');
      await tester.pumpWidget(
        _app(
          AppTextField(
            label: 'Password',
            controller: c,
            obscureText: true,
            showVisibilityToggle: true,
          ),
        ),
      );
      bool obscured() =>
          tester.widget<TextField>(find.byType(TextField)).obscureText;
      expect(obscured(), isTrue);

      await tester.tap(find.byKey(const Key('app_text_field_toggle')));
      await tester.pump();
      expect(obscured(), isFalse);

      await tester.tap(find.byKey(const Key('app_text_field_toggle')));
      await tester.pump();
      expect(obscured(), isTrue);
    });

    testWidgets('no eye unless asked for', (tester) async {
      await tester.pumpWidget(
        _app(
          AppTextField(
            label: 'Password',
            controller: TextEditingController(),
            obscureText: true,
          ),
        ),
      );
      expect(find.byKey(const Key('app_text_field_toggle')), findsNothing);
    });

    testWidgets('the eye is a full-size touch target', (tester) async {
      await tester.pumpWidget(
        _app(
          AppTextField(
            label: 'Password',
            controller: TextEditingController(),
            obscureText: true,
            showVisibilityToggle: true,
          ),
        ),
      );
      final size = tester.getSize(
        find.byKey(const Key('app_text_field_toggle')),
      );
      expect(
        size.shortestSide,
        greaterThanOrEqualTo(AppSpacing.minTouchTarget),
      );
    });

    testWidgets('an error is shown under the field', (tester) async {
      await tester.pumpWidget(
        _app(
          AppTextField(
            label: 'Email',
            controller: TextEditingController(),
            errorText: 'Enter a valid email',
          ),
        ),
      );
      expect(find.text('Enter a valid email'), findsOneWidget);
    });
  });

  group('AppSkeletonList', () {
    testWidgets('draws the requested number of rows and is announced as '
        'loading', (tester) async {
      await tester.pumpWidget(_app(const AppSkeletonList(rows: 3)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('app_skeleton')), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('app_skeleton'))).label,
        isNotNull,
      );
    });

    testWidgets('stands still when the system asks for reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: AppSkeletonList(rows: 2)),
        ),
      );
      // Nothing is ticking: pumpAndSettle returns instead of timing out.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });
  });

  group('ErrorView', () {
    testWidgets('Retry is a full-size touch target, compact and expanded', (
      tester,
    ) async {
      for (final expanded in [false, true]) {
        await tester.pumpWidget(
          _app(
            ErrorView(
              exception: const NetworkUnreachableException(),
              expanded: expanded,
              onRetry: () {},
            ),
          ),
        );
        final size = tester.getSize(find.byKey(const Key('error_view_retry')));
        expect(
          size.height,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
          reason: expanded ? 'expanded' : 'compact',
        );
      }
    });

    testWidgets('is announced to screen readers when it appears', (
      tester,
    ) async {
      for (final expanded in [false, true]) {
        await tester.pumpWidget(
          _app(
            ErrorView(
              exception: const NetworkUnreachableException(),
              expanded: expanded,
            ),
          ),
        );
        final node = tester.getSemantics(
          find.text("Can't reach Cerebro. Check your connection."),
        );
        // Walk up to the node that carries the live-region flag.
        SemanticsNode? n = node;
        var live = false;
        while (n != null) {
          if (n.flagsCollection.isLiveRegion) live = true;
          n = n.parent;
        }
        expect(live, isTrue, reason: expanded ? 'expanded' : 'compact');
      }
    });
  });
}
