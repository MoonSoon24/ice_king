import 'package:flutter/material.dart';

import '../services/sync_service.dart';

class DriverScreen extends StatelessWidget {
  const DriverScreen({super.key});

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
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: tugas['status_tugas'] == 'menunggu'
                      ? () async {
                          await SyncService.instance.mutateData(
                            'tugas_pengantaran',
                            'update',
                            {...tugas, 'status_tugas': 'dalam_proses'},
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
                          'Dropout real ${item['nama_barang']} (pesan: ${item['qty_pesanan']})',
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
                    DropdownMenuItem(value: 'tunai', child: Text('Tunai')),
                  ],
                  onChanged: (value) =>
                      setModal(() => metode = value ?? 'transfer'),
                ),
                if (metode == 'tunai')
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
                        .mutateData('tugas_pengantaran', 'update', {
                          ...tugas,
                          'metode_pembayaran': metode,
                          'jumlah_pembayaran_tunai': metode == 'tunai'
                              ? double.tryParse(tunaiCtrl.text) ?? 0
                              : null,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Layar Driver')),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: SyncService.instance.daftarTugas,
        builder: (context, tugas, _) {
          if (tugas.isEmpty)
            return const Center(child: Text('Belum ada tugas untuk driver.'));
          return ListView.builder(
            itemCount: tugas.length,
            itemBuilder: (context, index) {
              final item = tugas[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(item['nama_tugas'] ?? '-'),
                  subtitle: Text('Status: ${item['status_tugas']}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _kelolaTugas(context, item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
