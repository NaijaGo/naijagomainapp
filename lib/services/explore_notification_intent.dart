import 'package:flutter/foundation.dart';

class ExploreDestination {
  const ExploreDestination(this.type, this.id, {this.parentId});
  final String type;
  final String id;
  final String? parentId;
  static ExploreDestination? parse(Map data) {
    final raw = data['explore'] is Map ? data['explore'] as Map : data;
    if (data['explore'] is! Map && data['type'] != 'explore_activity')
      return null;
    final type = raw['targetType']?.toString();
    final id = (raw['targetId'] ?? raw['target'])?.toString();
    final parent = (raw['parentId'] ?? raw['parent'])?.toString();
    final validId = RegExp(r'^[a-fA-F0-9]{24}$');
    if (!['product', 'campaign'].contains(type) ||
        id == null ||
        !validId.hasMatch(id))
      return null;
    if (parent != null && !validId.hasMatch(parent)) return null;
    return ExploreDestination(type!, id, parentId: parent);
  }
}

class ExploreNotificationIntent {
  static final changed = ValueNotifier<int>(0);
  static ExploreDestination? _pending;
  static void receive(Map? data) {
    if (data == null) return;
    final destination = ExploreDestination.parse(data);
    if (destination == null) return;
    _pending = destination;
    changed.value++;
  }

  static ExploreDestination? take() {
    final value = _pending;
    _pending = null;
    return value;
  }

  static void clear() => _pending = null;
}
