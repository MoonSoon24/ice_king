import 'package:flutter/material.dart';

import '../services/sync_service.dart';

class DriverScreen extends StatelessWidget {
  const DriverScreen({super.key, required this.onToggleDashboard});

  final VoidCallback onToggleDashboard;

  Future<void> _kelolaTugas(
    BuildContext context,
    Map<String, dynamic> tugas,
  ) async {
    final items = SyncService.instance.daftarItem.value
        .where((e) => e['id_tugas'] == tugas['id'])
        .toList();
    final qtyCtrls = <String, TextEditingController>{};
    for (final item in items) {
      qtyCtrls[item['id'] as String] = TextEditingController(
        text: (item['qty_drop_real'] ?? '').toString(),
      );
    }

    String metode = (tugas['metode_pembayaran'] as String?) ?? 'transfer';
    final tunaiCtrl = TextEditingController(
      text: (tugas['jumlah_pembayaran_tunai'] ?? '').toString(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tugas['nama_tugas'] ?? '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Klien: ${tugas['nama_klien'] ?? '-'}'),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: tugas['status_tugas'] == 'pending'
                      ? () async {
                          await SyncService.instance.mutateData(
                            'tugas',
                            'update',
                            {'id': tugas['tugas_id'], 'status': 'in_progress'},
                          );
                          if (context.mounted) Navigator.pop(context);
                        }
                      : null,
                  child: const Text('Mulai Tugas'),
                ),
                const SizedBox(height: 12),
                ...items.map(
                  (item) => TextField(
                    controller: qtyCtrls[item['id']],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          'Drop real ${item['nama_barang']} (pesan: ${item['qty_pesanan']})',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: metode,
                  decoration: const InputDecoration(
                    labelText: 'Metode pembayaran',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'transfer',
                      child: Text('Transfer'),
                    ),
                    DropdownMenuItem(value: 'cash', child: Text('Tunai')),
                    DropdownMenuItem(value: 'tempo', child: Text('Tempo')),
                  ],
                  onChanged: (value) =>
                      setModal(() => metode = value ?? 'transfer'),
                ),
                if (metode == 'cash')
                  TextField(
                    controller: tunaiCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah pembayaran tunai',
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    for (final item in items) {
                      final qty = int.tryParse(qtyCtrls[item['id']]!.text);
                      await SyncService.instance.mutateData(
                        'item_pesanan',
                        'update',
                        {...item, 'qty_drop_real': qty},
                      );
                    }

                    await SyncService.instance
                        .mutateData('tugas_kunjungan', 'update', {
                          'id': tugas['id'],
                          'tugas_id': tugas['tugas_id'],
                          'status': 'delivered',
                          'metode_bayar': metode,
                          'total_dibayar': metode == 'cash'
                              ? double.tryParse(tunaiCtrl.text) ?? 0
                              : 0,
                        });
                    await SyncService.instance.mutateData('tugas', 'update', {
                      'id': tugas['tugas_id'],
                      'status': 'completed',
                    });

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Simpan Progress Driver'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: onToggleDashboard,
            child: const Text('Admin Dashboard'),
          ),
          bottom: const TabBar(tabs: [Tab(text: 'Tugas')]),
        ),
        body: TabBarView(
          children: [
            ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: SyncService.instance.daftarTugas,
              builder: (context, tugas, _) {
                if (tugas.isEmpty) {
                  return const Center(
                    child: Text('Belum ada tugas untuk driver.'),
                  );
                }
                return ListView.builder(
                  itemCount: tugas.length,
                  itemBuilder: (context, index) {
                    final item = tugas[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        title: Text(item['nama_tugas'] ?? '-'),
                        subtitle: Text(
                          'Klien: ${item['nama_klien'] ?? '-'} | Status: ${item['status_tugas']}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _kelolaTugas(context, item),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
