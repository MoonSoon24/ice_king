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

  Future<String?> _buatKaryawanBaru() async {
    final ctrlNama = TextEditingController();
    String? createdId;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Karyawan'),
        content: TextField(
          controller: ctrlNama,
          decoration: const InputDecoration(labelText: 'Nama karyawan'),
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
                decoration: const InputDecoration(labelText: 'Nama klien'),
              ),
              TextField(
                controller: ctrlAlamat,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
              TextField(
                controller: ctrlKontak,
                decoration: const InputDecoration(labelText: 'Kontak'),
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
                decoration: const InputDecoration(labelText: 'Nama barang'),
              ),
              TextField(
                controller: ctrlKategori,
                decoration: const InputDecoration(labelText: 'Kategori'),
              ),
              TextField(
                controller: ctrlHarga,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga satuan'),
              ),
              TextField(
                controller: ctrlStok,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stok gudang'),
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

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) => AlertDialog(
            title: const Text('Buat Tugas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrlNamaTugas,
                    decoration: const InputDecoration(labelText: 'Nama tugas'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedKaryawanId,
                          decoration: const InputDecoration(
                            labelText: 'Karyawan penugasan',
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
                      IconButton(
                        onPressed: () async {
                          final idBaru = await _buatKaryawanBaru();
                          if (idBaru != null) {
                            setModal(() => selectedKaryawanId = idBaru);
                          }
                        },
                        icon: const Icon(Icons.person_add_alt_1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Daftar klien & jumlah permintaan',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...kunjungan.asMap().entries.map((entry) {
                    final i = entry.key;
                    final row = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
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
                            child: TextField(
                              controller: row['qty'] as TextEditingController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Permintaan',
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              final idKlien = await _buatKlienBaru();
                              if (idKlien != null) {
                                setModal(() => row['klien_id'] = idKlien);
                              }
                            },
                            icon: const Icon(Icons.add_business),
                          ),
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
                      label: const Text('Tambah klien ke tugas'),
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
                  await SyncService.instance.mutateData('tugas', 'insert', {
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
                    final idKunjungan = SyncService.instance.generateId();
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
                          'nama_klien': SyncService.instance.daftarKlien.value
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
                                (row['qty'] as TextEditingController).text,
                              ) ??
                              0,
                          'qty_drop_real': null,
                        });
                  }

                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Buat Tugas'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabGudang() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: SyncService.instance.daftarBarang,
      builder: (context, barang, _) {
        if (barang.isEmpty) {
          return const Center(child: Text('Belum ada barang gudang.'));
        }
        return ListView.builder(
          itemCount: barang.length,
          itemBuilder: (context, index) {
            final item = barang[index];
            return ListTile(
              title: Text(item['nama']?.toString() ?? '-'),
              subtitle: Text(
                'Kategori: ${item['kategori'] ?? '-'} | Stok: ${item['stok_gudang'] ?? 0} | Harga: ${item['harga_satuan'] ?? 0}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => SyncService.instance.mutateData(
                  'barang',
                  'delete',
                  {'id': item['id']},
                ),
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
          return const Center(child: Text('Belum ada tugas.'));
        }
        return ListView.builder(
          itemCount: tugas.length,
          itemBuilder: (context, index) {
            final item = tugas[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(item['nama_tugas']?.toString() ?? '-'),
                subtitle: Text(
                  'Klien: ${item['nama_klien'] ?? '-'}\nStatus: ${item['status_tugas']} | Karyawan: ${item['nama_driver'] ?? '-'}',
                ),
                isThreeLine: true,
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
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total kunjungan tugas: ${tugas.length}'),
              const SizedBox(height: 8),
              Text('Menunggu: $pending'),
              const SizedBox(height: 8),
              Text('Selesai: $selesai'),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: widget.onToggleDashboard,
          child: const Text('Admin Dashboard'),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gudang'),
            Tab(text: 'Tugas'),
            Tab(text: 'Laporan'),
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
              icon: const Icon(Icons.inventory_2),
              label: const Text('Tambah barang'),
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
