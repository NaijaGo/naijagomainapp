// lib/screens/Main/faq_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/tech_glow_background.dart';

// Color constants
const Color deepNavyBlue = Color(0xFF000080);
const Color greenYellow = Color(0xFFADFF2F);
const Color whiteBackground = Colors.white;
const Color whiteSmoke = Color(0xFFF5F5F5);

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final Map<String, List<Map<String, String>>> _faqData = {
    "General": [
      {
        "q": "What is this app about?",
        "a":
            "This app helps you manage orders, track disputes, and communicate easily with support.",
      },
      {
        "q": "How do I create an account?",
        "a":
            "Go to the registration screen, enter your details, and submit to create your account.",
      },
      {
        "q": "How do I reset my password?",
        "a":
            "On the login screen, tap 'Forgot Password' and follow the instructions.",
      },
    ],
    "Orders": [
      {
        "q": "How do I place an order?",
        "a": "Browse products, add them to cart, and proceed to checkout.",
      },
      {
        "q": "Where can I see my orders?",
        "a":
            "Go to 'My Orders' from your account screen to view all past and active orders.",
      },
      {
        "q": "Can I cancel or change an order?",
        "a":
            "Yes, as long as the order is not yet shipped. Go to 'My Orders' and select cancel/change.",
      },
    ],
    "Disputes & Returns": [
      {
        "q": "What is a dispute?",
        "a":
            "A dispute is a request you open when you are unsatisfied with your order (e.g., damaged, missing items).",
      },
      {
        "q": "When should I open a dispute?",
        "a":
            "Open a dispute if you received the wrong item, damaged goods, or if your order never arrived.",
      },
      {
        "q": "How do I submit a dispute with attachments?",
        "a":
            "Go to 'Returns & Disputes', choose the order, provide details, and attach relevant images before submitting.",
      },
      {
        "q": "How long does it take to resolve a dispute?",
        "a":
            "Dispute resolution usually takes 3–7 business days depending on complexity.",
      },
      {
        "q": "What are the possible dispute statuses?",
        "a": "Disputes may be Pending, Reviewing, Processed, or Settled.",
      },
    ],
    "Payments": [
      {
        "q": "What payment methods are supported?",
        "a":
            "We support debit/credit cards, bank transfers, and digital wallets depending on your region.",
      },
      {
        "q": "Is my payment information secure?",
        "a":
            "Yes. Payments are processed using industry-standard encryption and are never stored directly.",
      },
      {
        "q": "When will I be charged?",
        "a": "You will be charged once your order is confirmed.",
      },
    ],
    "Technical Issues": [
      {
        "q": "Why can’t I log in?",
        "a":
            "Ensure you have entered the correct credentials and have a stable internet connection.",
      },
      {
        "q": "The app is crashing — what should I do?",
        "a":
            "Try restarting the app. If the issue persists, reinstall or contact support.",
      },
    ],
    "Support": [
      {
        "q": "How can I contact support?",
        "a":
            "Go to the 'Support' section in the app or email us directly at support@example.com.",
      },
      {
        "q": "Do you have live chat or email?",
        "a":
            "Yes, you can reach us through live chat inside the app or by email.",
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final filteredFaq = _faqData.map((category, faqs) {
      final filtered = faqs.where((faq) {
        final query = _searchQuery.toLowerCase();
        return faq["q"]!.toLowerCase().contains(query) ||
            faq["a"]!.toLowerCase().contains(query);
      }).toList();
      return MapEntry(category, filtered);
    });

    return TechGlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("FAQs", style: TextStyle(color: whiteBackground)),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: whiteBackground),
          centerTitle: true,
          elevation: 0,
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search FAQs...",
                  hintStyle: TextStyle(
                    color: deepNavyBlue.withValues(alpha: 0.6),
                  ),
                  prefixIcon: const Icon(Icons.search, color: deepNavyBlue),
                  filled: true,
                  fillColor: whiteSmoke.withValues(alpha: 0.96),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: deepNavyBlue),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: deepNavyBlue),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: deepNavyBlue, width: 2),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final category in filteredFaq.keys)
                    if (filteredFaq[category]!.isNotEmpty)
                      Card(
                        elevation: 0,
                        color: whiteSmoke.withValues(alpha: 0.96),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: deepNavyBlue,
                            width: 1.5,
                          ),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            category,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: deepNavyBlue,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.expand_more,
                            color: deepNavyBlue,
                          ),
                          children: [
                            for (final faq in filteredFaq[category]!)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 8.0,
                                  left: 16,
                                  right: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.help_outline,
                                        color: deepNavyBlue,
                                      ),
                                      title: Text(
                                        faq["q"]!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: deepNavyBlue,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6.0,
                                        ),
                                        child: Text(
                                          faq["a"]!,
                                          style: TextStyle(
                                            color: deepNavyBlue.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Divider(
                                      color: deepNavyBlue,
                                      height: 1,
                                      thickness: 0.5,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
            // Contact support button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Live chat coming soon...Message us at naijagodeliveryservice@gmail.com",
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.support_agent),
                label: const Text("Still Need Help? Contact Support"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: deepNavyBlue,
                  foregroundColor: whiteBackground,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
