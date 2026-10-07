import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/review.dart';
import '../../services/review_service.dart';
import '../../widgets/review_photos.dart';
import 'write_review_screen.dart';

class ProductReviewsScreen extends StatefulWidget {
  const ProductReviewsScreen({super.key, required this.product});
  final Product product;
  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}
class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  final _service = ReviewService();
  final List<Review> _reviews = [];
  bool _busy = false, _hasMore = true;
  int _page = 0;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final nextPage = reset ? 1 : _page + 1;
      final result = await _service.list(widget.product.id, nextPage);
      if (!mounted) return;
      setState(() {
        if (reset) _reviews.clear();
        _reviews.addAll(result.reviews); _hasMore = result.hasMore; _page = nextPage;
      });
    } catch (_) { if (mounted) setState(() => _error = 'Could not load reviews. Check your connection and try again.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _report(Review review) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Report review'),
      content: TextField(controller: controller, maxLength: 500, maxLines: 3,
          decoration: const InputDecoration(hintText: 'What should we review?')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Report'))]));
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    try {
      await _service.report(review.id, reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent for moderation.')));
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not report this review. Sign in and try again.'))); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customer reviews')),
    body: RefreshIndicator(onRefresh: () => _load(reset: true),
      child: ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
        Text(widget.product.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Reviews from customers. Photo reviews are checked before publication.'),
        OutlinedButton.icon(onPressed: () async {
          final submitted = await Navigator.of(context).push<bool>(MaterialPageRoute(
              builder: (_) => WriteReviewScreen(product: widget.product)));
          if (submitted == true && mounted) await _load(reset: true);
        }, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Write a review with photos')),
        if (_error != null) ...[Text(_error!), TextButton(onPressed: () => _load(), child: const Text('Try again'))],
        if (!_busy && _error == null && _reviews.isEmpty) const Padding(
            padding: EdgeInsets.symmetric(vertical: 32), child: Text('No published reviews yet.')),
        for (final review in _reviews) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(review.userName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.w700))),
              IconButton(tooltip: 'Report review', onPressed: () => _report(review), icon: const Icon(Icons.flag_outlined))]),
            if (review.verifiedPurchase) const Text('Verified purchase', style: TextStyle(color: Colors.green)),
            Row(children: List.generate(5, (index) => Icon(index < review.rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 20))),
            const SizedBox(height: 8), Text(review.comment), const SizedBox(height: 10), ReviewPhotos(urls: review.photos),
          ]))),
        if (_busy) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
        if (!_busy && _hasMore && _page > 0) TextButton(onPressed: () => _load(), child: const Text('Load more reviews')),
      ])),
  );
}
