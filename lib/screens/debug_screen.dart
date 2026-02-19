import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/logging/logger_service.dart';

/// Debug screen for viewing and exporting logs.
/// Access via: long-press on app logo, or Settings > About > Debug Mode
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _logs = 'Loading logs...';
  bool _isLoading = true;
  int _logSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await LoggerService.readNativeLogs();
      final sizeBytes = await LoggerService.getNativeLogFileSizeBytes();
      if (mounted) {
        setState(() {
          _logs = logs;
          _logSizeBytes = sizeBytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logs = 'Error loading logs: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportLogs() async {
    try {
      final exported = await LoggerService.exportLogs();
      await Clipboard.setData(ClipboardData(text: exported));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting logs: $e')),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs?'),
        content: const Text('This will delete all logged data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LoggerService.clearNativeLogs();
      if (mounted) {
        setState(() {
          _logs = '(Logs cleared)';
          _logSizeBytes = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh logs',
          ),
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: _exportLogs,
            tooltip: 'Copy to clipboard',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with log size info
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Log Size: ${(_logSizeBytes / 1024).toStringAsFixed(1)} KB',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _isLoading ? 'Loading...' : 'Ready',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _isLoading ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          // Logs viewer
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _logs,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
