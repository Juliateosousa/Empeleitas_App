import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/people_service.dart';
import 'services/auth_service.dart';
import 'person_page.dart';

import 'package:intl/intl.dart';
import 'ui/app_theme.dart';


// If you already have a money() helper elsewhere, delete this helper below.
String money(double v) {
  // Simple formatting without intl (fast). Example: R$ 10000.80
  // If you want "R$ 10.000,80" tell me and I’ll give the intl version.
  return "R\$ ${v.toStringAsFixed(2)}";
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _peopleService = PeopleService();
  final _authService = AuthService();

  bool get _isAdmin {
    final email =
        _authService.currentUser?.email?.trim().toLowerCase();

    return email == const String.fromEnvironment('ADMIN_EMAIL_1') ||
        email == const String.fromEnvironment('ADMIN_EMAIL_2');
  }

  final _searchCtrl = TextEditingController();
  String _query = "";

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String money(double value) {
  final formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  if (value < 0) {
    return "- ${formatter.format(value.abs())}";
  } else {
    return formatter.format(value);
  }
  }

  Future<void> _addPersonDialog() async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Adicionar Pessoa"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nome"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Valor Inicial"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final value =
                  double.tryParse(valueController.text.trim().replaceAll(',', '.')) ?? 0;

              if (name.isNotEmpty) {
                await _peopleService.addPerson(name: name, initialValue: value);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Adicionar"),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDeletePerson() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete person?"),
        content: const Text("This will delete the person and all their movements."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,

      // ✅ NORMAL APP BAR (small height)
      appBar: AppBar(
        backgroundColor: AppTheme.barDark,
        foregroundColor: AppTheme.cream,
        elevation: 0,
        title: const Text(
          "espart.móveis",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout),
            onPressed: () async => await AuthService().signOut(),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _addPersonDialog,
        backgroundColor: AppTheme.greenDark, // circle
        elevation: 4,
        shape: const CircleBorder(),
        child: const Text(
          "+",
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: AppTheme.cream, // plus color
            height: 1,
          ),
        ),
      ),

      body: SafeArea(
        top: false, // ✅ important: AppBar already handles the top safe area
        child: Column(
          children: [
            // ❌ OPTIONAL: remove this strip if you don’t want it under the appbar
            Container(height: 8, color: AppTheme.greenDark),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: "Pesquisar...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppTheme.cream,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppTheme.ink, width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppTheme.ink, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppTheme.ink, width: 2.0),
                  ),
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _peopleService.peopleStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  var docs = snapshot.data?.docs ?? [];

                  docs.sort((a, b) {
                    final an = (a.data()["name"] ?? "").toString().toLowerCase();
                    final bn = (b.data()["name"] ?? "").toString().toLowerCase();
                    return an.compareTo(bn);
                  });

                  if (_query.isNotEmpty) {
                    docs = docs.where((d) {
                      final name = (d.data()["name"] ?? "").toString().toLowerCase();
                      return name.contains(_query);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No people",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data();
                      final name = (data["name"] ?? "").toString();
                      final value = (data["value"] as num?)?.toDouble() ?? 0.0;

                      return Dismissible(
                        key: ValueKey(doc.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async => await _confirmDeletePerson(),
                        onDismissed: (_) async => await _peopleService.deletePerson(doc.id),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 18),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PersonPage(personId: doc.id, personName: name),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.cream,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppTheme.ink, width: 1.4),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  offset: Offset(4, 4),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppTheme.green.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.ink, width: 1.2),
                                  ),
                                  child: const Icon(Icons.person, color: AppTheme.ink, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.ink,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_isAdmin)
                                  Text(
                                    money(value),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}