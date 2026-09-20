import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/product.dart';
import '../../services/product_request_service.dart';
import 'product_detail_screen.dart';

const _conceptLabel =
    'AI-generated concept - not an actual product. Not for sale.';
const _requestStates = {
  'draft': 'Private draft',
  'requested': 'Request received',
  'sourcing': 'Sourcing your product',
  'matched': 'Real listing found',
  'unavailable': 'Not found yet',
  'cancelled': 'Cancelled',
};

class ProductRequestsScreen extends StatefulWidget {
  const ProductRequestsScreen({super.key});
  @override
  State<ProductRequestsScreen> createState() => _ProductRequestsScreenState();
}

class _ProductRequestsScreenState extends State<ProductRequestsScreen> {
  final _service = ProductRequestService();
  final List<Map<String, dynamic>> _rows = [];
  bool _busy = false;
  String? _cursor, _error;
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

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _service.request(
        '',
        query: {if (more && _cursor != null) 'before': _cursor!},
      );
      if (!mounted) return;
      setState(() {
        if (!more) _rows.clear();
        _rows.addAll(
          (data['requests'] as List? ?? []).whereType<Map>().map(
            (row) => Map<String, dynamic>.from(row),
          ),
        );
        _cursor = data['nextCursor'] as String?;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My product requests'),
      actions: [
        IconButton(
          tooltip: 'Refresh requests',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Text(
            'Tell us what you need. NaijaGo will look for a real listing. Requests are not orders and require no payment.',
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (!_busy && _error == null && _rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No product requests yet. Start from a search with no matching products.',
              ),
            ),
          for (final row in _rows)
            Card(
              child: ListTile(
                leading: const Icon(Icons.manage_search),
                title: Text(row['query']?.toString() ?? ''),
                subtitle: Text(_requestStates[row['state']] ?? 'Request'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductRequestScreen(requestId: row['id'] as String),
                    ),
                  );
                  if (mounted) _load();
                },
              ),
            ),
          if (_busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          if (_cursor != null)
            OutlinedButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: const Text('More requests'),
            ),
        ],
      ),
    ),
  );
}

class ProductRequestScreen extends StatefulWidget {
  const ProductRequestScreen({
    super.key,
    this.requestId,
    this.query = '',
    this.criteria = const {},
    this.service,
  });
  final String? requestId;
  final String query;
  final Map<String, String> criteria;
  final ProductRequestService? service;
  @override
  State<ProductRequestScreen> createState() => _ProductRequestScreenState();
}

class _ProductRequestScreenState extends State<ProductRequestScreen>
    with WidgetsBindingObserver {
  late final ProductRequestService _service;
  final _notes = TextEditingController();
  final _requestKey = const Uuid().v4();
  Map<String, dynamic>? _row;
  Timer? _poll;
  String? _error;
  bool _busy = false, _consent = false, _active = true;
  int _polls = 0;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductRequestService();
    WidgetsBinding.instance.addObserver(this);
    if (widget.requestId != null) _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _notes.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      _poll?.cancel();
    } else {
      _polls = 0;
      if (_row != null) _load();
    }
  }

  void _schedule() {
    _poll?.cancel();
    final state = (_row?['preview'] as Map?)?['state'];
    if (_active && ['queued', 'generating'].contains(state) && _polls++ < 90) {
      _poll = Timer(const Duration(seconds: 5), _load);
    }
  }

  Future<void> _load() async {
    final id = _row?['id'] ?? widget.requestId;
    if (id == null || _busy) return;
    await _work(() => _service.request(id as String));
  }

  Future<void> _work(Future<Map<String, dynamic>> Function() action) async {
    if (_busy) return;
    _poll?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final row = await action();
      if (mounted) setState(() => _row = row);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_error == null) _schedule();
      }
    }
  }

  Future<void> _saveDraft() => _work(
    () => _service.request(
      '',
      method: 'POST',
      body: {
        'query': widget.query,
        'criteria': widget.criteria,
        'notes': _notes.text.trim(),
        'clientRequestId': _requestKey,
      },
    ),
  );
  Future<void> _status(String state) => _work(
    () => _service.request(
      _row!['id'] as String,
      method: 'PUT',
      body: {'state': state, 'revision': _row!['revision']},
    ),
  );
  Future<void> _generate() async {
    _polls = 0;
    await _work(
      () => _service.request(
        '${_row!['id']}/preview',
        method: 'POST',
        body: {'revision': _row!['revision'], 'aiConsent': _consent},
      ),
    );
  }

  Future<void> _openProduct() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _service.request('${_row!['id']}/product');
      final product = Product.fromJson(
        Map<String, dynamic>.from(data['product'] as Map),
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: product,
            heroTag: 'request-${product.id}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = _row;
    final preview = row?['preview'] as Map? ?? {};
    final imageUrl = preview['imageUrl'];
    final matched = row?['matchedProduct'] as Map?;
    return Scaffold(
      backgroundColor: const Color(0xfff4f7fc),
      appBar: AppBar(
        title: const Text('Find it with NaijaGo'),
        actions: [
          if (row != null || widget.requestId != null)
            IconButton(
              tooltip: 'Refresh request',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.travel_explore, size: 44, color: Color(0xff4169e1)),
          const SizedBox(height: 12),
          Text(
            row?['query']?.toString() ?? widget.query,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'A sourcing request, not an order. No payment is taken and availability is not guaranteed.',
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (row == null && widget.requestId == null) ...[
            if (widget.criteria.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Your search preferences: ${widget.criteria.entries.map((e) => '${e.key}: ${e.value}').join(', ')}',
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Size, colour or other requirements (optional)',
                helperText:
                    'Do not include passwords, payment details or private health information.',
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : _saveDraft,
              child: const Text('Continue to request'),
            ),
          ],
          if (row != null) ...[
            const SizedBox(height: 18),
            Chip(label: Text(_requestStates[row['state']] ?? 'Request')),
            if ((row['notes'] as String? ?? '').isNotEmpty)
              Text(row['notes'] as String),
            if ((row['customerMessage'] as String? ?? '').isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(row['customerMessage'] as String),
                ),
              ),
            if (row['state'] != 'cancelled')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Optional visual concept',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        _conceptLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xff664000),
                        ),
                      ),
                      if (imageUrl is String &&
                          Uri.tryParse(imageUrl)?.scheme == 'https')
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Center(
                                child: Text(
                                  'Preview link expired or unavailable. Tap Refresh.',
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (['queued', 'generating'].contains(preview['state']))
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Creating your concept. This may take a few minutes. You may leave this screen and return through My product requests.',
                          ),
                        ),
                      if (['failed', 'uncertain'].contains(preview['state']))
                        const Text(
                          'The preview could not be confirmed. You can send your text request without an image, or explicitly try another preview.',
                        ),
                      if (preview['canGenerate'] == true) ...[
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _consent,
                          onChanged: _busy
                              ? null
                              : (value) =>
                                    setState(() => _consent = value == true),
                          title: const Text(
                            'Send my search description to Gemini for an AI concept',
                          ),
                          subtitle: const Text(
                            'Only the search description is sent, not your notes or account details.',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy || !_consent ? null : _generate,
                          icon: const Icon(Icons.auto_awesome),
                          label: Text(
                            (preview['generation'] as num? ?? 0) == 0
                                ? 'Generate AI concept'
                                : 'Generate another concept',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (row['state'] == 'draft')
              FilledButton.icon(
                onPressed: _busy ? null : () => _status('requested'),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Request This Product'),
              ),
            if (matched != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Actual catalog listing',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(matched['name']?.toString() ?? ''),
                      Text('Seller: ${matched['sellerName']}'),
                      const Text(
                        'Check the current price, stock and exact product details before ordering.',
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _openProduct,
                        child: const Text('View real product'),
                      ),
                    ],
                  ),
                ),
              ),
            if (row['matchedUnavailable'] == true)
              const Text(
                'The previously matched listing is currently unavailable. No substitute has been added to your cart.',
              ),
            const SizedBox(height: 16),
            for (final event
                in (row['history'] as List? ?? []).reversed.whereType<Map>())
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(_requestStates[event['state']] ?? 'Update'),
                subtitle: Text(
                  '${event['message'] ?? ''}\n${DateTime.tryParse(event['at']?.toString() ?? '')?.toLocal() ?? ''}',
                ),
              ),
            if (row['state'] != 'cancelled')
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Cancel this request?'),
                            content: const Text(
                              'This cancels sourcing, not an order or payment.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Keep request'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Cancel request'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) _status('cancelled');
                      },
                child: const Text('Cancel request'),
              ),
          ],
        ],
      ),
    );
  }
}
