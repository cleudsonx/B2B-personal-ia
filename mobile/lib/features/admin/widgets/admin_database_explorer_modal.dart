import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/admin_data_service.dart';

/// Modal seguro para exploração e auditoria de tabelas do banco de dados (Supabase / Postgres)
class AdminDatabaseExplorerModal extends StatefulWidget {
  const AdminDatabaseExplorerModal({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const AdminDatabaseExplorerModal(),
    );
  }

  @override
  State<AdminDatabaseExplorerModal> createState() => _AdminDatabaseExplorerModalState();
}

class _AdminDatabaseExplorerModalState extends State<AdminDatabaseExplorerModal> {
  String _selectedTable = 'profiles';
  bool _isLoading = true;
  AdminTableInspectionResult? _data;
  final TextEditingController _searchCtrl = TextEditingController();
  int _offset = 0;
  static const int _limit = 20;

  final List<String> _tables = AdminDataService.inspectableTables;

  @override
  void initState() {
    super.initState();
    _loadTableData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTableData() async {
    setState(() => _isLoading = true);
    final res = await AdminDataService.inspectTable(
      tableName: _selectedTable,
      limit: _limit,
      offset: _offset,
      searchQuery: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
    );
    if (mounted) {
      setState(() {
        _data = res;
        _isLoading = false;
      });
    }
  }

  void _showRowDetails(Map<String, dynamic> row) {
    HapticFeedback.selectionClick();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(row);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.data_object_rounded, color: Color(0xFF818CF8), size: 20),
            const SizedBox(width: 8),
            Text(
              'Registro ($_selectedTable)',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 400),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              jsonStr,
              style: const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('JSON copiado para a área de transferência!'),
                  backgroundColor: Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF818CF8)),
            label: const Text('Copiar JSON', style: TextStyle(color: Color(0xFF818CF8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 720),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF374151), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.storage_rounded, color: Color(0xFF818CF8), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explorador Seguro de Banco de Dados',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Consulta somente leitura de tabelas operacionais do Supabase',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1F2937), height: 1),

                // Controls Bar: Table Selector + Search + Refresh
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Dropdown de Tabelas
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF374151)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedTable,
                            dropdownColor: const Color(0xFF1F2937),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF818CF8)),
                            items: _tables.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedTable = val;
                                  _offset = 0;
                                });
                                _loadTableData();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Input de Busca
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Filtrar por ID, email ou texto...',
                            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            prefixIcon: const Icon(Icons.filter_list_rounded, color: Colors.grey, size: 18),
                            filled: true,
                            fillColor: const Color(0xFF1F2937),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) {
                            setState(() => _offset = 0);
                            _loadTableData();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      IconButton(
                        onPressed: _loadTableData,
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF818CF8)),
                        tooltip: 'Recarregar dados',
                      ),
                    ],
                  ),
                ),

                // Data Table View
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                      : (_data == null || _data!.rows.isEmpty)
                          ? Center(
                              child: Text(
                                'Nenhum registro encontrado na tabela "$_selectedTable".',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFF1F2937)),
                                  dataRowMinHeight: 44,
                                  dataRowMaxHeight: 52,
                                  columns: [
                                    const DataColumn(label: Text('AÇÕES', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                                    ..._data!.columns.take(7).map(
                                      (col) => DataColumn(
                                        label: Text(
                                          col.toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: _data!.rows.map((row) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.remove_red_eye_rounded, size: 16, color: Color(0xFF818CF8)),
                                            onPressed: () => _showRowDetails(row),
                                          ),
                                        ),
                                        ..._data!.columns.take(7).map((col) {
                                          final val = row[col];
                                          final str = val == null ? 'NULL' : val.toString();
                                          return DataCell(
                                            Text(
                                              str.length > 25 ? '${str.substring(0, 25)}...' : str,
                                              style: TextStyle(
                                                color: val == null ? Colors.grey : Colors.white70,
                                                fontSize: 12,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                ),

                // Footer with Pagination & Count
                const Divider(color: Color(0xFF1F2937), height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        'Total aproximado: ${_data?.totalCount ?? 0} registros',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _offset > 0
                            ? () {
                                setState(() => _offset = (_offset - _limit).clamp(0, 999999));
                                _loadTableData();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                      ),
                      Text(
                        'Página ${(_offset / _limit).floor() + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: (_data != null && _data!.rows.length == _limit)
                            ? () {
                                setState(() => _offset += _limit);
                                _loadTableData();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
