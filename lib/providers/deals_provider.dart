import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/deal.dart';
import '../services/deals_service.dart';

class DealsProvider extends ChangeNotifier {
  DealsProvider({
    DealsService? service,
    this.limit = 20,
    DateTime Function()? clock,
  }) : service = service ?? DealsService(),
       _clock = clock ?? DateTime.now {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed && _deals.isNotEmpty) notifyListeners();
    });
  }
  final DealsService service;
  final int limit;
  final DateTime Function() _clock;
  late final Timer _timer;
  Duration _offset = Duration.zero;
  List<Deal> _deals = [];
  bool loading = true,
      loadingMore = false,
      hasMore = false,
      failureWasLoadMore = false;
  String? error;
  int _page = 0, _generation = 0;
  bool _disposed = false;
  DateTime get serverNow => _clock().toUtc().add(_offset);
  List<Deal> get deals => _deals
      .where((deal) => deal.isActiveAt(serverNow))
      .toList(growable: false);

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_generation;
    loading = true;
    loadingMore = false;
    error = null;
    failureWasLoadMore = false;
    notifyListeners();
    await _load(1, generation, more: false);
  }

  Future<void> loadMore() async {
    if (_disposed || loading || loadingMore || !hasMore) return;
    loadingMore = true;
    error = null;
    failureWasLoadMore = true;
    notifyListeners();
    await _load(_page + 1, _generation, more: true);
  }

  Future<void> _load(int page, int generation, {required bool more}) async {
    try {
      final result = await service.list(page: page, limit: limit);
      if (_disposed || generation != _generation) return;
      if (result.serverTime != null) {
        _offset = result.serverTime!.difference(_clock().toUtc());
      }
      final ids = <String>{};
      _deals = [
        ...(more ? _deals : <Deal>[]),
        ...result.deals,
      ].where((deal) => ids.add(deal.id)).toList();
      _page = result.page;
      hasMore = result.hasMore;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure is DealsException
          ? failure.message
          : 'Could not load Deals. Please try again.';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() => failureWasLoadMore ? loadMore() : refresh();
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer.cancel();
    super.dispose();
  }
}
