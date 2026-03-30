import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/file_uploader.dart';
import '../disputes/dispute_api.dart';

// Color constants
const Color deepNavyBlue = Color(0xFF000080);
const Color greenYellow = Color(0xFFADFF2F);
const Color whiteBackground = Colors.white;

class DisputeCreateScreen extends StatefulWidget {
  final String baseUrl;
  final String token;
  const DisputeCreateScreen({super.key, required this.baseUrl, required this.token});

  @override
  State<DisputeCreateScreen> createState() => _DisputeCreateScreenState();
}

class _DisputeCreateScreenState extends State<DisputeCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderIdCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;
  final List<_LocalAttachment> _attachments = [];
  String? _thumbUrl;

  late final ApiClient _client;
  late final FileUploader _uploader;
  late final DisputeApi _disputes;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(baseUrl: widget.baseUrl, token: widget.token);
    _uploader = FileUploader(baseUrl: widget.baseUrl, token: widget.token);
    _disputes = DisputeApi(_client);
  }

  @override
  void dispose() {
    _orderIdCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: false);
    if (result == null) return;
    final files = result.files.map((pf) => _LocalAttachment(
          file: File(pf.path!),
          name: pf.name,
          size: pf.size,
          contentType: _guessType(pf.name),
        ));
    setState(() => _attachments.addAll(files));
  }

  String _guessType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      // upload attachments first
      final uploaded = <Map<String, dynamic>>[];
      for (final a in _attachments) {
        final signed = await _uploader.getSignedUrl(
          filename: a.name,
          contentType: a.contentType,
          size: a.size,
          purpose: 'dispute',
        );
        await _uploader.uploadToS3(uploadUrl: signed.uploadUrl, file: a.file, contentType: a.contentType);
        uploaded.add({
          'filename': a.name,
          'url': signed.fileUrl,
          'contentType': a.contentType,
          'size': a.size,
        });
      }

      final created = await _disputes.createDispute(
        orderId: _orderIdCtrl.text.trim(),
        thumbnailUrl: _thumbUrl,
        initialMessage: _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
        attachments: uploaded,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute submitted')));
      Navigator.of(context).pop(created); // return the created dispute payload
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: whiteBackground,
      appBar: AppBar(
        title: const Text('Initiate Dispute', style: TextStyle(color: greenYellow)),
        backgroundColor: deepNavyBlue,
        iconTheme: const IconThemeData(color: greenYellow),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _orderIdCtrl,
                  decoration: _inputDecoration(labelText: 'Order ID'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Order ID is required' : null,
                  style: const TextStyle(color: deepNavyBlue),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageCtrl,
                  maxLines: 4,
                  decoration: _inputDecoration(labelText: 'Initial message (optional)'),
                  style: const TextStyle(color: deepNavyBlue),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _pickFiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deepNavyBlue,
                    foregroundColor: greenYellow,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Add attachments'),
                ),
                const SizedBox(height: 8),
                ..._attachments.map((a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _getFileIcon(a.contentType),
                        color: deepNavyBlue,
                      ),
                      title: Text(
                        a.name,
                        style: const TextStyle(color: deepNavyBlue),
                      ),
                      subtitle: Text(
                        '${(a.size / 1024).toStringAsFixed(1)} KB • ${a.contentType}',
                        style: TextStyle(color: deepNavyBlue.withValues(alpha: 0.6)),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: deepNavyBlue),
                        onPressed: () => setState(() => _attachments.remove(a)),
                      ),
                    )),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deepNavyBlue,
                    foregroundColor: greenYellow,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: greenYellow),
                        )
                      : const Text(
                          'Submit Dispute',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String labelText}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: deepNavyBlue),
      hintStyle: TextStyle(color: deepNavyBlue.withValues(alpha: 0.6)),
      filled: true,
      fillColor: deepNavyBlue.withValues(alpha: 0.05),
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
    );
  }

  IconData _getFileIcon(String contentType) {
    if (contentType.startsWith('image/')) return Icons.image_outlined;
    if (contentType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file;
  }
}

class _LocalAttachment {
  final File file;
  final String name;
  final int size;
  final String contentType;
  _LocalAttachment({required this.file, required this.name, required this.size, required this.contentType});
}
