import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/socket_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final Map<String, dynamic> callArgs;
  const IncomingCallScreen({super.key, required this.callArgs});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  String get callId => widget.callArgs['callId'] ?? '';
  String get callerName => widget.callArgs['callerName'] ?? 'Unknown';
  String get callerId => widget.callArgs['callerId'] ?? '';
  String get callerLang => widget.callArgs['callerLang'] ?? 'en';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Auto-reject after 30s
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) _reject();
    });
  }

  void _accept() {
    final appState = context.read<AppState>();
    final ws = context.read<SocketService>();
    ws.answerCall(callId, appState.userId, true);
    Navigator.pushReplacementNamed(context, '/call', arguments: {
      'callId': callId,
      'isCaller': false,
      'contactName': callerName,
      'contactId': callerId,
      'myLang': appState.myLanguage,
      'contactLang': callerLang,
    });
  }

  void _reject() {
    if (!mounted) return;
    final appState = context.read<AppState>();
    final ws = context.read<SocketService>();
    ws.answerCall(callId, appState.userId, false);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D1A),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top info
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(children: [
                const Text('Incoming Call',
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 8),
                Text(callerName,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Language: ${callerLang.toUpperCase()}',
                    style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 13)),
                ),
              ]),
            ),

            // Avatar with pulse
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4), width: 3),
                ),
                child: Center(
                  child: Text(
                    callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 56, color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject
                  GestureDetector(
                    onTap: _reject,
                    child: Column(children: [
                      Container(
                        width: 70, height: 70,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 10),
                      const Text('Decline', style: TextStyle(color: Colors.white54)),
                    ]),
                  ),
                  // Accept
                  GestureDetector(
                    onTap: _accept,
                    child: Column(children: [
                      Container(
                        width: 70, height: 70,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.call, color: Colors.black, size: 32),
                      ),
                      const SizedBox(height: 10),
                      const Text('Accept', style: TextStyle(color: Colors.white54)),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
