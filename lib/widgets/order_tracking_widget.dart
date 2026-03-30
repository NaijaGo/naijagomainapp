// lib/widgets/order_tracking_widget.dart

import 'package:flutter/material.dart';

class OrderTrackingWidget extends StatelessWidget {
  final String orderStatus;

  const OrderTrackingWidget({
    super.key,
    required this.orderStatus,
  });

  // 1. ⚠️ Backend Enums (MUST MATCH the Mongoose orderStatus field values)
  final List<String> statuses = const [
    'pending_payment',
    'processing',
    'partially_shipped',
    'shipped',
    'delivered',
    'completed',
  ];

  // 2. Frontend Display Names (Shrunk for better fit)
  final List<String> displayStatuses = const [
    'Payment', // Was 'Payment Pending'
    'Process', // Was 'Processing'
    'Partial', // Was 'Partially Shipped'
    'Shipped', // Was 'Shipped'
    'Deliver', // Was 'Delivered'
    'Complete', // Was 'Completed'
  ];

  int get currentStep {
    final status = orderStatus.trim().toLowerCase();
    
    // Handle status that ends the tracker flow
    if (status == 'cancelled') return -1;
    
    // Find the index of the current status string in the backend list
    return statuses.indexOf(status);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final status = orderStatus.trim().toLowerCase();
    final stepIndex = currentStep;
    
    // 1. Handle Cancelled Status
    if (status == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Order Cancelled',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    
    // Handle status not yet found (e.g., future status was added)
    if (stepIndex == -1) {
      return Center(
        child: Text(
          'Status: ${status[0].toUpperCase() + status.substring(1)} (New Status)',
          style: TextStyle(color: color.error),
        ),
      );
    }

    // 2. Build the Stepper Row (Steps + Dividers)
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          // Generate 6 steps + 5 dividers = 11 items
          children: List.generate(displayStatuses.length * 2 - 1, (i) {
            
            if (i.isEven) {
              // --- STEP ICON (0, 2, 4, 6, 8, 10) ---
              final index = i ~/ 2; 
              final isCompleted = index < stepIndex;
              final isCurrent = index == stepIndex;

              Color bgColor = Colors.grey[300]!;
              IconData icon = Icons.circle_outlined;
              Color iconColor = Colors.grey;

              if (isCompleted) {
                bgColor = Colors.green;
                icon = Icons.check;
                iconColor = Colors.white;
              } else if (isCurrent) {
                bgColor = color.primary; 
                icon = Icons.radio_button_checked;
                iconColor = Colors.white;
              }

              return SizedBox(
                width: 50, // ⚠️ VISUAL FIX: Reduced width to fit 6 columns
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 14, // ⚠️ VISUAL FIX: Reduced radius
                      backgroundColor: bgColor,
                      child: Icon(icon, color: iconColor, size: 16), // ⚠️ VISUAL FIX: Reduced icon size
                    ),
                    const SizedBox(height: 4), // ⚠️ VISUAL FIX: Reduced spacing
                    Text(
                      displayStatuses[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8, // ⚠️ VISUAL FIX: Much smaller font for labels
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCompleted || isCurrent ? Colors.black : Colors.grey,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              );
            } else {
              // --- DIVIDER LINE (1, 3, 5, 7, 9) ---
              final prevIndex = (i - 1) ~/ 2;
              final dividerIsActive = prevIndex < stepIndex;

              return Expanded(
                child: Container(
                  height: 2.0,
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  color: dividerIsActive ? Colors.green : Colors.grey[300],
                ),
              );
            }
          }),
        ),
        const SizedBox(height: 10),
        // Display current status explicitly
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Current Status: ${displayStatuses[stepIndex]}',
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: color.primary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
