import 'package:flutter_test/flutter_test.dart';
import '../lib/services/explore_notification_intent.dart';

void main() {
  const id = 'aaaaaaaaaaaaaaaaaaaaaaaa';
  const parent = 'bbbbbbbbbbbbbbbbbbbbbbbb';
  tearDown(ExploreNotificationIntent.clear);

  test('push and inbox notifications resolve to the same reply thread', () {
    final push = ExploreDestination.parse({
      'type': 'explore_activity',
      'targetType': 'product',
      'targetId': id,
      'parentId': parent,
    });
    final inbox = ExploreDestination.parse({
      'explore': {'targetType': 'product', 'target': id, 'parent': parent},
    });
    expect(push?.type, 'product');
    expect(push?.id, inbox?.id);
    expect(push?.parentId, inbox?.parentId);
  });

  test(
    'rejects unrelated events, arbitrary destinations and malformed identifiers',
    () {
      expect(
        ExploreDestination.parse({
          'type': 'order',
          'targetType': 'product',
          'targetId': id,
        }),
        isNull,
      );
      expect(
        ExploreDestination.parse({
          'type': 'explore_activity',
          'targetType': 'external',
          'targetId': id,
        }),
        isNull,
      );
      expect(
        ExploreDestination.parse({
          'type': 'explore_activity',
          'targetType': 'product',
          'targetId': '../orders',
        }),
        isNull,
      );
      expect(
        ExploreDestination.parse({
          'type': 'explore_activity',
          'targetType': 'product',
          'targetId': id,
          'parentId': 'wrong',
        }),
        isNull,
      );
    },
  );

  test('cold-start intent remains pending until consumed exactly once', () {
    ExploreNotificationIntent.receive({
      'type': 'explore_activity',
      'targetType': 'campaign',
      'targetId': id,
    });
    ExploreNotificationIntent.receive({'type': 'unrelated'});
    expect(ExploreNotificationIntent.take()?.id, id);
    expect(ExploreNotificationIntent.take(), isNull);
  });

  test('logout clears a pending notification', () {
    ExploreNotificationIntent.receive({
      'type': 'explore_activity',
      'targetType': 'product',
      'targetId': id,
    });
    ExploreNotificationIntent.clear();
    expect(ExploreNotificationIntent.take(), isNull);
  });
}
