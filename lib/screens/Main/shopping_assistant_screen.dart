import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/shopping_assistant_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shopping_assistant_identity.dart';
import 'home_screen.dart' show ProductCard, SearchScreen;

class ShoppingAssistantScreen extends StatefulWidget {
  const ShoppingAssistantScreen({super.key, this.service});
  final ShoppingAssistantService? service;
  @override
  State<ShoppingAssistantScreen> createState() =>
      _ShoppingAssistantScreenState();
}

class _ShoppingAssistantScreenState extends State<ShoppingAssistantScreen> {
  final _request = TextEditingController();
  late final ShoppingAssistantService _service;
  ShoppingSuggestions? _suggestions;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ShoppingAssistantService();
  }

  @override
  void dispose() {
    _request.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = null;
    });
    try {
      final suggestions = await _service.suggest(_request.text);
      if (mounted) setState(() => _suggestions = suggestions);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ShoppingAssistantException
              ? error.message
              : 'Could not load suggestions. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _suggestions;
    final products = result?.products ?? [];
    return Scaffold(
      backgroundColor: AppTheme.softGrey,
      appBar: AppBar(
        title: const Text('Shopping Assistant'),
        foregroundColor: AppTheme.logoBlue,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShoppingAssistantIntro(),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _request,
                      enabled: !_loading,
                      maxLength: 500,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: 'What are you looking for?',
                        hintText: 'Find me a phone charger under ₦15k',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.newline,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                                'I have ₦10,000. I need food for 3 people tonight.',
                                'Find me a phone charger under ₦15k.',
                                "I need a birthday gift for my girlfriend.",
                              ]
                              .map(
                                (example) => ActionChip(
                                  label: Text(example),
                                  onPressed: _loading
                                      ? null
                                      : () => setState(
                                          () => _request.text = example,
                                        ),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.logoBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _loading ? null : _find,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(
                        _loading ? 'Finding listings…' : 'Find options',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SearchScreen(
                                  initialQuery: _request.text.trim(),
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.search),
                      label: const Text('Use normal search'),
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      TextButton(onPressed: _find, child: const Text('Retry')),
                    ],
                    if (result != null) ...[
                      const SizedBox(height: 12),
                      if (result.question != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.softGrey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            result.question!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (result.question != null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Edit your request above and tap Find options again.',
                          ),
                        ),
                      if (result.message.isNotEmpty)
                        Text(
                          result.message,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (result.maxPrice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Maximum per suggestion: ${NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2).format(result.maxPrice)} · delivery excluded',
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          result.notice,
                          style: const TextStyle(
                            color: AppTheme.mutedText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth >= 700 ? 3 : 2,
                  mainAxisExtent:
                      // Allow wrapped card text on narrow phone columns.
                      ProductCard.standardCardHeight +
                      24 +
                      (MediaQuery.textScalerOf(context).scale(100) - 100).clamp(
                        0,
                        300,
                      ),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ProductCard(
                    product: products[index],
                    heroTag:
                        'assistant-${products[index].id}-${products[index].offerId ?? ''}',
                  ),
                  childCount: products.length,
                ),
              ),
            ),
            if (result?.limited == true && products.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Showing a selection of matches. Refine your request or use normal search for more listings.',
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
