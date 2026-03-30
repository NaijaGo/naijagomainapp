// lib/screens/disputes/dispute_chat_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naija_go/constants.dart';
import '../../widgets/tech_glow_background.dart';

// Color constants
const Color deepNavyBlue = Color(0xFF000080);
const Color greenYellow = Color(0xFFADFF2F);
const Color whiteBackground = Colors.white;
const Color whiteSmoke = Color(0xFFF5F5F5);

class DisputeChatScreen extends StatefulWidget {
  final String disputeId;
  const DisputeChatScreen({super.key, required this.disputeId});

  @override
  State<DisputeChatScreen> createState() => _DisputeChatScreenState();
}

class _DisputeChatScreenState extends State<DisputeChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  List<dynamic> _messages = [];
  bool _loading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndFetchMessages();
  }

  Future<void> _loadUserDataAndFetchMessages() async {
    final prefs = await SharedPreferences.getInstance();
    // Corrected key for user ID
    final userId = prefs.getString('user_id');
    setState(() => _currentUserId = userId);
    await _fetchMessages();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    // Corrected key to match your login screen
    return prefs.getString('jwt_token');
  }

  Future<void> _fetchMessages() async {
    setState(() => _loading = true);
    final token = await _getToken();
    if (token == null) {
      debugPrint("No token found for fetching messages.");
      setState(() => _loading = false);
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/disputes/${widget.disputeId}/messages'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        setState(() {
          _messages = json.decode(res.body);
          _loading = false;
        });
      } else {
        debugPrint(
          "Failed to load messages with status code: ${res.statusCode}",
        );
        debugPrint("Response body: ${res.body}");
        throw Exception("Failed to load messages: ${res.body}");
      }
    } catch (e) {
      debugPrint("Error fetching messages: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final token = await _getToken();
    if (token == null) {
      debugPrint("No token found for sending message.");
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/disputes/${widget.disputeId}/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'text': text}),
      );

      if (res.statusCode == 201) {
        _msgController.clear();
        _fetchMessages();
      } else {
        debugPrint(
          "Failed to send message with status code: ${res.statusCode}",
        );
        debugPrint("Response body: ${res.body}");
        throw Exception("Failed to send message: ${res.body}");
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return TechGlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "Dispute Chat",
            style: TextStyle(color: whiteBackground),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: whiteBackground),
        ),
        body: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: greenYellow),
                    )
                  : _messages.isEmpty
                  ? Center(
                      child: Text(
                        "No messages yet. Start the conversation!",
                        style: TextStyle(
                          color: whiteBackground.withValues(alpha: 0.75),
                        ),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) {
                        final m = _messages[_messages.length - 1 - i];
                        final isUser = m['sender']['_id'] == _currentUserId;

                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 12,
                            ),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? deepNavyBlue
                                  : whiteBackground.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['text'],
                                  style: TextStyle(
                                    color: isUser
                                        ? whiteBackground
                                        : deepNavyBlue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isUser
                                      ? "You"
                                      : "${m['sender']['firstName'] ?? 'Support'}",
                                  style: TextStyle(
                                    color: isUser
                                        ? whiteBackground
                                        : deepNavyBlue.withValues(alpha: 0.6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: whiteSmoke.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          hintStyle: TextStyle(
                            color: deepNavyBlue.withValues(alpha: 0.6),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: deepNavyBlue),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: deepNavyBlue),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: deepNavyBlue,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: whiteBackground,
                        ),
                        style: const TextStyle(color: deepNavyBlue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: () => _sendMessage(_msgController.text),
                      backgroundColor: deepNavyBlue,
                      foregroundColor: whiteBackground,
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
