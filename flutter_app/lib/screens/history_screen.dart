import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _calls = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final api = context.read<ApiService>();
    final calls = await api.getCallHistory(appState.userId);
    setState(() { _calls = calls; _loading = false; });
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ended': return Colors.greenAccent;
      case 'missed': return Colors.redAccent;
      case 'rejected': return Colors.orangeAccent;
      default: return Colors.white38;
    }
  }

  IconData _statusIcon(String status, bool isCaller) {
    switch (status) {
      case 'ended': return isCaller ? Icons.call_made : Icons.call_received;
      case 'missed': return Icons.call_missed;
      case 'rejected': return Icons.call_end;
      default: return Icons.call;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
        : _calls.isEmpty
          ? const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.history, size: 64, color: Colors.white12),
                SizedBox(height: 16),
                Text('No call history yet', style: TextStyle(color: Colors.white38)),
              ]))
          : ListView.builder(
              itemCount: _calls.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (_, i) {
                final call = _calls[i];
                final isCaller = call['callerId'] == appState.userId;
                final otherName = isCaller
                  ? (call['receiverName'] ?? call['receiverId'] ?? 'Unknown')
                  : (call['callerName'] ?? call['callerId'] ?? 'Unknown');
                final status = call['status'] ?? 'ended';
                final duration = call['duration'] ?? 0;
                final timestamp = call['timestamp'] ?? '';
                DateTime? dt;
                try { dt = DateTime.parse(timestamp); } catch (_) {}

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D27),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _statusIcon(status, isCaller),
                        color: _statusColor(status), size: 20),
                    ),
                    title: Text(otherName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Row(children: [
                          Text(status.toUpperCase(),
                            style: TextStyle(
                              color: _statusColor(status), fontSize: 11,
                              fontWeight: FontWeight.w600)),
                          if (duration > 0) ...[
                            const Text(' · ', style: TextStyle(color: Colors.white24)),
                            Text(_formatDuration(duration),
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ]),
                        if (dt != null) ...[
                          const SizedBox(height: 2),
                          Text(DateFormat('MMM d, h:mm a').format(dt.toLocal()),
                            style: const TextStyle(color: Colors.white30, fontSize: 11)),
                        ],
                      ],
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      // Lang badges
                      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _langBadge(call['callerLang'] ?? 'en'),
                        const SizedBox(height: 4),
                        _langBadge(call['receiverLang'] ?? 'en'),
                      ]),
                    ]),
                    onTap: () => _showTranscript(call['callId']),
                  ),
                );
              },
            ),
    );
  }

  Widget _langBadge(String lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(lang.toUpperCase(),
        style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 9,
          fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _showTranscript(String? callId) async {
    if (callId == null) return;
    final api = context.read<ApiService>();
    final messages = await api.getTranscript(callId);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D27),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const Text('Call Transcript',
            style: TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: messages.isEmpty
              ? const Center(child: Text('No transcript available',
                  style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252840),
                        borderRadius: BorderRadius.circular(10)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m['speakerName'] ?? m['speaker'] ?? 'Speaker',
                          style: const TextStyle(color: Color(0xFF6C63FF),
                            fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(m['originalText'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                        if ((m['translatedText'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(m['translatedText'],
                            style: const TextStyle(color: Colors.tealAccent,
                              fontSize: 13, fontStyle: FontStyle.italic)),
                        ],
                      ]),
                    );
                  },
                ),
          ),
        ]),
      ),
    );
  }
}
