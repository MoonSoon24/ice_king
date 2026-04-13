import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../widgets/app_snackbar.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.onToggleDashboard});

  final VoidCallback onToggleDashboard;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _selectedGudangIds = <String>{};
  final Set<String> _selectedTugasIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_selectedGudangIds.isNotEmpty || _selectedTugasIds.isNotEmpty) {
        setState(() {
          _selectedGudangIds.clear();
          _selectedTugasIds.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isSelectingGudang =>
      _tabController.index == 0 && _selectedGudangIds.isNotEmpty;

  bool get _isSelectingTugas =>
      _tabController.index == 1 && _selectedTugasIds.isNotEmpty;

  bool get _isSelectionMode => _isSelectingGudang || _isSelectingTugas;

  bool _isItemSelected(String id) {
    if (_tabController.index == 0) return _selectedGudangIds.contains(id);
    if (_tabController.index == 1) return _selectedTugasIds.contains(id);
    return false;
  }

  void _toggleGudangSelection(String id) {
    setState(() {
      if (_selectedGudangIds.contains(id)) {
        _selectedGudangIds.remove(id);
      } else {
        _selectedGudangIds.add(id);
      }
    });
  }

  void _toggleTugasSelection(String id) {
    setState(() {
      if (_selectedTugasIds.contains(id)) {
        _selectedTugasIds.remove(id);
      } else {
        _selectedTugasIds.add(id);
      }
    });
  }

  Future<void> _toggleSelectAll() async {
    if (_tabController.index == 0) {
      final ids = SyncService.instance.daftarBarang.value
          .map((e) => e['id']?.toString())
          .whereType<String>()
          .toSet();
      setState(() {
        if (_selectedGudangIds.length == ids.length && ids.isNotEmpty) {
          _selectedGudangIds.clear();
        } else {
          _selectedGudangIds
            ..clear()
            ..addAll(ids);
        }
      });
      return;
    }

    if (_tabController.index == 1) {
      final ids = SyncService.instance.daftarTugas.value
          .map((e) => e['id']?.toString())
          .whereType<String>()
          .toSet();
      setState(() {
        if (_selectedTugasIds.length == ids.length && ids.isNotEmpty) {
          _selectedTugasIds.clear();
        } else {
          _selectedTugasIds
            ..clear()
            ..addAll(ids);
        }
      });
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final isGudangTab = _tabController.index == 0;
    final ids = isGudangTab
        ? _selectedGudangIds.toList(growable: false)
        : _selectedTugasIds.toList(growable: false);
    if (ids.isEmpty) return;

    final targetLabel = isGudangTab ? 'barang gudang' : 'tugas';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: Text(
            'Yakin ingin menghapus ${ids.length} $targetLabel terpilih? Tindakan ini tidak bisa dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final table = isGudangTab ? 'barang' : 'tugas';
    for (final id in ids) {
      await SyncService.instance.mutateData(table, 'delete', {
        'id': id,
      }, showSnackbar: false);
    }

    if (!mounted) return;
    setState(() {
      _selectedGudangIds.clear();
      _selectedTugasIds.clear();
    });
    AppSnackbar.show(
      context,
      '${ids.length} $targetLabel berhasil dihapus.',
      type: AppSnackbarType.success,
    );
  }

  // --- Detail & Timeline Functions ---

  void _showTugasDetail(Map<String, dynamic> tugas) {
    // (1 & 2: Data fetching & Controller setup remains exactly the same)
    List<Map<String, dynamic>> kunjunganRaw = [];
    List<Map<String, dynamic>> muatanRaw = [];
    final semuaTugasItem = SyncService.instance.daftarTugasItem.value;

    try {
      kunjunganRaw = SyncService.instance.daftarTugasKunjungan.value
          .where((k) => k['tugas_id'] == tugas['id'])
          .toList();
      muatanRaw = SyncService.instance.daftarMuatanTugas.value
          .where((m) => m['tugas_id'] == tugas['id'])
          .toList();
    } catch (_) {}

    final ctrlNamaTugas = TextEditingController(
      text: tugas['nama_tugas']?.toString() ?? '',
    );
    final ctrlModalAwal = TextEditingController(
      text: tugas['modal_awal']?.toString() ?? '0',
    );
    String? selectedKaryawanId = tugas['karyawan_id'] ?? tugas['id_driver'];
    final isCompletedTugas =
        (tugas['status'] == 'completed' ||
        tugas['status_tugas'] == 'completed');

    List<Map<String, dynamic>> kunjunganEdit = kunjunganRaw.map((k) {
      final item = semuaTugasItem.firstWhere(
        (ti) => ti['kunjungan_id'] == k['id'],
        orElse: () => <String, dynamic>{},
      );
      return {
        'id': k['id'],
        'klien_id': k['klien_id'],
        'barang_id': item['barang_id'],
        'qty': TextEditingController(
          text: item['qty_diminta']?.toString() ?? '',
        ),
        'tugas_item_id': item['id'],
      };
    }).toList();
    if (kunjunganEdit.isEmpty) {
      kunjunganEdit.add({
        'id': null,
        'klien_id': null,
        'barang_id': null,
        'qty': TextEditingController(),
      });
    }

    List<Map<String, dynamic>> muatanEdit = muatanRaw.map((m) {
      return {
        'id': m['id'],
        'barang_id': m['barang_id'],
        'qty': TextEditingController(text: m['qty_bawa']?.toString() ?? ''),
        'old_qty': m['qty_bawa'] ?? 0,
      };
    }).toList();
    if (muatanEdit.isEmpty) {
      muatanEdit.add({
        'id': null,
        'barang_id': null,
        'qty': TextEditingController(),
        'old_qty': 0,
      });
    }

    // STATE UNTUK ACCORDION
    bool isEditExpanded = false;

    // 3. TAMPILKAN BOTTOM SHEET
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return ConstrainedBox(
              // Batasi tinggi maksimal agar tidak melebihi layar
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.95,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: 12,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- DRAG HANDLE ---
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- BAGIAN 1: HEADER & TIMELINE (SELALU TERLIHAT) ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Text(
                              tugas['nama_tugas'] ?? 'Detail Tugas',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Progress Perjalanan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTrackingTimeline(kunjunganRaw),
                          ],
                        ),
                      ),

                      // --- ACCORDION TRIGGER ---
                      BouncingExpandArrow(
                        isExpanded: isEditExpanded,
                        collapsedLabel: isCompletedTugas
                            ? 'Ketuk untuk Lihat Detail Pengiriman'
                            : 'Ketuk untuk Edit Detail Tugas',
                        expandedLabel: isCompletedTugas
                            ? 'Tutup Detail Pengiriman'
                            : 'Tutup Form Edit',
                        onTap: () {
                          setModal(() {
                            isEditExpanded = !isEditExpanded;
                          });
                        },
                      ),

                      // --- BAGIAN 2: FORM EDIT (DIBUNGKUS ANIMATEDSIZE) ---
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: !isEditExpanded
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Pemisah yang hanya muncul saat accordion terbuka
                                  Container(
                                    color: Colors.grey.shade50,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: const Divider(
                                      thickness: 2,
                                      height: 2,
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 24,
                                      right: 24,
                                      top: 16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          isCompletedTugas
                                              ? 'Ringkasan Pengiriman'
                                              : 'Edit Detail Tugas',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        if (isCompletedTugas) ...[
                                          _buildCompletedTugasInfo(tugas),
                                        ] else ...[
                                          TextField(
                                            controller: ctrlNamaTugas,
                                            decoration: const InputDecoration(
                                              labelText: 'Nama tugas',
                                              prefixIcon: Icon(Icons.task_alt),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          TextField(
                                            controller: ctrlModalAwal,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Modal Awal',
                                              prefixIcon: Icon(
                                                Icons.attach_money,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          DropdownButtonFormField<String>(
                                            value: selectedKaryawanId,
                                            decoration: const InputDecoration(
                                              labelText: 'Pengantar (Driver)',
                                              prefixIcon: Icon(Icons.person),
                                            ),
                                            items: SyncService
                                                .instance
                                                .daftarKaryawan
                                                .value
                                                .map(
                                                  (
                                                    k,
                                                  ) => DropdownMenuItem<String>(
                                                    value: k['id'].toString(),
                                                    child: Text(
                                                      k['nama']?.toString() ??
                                                          '-',
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (val) => setModal(
                                              () => selectedKaryawanId = val,
                                            ),
                                          ),

                                          // --- KLIEN & PERMINTAAN ---
                                          const SizedBox(height: 24),
                                          const Text(
                                            'Daftar Klien & Permintaan',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ...kunjunganEdit.asMap().entries.map((
                                            entry,
                                          ) {
                                            final i = entry.key;
                                            final row = entry.value;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 3,
                                                    child: DropdownButtonFormField<String>(
                                                      value:
                                                          row['klien_id']
                                                              as String?,
                                                      decoration:
                                                          InputDecoration(
                                                            labelText:
                                                                'Klien ${i + 1}',
                                                          ),
                                                      items: SyncService
                                                          .instance
                                                          .daftarKlien
                                                          .value
                                                          .map(
                                                            (k) =>
                                                                DropdownMenuItem<
                                                                  String
                                                                >(
                                                                  value: k['id']
                                                                      .toString(),
                                                                  child: Text(
                                                                    k['nama']
                                                                            ?.toString() ??
                                                                        '-',
                                                                  ),
                                                                ),
                                                          )
                                                          .toList(),
                                                      onChanged: (val) =>
                                                          setModal(
                                                            () =>
                                                                row['klien_id'] =
                                                                    val,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    flex: 3,
                                                    child: DropdownButtonFormField<String>(
                                                      value:
                                                          row['barang_id']
                                                              as String?,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText: 'Barang',
                                                          ),
                                                      items: SyncService
                                                          .instance
                                                          .daftarBarang
                                                          .value
                                                          .map(
                                                            (b) =>
                                                                DropdownMenuItem<
                                                                  String
                                                                >(
                                                                  value: b['id']
                                                                      .toString(),
                                                                  child: Text(
                                                                    b['nama']
                                                                            ?.toString() ??
                                                                        '-',
                                                                  ),
                                                                ),
                                                          )
                                                          .toList(),
                                                      onChanged: (val) =>
                                                          setModal(
                                                            () =>
                                                                row['barang_id'] =
                                                                    val,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    flex: 2,
                                                    child: TextField(
                                                      controller:
                                                          row['qty']
                                                              as TextEditingController,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText: 'Qty',
                                                          ),
                                                    ),
                                                  ),
                                                  if (kunjunganEdit.length > 1)
                                                    IconButton(
                                                      onPressed: () => setModal(
                                                        () => kunjunganEdit
                                                            .removeAt(i),
                                                      ),
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.redAccent,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton.icon(
                                              onPressed: () => setModal(
                                                () => kunjunganEdit.add({
                                                  'id': null,
                                                  'klien_id': null,
                                                  'barang_id': null,
                                                  'qty':
                                                      TextEditingController(),
                                                }),
                                              ),
                                              icon: const Icon(Icons.add),
                                              label: const Text(
                                                'Tambah klien lain',
                                              ),
                                            ),
                                          ),

                                          // --- MUATAN KENDARAAN ---
                                          const SizedBox(height: 24),
                                          const Text(
                                            'Muatan Kendaraan',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ...muatanEdit.asMap().entries.map((
                                            entry,
                                          ) {
                                            final i = entry.key;
                                            final row = entry.value;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 5,
                                                    child: DropdownButtonFormField<String>(
                                                      value:
                                                          row['barang_id']
                                                              as String?,
                                                      decoration: InputDecoration(
                                                        labelText:
                                                            'Barang Muatan ${i + 1}',
                                                      ),
                                                      items: SyncService
                                                          .instance
                                                          .daftarBarang
                                                          .value
                                                          .map(
                                                            (b) =>
                                                                DropdownMenuItem<
                                                                  String
                                                                >(
                                                                  value: b['id']
                                                                      .toString(),
                                                                  child: Text(
                                                                    '${b['nama']} (Stok: ${b['stok_gudang']})',
                                                                  ),
                                                                ),
                                                          )
                                                          .toList(),
                                                      onChanged: (val) =>
                                                          setModal(
                                                            () =>
                                                                row['barang_id'] =
                                                                    val,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    flex: 2,
                                                    child: TextField(
                                                      controller:
                                                          row['qty']
                                                              as TextEditingController,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Qty Dibawa',
                                                          ),
                                                    ),
                                                  ),
                                                  if (muatanEdit.length > 1)
                                                    IconButton(
                                                      onPressed: () => setModal(
                                                        () => muatanEdit
                                                            .removeAt(i),
                                                      ),
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.redAccent,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton.icon(
                                              onPressed: () => setModal(
                                                () => muatanEdit.add({
                                                  'id': null,
                                                  'barang_id': null,
                                                  'qty':
                                                      TextEditingController(),
                                                  'old_qty': 0,
                                                }),
                                              ),
                                              icon: const Icon(
                                                Icons.local_shipping,
                                              ),
                                              label: const Text(
                                                'Tambah barang muatan',
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 32),

                                          // --- SAVE BUTTON ---
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.all(16),
                                            ),
                                            onPressed: () async {
                                              await SyncService.instance
                                                  .mutateData(
                                                    'tugas',
                                                    'update',
                                                    {
                                                      'id': tugas['id'],
                                                      'nama_tugas':
                                                          ctrlNamaTugas.text
                                                              .trim(),
                                                      'modal_awal':
                                                          double.tryParse(
                                                            ctrlModalAwal.text,
                                                          ) ??
                                                          0,
                                                      'karyawan_id':
                                                          selectedKaryawanId,
                                                    },
                                                  );

                                              List<String> currentKunjunganIds =
                                                  kunjunganEdit
                                                      .where(
                                                        (e) => e['id'] != null,
                                                      )
                                                      .map(
                                                        (e) =>
                                                            e['id'].toString(),
                                                      )
                                                      .toList();
                                              for (var raw in kunjunganRaw) {
                                                if (!currentKunjunganIds
                                                    .contains(raw['id'])) {
                                                  final rawItemId =
                                                      semuaTugasItem.firstWhere(
                                                        (ti) =>
                                                            ti['kunjungan_id'] ==
                                                            raw['id'],
                                                        orElse: () =>
                                                            <String, dynamic>{},
                                                      )['id'];
                                                  if (rawItemId != null)
                                                    await SyncService.instance
                                                        .mutateData(
                                                          'tugas_item',
                                                          'delete',
                                                          {'id': rawItemId},
                                                        );
                                                  await SyncService.instance
                                                      .mutateData(
                                                        'tugas_kunjungan',
                                                        'delete',
                                                        {'id': raw['id']},
                                                      );
                                                }
                                              }

                                              for (var row in kunjunganEdit) {
                                                if (row['klien_id'] == null ||
                                                    row['barang_id'] == null)
                                                  continue;
                                                final qty =
                                                    int.tryParse(
                                                      row['qty'].text,
                                                    ) ??
                                                    0;
                                                final barang = SyncService
                                                    .instance
                                                    .daftarBarang
                                                    .value
                                                    .firstWhere(
                                                      (b) =>
                                                          b['id'] ==
                                                          row['barang_id'],
                                                      orElse: () =>
                                                          <String, dynamic>{},
                                                    );
                                                final hargaTotal =
                                                    (double.tryParse(
                                                          '${barang['harga_satuan'] ?? 0}',
                                                        ) ??
                                                        0) *
                                                    qty;

                                                if (row['id'] == null) {
                                                  final newKunjunganId =
                                                      SyncService.instance
                                                          .generateId();
                                                  await SyncService.instance
                                                      .mutateData(
                                                        'tugas_kunjungan',
                                                        'insert',
                                                        {
                                                          'id': newKunjunganId,
                                                          'tugas_id':
                                                              tugas['id'],
                                                          'klien_id':
                                                              row['klien_id'],
                                                          'status': 'pending',
                                                          'total_dibayar': 0,
                                                        },
                                                      );
                                                  await SyncService.instance
                                                      .mutateData(
                                                        'tugas_item',
                                                        'insert',
                                                        {
                                                          'id': SyncService
                                                              .instance
                                                              .generateId(),
                                                          'kunjungan_id':
                                                              newKunjunganId,
                                                          'barang_id':
                                                              row['barang_id'],
                                                          'qty_diminta': qty,
                                                          'qty_dikirim': 0,
                                                          'harga_total':
                                                              hargaTotal,
                                                        },
                                                      );
                                                } else {
                                                  await SyncService.instance
                                                      .mutateData(
                                                        'tugas_kunjungan',
                                                        'update',
                                                        {
                                                          'id': row['id'],
                                                          'klien_id':
                                                              row['klien_id'],
                                                        },
                                                      );
                                                  if (row['tugas_item_id'] !=
                                                      null) {
                                                    await SyncService.instance
                                                        .mutateData(
                                                          'tugas_item',
                                                          'update',
                                                          {
                                                            'id':
                                                                row['tugas_item_id'],
                                                            'barang_id':
                                                                row['barang_id'],
                                                            'qty_diminta': qty,
                                                            'harga_total':
                                                                hargaTotal,
                                                          },
                                                        );
                                                  }
                                                }
                                              }

                                              List<String> currentMuatanIds =
                                                  muatanEdit
                                                      .where(
                                                        (e) => e['id'] != null,
                                                      )
                                                      .map(
                                                        (e) =>
                                                            e['id'].toString(),
                                                      )
                                                      .toList();
                                              for (var raw in muatanRaw) {
                                                if (!currentMuatanIds.contains(
                                                  raw['id'],
                                                )) {
                                                  await SyncService.instance
                                                      .mutateData(
                                                        'muatan_tugas',
                                                        'delete',
                                                        {'id': raw['id']},
                                                      );
                                                }
                                              }
                                              for (var row in muatanEdit) {
                                                if (row['barang_id'] == null)
                                                  continue;
                                                final qty =
                                                    int.tryParse(
                                                      row['qty'].text,
                                                    ) ??
                                                    0;

                                                if (row['id'] == null) {
                                                  await SyncService.instance
                                                      .mutateData(
                                                        'muatan_tugas',
                                                        'insert',
                                                        {
                                                          'id': SyncService
                                                              .instance
                                                              .generateId(),
                                                          'tugas_id':
                                                              tugas['id'],
                                                          'barang_id':
                                                              row['barang_id'],
                                                          'qty_bawa': qty,
                                                          'qty_sisa': 0,
                                                        },
                                                      );
                                                } else {
                                                  await SyncService.instance
                                                      .mutateData(
                                                        'muatan_tugas',
                                                        'update',
                                                        {
                                                          'id': row['id'],
                                                          'barang_id':
                                                              row['barang_id'],
                                                          'qty_bawa': qty,
                                                        },
                                                      );
                                                }
                                              }

                                              if (context.mounted) {
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Tugas berhasil diperbarui!',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: const Text(
                                              'Simpan Perubahan',
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
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
    );
  }

  Widget _buildCompletedTugasInfo(Map<String, dynamic> tugas) {
    final kunjungan = SyncService.instance.daftarTugasKunjungan.value
        .where((k) => k['tugas_id'] == tugas['id'])
        .toList();
    final kunjunganIds = kunjungan.map((e) => e['id']).toSet();
    final items = SyncService.instance.daftarTugasItem.value
        .where((ti) => kunjunganIds.contains(ti['kunjungan_id']))
        .toList();
    final totalDiminta = items.fold<int>(
      0,
      (sum, item) => sum + (int.tryParse('${item['qty_diminta'] ?? 0}') ?? 0),
    );
    final totalDikirim = items.fold<int>(
      0,
      (sum, item) => sum + (int.tryParse('${item['qty_dikirim'] ?? 0}') ?? 0),
    );
    final alasan = kunjungan
        .map((k) => k['catatan']?.toString().trim() ?? '')
        .where((text) => text.isNotEmpty)
        .toList();

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${(tugas['status'] ?? tugas['status_tugas'] ?? '-').toString().toUpperCase()}',
            ),
            const SizedBox(height: 8),
            Text('Total Requested: $totalDiminta'),
            Text('Total Delivered: $totalDikirim'),
            if (alasan.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Alasan/Catatan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...alasan.map((a) => Text('• $a')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingTimeline(List<Map<String, dynamic>> visits) {
    if (visits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('Belum ada rute klien untuk tugas ini.'),
        ),
      );
    }

    return Column(
      children: List.generate(visits.length, (index) {
        final visit = visits[index];
        final status =
            (visit['status_kunjungan'] ?? visit['status'] ?? 'pending')
                .toString();

        final isDelivered = status == 'delivered';
        final isFailed = status == 'failed';
        final isLast = index == visits.length - 1;

        // Find if this is the "active" destination (the first pending node)
        // A node is active if it's pending, AND the one before it is NOT pending.
        final isActiveLocation =
            status == 'pending' &&
            (index == 0 ||
                (visits[index - 1]['status_kunjungan'] != 'pending' &&
                    visits[index - 1]['status'] != 'pending'));

        Color dotColor;
        IconData icon;

        if (isDelivered) {
          dotColor = Colors.green;
          icon = Icons.check_circle;
        } else if (isFailed) {
          dotColor = Colors.red;
          icon = Icons.cancel;
        } else if (isActiveLocation) {
          dotColor = Colors.blue;
          icon = Icons.local_shipping; // Driver current target
        } else {
          dotColor = Colors.grey.shade400;
          icon = Icons.circle_outlined;
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Column for the Line and Icon
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActiveLocation
                            ? Colors.blue.shade50
                            : Colors.transparent,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Icon(icon, color: dotColor, size: 24),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isDelivered
                              ? Colors.green
                              : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Column for the Text Data
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit['nama_klien'] ?? 'Klien ${index + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isActiveLocation
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isActiveLocation
                              ? Colors.blue.shade800
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isActiveLocation
                            ? 'Driver sedang menuju lokasi ini'
                            : 'Status: ${status.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isActiveLocation
                              ? Colors.blue.shade600
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
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

  Future<void> _editBarang(Map<String, dynamic> item) async {
    final ctrlNama = TextEditingController(
      text: item['nama']?.toString() ?? '',
    );
    final ctrlKategori = TextEditingController(
      text: item['kategori']?.toString() ?? '',
    );
    final ctrlHarga = TextEditingController(
      text: (item['harga_satuan'] ?? 0).toString(),
    );
    final ctrlStok = TextEditingController(
      text: (item['stok_gudang'] ?? 0).toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Barang Gudang'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlNama,
                decoration: const InputDecoration(labelText: 'Nama barang'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrlKategori,
                decoration: const InputDecoration(labelText: 'Kategori'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrlHarga,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga satuan'),
              ),
              const SizedBox(height: 12),
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
              await SyncService.instance.mutateData('barang', 'update', {
                'id': item['id'],
                'nama': ctrlNama.text.trim(),
                'kategori': ctrlKategori.text.trim().isEmpty
                    ? null
                    : ctrlKategori.text.trim(),
                'harga_satuan': double.tryParse(ctrlHarga.text) ?? 0,
                'stok_gudang': int.tryParse(ctrlStok.text) ?? 0,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );
  }

  Future<void> _buatTugas() async {
    final ctrlNamaTugas = TextEditingController();
    String? selectedKaryawanId;
    final List<Map<String, dynamic>> kunjungan = [
      {'klien_id': null, 'barang_id': null, 'qty': TextEditingController()},
    ];

    final List<Map<String, dynamic>> muatan = [
      {'barang_id': null, 'qty': TextEditingController()},
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
                            child: DropdownButtonFormField<String>(
                              value: row['barang_id'] as String?,
                              decoration: const InputDecoration(
                                labelText: 'Barang',
                              ),
                              items: SyncService.instance.daftarBarang.value
                                  .map(
                                    (b) => DropdownMenuItem<String>(
                                      value: b['id'] as String,
                                      child: Text(b['nama']?.toString() ?? '-'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setModal(() => row['barang_id'] = value),
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
                          'barang_id': null,
                          'qty': TextEditingController(),
                        });
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah klien lain ke tugas'),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Muatan Kendaraan (potong stok gudang)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ...muatan.asMap().entries.map((entry) {
                    final i = entry.key;
                    final row = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: row['barang_id'] as String?,
                              decoration: InputDecoration(
                                labelText: 'Barang Muatan ${i + 1}',
                              ),
                              items: SyncService.instance.daftarBarang.value
                                  .map(
                                    (b) => DropdownMenuItem<String>(
                                      value: b['id'] as String,
                                      child: Text(
                                        '${b['nama'] ?? '-'} (Stok: ${b['stok_gudang'] ?? 0})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setModal(() => row['barang_id'] = value),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: row['qty'] as TextEditingController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Qty Dibawa',
                              ),
                            ),
                          ),
                          if (muatan.length > 1) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () =>
                                  setModal(() => muatan.removeAt(i)),
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
                        muatan.add({
                          'barang_id': null,
                          'qty': TextEditingController(),
                        });
                      }),
                      icon: const Icon(Icons.local_shipping),
                      label: const Text('Tambah barang muatan'),
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
                                  row['barang_id'] != null &&
                                  (row['qty'] as TextEditingController).text
                                      .trim()
                                      .isNotEmpty,
                            );
                            if (rowsValid.isEmpty) return;

                            final muatanValid = muatan.where(
                              (row) =>
                                  row['barang_id'] != null &&
                                  (row['qty'] as TextEditingController).text
                                      .trim()
                                      .isNotEmpty,
                            );
                            if (muatanValid.isEmpty) return;

                            final stokByBarang = {
                              for (final b
                                  in SyncService.instance.daftarBarang.value)
                                b['id'] as String:
                                    int.tryParse('${b['stok_gudang'] ?? 0}') ??
                                    0,
                            };
                            final Map<String, int> totalMuatanByBarang = {};
                            for (final row in muatanValid) {
                              final barangId = row['barang_id'] as String;
                              final qty =
                                  int.tryParse(
                                    (row['qty'] as TextEditingController).text,
                                  ) ??
                                  0;
                              totalMuatanByBarang[barangId] =
                                  (totalMuatanByBarang[barangId] ?? 0) + qty;
                              if (qty <= 0 ||
                                  (stokByBarang[barangId] ?? 0) < qty) {
                                if (!context.mounted) return;
                                AppSnackbar.show(
                                  context,
                                  'Qty muatan melebihi stok gudang atau tidak valid.',
                                  type: AppSnackbarType.error,
                                );
                                return;
                              }
                              stokByBarang[barangId] =
                                  (stokByBarang[barangId] ?? 0) - qty;
                            }

                            final idTugas = SyncService.instance.generateId();
                            await SyncService.instance
                                .mutateData('tugas', 'insert', {
                                  'id': idTugas,
                                  'nama_tugas': ctrlNamaTugas.text.trim(),
                                  'status': 'pending',
                                  'karyawan_id': selectedKaryawanId,
                                  'modal_awal': 0,
                                });
                            for (final entry in totalMuatanByBarang.entries) {
                              await SyncService.instance
                                  .mutateData('muatan_tugas', 'insert', {
                                    'id': SyncService.instance.generateId(),
                                    'tugas_id': idTugas,
                                    'barang_id': entry.key,
                                    'qty_bawa': entry.value,
                                    'qty_sisa': 0,
                                  });
                            }

                            for (final row in rowsValid) {
                              final idKunjungan = SyncService.instance
                                  .generateId();
                              final barang = SyncService
                                  .instance
                                  .daftarBarang
                                  .value
                                  .firstWhere(
                                    (b) => b['id'] == row['barang_id'],
                                    orElse: () => <String, dynamic>{},
                                  );
                              final qty =
                                  int.tryParse(
                                    (row['qty'] as TextEditingController).text,
                                  ) ??
                                  0;
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
                                    'status_kunjungan': 'pending',
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
                                  .mutateData('tugas_item', 'insert', {
                                    'id': SyncService.instance.generateId(),
                                    'kunjungan_id': idKunjungan,
                                    'barang_id': row['barang_id'],
                                    'qty_diminta': qty,
                                    'qty_dikirim': 0,
                                    'harga_total':
                                        (double.tryParse(
                                              '${barang['harga_satuan'] ?? 0}',
                                            ) ??
                                            0) *
                                        qty,
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
                onTap: () {
                  final itemId = item['id']?.toString();
                  if (itemId == null) return;
                  if (_isSelectingGudang) {
                    _toggleGudangSelection(itemId);
                    return;
                  }
                  _editBarang(item);
                },
                onLongPress: () {
                  final itemId = item['id']?.toString();
                  if (itemId == null) return;
                  _toggleGudangSelection(itemId);
                },
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: _isSelectingGudang
                    ? Checkbox(
                        value: _isItemSelected(item['id']?.toString() ?? ''),
                        onChanged: (_) => _toggleGudangSelection(
                          item['id']?.toString() ?? '',
                        ),
                      )
                    : CircleAvatar(
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
                trailing: _isSelectingGudang
                    ? null
                    : Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editBarang(item),
                          ),
                          IconButton(
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
                        ],
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
            final isCompleted =
                item['status'] == 'completed' ||
                item['status_tugas'] == 'completed';
            final statusTugas =
                (item['status'] ?? item['status_tugas'] ?? 'pending')
                    .toString();

            return Card(
              margin: EdgeInsets.zero,
              clipBehavior:
                  Clip.antiAlias, // Required for InkWell splash effect
              child: InkWell(
                onTap: () {
                  final itemId = item['id']?.toString();
                  if (itemId == null) return;
                  if (_isSelectingTugas) {
                    _toggleTugasSelection(itemId);
                    return;
                  }
                  _showTugasDetail(item);
                }, // Open the detail drawer
                onLongPress: () {
                  final itemId = item['id']?.toString();
                  if (itemId == null) return;
                  _toggleTugasSelection(itemId);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_isSelectingTugas)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Checkbox(
                                value: _isItemSelected(
                                  item['id']?.toString() ?? '',
                                ),
                                onChanged: (_) => _toggleTugasSelection(
                                  item['id']?.toString() ?? '',
                                ),
                              ),
                            ),
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
                              statusTugas.toUpperCase(),
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
                          const Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          // Fallback check based on how your data is joined
                          Text(
                            'Driver: ${item['nama_driver'] ?? 'Karyawan ID: ${item['karyawan_id']}'}',
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
        title: Text(
          _isSelectionMode
              ? '${_tabController.index == 0 ? _selectedGudangIds.length : _selectedTugasIds.length} dipilih'
              : 'Admin Dashboard',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedGudangIds.clear();
                    _selectedTugasIds.clear();
                  });
                },
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  tooltip: 'Pilih semua',
                  icon: const Icon(Icons.select_all),
                  onPressed: _toggleSelectAll,
                ),
                IconButton(
                  tooltip: 'Hapus terpilih',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _confirmDeleteSelected,
                ),
                const SizedBox(width: 8),
              ]
            : [
                Tooltip(
                  message: 'Sinkronisasi Data',
                  child: IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: () async {
                      AppSnackbar.show(
                        context,
                        'Menyinkronkan data ke server...',
                        type: AppSnackbarType.info,
                      );
                      try {
                        // Call your sync method here
                        // await SyncService.instance.sync();

                        // Simulating a delay for the UI feel (remove this in production)
                        await Future.delayed(const Duration(seconds: 1));

                        if (context.mounted) {
                          AppSnackbar.show(
                            context,
                            'Sinkronisasi selesai!',
                            type: AppSnackbarType.success,
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackbar.show(
                            context,
                            'Gagal sinkron: $e',
                            type: AppSnackbarType.error,
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
          if (_isSelectionMode) {
            return const SizedBox.shrink();
          }
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

class BouncingExpandArrow extends StatefulWidget {
  final VoidCallback onTap;
  final bool isExpanded; // Tambahkan properti ini
  final String collapsedLabel;
  final String expandedLabel;

  const BouncingExpandArrow({
    super.key,
    required this.onTap,
    this.isExpanded = false, // Default false
    this.collapsedLabel = 'Ketuk untuk Edit Detail Tugas',
    this.expandedLabel = 'Tutup Form Edit',
  });

  @override
  State<BouncingExpandArrow> createState() => _BouncingExpandArrowState();
}

class _BouncingExpandArrowState extends State<BouncingExpandArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            Text(
              widget.isExpanded ? widget.expandedLabel : widget.collapsedLabel,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -6 * _controller.value),
                  child: child,
                );
              },
              child: Icon(
                widget.isExpanded
                    ? Icons.keyboard_double_arrow_down
                    : Icons.keyboard_double_arrow_up,
                color: Colors.blue,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
