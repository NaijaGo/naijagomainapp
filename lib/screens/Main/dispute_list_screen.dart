import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naija_go/constants.dart';
import '../../widgets/tech_glow_background.dart';
import 'create_dispute_screen.dart';
import 'dispute_chat_screen.dart';

// Color constants
const Color deepNavyBlue = Color(0xFF000080);
const Color greenYellow = Color(0xFFADFF2F);
const Color whiteBackground = Colors.white;

class DisputeListScreen extends StatefulWidget {
  const DisputeListScreen({super.key});

  @override
  State<DisputeListScreen> createState() => _DisputeListScreenState();
}

class _DisputeListScreenState extends State<DisputeListScreen> {
  List<dynamic> _disputes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDisputes();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _fetchDisputes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = await _getToken();
    if (token == null) {
      debugPrint("Authentication token not found.");
      setState(() {
        _error = "Authentication token not found";
        _loading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/disputes"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _disputes = data);
      } else {
        debugPrint(
          "Failed to load disputes with status code: ${response.statusCode}",
        );
        debugPrint("Response body: ${response.body}");
        setState(() => _error = "Failed to load disputes: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error fetching disputes: $e");
      setState(() => _error = "Error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchUserOrdersAndNavigate() async {
    final token = await _getToken();
    if (token == null) {
      if (!mounted) return;
      debugPrint("Authentication token not found.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Authentication token not found")),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/orders/my"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final orders = jsonDecode(response.body);
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateDisputeScreen(orders: orders),
          ),
        );
        if (result == true) {
          _fetchDisputes();
        }
      } else {
        debugPrint(
          "Failed to fetch orders with status code: ${response.statusCode}",
        );
        debugPrint("Response body: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to fetch orders: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("Error fetching orders: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error fetching orders: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TechGlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "My Disputes",
            style: TextStyle(color: whiteBackground),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: whiteBackground),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: greenYellow))
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: whiteBackground,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _disputes.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.gavel_outlined,
                      size: 80,
                      color: greenYellow.withValues(alpha: 0.72),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No disputes found",
                      style: const TextStyle(
                        color: whiteBackground,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tap the '+' button to open a new dispute.",
                      style: TextStyle(
                        color: whiteBackground.withValues(alpha: 0.75),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _disputes.length,
                itemBuilder: (context, index) {
                  final d = _disputes[index];
                  final orderId = d['order'] != null
                      ? d['order']['_id']
                      : 'N/A';
                  final reason = d['reason'] ?? 'No reason provided';
                  final status = d['status'] ?? 'N/A';

                  Color statusColor;
                  switch (status.toLowerCase()) {
                    case 'resolved':
                      statusColor = greenYellow;
                      break;
                    case 'rejected':
                      statusColor = Colors.red;
                      break;
                    default:
                      statusColor = Colors.orange;
                      break;
                  }

                  return Card(
                    color: whiteBackground.withValues(alpha: 0.94),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: greenYellow.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: const Icon(
                        Icons.assignment,
                        color: deepNavyBlue,
                      ),
                      title: Text(
                        "Dispute for Order $orderId",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: deepNavyBlue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: deepNavyBlue.withValues(alpha: 0.8),
                        ),
                      ),
                      trailing: Chip(
                        label: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            color: deepNavyBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: statusColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(
                            color: deepNavyBlue,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DisputeChatScreen(disputeId: d['_id']),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _fetchUserOrdersAndNavigate,
          backgroundColor: deepNavyBlue,
          foregroundColor: whiteBackground,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
