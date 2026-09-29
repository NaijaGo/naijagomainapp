import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/planned_order_service.dart';

class PlannedOrderComposer extends StatefulWidget {
  const PlannedOrderComposer({
    super.key,
    required this.items,
    required this.destination,
    required this.singleSeller,
    required this.sellerType,
    required this.sellerId,
  });

  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> destination;
  final bool singleSeller;
  final String sellerType;
  final String? sellerId;

  static Future<PlannedOrderDestination?> open(
    BuildContext context, {
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> destination,
    required bool singleSeller,
    required String sellerType,
    required String? sellerId,
  }) => showModalBottomSheet<PlannedOrderDestination>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PlannedOrderComposer(
      items: items,
      destination: destination,
      singleSeller: singleSeller,
      sellerType: sellerType,
      sellerId: sellerId,
    ),
  );

  @override
  State<PlannedOrderComposer> createState() => _PlannedOrderComposerState();
}

class _PlannedOrderComposerState extends State<PlannedOrderComposer> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final PlannedOrderService _service = PlannedOrderService();
  String _kind = 'group';
  String _frequency = 'weekly';
  int _cutoffHours = 4;
  int _participantLimit = 10;
  DateTime _firstDate = DateTime.now().add(const Duration(days: 2));
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.singleSeller) _kind = 'recurring';
  }

  @override
  void dispose() {
    _name.dispose();
    _service.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _safeItems => widget.items.map((item) {
    return <String, dynamic>{
      'product': item['product'],
      if (item['offer'] != null) 'offer': item['offer'],
      if (item['variantId'] != null) 'variantId': item['variantId'],
      if (item['selectedSize'] != null) 'selectedSize': item['selectedSize'],
      'quantity': item['quantity'],
      if (item['customerNote'] != null) 'customerNote': item['customerNote'],
    };
  }).toList();

  String get _destinationLabel {
    final value =
        widget.destination['address']?.toString().trim() ?? 'Delivery address';
    return value.length <= 80 ? value : value.substring(0, 80);
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _firstDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null && mounted) setState(() => _firstDate = value);
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (_safeItems.isEmpty) {
      setState(
        () => _error = 'Add at least one product before planning an order.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_kind == 'group') {
        if (!widget.singleSeller) {
          throw const PlannedOrderException(
            'Group orders must contain products from one shop only.',
          );
        }
        final result = await _service.createGroup({
          'name': _name.text.trim(),
          'sellerType': widget.sellerType,
          'sellerId': widget.sellerType == 'vendor' ? widget.sellerId : null,
          'anchorItem': _safeItems.first,
          'items': _safeItems,
          'cutoffAt': DateTime.now()
              .add(Duration(hours: _cutoffHours))
              .toUtc()
              .toIso8601String(),
          'participantLimit': _participantLimit,
          'destination': widget.destination,
          'destinationLabel': _destinationLabel,
          'schedule': {'mode': 'now'},
        });
        final group = result['group'] is Map
            ? Map<String, dynamic>.from(result['group'] as Map)
            : <String, dynamic>{};
        final id = group['id']?.toString();
        final token = result['inviteToken']?.toString();
        if (id == null || token == null || !mounted) {
          throw const PlannedOrderException(
            'The group was created, but its invitation is unavailable.',
          );
        }
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Group order created'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share this private invitation code with the people you want to join:',
                ),
                const SizedBox(height: 12),
                SelectableText(
                  token,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: token));
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Invitation code copied.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Open group'),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.pop(context, PlannedOrderDestination('group', id));
        }
      } else {
        final result = await _service.createRecurring({
          'name': _name.text.trim(),
          'items': _safeItems,
          'destination': widget.destination,
          'rule': {
            'timeZone': 'Africa/Lagos',
            'startDate': DateFormat('yyyy-MM-dd').format(_firstDate),
            'frequency': _frequency,
            'windowStart': '09:00',
            'windowEnd': '12:00',
          },
          'substitutionPreference': 'do_not_replace',
          'reminderLeadDays': 1,
        });
        final id = (result['_id'] ?? result['id'])?.toString();
        if (id == null || !mounted) {
          throw const PlannedOrderException(
            'The recurring plan could not be opened.',
          );
        }
        Navigator.pop(context, PlannedOrderDestination('recurring', id));
      }
    } on PlannedOrderException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Plan this cart',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Stock and prices are checked again before payment. Recurring plans never charge automatically.',
                style: TextStyle(color: Color(0xFF667085), height: 1.4),
              ),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'group',
                    enabled: widget.singleSeller,
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Group'),
                  ),
                  const ButtonSegment(
                    value: 'recurring',
                    icon: Icon(Icons.event_repeat_outlined),
                    label: Text('Recurring'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: _submitting
                    ? null
                    : (value) => setState(() => _kind = value.first),
              ),
              if (!widget.singleSeller) ...[
                const SizedBox(height: 8),
                const Text(
                  'Group orders use one shop. Your cart contains more than one seller, so only a recurring plan is available.',
                  style: TextStyle(color: Color(0xFFB54708), fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                enabled: !_submitting,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: _kind == 'group' ? 'Group name' : 'Plan name',
                  hintText: _kind == 'group'
                      ? 'Office lunch order'
                      : 'Weekly household restock',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
              if (_kind == 'group') ...[
                DropdownButtonFormField<int>(
                  initialValue: _cutoffHours,
                  decoration: const InputDecoration(
                    labelText: 'Invitation closes in',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 hour')),
                    DropdownMenuItem(value: 4, child: Text('4 hours')),
                    DropdownMenuItem(value: 24, child: Text('24 hours')),
                    DropdownMenuItem(value: 72, child: Text('3 days')),
                  ],
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _cutoffHours = value ?? 4),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _participantLimit,
                  decoration: const InputDecoration(
                    labelText: 'Maximum participants',
                    border: OutlineInputBorder(),
                  ),
                  items: const [5, 10, 20, 50]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value people'),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) =>
                            setState(() => _participantLimit = value ?? 10),
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'weekly',
                      child: Text('Every week'),
                    ),
                    DropdownMenuItem(
                      value: 'biweekly',
                      child: Text('Every two weeks'),
                    ),
                    DropdownMenuItem(
                      value: 'monthly',
                      child: Text('Every month'),
                    ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (value) =>
                            setState(() => _frequency = value ?? 'weekly'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: const BorderSide(color: Color(0xFF98A2B3)),
                  ),
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('First delivery review'),
                  subtitle: Text(
                    DateFormat('EEE, d MMM yyyy').format(_firstDate),
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _submitting ? null : _pickDate,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _kind == 'group'
                              ? Icons.group_add_outlined
                              : Icons.event_repeat_outlined,
                        ),
                  label: Text(
                    _submitting
                        ? 'Creating...'
                        : _kind == 'group'
                        ? 'Create group order'
                        : 'Create recurring plan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
