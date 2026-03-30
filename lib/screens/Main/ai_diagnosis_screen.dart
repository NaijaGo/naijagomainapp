import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AiDiagnosisScreen extends StatefulWidget {
  const AiDiagnosisScreen({super.key});

  @override
  State<AiDiagnosisScreen> createState() => _AiDiagnosisScreenState();
}

class _AiDiagnosisScreenState extends State<AiDiagnosisScreen> {
  final TextEditingController _controller = TextEditingController();
  String _diagnosis = '';
  bool _isLoading = false;

  final Color primaryColor = const Color(0xFF001F54); // Royal deep blue navy
  final Color secondaryColor = const Color.fromARGB(255, 69, 39, 39); // Deep black
  final Color accentColor = Colors.white;

  Future<void> _getDiagnosis() async {
  final inputText = _controller.text.trim();

  if (inputText.isEmpty) {
    setState(() {
      _diagnosis = "Please enter some symptoms before requesting a diagnosis.";
    });
    return;
  }

  setState(() {
    _isLoading = true;
    _diagnosis = '';
  });

  try {
    // 👇 Replace this with your actual backend URL
    const backendUrl = "https://naijago-backend.onrender.com/api/chatbot";

    final response = await http.post(
      Uri.parse(backendUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': inputText}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      setState(() {
        _diagnosis = body['reply'] ?? 'No response from AI.';
      });
    } else {
      setState(() {
        _diagnosis =
            'Failed to fetch response: ${response.statusCode}\n${response.body}';
      });
    }
  } catch (e) {
    setState(() {
      _diagnosis = 'Error: $e';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: accentColor,
      appBar: AppBar(
        title: const Text('AI Health Diagnosis'),
        backgroundColor: primaryColor,
        foregroundColor: accentColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Describe your symptoms and our AI will give a likely diagnosis.",
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF001F54),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "e.g. sore throat, high fever, dry cough...",
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _getDiagnosis,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.medical_information),
              label: Text(
                _isLoading ? 'Diagnosing...' : 'Get Diagnosis',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: _diagnosis.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _diagnosis,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF0D0D0D),
                          ),
                        ),
                      )
                    : const Text(
                        "Diagnosis will appear here.",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

