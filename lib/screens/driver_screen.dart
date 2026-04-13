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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) => Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bottom sheet drag handle indicator
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tugas['nama_tugas'] ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.business, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Klien: ${tugas['nama_klien'] ?? '-'}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (tugas['status_tugas'] == 'pending')
                    FilledButton.icon(
                      onPressed: () async {
                        await SyncService.instance.mutateData(
                          'tugas',
                          'update',
                          {'id': tugas['tugas_id'], 'status': 'in_progress'},
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Mulai Tugas'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.all(16),
                      ),
                    )
                  else ...[
                    const Text(
                      'Progress Pengiriman',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: qtyCtrls[item['id']],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                '${item['nama_barang']} (Dipesan: ${item['qty_pesanan']})',
                            helperText: 'Jumlah drop aktual',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: metode,
                      decoration: const InputDecoration(
                        labelText: 'Metode Pembayaran',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'transfer',
                          child: Text('Transfer Bank'),
                        ),
                        DropdownMenuItem(
                          value: 'cash',
                          child: Text('Tunai (Cash)'),
                        ),
                        DropdownMenuItem(
                          value: 'tempo',
                          child: Text('Jatuh Tempo'),
                        ),
                      ],
                      onChanged: (value) =>
                          setModal(() => metode = value ?? 'transfer'),
                    ),
                    if (metode == 'cash') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: tunaiCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Jumlah Pembayaran Tunai',
                          prefixText: 'Rp ',
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
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
                        await SyncService.instance.mutateData(
                          'tugas',
                          'update',
                          {'id': tugas['tugas_id'], 'status': 'completed'},
                        );

                        if (context.mounted) Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text(
                        'Selesaikan Tugas',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Driver Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueGrey.shade800, // Distinct color for driver
        foregroundColor: Colors.white,
        actions: [
          Tooltip(
            message: 'Sinkronisasi Data',
            child: IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Menyinkronkan data ke server...'),
                  ),
                );
                try {
                  // Call your sync method here
                  // await SyncService.instance.sync();

                  await Future.delayed(
                    const Duration(seconds: 1),
                  ); // Placeholder delay

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sinkronisasi selesai!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal sinkron: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
          Tooltip(
            message: 'Switch to Admin App',
            child: IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: onToggleDashboard,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: Colors.grey.shade100, // Light background to make cards pop
        child: ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: SyncService.instance.daftarTugas,
          builder: (context, tugas, _) {
            if (tugas.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hore! Belum ada tugas hari ini.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tugas.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = tugas[index];
                final isCompleted = item['status_tugas'] == 'completed';

                return Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _kelolaTugas(context, item),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: isCompleted
                                ? Colors.green.shade100
                                : Colors.blue.shade100,
                            child: Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : Icons.local_shipping,
                              color: isCompleted ? Colors.green : Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['nama_tugas'] ?? '-',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Klien: ${item['nama_klien'] ?? '-'}',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
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
    );
  }
}
