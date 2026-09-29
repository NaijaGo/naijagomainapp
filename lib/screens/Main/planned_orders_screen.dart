import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import '../../services/order_payment_coordinator.dart';
import '../../services/planned_order_service.dart';
import 'my_orders_screen.dart';

class PlannedOrdersScreen extends StatefulWidget {
  const PlannedOrdersScreen({super.key, this.initialDestination});
  final PlannedOrderDestination? initialDestination;
  @override
  State<PlannedOrdersScreen> createState() => _PlannedOrdersScreenState();
}

class _PlannedOrdersScreenState extends State<PlannedOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final PlannedOrderService _service = PlannedOrderService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialDestination?.kind == 'recurring' ? 1 : 0,
    );
    _load(openInitial: true);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _service.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : <Map<String, dynamic>>[];

  Future<void> _load({bool openInitial = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _service.groups(),
        _service.recurring(),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = _rows(results[0]['groups']);
        _plans = _rows(results[1]['plans']);
      });
      if (openInitial && widget.initialDestination != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = widget.initialDestination;
          if (mounted && target != null) _open(target.kind, target.id);
        });
      }
    } on PlannedOrderException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final input = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a group order'),
        content: TextField(
          controller: input,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Invitation code',
            hintText: 'Paste the code shared by the owner',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    input.dispose();
    if (token == null || token.isEmpty) return;
    try {
      final group = await _service.joinGroup(token);
      if (!mounted) return;
      await _load();
      final id = group['id']?.toString();
      if (mounted && id != null) _open('group', id);
    } on PlannedOrderException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _open(String kind, String id) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PlannedOrderDetailScreen(kind: kind, id: id),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF102B5C);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Plan together'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFADFF2F),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.groups_outlined), text: 'Group orders'),
            Tab(icon: Icon(Icons.event_repeat_outlined), text: 'Recurring'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _join,
        backgroundColor: const Color(0xFFADFF2F),
        foregroundColor: navy,
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Join group'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _Message(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load planned orders',
              message: _error!,
              action: _load,
            )
          : TabBarView(
              controller: _tabs,
              children: [
                _OrderList(
                  rows: _groups,
                  icon: Icons.groups_outlined,
                  emptyTitle: 'No group orders yet',
                  emptyMessage:
                      'Join an invitation or start a group order from an eligible cart.',
                  onRefresh: _load,
                  onTap: (row) => _open('group', row['id'].toString()),
                  title: (row) => row['name']?.toString() ?? 'Group order',
                  subtitle: (row) => [
                    (row['memberCount'] ?? 0).toString(),
                    'participant(s)',
                    label(row['state']),
                  ].join(' • '),
                ),
                _OrderList(
                  rows: _plans,
                  icon: Icons.event_repeat_outlined,
                  emptyTitle: 'No recurring plans yet',
                  emptyMessage:
                      'Repeat plans always ask you to review and pay. Automatic charging is off.',
                  onRefresh: _load,
                  onTap: (row) =>
                      _open('recurring', (row['_id'] ?? row['id']).toString()),
                  title: (row) => row['name']?.toString() ?? 'Recurring order',
                  subtitle: (row) => [
                    label(row['state']),
                    'next review',
                    date(row['nextGenerateAt']),
                  ].join(' • '),
                ),
              ],
            ),
    );
  }

  static String label(dynamic value) => (value?.toString() ?? '')
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (word) =>
            word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
      )
      .join(' ');
  static String date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? 'not scheduled'
        : DateFormat('d MMM, h:mm a').format(parsed.toLocal());
  }
}

class PlannedOrderDetailScreen extends StatefulWidget {
  const PlannedOrderDetailScreen({
    super.key,
    required this.kind,
    required this.id,
  });
  final String kind;
  final String id;
  @override
  State<PlannedOrderDetailScreen> createState() =>
      _PlannedOrderDetailScreenState();
}

class _PlannedOrderDetailScreenState extends State<PlannedOrderDetailScreen> {
  final PlannedOrderService _service = PlannedOrderService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _actionBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = widget.kind == 'group'
          ? await _service.group(widget.id)
          : await _service.recurringPlan(widget.id);
      if (mounted) setState(() => _data = result);
    } on PlannedOrderException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _control(String action) async {
    if (_actionBusy) return;
    final root = widget.kind == 'group' ? _data : _data?['plan'];
    final revision = (root?['revision'] as num?)?.toInt();
    if (revision == null) return;
    setState(() => _actionBusy = true);
    try {
      if (widget.kind == 'group') {
        await _service.controlGroup(
          widget.id,
          revision: revision,
          action: action,
        );
      } else {
        await _service.controlRecurring(
          widget.id,
          revision: revision,
          action: action,
        );
      }
      await _load();
    } on PlannedOrderException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _rotateInvite() async {
    if (_actionBusy || _data == null) return;
    final revision = (_data!['revision'] as num?)?.toInt();
    if (revision == null) return;
    setState(() => _actionBusy = true);
    try {
      final result = await _service.rotateGroupInvite(
        widget.id,
        revision: revision,
      );
      final token = result['inviteToken']?.toString().trim() ?? '';
      final group = result['group'];
      if (group is Map && mounted) {
        setState(() => _data = Map<String, dynamic>.from(group));
      }
      if (token.isEmpty || !mounted) {
        throw const PlannedOrderException(
          'The new invitation could not be displayed.',
        );
      }
      await Clipboard.setData(ClipboardData(text: token));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('New group invitation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The previous invitation no longer works. This new code has been copied to your clipboard.',
              ),
              const SizedBox(height: 14),
              SelectableText(
                token,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: token));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Copy & close'),
            ),
          ],
        ),
      );
    } on PlannedOrderException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  List<Map<String, dynamic>> _currentCartItems() {
    return context.read<CartProvider>().items.values.map((entry) {
      final item = entry.toJson();
      return <String, dynamic>{
        'product': item['product'],
        if (item['offer'] != null) 'offer': item['offer'],
        if (item['variantId'] != null) 'variantId': item['variantId'],
        if (item['selectedSize'] != null) 'selectedSize': item['selectedSize'],
        'quantity': item['quantity'],
        if (item['customerNote'] != null) 'customerNote': item['customerNote'],
      };
    }).toList();
  }

  Future<void> _replaceWithCurrentCart({required bool recurring}) async {
    if (_actionBusy) return;
    final items = _currentCartItems();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add products to your cart first.')),
      );
      return;
    }
    final root = recurring ? (_data == null ? null : _data!['plan']) : _data;
    final revision = (root?['revision'] as num?)?.toInt();
    if (revision == null) return;
    setState(() => _actionBusy = true);
    try {
      if (recurring) {
        await _service.editRecurring(
          widget.id,
          revision: revision,
          input: {'items': items},
        );
      } else {
        await _service.editGroup(widget.id, revision: revision, items: items);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            recurring
                ? 'Future recurring orders will use the current cart.'
                : 'Your group basket was updated from the current cart.',
          ),
        ),
      );
      await _load();
    } on PlannedOrderException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<String?> _approveQuote(Map<String, dynamic> response) async {
    final quote = response['quote'] is Map
        ? Map<String, dynamic>.from(response['quote'] as Map)
        : <String, dynamic>{};
    final total = (quote['totalPrice'] as num?)?.toDouble();
    if (total == null) {
      throw const PlannedOrderException('A current total is unavailable.');
    }
    if (!mounted) return null;
    var method = 'Card';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Review current total'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₦${NumberFormat('#,##0.00').format(total)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Prices, stock, fees and delivery were checked again. The quote expires shortly.',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(
                  labelText: 'Payment method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Card',
                    child: Text('Card / bank payment'),
                  ),
                  DropdownMenuItem(
                    value: 'Wallet',
                    child: Text('NaijaGo wallet'),
                  ),
                ],
                onChanged: (value) => update(() => method = value ?? 'Card'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, method),
              child: const Text('Approve & continue'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkoutGroup() async {
    if (_actionBusy || _data == null) return;
    final revision = (_data!['revision'] as num?)?.toInt();
    if (revision == null) return;
    setState(() => _actionBusy = true);
    try {
      final approved = await _service.quoteGroup(widget.id, revision: revision);
      final method = await _approveQuote(approved);
      if (method == null || !mounted) return;
      final token = approved['approvalToken']?.toString();
      final quote = approved['quote'] is Map
          ? Map<String, dynamic>.from(approved['quote'] as Map)
          : <String, dynamic>{};
      final total = (quote['totalPrice'] as num?)?.toDouble();
      if (token == null || total == null) {
        throw const PlannedOrderException(
          'Refresh and review the current total again.',
        );
      }
      final checkout = await _service.checkoutGroup(
        widget.id,
        revision: revision,
        approvalToken: token,
        paymentMethod: method,
      );
      await _payCreatedOrder(checkout['orderId']?.toString(), total, method);
    } on PlannedOrderException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _checkoutOccurrence(Map occurrence) async {
    if (_actionBusy) return;
    final id = occurrence['_id']?.toString();
    final revision = (occurrence['revision'] as num?)?.toInt();
    if (id == null || revision == null) return;
    setState(() => _actionBusy = true);
    try {
      final approved = await _service.quoteOccurrence(id, revision: revision);
      final method = await _approveQuote(approved);
      if (method == null || !mounted) return;
      final token = approved['approvalToken']?.toString();
      final quote = approved['quote'] is Map
          ? Map<String, dynamic>.from(approved['quote'] as Map)
          : <String, dynamic>{};
      final total = (quote['totalPrice'] as num?)?.toDouble();
      if (token == null || total == null) {
        throw const PlannedOrderException(
          'Refresh and review the current total again.',
        );
      }
      final checkout = await _service.checkoutOccurrence(
        id,
        revision: revision,
        approvalToken: token,
        paymentMethod: method,
      );
      await _payCreatedOrder(checkout['orderId']?.toString(), total, method);
    } on PlannedOrderException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _skipOccurrence(Map occurrence) async {
    if (_actionBusy) return;
    final id = occurrence['_id']?.toString();
    final revision = (occurrence['revision'] as num?)?.toInt();
    if (id == null || revision == null) return;
    setState(() => _actionBusy = true);
    try {
      await _service.controlOccurrence(id, revision: revision, action: 'skip');
      await _load();
    } on PlannedOrderException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _payCreatedOrder(
    String? orderId,
    double total,
    String paymentMethod,
  ) async {
    if (orderId == null) {
      throw const PlannedOrderException(
        'The order receipt could not be opened.',
      );
    }
    final payment = OrderPaymentCoordinator();
    try {
      final result = await payment.pay(
        context,
        orderId: orderId,
        approvedTotal: total,
        paymentMethod: paymentMethod,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      if (result.completed) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment is still pending. Open My Orders before trying again.',
            ),
          ),
        );
      }
    } finally {
      payment.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Planned order')),
        body: _Message(
          icon: Icons.error_outline,
          title: 'Unable to open order',
          message: _error!,
          action: _load,
        ),
      );
    }
    final root = widget.kind == 'group'
        ? _data!
        : Map<String, dynamic>.from(_data?['plan'] as Map? ?? {});
    final state = root['state']?.toString() ?? 'unknown';
    final occurrences = _data?['occurrences'] is List
        ? (_data!['occurrences'] as List).whereType<Map>().toList()
        : <Map>[];
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(root['name']?.toString() ?? 'Planned order'),
        backgroundColor: const Color(0xFF102B5C),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Summary(root: root, kind: widget.kind),
            const SizedBox(height: 12),
            if (_actionBusy) const LinearProgressIndicator(),
            if (_actionBusy) const SizedBox(height: 12),
            if (widget.kind == 'group' && state == 'open')
              OutlinedButton.icon(
                onPressed: _actionBusy
                    ? null
                    : () => _replaceWithCurrentCart(recurring: false),
                icon: const Icon(Icons.shopping_cart_checkout_outlined),
                label: const Text('Use my current cart for this group'),
              ),
            if (widget.kind == 'recurring' &&
                (state == 'active' || state == 'paused'))
              OutlinedButton.icon(
                onPressed: _actionBusy
                    ? null
                    : () => _replaceWithCurrentCart(recurring: true),
                icon: const Icon(Icons.shopping_cart_checkout_outlined),
                label: const Text('Use current cart for future orders'),
              ),
            if (widget.kind == 'group' &&
                root['isOwner'] == true &&
                state == 'closed')
              FilledButton.icon(
                onPressed: _actionBusy ? null : _checkoutGroup,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Review total & pay'),
              ),
            if (widget.kind == 'group' &&
                root['isOwner'] == true &&
                root['orderId'] != null)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open order receipt'),
              ),
            if (widget.kind == 'group' &&
                root['isOwner'] == true &&
                state == 'open')
              OutlinedButton.icon(
                onPressed: _actionBusy ? null : _rotateInvite,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Create a new invite code'),
              ),
            if (widget.kind == 'group' &&
                root['isOwner'] == true &&
                state == 'open')
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _control('close'),
                      child: const Text('Close group'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _control('cancel'),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            if (widget.kind == 'recurring' &&
                (state == 'active' || state == 'paused'))
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          _control(state == 'paused' ? 'resume' : 'pause'),
                      child: Text(
                        state == 'paused' ? 'Resume plan' : 'Pause plan',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _control('cancel'),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            if (occurrences.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Upcoming reviews',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              ...occurrences.map((row) {
                final occurrenceState = row['state']?.toString();
                final actionable =
                    occurrenceState == 'awaiting_review' ||
                    occurrenceState == 'needs_attention';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(_PlannedOrdersScreenState.date(row['startAt'])),
                    subtitle: Text(
                      _PlannedOrdersScreenState.label(row['state']),
                    ),
                    trailing: actionable
                        ? PopupMenuButton<String>(
                            enabled: !_actionBusy,
                            onSelected: (value) {
                              if (value == 'pay') {
                                _checkoutOccurrence(row);
                              }
                              if (value == 'skip') {
                                _skipOccurrence(row);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'pay',
                                child: Text('Review & pay'),
                              ),
                              PopupMenuItem(
                                value: 'skip',
                                child: Text('Skip this delivery'),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.rows,
    required this.icon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onTap,
    required this.title,
    required this.subtitle,
  });

  final List<Map<String, dynamic>> rows;
  final IconData icon;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, dynamic>) onTap;
  final String Function(Map<String, dynamic>) title;
  final String Function(Map<String, dynamic>) subtitle;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(28, 72, 28, 120),
          children: [
            Icon(icon, size: 66, color: const Color(0xFF91A0B8)),
            const SizedBox(height: 18),
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667085), height: 1.45),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 110),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final row = rows[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE5EAF2)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEAF1FF),
                foregroundColor: const Color(0xFF102B5C),
                child: Icon(icon),
              ),
              title: Text(
                title(row),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(subtitle(row)),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onTap(row),
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.root, required this.kind});
  final Map<String, dynamic> root;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final state = _PlannedOrdersScreenState.label(root['state']);
    final seller =
        root['sellerName'] ?? root['vendorName'] ?? root['storeName'];
    final schedule = kind == 'group'
        ? root['closesAt']
        : root['nextGenerateAt'];
    final scheduleLabel = kind == 'group' ? 'Closes' : 'Next review';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5EAF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    state,
                    style: const TextStyle(
                      color: Color(0xFF102B5C),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  kind == 'group'
                      ? Icons.groups_outlined
                      : Icons.event_repeat_outlined,
                  color: const Color(0xFF102B5C),
                ),
              ],
            ),
            if (seller != null && seller.toString().trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                seller.toString(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '$scheduleLabel: ${_PlannedOrdersScreenState.date(schedule)}',
              style: const TextStyle(color: Color(0xFF667085)),
            ),
            if (kind == 'group' && root['memberCount'] != null) ...[
              const SizedBox(height: 6),
              Text(
                '${root['memberCount']} participant(s)',
                style: const TextStyle(color: Color(0xFF667085)),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Prices, stock and availability are checked again before payment. You stay in control of every purchase.',
              style: TextStyle(color: Color(0xFF475467), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function() action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 58, color: const Color(0xFF91A0B8)),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: action,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
