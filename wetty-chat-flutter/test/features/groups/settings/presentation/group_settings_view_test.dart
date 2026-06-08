import 'package:chahua/core/api/models/group_info_api_models.dart';
import 'package:chahua/core/feature_gates/feature_gates.dart';
import 'package:chahua/features/groups/metadata/data/group_metadata_api_service.dart';
import 'package:chahua/features/groups/metadata/data/group_metadata_repository.dart';
import 'package:chahua/features/groups/settings/presentation/group_settings_view.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('group settings opens chat-scoped saved messages', (
    tester,
  ) async {
    final container = _container();
    final router = _router();
    addTearDown(container.dispose);

    await _pump(tester, container, router);

    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('chat saved messages route'), findsOneWidget);
  });

  testWidgets('group settings hides saved action when gate is disabled', (
    tester,
  ) async {
    final container = _container(savedMessagesEnabled: false);
    final router = _router();
    addTearDown(container.dispose);

    await _pump(tester, container, router);

    expect(find.text('Saved'), findsNothing);
  });
}

ProviderContainer _container({bool savedMessagesEnabled = true}) {
  return ProviderContainer(
    overrides: [
      groupMetadataRepositoryProvider.overrideWithValue(
        GroupMetadataRepository(
          _FakeGroupMetadataApiService(
            const GroupInfoResponseDto(id: 42, name: 'General'),
          ),
        ),
      ),
      featureGateConfigProvider.overrideWithValue(
        FeatureGateConfig(
          overrides: {AppFeatureGate.savedMessages: savedMessagesEnabled},
        ),
      ),
    ],
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/chat/42/settings',
    routes: [
      GoRoute(
        path: '/chat/:chatId/settings',
        builder: (context, state) =>
            GroupSettingsPage(chatId: state.pathParameters['chatId']!),
        routes: [
          GoRoute(
            path: 'saved-messages',
            builder: (context, state) => const CupertinoPageScaffold(
              child: Center(child: Text('chat saved messages route')),
            ),
          ),
        ],
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  GoRouter router,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: CupertinoApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _FakeGroupMetadataApiService extends GroupMetadataApiService {
  _FakeGroupMetadataApiService(this.response) : super(Dio());

  final GroupInfoResponseDto response;

  @override
  Future<GroupInfoResponseDto> fetchGroupMetadata(String chatId) async {
    return response;
  }
}
