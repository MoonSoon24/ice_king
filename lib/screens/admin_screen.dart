import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.onToggleDashboard});

  final VoidCallback onToggleDashboard;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Helpers for empty states ---
  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // --- Dialogs ---
  // (Keep the logic the same, just update the UI of the dialogs to use spacing)
  // ... [Keep your _buatKaryawanBaru and _buatKlienBaru functions here, add padding between textfields]

  Future<String?> _buatKaryawanBaru() async {
    final ctrlNama = TextEditingController();
    String? createdId;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Karyawan'),
        content: TextField(
          controller: ctrlNama,
          decoration: const InputDecoration(
            labelText: 'Nama karyawan',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (ctrlNama.text.trim().isEmpty) return;
              createdId = SyncService.instance.generateId();
              await SyncService.instance.mutateData('karyawan', 'insert', {
                'id': createdId,
                'nama': ctrlNama.text.trim(),
                'role': 'driver',
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    return createdId;
  }

  Future<String?> _buatKlienBaru() async {
    final ctrlNama = TextEditingController();
    final ctrlAlamat = TextEditingController();
    final ctrlKontak = TextEditingController();
    String? createdId;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Klien'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlNama,
                decoration: const InputDecoration(
                  labelText: 'Nama klien',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrlAlamat,
                decoration: const InputDecoration(
                  labelText: 'Alamat',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrlKontak,
                decoration: const InputDecoration(
                  labelText: 'Kontak',
                  prefixIcon: Icon(Icons.phone),
                ),
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
              if (ctrlNama.text.trim().isEmpty) return;
              createdId = SyncService.instance.generateId();
              await SyncService.instance.mutateData('klien', 'insert', {
                'id': createdId,
                'nama': ctrlNama.text.trim(),
                'alamat': ctrlAlamat.text.trim(),
                'kontak': ctrlKontak.text.trim(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    return createdId;
  }

  Future<void> _buatBarang() async {
    final ctrlNama = TextEditingController();
    final ctrlKategori = TextEditingController();
    final ctrlHarga = TextEditingController();
    final ctrlStok = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Barang Gudang'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlNama,
                decoration: const InputDecoration(
                  labelText: 'Nama barang',
                  prefixIcon: Icon(Icons.inventory),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrlKategori,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrlHarga,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga satuan',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrlStok,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stok gudang',
                  prefixIcon: Icon(Icons.numbers),
                ),
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
              if (ctrlNama.text.trim().isEmpty) return;
              await SyncService.instance.mutateData('barang', 'insert', {
                'id': SyncService.instance.generateId(),
                'nama': ctrlNama.text.trim(),
                'kategori': ctrlKategori.text.trim().isEmpty
                    ? null
                    : ctrlKategori.text.trim(),
                'harga_satuan': double.tryParse(ctrlHarga.text) ?? 0,
                'stok_gudang': int.tryParse(ctrlStok.text) ?? 0,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _buatTugas() async {
    final ctrlNamaTugas = TextEditingController();
    String? selectedKaryawanId;
    final List<Map<String, dynamic>> kunjungan = [
      {'klien_id': null, 'qty': TextEditingController()},
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled:
          true, // This allows the sheet to expand to full screen height if needed
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
              // This pushes the content up when the keyboard appears
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
                  const Text(
                    'Buat Tugas Baru',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: ctrlNamaTugas,
                    decoration: const InputDecoration(
                      labelText: 'Nama tugas',
                      prefixIcon: Icon(Icons.task_alt),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedKaryawanId,
                          decoration: const InputDecoration(
                            labelText: 'Karyawan penugasan',
                            prefixIcon: Icon(Icons.person),
                          ),
                          items: SyncService.instance.daftarKaryawan.value
                              .map(
                                (k) => DropdownMenuItem<String>(
                                  value: k['id'] as String,
                                  child: Text(k['nama']?.toString() ?? '-'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setModal(() => selectedKaryawanId = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Tambah Karyawan Baru',
                        child: IconButton.filledTonal(
                          onPressed: () async {
                            final idBaru = await _buatKaryawanBaru();
                            if (idBaru != null) {
                              setModal(() => selectedKaryawanId = idBaru);
                            }
                          },
                          icon: const Icon(Icons.person_add),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),

                  const Text(
                    'Daftar Klien & Permintaan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  ...kunjungan.asMap().entries.map((entry) {
                    final i = entry.key;
                    final row = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: row['klien_id'] as String?,
                              decoration: InputDecoration(
                                labelText: 'Klien ${i + 1}',
                              ),
                              items: SyncService.instance.daftarKlien.value
                                  .map(
                                    (k) => DropdownMenuItem<String>(
                                      value: k['id'] as String,
                                      child: Text(k['nama']?.toString() ?? '-'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setModal(() => row['klien_id'] = value),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: row['qty'] as TextEditingController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () async {
                              final idKlien = await _buatKlienBaru();
                              if (idKlien != null) {
                                setModal(() => row['klien_id'] = idKlien);
                              }
                            },
                            icon: const Icon(Icons.add_business),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          // Only show delete icon if there's more than 1 row
                          if (kunjungan.length > 1) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () {
                                setModal(() => kunjungan.removeAt(i));
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setModal(() {
                        kunjungan.add({
                          'klien_id': null,
                          'qty': TextEditingController(),
                        });
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah klien lain ke tugas'),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () async {
                            if (ctrlNamaTugas.text.trim().isEmpty ||
                                selectedKaryawanId == null) {
                              return;
                            }
                            final rowsValid = kunjungan.where(
                              (row) =>
                                  row['klien_id'] != null &&
                                  (row['qty'] as TextEditingController).text
                                      .trim()
                                      .isNotEmpty,
                            );
                            if (rowsValid.isEmpty) return;

                            final idTugas = SyncService.instance.generateId();
                            await SyncService.instance
                                .mutateData('tugas', 'insert', {
                                  'id': idTugas,
                                  'nama_tugas': ctrlNamaTugas.text.trim(),
                                  'tanggal': DateTime.now()
                                      .toIso8601String()
                                      .split('T')
                                      .first,
                                  'status': 'pending',
                                  'karyawan_id': selectedKaryawanId,
                                  'modal_awal': 0,
                                });

                            for (final row in rowsValid) {
                              final idKunjungan = SyncService.instance
                                  .generateId();
                              await SyncService.instance
                                  .mutateData('tugas_kunjungan', 'insert', {
                                    'id': idKunjungan,
                                    'tugas_id': idTugas,
                                    'klien_id': row['klien_id'],
                                    'status': 'pending',
                                    'metode_bayar': null,
                                    'total_dibayar': 0,
                                    'nama_tugas': ctrlNamaTugas.text.trim(),
                                    'status_tugas': 'pending',
                                    'tanggal_tugas': DateTime.now()
                                        .toIso8601String()
                                        .split('T')
                                        .first,
                                    'id_driver': selectedKaryawanId,
                                    'nama_driver': SyncService
                                        .instance
                                        .daftarKaryawan
                                        .value
                                        .firstWhere(
                                          (k) => k['id'] == selectedKaryawanId,
                                          orElse: () => <String, dynamic>{},
                                        )['nama'],
                                    'nama_klien': SyncService
                                        .instance
                                        .daftarKlien
                                        .value
                                        .firstWhere(
                                          (k) => k['id'] == row['klien_id'],
                                          orElse: () => <String, dynamic>{},
                                        )['nama'],
                                  });
                              await SyncService.instance
                                  .mutateData('item_pesanan', 'insert', {
                                    'id': SyncService.instance.generateId(),
                                    'id_tugas': idKunjungan,
                                    'nama_barang': 'Permintaan Klien',
                                    'qty_pesanan':
                                        int.tryParse(
                                          (row['qty'] as TextEditingController)
                                              .text,
                                        ) ??
                                        0,
                                    'qty_drop_real': null,
                                  });
                            }

                            if (context.mounted) Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                          child: const Text(
                            'Buat Tugas',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  // --- Tabs ---

  Widget _tabGudang() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: SyncService.instance.daftarBarang,
      builder: (context, barang, _) {
        if (barang.isEmpty) {
          return _buildEmptyState(
            Icons.inventory_2_outlined,
            'Belum ada barang di gudang.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: barang.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = barang[index];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.inventory_2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  item['nama']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Kategori: ${item['kategori'] ?? '-'}\nStok: ${item['stok_gudang'] ?? 0}  |  Harga: Rp${item['harga_satuan'] ?? 0}',
                    style: const TextStyle(height: 1.4),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => SyncService.instance.mutateData(
                    'barang',
                    'delete',
                    {'id': item['id']},
                  ),
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _tabTugas() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: SyncService.instance.daftarTugas,
      builder: (context, tugas, _) {
        if (tugas.isEmpty) {
          return _buildEmptyState(
            Icons.assignment_outlined,
            'Belum ada tugas saat ini.',
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['nama_tugas']?.toString() ?? '-',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            (item['status_tugas'] ?? '')
                                .toString()
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCompleted
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Driver: ${item['nama_driver'] ?? '-'}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.business,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text('Klien: ${item['nama_klien'] ?? '-'}'),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _tabLaporan() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: SyncService.instance.daftarTugas,
      builder: (context, tugas, _) {
        final pending = tugas
            .where((e) => e['status_tugas'] == 'pending')
            .length;
        final selesai = tugas
            .where((e) => e['status_tugas'] == 'completed')
            .length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.analytics,
                      size: 48,
                      color: Color(0xFF0288D1),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ringkasan Tugas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Total',
                          tugas.length.toString(),
                          Colors.blue,
                        ),
                        _buildStatItem(
                          'Menunggu',
                          pending.toString(),
                          Colors.orange,
                        ),
                        _buildStatItem(
                          'Selesai',
                          selesai.toString(),
                          Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, MaterialColor color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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

                  // Simulating a delay for the UI feel (remove this in production)
                  await Future.delayed(const Duration(seconds: 1));

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
            message: 'Switch to Driver App',
            child: IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: widget.onToggleDashboard,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Gudang'),
            Tab(icon: Icon(Icons.assignment), text: 'Tugas'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Laporan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_tabGudang(), _tabTugas(), _tabLaporan()],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          if (_tabController.index == 0) {
            return FloatingActionButton.extended(
              onPressed: _buatBarang,
              icon: const Icon(Icons.add),
              label: const Text('Barang'),
            );
          }
          if (_tabController.index == 1) {
            return FloatingActionButton.extended(
              onPressed: _buatTugas,
              icon: const Icon(Icons.add_task),
              label: const Text('Buat tugas'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
