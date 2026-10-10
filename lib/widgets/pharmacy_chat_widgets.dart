import 'package:flutter/material.dart';
import 'pharmacy_ui.dart';

class PharmacyChatHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const PharmacyChatHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: PharmacyUi.border),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 23,
          backgroundColor: PharmacyUi.mint,
          child: Icon(Icons.local_pharmacy_rounded, color: PharmacyUi.teal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PharmacyUi.deepNavy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: PharmacyUi.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PharmacyMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String myRole;
  final VoidCallback? onRetry;
  const PharmacyMessageBubble({
    super.key,
    required this.message,
    required this.myRole,
    this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    final text = message['text']?.toString() ?? '';
    if (message['from'] == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: PharmacyUi.mutedText, fontSize: 12),
        ),
      );
    }
    final mine = message['from'] == myRole;
    final status = message['status'] ?? 'sent';
    final date = DateTime.tryParse(
      message['createdAt']?.toString() ?? '',
    )?.toLocal();
    final time = date == null
        ? ''
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .80,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
        decoration: BoxDecoration(
          color: mine ? PharmacyUi.deepNavy : Colors.white,
          border: mine ? null : Border.all(color: PharmacyUi.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mine
                  ? 'You'
                  : message['from'] == 'pharmacist'
                  ? 'Pharmacist'
                  : 'Customer',
              style: TextStyle(
                color: mine ? Colors.white70 : PharmacyUi.teal,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              text,
              style: TextStyle(
                color: mine ? Colors.white : PharmacyUi.deepNavy,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: TextStyle(
                      color: mine ? Colors.white70 : PharmacyUi.mutedText,
                      fontSize: 11,
                    ),
                  ),
                if (mine)
                  Text(
                    status == 'pending'
                        ? 'Sending...'
                        : status == 'failed'
                        ? 'Not confirmed'
                        : 'Sent',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                if (mine && status == 'failed')
                  TextButton(
                    key: ValueKey('retry-${message['id']}'),
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(44, 36),
                    ),
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
