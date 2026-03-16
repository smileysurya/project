import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';


class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];
  List<Contact> _filtered = [];
  bool _loading = true;
  bool _permissionDenied = false;
  final _searchCtrl = TextEditingController();
  final _manualNumberCtrl = TextEditingController();
  final _manualNameCtrl = TextEditingController();
  String _manualLang = 'en';

  // Language per contact (locally stored)
  final Map<String, String> _contactLangs = {};

  static const _langs = {
    'en': '🇺🇸 EN', 'ta': '🇮🇳 TA', 'hi': '🇮🇳 HI',
    'es': '🇪🇸 ES', 'fr': '🇫🇷 FR', 'de': '🇩🇪 DE',
    'ja': '🇯🇵 JA', 'zh': '🇨🇳 ZH', 'ar': '🇸🇦 AR',
    'ko': '🇰🇷 KO', 'pt': '🇧🇷 PT', 'ru': '🇷🇺 RU',
  };

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _setupSocketCallbacks();
  }

  void _setupSocketCallbacks() {
    final ws = context.read<SocketService>();
    final appState = context.read<AppState>();

    ws.onIncomingCall = (callId, callerId, callerName, callerLang) {
      if (!mounted) return;
      Navigator.pushNamed(context, '/incoming_call', arguments: {
        'callId': callId, 'callerId': callerId,
        'callerName': callerName, 'callerLang': callerLang,
      });
    };
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);

    if (kIsWeb) {
      setState(() { _loading = false; });
      return;
    }

    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      setState(() { _loading = false; _permissionDenied = true; });
      return;
    }

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      // Filter contacts that have phone numbers
      final withPhone = contacts.where((c) => c.phones.isNotEmpty).toList();
      withPhone.sort((a, b) => a.displayName.compareTo(b.displayName));
      setState(() {
        _contacts = withPhone;
        _filtered = withPhone;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _search(String query) {
    setState(() {
      _filtered = _contacts.where((c) =>
        c.displayName.toLowerCase().contains(query.toLowerCase()) ||
        c.phones.any((p) => p.number.contains(query))
      ).toList();
    });
  }

  Future<void> _initiateCall(Contact contact) async {
    final appState = context.read<AppState>();
    final ws = context.read<SocketService>();
    final api = context.read<ApiService>();

    final phone = contact.phones.first.number.replaceAll(RegExp(r'[^0-9]'), '');
    final receiverId = phone;
    final receiverLang = _contactLangs[contact.id] ?? 'en';

    // Create call ID
    final callId = const Uuid().v4();

    // Register call in DB
    await api.startCall(
      callerId: appState.userId,
      receiverId: receiverId,
      callerName: appState.userName,
      receiverName: contact.displayName,
      callerLang: appState.myLanguage,
      receiverLang: receiverLang,
    );

    // Emit via socket
    ws.initiateCall(
      callId: callId,
      callerId: appState.userId,
      receiverId: receiverId,
      callerName: appState.userName,
      callerLang: appState.myLanguage,
      receiverLang: receiverLang,
    );

    if (!mounted) return;
    Navigator.pushNamed(context, '/call', arguments: {
      'callId': callId,
      'isCaller': true,
      'contactName': contact.displayName,
      'contactId': receiverId,
      'myLang': appState.myLanguage,
      'contactLang': receiverLang,
    });
  }

  void _showLangPicker(Contact contact) {
    final current = _contactLangs[contact.id] ?? 'en';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${contact.displayName}\'s Language',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _langs.entries.map((e) => ChoiceChip(
                label: Text(e.value),
                selected: current == e.key,
                selectedColor: const Color(0xFF6C63FF),
                labelStyle: TextStyle(
                  color: current == e.key ? Colors.white : Colors.white70),
                backgroundColor: const Color(0xFF252840),
                onSelected: (_) {
                  setState(() => _contactLangs[contact.id] = e.key);
                  Navigator.pop(context);
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToRecent(String number, String name, String lang) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('recent_manual_calls') ?? [];
    final entry = json.encode({'number': number, 'name': name, 'lang': lang});
    existing.removeWhere((e) => json.decode(e)['number'] == number);
    existing.insert(0, entry);
    final trimmed = existing.take(5).toList();
    await prefs.setStringList('recent_manual_calls', trimmed);
    if (mounted) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _loadRecentManualCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_manual_calls') ?? [];
    return list.map((e) => Map<String, dynamic>.from(json.decode(e))).toList();
  }

  Widget _buildRecentManualCalls() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadRecentManualCalls(),
      builder: (ctx, snap) {
        final recents = snap.data ?? [];
        if (recents.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Recent', style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1)),
            ),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: recents.length,
                itemBuilder: (_, i) {
                  final r = recents[i];
                  return GestureDetector(
                    onTap: () => _initiateManualCall(
                      number: r['number'],
                      name: r['name'],
                      lang: r['lang'],
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252840),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.history, size: 14, color: Colors.white38),
                        const SizedBox(width: 6),
                        Text(r['name'].isNotEmpty ? r['name'] : r['number'],
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _showManualCallSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Call',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Phone Number', style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _manualNumberCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '+91 98765 43210',
                  prefixIcon: Icon(Icons.dialpad, color: Colors.white38),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Name (optional)', style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _manualNameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. Doctor, Office, New Friend',
                  prefixIcon: Icon(Icons.person_outline, color: Colors.white38),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Their Language', style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _langs.entries.map((e) {
                  final selected = _manualLang == e.key;
                  return GestureDetector(
                    onTap: () => setModalState(() => _manualLang = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF6C63FF) : const Color(0xFF252840),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? const Color(0xFF6C63FF) : Colors.white12),
                      ),
                      child: Text(e.value,
                        style: TextStyle(color: selected ? Colors.white : Colors.white60, fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final num = _manualNumberCtrl.text.trim();
                    final name = _manualNameCtrl.text.trim();
                    final lang = _manualLang;
                    Navigator.pop(ctx);
                    _initiateManualCall(number: num, name: name, lang: lang);
                  },
                  icon: const Icon(Icons.call),
                  label: const Text('Call Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      _manualNumberCtrl.clear();
      _manualNameCtrl.clear();
      _manualLang = 'en';
    });
  }

  Future<void> _initiateManualCall({
    required String number,
    required String name,
    required String lang,
  }) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    final appState = context.read<AppState>();
    final ws = context.read<SocketService>();
    final api = context.read<ApiService>();

    final receiverId = cleaned;
    final displayName = name.isNotEmpty ? name : number;
    final callId = const Uuid().v4();

    // Register call in DB
    await api.startCall(
      callerId: appState.userId,
      receiverId: receiverId,
      callerName: appState.userName,
      receiverName: displayName,
      callerLang: appState.myLanguage,
      receiverLang: lang,
    );

    // Emit via socket
    ws.initiateCall(
      callId: callId,
      callerId: appState.userId,
      receiverId: receiverId,
      callerName: appState.userName,
      callerLang: appState.myLanguage,
      receiverLang: lang,
    );

    // Save to recent
    _saveToRecent(cleaned, name, lang);

    if (!mounted) return;
    Navigator.pushNamed(context, '/call', arguments: {
      'callId': callId,
      'isCaller': true,
      'contactName': displayName,
      'contactId': receiverId,
      'myLang': appState.myLanguage,
      'contactLang': lang,
    });
  }



  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
// ... (omitting some parts for brevity but keeping the target logic)
      ),
      body: Column(
        children: [
          if (kIsWeb)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.amber.withOpacity(0.1),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text('Running on web — use "New Call" to dial any ID directly.', style: TextStyle(color: Colors.amber, fontSize: 12))),
                ],
              ),
            ),
          _buildRecentManualCalls(),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: Icon(Icons.search, color: Colors.white38),
              ),
            ),
          ),

          // Status bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D27),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.person, size: 16,
                color: appState.isLoggedIn ? Colors.greenAccent : Colors.redAccent),
              const SizedBox(width: 8),
              Text(appState.userName,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(appState.myLanguage.toUpperCase(),
                  style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12,
                    fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          const SizedBox(height: 8),

          // Contact list
          Expanded(child: _buildContactList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualCallSheet,
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.dialpad),
        label: const Text('New Call'),
      ),
    );
  }

  Widget _buildContactList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
    }

    if (_permissionDenied) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.contacts_outlined, size: 64, color: Colors.white30),
          const SizedBox(height: 16),
          const Text('Contacts permission denied',
            style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings'),
          ),
        ]),
      );
    }

    if (_filtered.isEmpty) {
      return const Center(
        child: Text('No contacts found', style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final c = _filtered[i];
        final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
        final lang = _contactLangs[c.id] ?? 'en';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF252840),
            child: Text(
              c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
              style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(c.displayName, style: const TextStyle(color: Colors.white)),
          subtitle: Text(phone, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            // Language chip
            GestureDetector(
              onTap: () => _showLangPicker(c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF252840),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(lang.toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
            // Call button
            GestureDetector(
              onTap: () => _initiateCall(c),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call, color: Colors.greenAccent, size: 20),
              ),
            ),
          ]),
        );
      },
    );
  }
}
