import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'ui/app_theme.dart';
import 'package:intl/intl.dart';

class PersonPage extends StatefulWidget {
  final String personId;
  final String personName;

  const PersonPage({
    super.key,
    required this.personId,
    required this.personName,
  });

  @override
  State<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<PersonPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final AuthService _authService = AuthService();

  bool get _isAdmin {
    final email =
        _authService.currentUser?.email?.trim().toLowerCase();

    return email == const String.fromEnvironment('ADMIN_EMAIL_1') ||
        email == const String.fromEnvironment('ADMIN_EMAIL_2');
  }

  int? _fy; // year
  int? _fm; // month
  int? _fd; // day

  DocumentReference<Map<String, dynamic>> get _personDoc =>
      _db.collection("people").doc(widget.personId);

  CollectionReference<Map<String, dynamic>> get _movementsCol =>
      _personDoc.collection("movements");

  // ---------------- Date helpers ----------------

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  String _fmtMonthYear(DateTime d) {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return "${months[d.month - 1]} ${d.year}";
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

  Query<Map<String, dynamic>> _getMovementsQuery() {
    Query<Map<String, dynamic>> query = _movementsCol;

    // Employees are ONLY allowed to request Empeleitas.
    if (!_isAdmin) {
      query = query.where(
        "type",
        isEqualTo: "empeleita",
      );
    }

    if (_fy == null) {
      return query.orderBy(
        "date",
        descending: true,
      );
    }

    DateTime start;
    DateTime end;

    if (_fm == null) {
      start = DateTime(_fy!, 1, 1);
      end = DateTime(_fy! + 1, 1, 1);
    } else if (_fd == null) {
      start = DateTime(_fy!, _fm!, 1);

      end = (_fm == 12)
          ? DateTime(_fy! + 1, 1, 1)
          : DateTime(_fy!, _fm! + 1, 1);
    } else {
      start = DateTime(
        _fy!,
        _fm!,
        _fd!,
      );

      end = start.add(
        const Duration(days: 1),
      );
    }

    return query
        .where(
          "date",
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(start),
        )
        .where(
          "date",
          isLessThan:
              Timestamp.fromDate(end),
        )
        .orderBy(
          "date",
          descending: true,
        );
  }

  // ---------------- Add movement picker ----------------

    Future<void> _openTypePicker() async {
    // Employees go directly to Empeleita.
    if (!_isAdmin) {
      await _openEmpeleitaForm();
      return;
    }

    // Admins can choose Empeleita or Vale.
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Adicionar Movimento"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openEmpeleitaForm();
                },
                child: const Text("Empeleita"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openValeForm();
                },
                child: const Text("Vale"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Empeleita ----------------

  Future<void> _openEmpeleitaForm() async {
    DateTime selectedDate = DateTime.now();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text("Adicionar Empeleita"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_fmtDate(selectedDate))),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setLocalState(() => selectedDate = picked);
                        }
                      },
                      child: const Text("Escolher Data"),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Valor",
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: "Descrição",
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final amountText =
                    amountCtrl.text.trim().replaceAll(',', '.');
                final amount = double.tryParse(amountText);
                final desc = descCtrl.text.trim();

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Valor inválido."),
                    ),
                  );
                  return;
                }

                try {
                  await _db.runTransaction((tx) async {
                    // Empeleita adds to the balance
                    tx.update(
                      _personDoc,
                      {
                        "value": FieldValue.increment(amount),
                      },
                    );

                    final moveRef = _movementsCol.doc();

                    tx.set(moveRef, {
                      "type": "empeleita",
                      "amount": amount,
                      "description": desc.isEmpty ? null : desc,
                      "date": Timestamp.fromDate(selectedDate),
                    });
                  });

                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error saving Empeleita: $e"),
                    ),
                  );
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }


  // ---------------- Vale ----------------

  Future<void> _openValeForm() async {
    if (!_isAdmin) {
      return;
    }

    DateTime selectedDate = DateTime.now();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text("Adicionar Vale"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_fmtDate(selectedDate))),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setLocalState(() => selectedDate = picked);
                        }
                      },
                      child: const Text("Escolher Data"),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "Valor",
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: "Descrição",
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final amountText =
                    amountCtrl.text.trim().replaceAll(',', '.');
                final amount = double.tryParse(amountText);
                final desc = descCtrl.text.trim();

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Valor inválido."),
                    ),
                  );
                  return;
                }

                try {
                  await _db.runTransaction((tx) async {
                    // Vale subtracts from the balance
                    tx.update(
                      _personDoc,
                      {
                        "value": FieldValue.increment(-amount),
                      },
                    );

                    final moveRef = _movementsCol.doc();

                    tx.set(moveRef, {
                      "type": "vale",
                      "amount": amount,
                      "description": desc.isEmpty ? null : desc,
                      "date": Timestamp.fromDate(selectedDate),
                    });
                  });

                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error saving Vale: $e"),
                    ),
                  );
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Delete movement ----------------

  Future<void> _deleteMovement({
    required String movementId,
    required String type,
    required double amount,
  }) async {
    // Employees can ONLY delete Empeleitas.
    if (!_isAdmin && type != "empeleita") {
      return;
    }

    double delta;

    if (type == "empeleita") {
      // Removing an Empeleita removes money from the total.
      delta = -amount;
    } else if (type == "vale") {
      // Removing a Vale puts the money back into the total.
      delta = amount;
    } else {
      return;
    }

    await _db.runTransaction((tx) async {
      final moveRef = _movementsCol.doc(movementId);

      tx.update(
        _personDoc,
        {
          "value": FieldValue.increment(delta),
        },
      );

      tx.delete(moveRef);
    });
  }

  Future<bool> _confirmDeleteMovement() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Deletar Movimento?"),
        content: const Text("Isso vai remover o movimento e atualizar o valor da pessoa."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );
    return ok ?? false;
  }

  // ---------------- Date filter UI ----------------

  Widget _dateFilterBar() {
    String two(int? n, String placeholder) =>
        n == null ? placeholder : n.toString().padLeft(2, '0');

    final dd = two(_fd, "DD");
    final mm = two(_fm, "MM");
    final yyyy = _fy?.toString() ?? "AAAA";
    final isActive = _fy != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: InkWell(
        onTap: _openSmartDateFilter,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cream,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.ink, width: 1.3),
            boxShadow: const [
              BoxShadow(color: Colors.black54, offset: Offset(4, 4), blurRadius: 0),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: AppTheme.ink),
              const SizedBox(width: 10),
              const Text("Filtro:", style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.ink)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "$dd/$mm/$yyyy",
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.ink),
                ),
              ),
              if (isActive)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _fy = null;
                      _fm = null;
                      _fd = null;
                    });
                  },
                  child: const Text("Clear"),
                )
              else
                const Icon(Icons.chevron_right, color: AppTheme.ink),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSmartDateFilter() async {
    int? ly = _fy;
    int? lm = _fm;
    int? ld = _fd;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          String two(int? n, String placeholder) =>
              n == null ? placeholder : n.toString().padLeft(2, '0');

          return AlertDialog(
            title: const Text("Escolher Data"),
            content: Row(
              children: [
                Expanded(
                  child: _squareBox(
                    label: "DD",
                    value: two(ld, "DD"),
                    onTap: () async {
                      if (ly == null || lm == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Select Year and Month first.")),
                        );
                        return;
                      }
                      final initial = DateTime(ly!, lm!, ld ?? 1);
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null) return;
                      setLocal(() => ld = picked.day);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _squareBox(
                    label: "MM",
                    value: two(lm, "MM"),
                    onTap: () async {
                      final pickedMonth = await _pickMonthGrid();
                      if (pickedMonth == null) return;
                      setLocal(() {
                        lm = pickedMonth;
                        ld = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _squareBox(
                    label: "AAAA",
                    value: ly?.toString() ?? "AAAA",
                    onTap: () async {
                      final pickedYear = await _pickYearGrid();
                      if (pickedYear == null) return;
                      setLocal(() {
                        ly = pickedYear;
                        ld = null;
                      });
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              TextButton(
                onPressed: () => setLocal(() {
                  ly = null;
                  lm = null;
                  ld = null;
                }),
                child: const Text("Clear"),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _fy = ly;
                    _fm = lm;
                    _fd = ld;
                  });
                  Navigator.pop(context);
                },
                child: const Text("Apply"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _squareBox({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.ink, width: 1.2),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.55))),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Future<int?> _pickMonthGrid() async {
    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Escolher Mês"),
        content: SizedBox(
          width: 320,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: List.generate(12, (i) {
              final m = i + 1;
              return _gridPickTile(
                text: m.toString().padLeft(2, '0'),
                onTap: () => Navigator.pop(context, m),
              );
            }),
          ),
        ),
      ),
    );
  }

  Future<int?> _pickYearGrid() async {
    final now = DateTime.now().year;
    final years = List.generate(16, (i) => now - i);

    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Escolher Ano"),
        content: SizedBox(
          width: 320,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: years
                .map((y) => _gridPickTile(
                      text: y.toString(),
                      onTap: () => Navigator.pop(context, y),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _gridPickTile({required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.ink, width: 1.2),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  // ---------------- Movements list ----------------

  Widget _movementsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getMovementsQuery().snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snap.hasError) {
          return Center(
            child: Text(
              "Error loading movements: ${snap.error}",
            ),
          );
        }

        final allDocs = snap.data?.docs ?? [];

        // Admin sees everything.
        // Employee sees ONLY Empeleitas.
        final docs = _isAdmin
            ? allDocs
            : allDocs.where((doc) {
                final type =
                    (doc.data()["type"] ?? "").toString();

                return type == "empeleita";
              }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "Nenhuma empeleita encontrada",
              style: TextStyle(
                color: AppTheme.cream,
              ),
            ),
          );
        }

        final Map<
            String,
            List<QueryDocumentSnapshot<Map<String, dynamic>>>>
            grouped = {};

        for (final d in docs) {
          final ts = d.data()["date"] as Timestamp?;

          if (ts == null) continue;

          final date = ts.toDate();

          final key =
              "${date.year}-${date.month.toString().padLeft(2, '0')}";

          grouped.putIfAbsent(key, () => []).add(d);
        }

        final keys = grouped.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            16,
            4,
            16,
            16,
          ),
          itemCount: keys.length,
          itemBuilder: (context, idx) {
            final key = keys[idx];
            final monthDocs = grouped[key]!;

            final firstDate =
                (monthDocs.first.data()["date"] as Timestamp)
                    .toDate();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _fmtMonthYear(firstDate),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.cream,
                    ),
                  ),
                ),

                for (final d in monthDocs)
                  _movementItem(d),
              ],
            );
          },
        );
      },
    );
  }

  Widget _movementItem(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final movementId = doc.id;

    final type =
        (data["type"] ?? "").toString();

    final amount =
        (data["amount"] as num?)?.toDouble() ?? 0.0;

    final description =
        (data["description"] ?? "").toString();

    final date =
        (data["date"] as Timestamp?)?.toDate() ??
            DateTime.now();

    final isEmpeleita = type == "empeleita";
    final isVale = type == "vale";

    // Extra protection:
    // employees should never render a Vale.
    if (!_isAdmin && !isEmpeleita) {
      return const SizedBox.shrink();
    }

    // Admin can delete everything.
    // Employee can delete only Empeleitas.
    final canDelete =
        _isAdmin || isEmpeleita;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.ink,
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppTheme.ink,
                width: 1.2,
              ),
              color: isEmpeleita
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.red.withValues(alpha: 0.12),
            ),
            child: Text(
              isEmpeleita
                  ? "EMPELEITA"
                  : isVale
                      ? "VALE"
                      : type.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: AppTheme.ink,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmtDate(date),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.ink,
                      ),
                    ),

                    Text(
                      "${isEmpeleita ? '+' : '-'} ${money(amount)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Descrição: $description",
                    style: const TextStyle(
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (!canDelete) {
      return card;
    }

    return Dismissible(
      key: ValueKey(movementId),
      direction: DismissDirection.endToStart,

      confirmDismiss: (_) async {
        return await _confirmDeleteMovement();
      },

      onDismissed: (_) async {
        await _deleteMovement(
          movementId: movementId,
          type: type,
          amount: amount,
        );
      },

      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),

      child: card,
    );
  }

  // ---------------- Main UI ----------------

  @override
  Widget build(BuildContext context) {
    if (_authService.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _personDoc.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snap.data?.data() ?? {};

        final value =
            (data["value"] as num?)?.toDouble() ?? 0.0;

        return Scaffold(
          backgroundColor: AppTheme.bgDark,

          appBar: AppBar(
            backgroundColor: AppTheme.barDark,
            foregroundColor: AppTheme.cream,

            title: Text(widget.personName),

            actions: [
              // ONLY ADMINS SEE THE ACCOUNT TOTAL
              if (_isAdmin)
                Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(right: 8),
                    child: Text(
                      money(value),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

              IconButton(
                icon: const Icon(Icons.filter_alt),
                onPressed: _openSmartDateFilter,
              ),

              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  // Leave PersonPage first so its Firestore listeners are disposed.
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }

                  // Give Flutter a frame to dispose PersonPage and cancel its streams.
                  await Future<void>.delayed(Duration.zero);

                  // Now remove Firebase authentication.
                  await _authService.signOut();
                },
              ),
            ],
          ),

          floatingActionButton: FloatingActionButton(
            onPressed: _openTypePicker,
            backgroundColor: AppTheme.greenDark,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Text(
              "+",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: AppTheme.cream,
                height: 1,
              ),
            ),
          ),

          body: Column(
            children: [
              _dateFilterBar(),
              const Divider(height: 1),
              Expanded(
                child: _movementsList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
