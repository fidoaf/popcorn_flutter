import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:popcorn_flutter/src/admin/push_notification_panel.dart';
import 'package:popcorn_flutter/src/app/startup_error_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin console for Supabase notes and Web Push broadcasts.
/// See README.md for the required migration, Edge Function and admin role.
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/config/app.env');

  final url = dotenv.env['supabase.url'];
  final publishableKey = dotenv.env['supabase.publishableKey'];
  if (url == null || publishableKey == null) {
    runApp(
      const StartupErrorApp(
        message: 'Unable to start the admin console: missing Supabase configuration.',
        details: 'Add supabase.url and supabase.publishableKey to assets/config/app.env',
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    runApp(const _SupabaseExampleApp());
  } catch (error, stack) {
    runApp(StartupErrorApp(message: 'Unable to start the admin console.', details: '$error\n$stack'));
    // ignore: avoid_print
    print('Admin startup error: $error\n$stack');
  }
}

/// Convenience accessor for the initialized Supabase client.
SupabaseClient get _supabase => Supabase.instance.client;

class _SupabaseExampleApp extends StatelessWidget {
  const _SupabaseExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Popcorn admin console',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Popcorn admin console'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Notes'),
                Tab(text: 'Push notifications'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              const _NotesView(),
              PushNotificationPanel(client: _supabase),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesView extends StatefulWidget {
  const _NotesView();

  @override
  State<_NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<_NotesView> {
  final _controller = TextEditingController();

  /// A realtime stream of the `notes` table ordered by creation time.
  /// The list rebuilds automatically whenever rows are inserted or deleted.
  final _notesStream = _supabase.from('notes').stream(primaryKey: ['id']).order('created_at');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    _controller.clear();
    try {
      await _supabase.from('notes').insert({'content': content});
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _deleteNote(int id) async {
    try {
      await _supabase.from('notes').delete().eq('id', id);
    } on PostgrestException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _notesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notes = snapshot.data!;
                if (notes.isEmpty) {
                  return const Center(child: Text('No notes yet. Add one below.'));
                }
                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return ListTile(
                      title: Text(note['content'] as String),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteNote(note['id'] as int)),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Write a note…', border: OutlineInputBorder()),
                      onSubmitted: (_) => _addNote(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _addNote, child: const Text('Add')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
