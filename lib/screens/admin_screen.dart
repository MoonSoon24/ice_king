import 'package:flutter/material.dart';

import '../services/sync_service.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _buatTugas(BuildContext context) async {
    final ctrlNama = TextEditingController();
    final ctrlDriver = TextEditingController();
    final ctrlBarang = TextEditingController();
    final ctrlQty = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buat Tugas Pengantaran'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlNama,
                decoration: const InputDecoration(labelText: 'Nama tugas'),
              ),
              TextField(
                controller: ctrlDriver,
                decoration: const InputDecoration(labelText: 'Nama driver'),
              ),
              TextField(
                controller: ctrlBarang,
                decoration: const InputDecoration(labelText: 'Nama barang'),
              ),
              TextField(
                controller: ctrlQty,
                decoration: const InputDecoration(labelText: 'Qty pesanan'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final idTugas = SyncService.instance.generateId();
              await SyncService.instance
                  .mutateData('tugas_pengantaran', 'insert', {
                    'id': idTugas,
                    'nama_tugas': ctrlNama.text,
                    'tanggal_tugas': DateTime.now().toIso8601String(),
                    'status_tugas': 'menunggu',
                    'nama_driver': ctrlDriver.text,
                  });
              await SyncService.instance.mutateData('item_pesanan', 'insert', {
                'id': SyncService.instance.generateId(),
                'id_tugas': idTugas,
                'nama_barang': ctrlBarang.text,
                'qty_pesanan': int.tryParse(ctrlQty.text) ?? 0,
                'qty_drop_real': null,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel Admin')),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: SyncService.instance.daftarTugas,
        builder: (context, tugas, _) {
          if (tugas.isEmpty) {
            return const Center(child: Text('Belum ada tugas.'));
          }
          return ListView.builder(
            itemCount: tugas.length,
            itemBuilder: (context, index) {
              final item = tugas[index];
              return ListTile(
                title: Text(item['nama_tugas'] ?? '-'),
                subtitle: Text(
                  'Status: ${item['status_tugas']} | Driver: ${item['nama_driver'] ?? '-'}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => SyncService.instance.mutateData(
                    'tugas_pengantaran',
                    'delete',
                    {'id': item['id']},
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _buatTugas(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah tugas'),
      ),
    );
  }
}
