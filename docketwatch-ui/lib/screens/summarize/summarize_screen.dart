import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/providers.dart';
import '../../models/document_model.dart';

/// Ad-hoc PDF upload tool with drag-and-drop for AI summarization.
/// Replaces: tools/summarize/index.cfm + ajax/upload_and_summarize.cfm
class SummarizeScreen extends ConsumerStatefulWidget {
  const SummarizeScreen({super.key});

  @override
  ConsumerState<SummarizeScreen> createState() => _SummarizeScreenState();
}

class _SummarizeScreenState extends ConsumerState<SummarizeScreen> {
  bool _uploading = false;
  DocumentModel? _result;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Document Summarizer',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Upload a PDF to extract structured data and generate an AI summary using FACT_GUARD verification.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Upload zone
            InkWell(
              onTap: _uploading ? null : _pickAndUpload,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _uploading
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                child: _uploading
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Uploading and processing...'),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file, size: 48,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 12),
                          const Text('Click to upload a PDF',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('Maximum file size: 25 MB',
                              style: TextStyle(fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                )),
              ),
            ],

            // Result display
            if (_result != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Text('Document uploaded: ${_result!.pdfTitle}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Size: ${_result!.fileSizeFormatted}'),
                      Text('ID: ${_result!.docUid}'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          await ref.read(apiClientProvider)
                              .summarizeDocument(_result!.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Summarization queued')),
                            );
                          }
                        },
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Generate AI Summary'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _uploading = true;
      _error = null;
      _result = null;
    });

    try {
      final doc = await ref.read(apiClientProvider).uploadDocument(
        file.bytes!,
        file.name,
      );
      setState(() => _result = doc);
    } catch (e) {
      setState(() => _error = 'Upload failed: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }
}
