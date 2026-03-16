import 'package:flutter/material.dart';
import 'voice_assistant_screen.dart';
import 'contacts_screen.dart';
import 'message_translation_screen.dart';
import 'history_screen.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  void setTabIndex(int index) {
    setState(() => currentIndex = index);
  }

  final List<Widget> _screens = [
    const DashboardView(),
    const VoiceAssistantScreen(),
    const ContactsScreen(),
    const MessageTranslationScreen(),
    const HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A1D27),
        selectedItemColor: const Color(0xFF6C63FF),
        unselectedItemColor: Colors.white38,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic_none),
            activeIcon: Icon(Icons.mic),
            label: 'Voice AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call_outlined),
            activeIcon: Icon(Icons.call),
            label: 'Live Call',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.translate),
            label: 'Translate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Voice Translator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              appState.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text('Hello, ${appState.userName} 👋',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('What would you like to do?',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 30),
            
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: [
                _buildModuleCard(
                  context,
                  index: 1,
                  icon: Icons.mic,
                  title: "Voice Assistant",
                  subtitle: "Speak and translate with AI reply",
                  color: const Color(0xFF6C63FF),
                ),
                _buildModuleCard(
                  context,
                  index: 2,
                  icon: Icons.call,
                  title: "Live Call",
                  subtitle: "Call contact with live subtitles",
                  color: Colors.greenAccent,
                  badge: "Online",
                ),
                _buildModuleCard(
                  context,
                  index: 3,
                  icon: Icons.translate,
                  title: "Text Translate",
                  subtitle: "Type, translate and get AI suggestions",
                  color: Colors.tealAccent,
                ),
                _buildModuleCard(
                  context,
                  index: 4,
                  icon: Icons.history,
                  title: "Call History",
                  subtitle: "View past calls and transcripts",
                  color: Colors.amberAccent,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            _buildActionTile(
              icon: Icons.language,
              title: "Language Settings",
              onTap: () => Navigator.pushNamed(context, '/language'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, {
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    String? badge,
  }) {
    return GestureDetector(
      onTap: () {
        final state = context.findAncestorStateOfType<_HomeScreenState>();
        state?.setTabIndex(index);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(badge,
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const Spacer(),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor: const Color(0xFF1A1D27),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
    );
  }
}
