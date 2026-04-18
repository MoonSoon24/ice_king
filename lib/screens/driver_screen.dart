import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/formatters.dart';
import '../services/sync_service.dart';
import '../widgets/app_snackbar.dart';

// ==========================================
// 1. LAYAR UTAMA DRIVER (DAFTAR TUGAS INDUK)
// ==========================================
class DriverScreen extends StatelessWidget {
  const DriverScreen({super.key, required this.onToggleDashboard});
  final VoidCallback onToggleDashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Driver Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        actions: [
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
        color: Colors.grey.shade100,
        child: ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: SyncService.instance.daftarTugas,
          builder: (context, tugasList, _) {
            if (tugasList.isEmpty) {
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
              itemCount: tugasList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tugas = tugasList[index];
                final status =
                    (tugas['status'] ?? tugas['status_tugas'] ?? 'pending')
                        .toString();
                final isCompleted = status == 'completed';

                final jumlahTujuan = SyncService
                    .instance
                    .daftarTugasKunjungan
                    .value
                    .where((k) => k['tugas_id'] == tugas['id'])
                    .length;

                return Card(
                  margin: EdgeInsets.zero,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DriverTugasDetailScreen(tugas: tugas),
                        ),
                      );
                    },
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
                                  tugas['nama_tugas'] ?? '-',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$jumlahTujuan Tujuan Pengiriman',
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

// ==========================================
// 2. LAYAR DETAIL TUGAS (REORDER & EKSEKUSI)
// ==========================================
class DriverTugasDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tugas;
  const DriverTugasDetailScreen({super.key, required this.tugas});

  @override
  State<DriverTugasDetailScreen> createState() =>
      _DriverTugasDetailScreenState();
}

class _RouteEntry {
  const _RouteEntry({
    required this.routeKey,
    required this.routeName,
    required this.visitIds,
    required this.isMergedCard,
  });

  final String routeKey;
  final String routeName;
  final List<String> visitIds;
  final bool isMergedCard;
}

class _DriverTugasDetailScreenState extends State<DriverTugasDetailScreen> {
  List<Map<String, dynamic>> _kunjunganList = [];
  bool _isPending = true;
  bool _isLoading = false;
  final Set<String> _splitRouteKeys = {};

  final Map<String, TextEditingController> _qtyCtrls = {};
  final TextEditingController _tunaiCtrl = TextEditingController();
  String _metode = 'transfer';
  String? _activeKunjunganId;

  String _statusTugas() =>
      (widget.tugas['status'] ?? widget.tugas['status_tugas'] ?? 'pending')
          .toString();

  void _showPrettySnackbar(
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
  }) {
    AppSnackbar.show(context, message, type: type);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final statusTugas = _statusTugas();
    _isPending = statusTugas == 'pending';

    final raw = SyncService.instance.daftarTugasKunjungan.value
        .where((k) => k['tugas_id'] == widget.tugas['id'])
        .toList();

    raw.sort((a, b) {
      final urutanA = int.tryParse('${a['urutan'] ?? 0}') ?? 0;
      final urutanB = int.tryParse('${b['urutan'] ?? 0}') ?? 0;
      return urutanA.compareTo(urutanB);
    });
    _kunjunganList = List.from(raw);
    _normalizeMergedRoutes();

    _refreshActiveForm();
  }

  String _routeName(Map<String, dynamic> kunjungan) =>
      (kunjungan['nama_klien'] ?? '-').toString();

  String _routeKey(Map<String, dynamic> kunjungan) =>
      _routeName(kunjungan).trim().toLowerCase();

  void _normalizeMergedRoutes() {
    if (!_isPending || _kunjunganList.isEmpty) return;

    final grouped = <String, List<Map<String, dynamic>>>{};
    final keyOrder = <String>[];

    for (final kunjungan in _kunjunganList) {
      final key = _routeKey(kunjungan);
      if (!grouped.containsKey(key)) {
        keyOrder.add(key);
        grouped[key] = [];
      }
      grouped[key]!.add(kunjungan);
    }

    _kunjunganList = [for (final key in keyOrder) ...grouped[key]!];
  }

  Map<String, int> _routeCounts() {
    final counts = <String, int>{};
    for (final kunjungan in _kunjunganList) {
      final key = _routeKey(kunjungan);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  List<_RouteEntry> _buildReorderEntries() {
    final counts = _routeCounts();
    final entries = <_RouteEntry>[];
    int i = 0;

    while (i < _kunjunganList.length) {
      final current = _kunjunganList[i];
      final key = _routeKey(current);
      final totalCount = counts[key] ?? 1;
      final shouldShowMerged = totalCount > 1 && !_splitRouteKeys.contains(key);

      if (shouldShowMerged) {
        final groupedIds = _kunjunganList
            .where((k) => _routeKey(k) == key)
            .map((k) => k['id'].toString())
            .toList();
        entries.add(
          _RouteEntry(
            routeKey: key,
            routeName: _routeName(current),
            visitIds: groupedIds,
            isMergedCard: true,
          ),
        );
        i += totalCount;
      } else {
        entries.add(
          _RouteEntry(
            routeKey: key,
            routeName: _routeName(current),
            visitIds: [current['id'].toString()],
            isMergedCard: false,
          ),
        );
        i += 1;
      }
    }
    return entries;
  }

  void _onReorderPending(int oldIndex, int newIndex) {
    final entries = _buildReorderEntries();
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = entries.removeAt(oldIndex);
    entries.insert(newIndex, moved);

    final byId = {for (final k in _kunjunganList) k['id'].toString(): k};

    final reorderedIds = <String>[
      for (final entry in entries) ...entry.visitIds,
    ];

    _kunjunganList = [
      for (final id in reorderedIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  void _setRouteSplit(String routeKey, bool split) {
    setState(() {
      if (split) {
        _splitRouteKeys.add(routeKey);
      } else {
        _splitRouteKeys.remove(routeKey);
        _normalizeMergedRoutes();
      }
    });
  }

  List<Map<String, dynamic>> _orderedKunjunganForSaving() {
    if (!_isPending) return List<Map<String, dynamic>>.from(_kunjunganList);
    final entries = _buildReorderEntries();
    final byId = {for (final k in _kunjunganList) k['id'].toString(): k};
    final ordered = <Map<String, dynamic>>[];
    for (final entry in entries) {
      for (final id in entry.visitIds) {
        final row = byId[id];
        if (row != null) ordered.add(row);
      }
    }
    return ordered;
  }

  void _populateFormsFor(String id) {
    _qtyCtrls.clear();
    _tunaiCtrl.clear();
    _metode = 'transfer';

    final items = SyncService.instance.daftarTugasItem.value
        .where((e) => e['kunjungan_id'] == id)
        .toList();

    final kunjungan = _kunjunganList.firstWhere(
      (k) => k['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    if (kunjungan.isEmpty) return;

    final statusKunjungan =
        (kunjungan['status_kunjungan'] ?? kunjungan['status']).toString();
    final isPendingKunjungan = statusKunjungan == 'pending';

    for (final item in items) {
      // Jika pending tampilkan qty_diminta, jika sudah selesai tampilkan qty_dikirim
      final qty = isPendingKunjungan
          ? (item['qty_diminta'] ?? 0)
          : (item['qty_dikirim'] ?? item['qty_diminta'] ?? 0);
      _qtyCtrls[item['id']] = TextEditingController(text: qty.toString());
    }

    if (!isPendingKunjungan) {
      final metodeValue = kunjungan['metode_bayar']?.toString();
      if (metodeValue == 'cash' ||
          metodeValue == 'transfer' ||
          metodeValue == 'tempo') {
        _metode = metodeValue!;
      }
      _tunaiCtrl.text = (kunjungan['total_dibayar'] ?? 0).toString();
    }
  }

  void _refreshActiveForm() {
    if (_isPending) return;

    if (_activeKunjunganId == null) {
      final active = _kunjunganList.firstWhere(
        (k) => (k['status_kunjungan'] ?? k['status']) == 'pending',
        orElse: () => <String, dynamic>{},
      );
      if (active.isNotEmpty) {
        _activeKunjunganId = active['id'];
      }
    }

    if (_activeKunjunganId != null) {
      _populateFormsFor(_activeKunjunganId!);
    }
  }

  void _geserKunjunganSelesai(int direction) {
    final currentIndex = _kunjunganList.indexWhere(
      (k) => k['id'] == _activeKunjunganId,
    );
    if (currentIndex == -1) return;

    int newIndex = currentIndex + direction;

    if (newIndex >= 0 && newIndex < _kunjunganList.length) {
      setState(() {
        _activeKunjunganId = _kunjunganList[newIndex]['id'];
        _populateFormsFor(_activeKunjunganId!);
      });
    }
  }

  Future<void> _mulaiTugas() async {
    final tugasLainBerjalan = SyncService.instance.daftarTugas.value.any(
      (t) =>
          t['id'] != widget.tugas['id'] &&
          ((t['status'] ?? t['status_tugas']) == 'in_progress'),
    );
    if (tugasLainBerjalan) {
      _showPrettySnackbar(
        'Masih ada tugas lain yang sedang berjalan. Selesaikan dulu sebelum memulai tugas baru.',
        type: AppSnackbarType.warning,
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    final orderedKunjungan = _orderedKunjunganForSaving();
    _kunjunganList = List<Map<String, dynamic>>.from(orderedKunjungan);

    final sync = SyncService.instance;
    final wasOnline = sync.isOnline;
    sync.isOnline = false;
    try {
      for (int i = 0; i < orderedKunjungan.length; i++) {
        await sync.mutateData('tugas_kunjungan', 'update', {
          'id': orderedKunjungan[i]['id'],
          'urutan': i,
        }, showSnackbar: false);
      }

      await sync.mutateData('tugas', 'update', {
        'id': widget.tugas['id'],
        'status': 'in_progress',
      });
    } finally {
      sync.isOnline = wasOnline;
    }
    if (wasOnline) {
      await sync.sinkronkanSemua();
    }

    widget.tugas['status'] = 'in_progress';
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    setState(() {
      _isPending = false;
      _isLoading = false;
      _refreshActiveForm();
    });
  }

  Future<void> _selesaikanKunjunganSaatIni(
    Map<String, dynamic> activeKunjungan,
    List<Map<String, dynamic>> items,
    String? catatanTambahan,
    bool lanjutKeKlienBerikutnya,
  ) async {
    final Map<String, int> qtyPerBarang = {};
    for (final item in items) {
      final qty = int.tryParse(_qtyCtrls[item['id']]!.text) ?? 0;
      final barangId = item['barang_id'];
      final barang = SyncService.instance.daftarBarang.value.firstWhere(
        (b) => b['id'] == barangId,
        orElse: () => <String, dynamic>{},
      );
      final hargaSatuan =
          double.tryParse('${barang['harga_satuan'] ?? 0}') ?? 0;
      if (barangId != null)
        qtyPerBarang[barangId] = (qtyPerBarang[barangId] ?? 0) + qty;

      await SyncService.instance.mutateData('tugas_item', 'update', {
        'id': item['id'],
        'qty_dikirim': qty,
        'harga_total': qty * hargaSatuan,
      }, showSnackbar: false);
    }

    final muatan = SyncService.instance.daftarMuatanTugas.value.where(
      (m) => m['tugas_id'] == widget.tugas['id'],
    );
    for (final m in muatan) {
      final barangId = m['barang_id'];
      if (barangId == null) continue;
      final berkurang = qtyPerBarang[barangId] ?? 0;
      final current = int.tryParse('${m['qty_sisa'] ?? 0}') ?? 0;
      final sisaBaru = (current - berkurang).clamp(0, 1 << 31);

      await SyncService.instance.mutateData('muatan_tugas', 'update', {
        'id': m['id'],
        'qty_sisa': sisaBaru,
      }, showSnackbar: false);
    }

    final catatan = [
      if (catatanTambahan != null && catatanTambahan.trim().isNotEmpty)
        catatanTambahan.trim(),
    ].join('\n');

    await SyncService.instance.mutateData('tugas_kunjungan', 'update', {
      'id': activeKunjungan['id'],
      'status': 'delivered',
      'catatan': catatan.isEmpty ? null : catatan,
      'metode_bayar': _metode,
      'total_dibayar': _metode == 'cash'
          ? (double.tryParse(_tunaiCtrl.text) ?? 0)
          : 0,
      'waktu_selesai': DateTime.now().toUtc().toIso8601String(),
    }, showSnackbar: false);

    await _cekStatusTugasSelesai(
      lanjutKeKlienBerikutnya: lanjutKeKlienBerikutnya,
    );
  }

  Future<void> _tandaiGagal(
    Map<String, dynamic> activeKunjungan,
    String catatan,
    bool lanjutKeKlienBerikutnya,
  ) async {
    await SyncService.instance.mutateData('tugas_kunjungan', 'update', {
      'id': activeKunjungan['id'],
      'status': 'failed',
      'catatan': catatan.trim(),
      'waktu_selesai': DateTime.now().toUtc().toIso8601String(),
    }, showSnackbar: false);

    await _cekStatusTugasSelesai(
      lanjutKeKlienBerikutnya: lanjutKeKlienBerikutnya,
    );
  }

  Future<void> _cekStatusTugasSelesai({
    required bool lanjutKeKlienBerikutnya,
  }) async {
    final raw = SyncService.instance.daftarTugasKunjungan.value
        .where((k) => k['tugas_id'] == widget.tugas['id'])
        .toList();
    final semuaSelesai = raw.every(
      (k) => (k['status_kunjungan'] ?? k['status']) != 'pending',
    );

    if (semuaSelesai) {
      final kunjunganIds = raw.map((k) => k['id']).toSet();
      final tugasItems = SyncService.instance.daftarTugasItem.value.where(
        (ti) => kunjunganIds.contains(ti['kunjungan_id']),
      );

      // Hitung total barang yang BENAR-BENAR DIKIRIM (di-drop)
      final Map<String, int> totalDikirimByBarang = {};
      for (final item in tugasItems) {
        final barangId = item['barang_id']?.toString();
        if (barangId == null) continue;
        final qtyDikirim = int.tryParse('${item['qty_dikirim'] ?? 0}') ?? 0;
        totalDikirimByBarang[barangId] =
            (totalDikirimByBarang[barangId] ?? 0) + qtyDikirim;
      }

      final muatanTugas = SyncService.instance.daftarMuatanTugas.value.where(
        (m) => m['tugas_id'] == widget.tugas['id'],
      );

      // Update qty_sisa di muatan_tugas secara otomatis
      for (final muatan in muatanTugas) {
        final barangId = muatan['barang_id']?.toString();
        final muatanId = muatan['id']?.toString();
        if (barangId == null || muatanId == null) continue;

        final qtyBawa = int.tryParse('${muatan['qty_bawa'] ?? 0}') ?? 0;
        final qtyDikirim = totalDikirimByBarang[barangId] ?? 0;
        final qtySisa = (qtyBawa - qtyDikirim).clamp(0, 1 << 31);

        // KITA HANYA UPDATE MUATAN TUGAS. Trigger DB mengurus sisanya!
        await SyncService.instance.mutateData('muatan_tugas', 'update', {
          'id': muatanId,
          'qty_sisa': qtySisa,
        }, showSnackbar: false);
      }

      await SyncService.instance.mutateData('tugas', 'update', {
        'id': widget.tugas['id'],
        'status': 'completed',
      }, showSnackbar: false);

      if (mounted) {
        Navigator.pop(context);
        _showPrettySnackbar(
          'Tugas selesai! Sisa muatan otomatis dikembalikan ke gudang.',
          type: AppSnackbarType.success,
        );
      }
    } else {
      if (!mounted) return;
      setState(() {
        if (lanjutKeKlienBerikutnya) {
          _activeKunjunganId = null; // Memaksa mencari klien pending berikutnya
        }
        _loadData(); // Menyegarkan list & trigger _refreshActiveForm()
      });
      _showPrettySnackbar(
        lanjutKeKlienBerikutnya
            ? 'Lanjut ke klien berikutnya.'
            : 'Drop tersimpan. Anda tetap melihat histori tujuan ini.',
        type: AppSnackbarType.info,
      );
    }
  }

  Future<String?> _askReasonModal({
    required String title,
    required String hint,
  }) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReasonDialog(title: title, hint: hint),
    );
  }

  Future<void> _onTapGagal(Map<String, dynamic> activeKunjungan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Gagal Drop'),
        content: const Text('Yakin ingin menandai drop ini sebagai gagal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Gagal'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final alasan = await _askReasonModal(
      title: 'Alasan Gagal Drop',
      hint: 'Contoh: klien tutup, alamat tidak ditemukan, dll.',
    );
    if (alasan == null) return;

    if (_isLastPending) {
      await _tampilkanModalSelesaiTugas(() async {
        await _tandaiGagal(activeKunjungan, alasan, false);
      });
    } else {
      final lanjut = await _askContinueModal();
      if (lanjut == null) return;
      await _tandaiGagal(activeKunjungan, alasan, lanjut);
    }
  }

  Future<bool?> _askContinueModal() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lanjutkan Perjalanan?'),
        content: const Text(
          'Pilih aksi berikutnya setelah proses drop ini disimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tetap di halaman ini'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjut ke klien berikutnya'),
          ),
        ],
      ),
    );
  }

  Future<void> _onTapSelesaiDrop(
    Map<String, dynamic> activeKunjungan,
    List<Map<String, dynamic>> items,
  ) async {
    if (_metode == 'cash') {
      double totalTagihan = 0;

      for (final item in items) {
        final qtyInput = int.tryParse(_qtyCtrls[item['id']]?.text ?? '') ?? 0;
        final barangId = item['barang_id'];

        final barang = SyncService.instance.daftarBarang.value.firstWhere(
          (b) => b['id'] == barangId,
          orElse: () => <String, dynamic>{},
        );

        final hargaSatuan =
            double.tryParse('${barang['harga_satuan'] ?? 0}') ?? 0;
        totalTagihan += (qtyInput * hargaSatuan);
      }

      final double totalDibayar = double.tryParse(_tunaiCtrl.text) ?? 0;

      if (totalDibayar < totalTagihan) {
        _showPrettySnackbar(
          'Uang tunai kurang! Tagihan: ${_formatNominal(totalTagihan)} | Dibayar: ${_formatNominal(totalDibayar)}',
          type: AppSnackbarType.error,
        );
        return;
      }
    }

    String? catatanTambahan;
    final adaPenyesuaianQty = items.any((item) {
      final qtyInput = int.tryParse(_qtyCtrls[item['id']]?.text ?? '') ?? 0;
      final qtyDiminta = int.tryParse('${item['qty_diminta'] ?? 0}') ?? 0;
      return qtyInput != qtyDiminta;
    });

    if (adaPenyesuaianQty) {
      catatanTambahan = await _askReasonModal(
        title: 'Alasan Perubahan Qty',
        hint: 'Jelaskan alasan qty bertambah/berkurang.',
      );
      if (catatanTambahan == null) return;
    }

    if (_isLastPending) {
      await _tampilkanModalSelesaiTugas(() async {
        await _selesaikanKunjunganSaatIni(
          activeKunjungan,
          items,
          catatanTambahan,
          false,
        );
      });
    } else {
      final lanjut = await _askContinueModal();
      if (lanjut == null) return;
      await _selesaikanKunjunganSaatIni(
        activeKunjungan,
        items,
        catatanTambahan,
        lanjut,
      );
    }
  }

  Future<void> _bukaMaps(String alamat) async {
    final urlString =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(alamat)}';
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showPrettySnackbar(
          'Tidak dapat membuka Google Maps.',
          type: AppSnackbarType.error,
        );
      }
    } catch (e) {
      _showPrettySnackbar('Terjadi kesalahan: $e', type: AppSnackbarType.error);
    }
  }

  int _getSisaMuatan(String barangId) {
    final muatanList = SyncService.instance.daftarMuatanTugas.value.where(
      (m) => m['tugas_id'] == widget.tugas['id'] && m['barang_id'] == barangId,
    );
    final totalBawa = muatanList.fold(
      0,
      (sum, m) => sum + (int.tryParse('${m['qty_bawa'] ?? 0}') ?? 0),
    );

    final deliveredKunjungans = SyncService.instance.daftarTugasKunjungan.value
        .where(
          (k) =>
              k['tugas_id'] == widget.tugas['id'] &&
              (k['status_kunjungan'] == 'delivered' ||
                  k['status'] == 'delivered'),
        )
        .map((k) => k['id'])
        .toSet();

    final deliveredItems = SyncService.instance.daftarTugasItem.value.where(
      (ti) =>
          deliveredKunjungans.contains(ti['kunjungan_id']) &&
          ti['barang_id'] == barangId,
    );
    final totalTerkirim = deliveredItems.fold(
      0,
      (sum, ti) => sum + (int.tryParse('${ti['qty_dikirim'] ?? 0}') ?? 0),
    );

    return totalBawa - totalTerkirim;
  }

  // Helper untuk mengecek apakah ini adalah kunjungan terakhir yang pending
  bool get _isLastPending {
    final pendingList = _kunjunganList
        .where((k) => (k['status_kunjungan'] ?? k['status']) == 'pending')
        .toList();
    return pendingList.length == 1;
  }

  // Fungsi memunculkan modal penyelesaian tugas saat last drop
  Future<void> _tampilkanModalSelesaiTugas(Function onConfirm) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selesaikan Tugas?'),
        content: const Text(
          'Ini adalah tujuan terakhir. Apakah Anda yakin semua drop dan catatan sudah benar? Sisa muatan akan dikembalikan ke Gudang secara otomatis dan Tugas akan ditutup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Ya, Selesaikan'),
          ),
        ],
      ),
    );
  }

  // --- UI BUILDERS ---

  Widget _buildPendingReorderView() {
    final entries = _buildReorderEntries();
    final routeCounts = _routeCounts();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rute sama digabung otomatis. Tahan dan geser (drag) baris ke atas/bawah untuk menyusun rute terbaik Anda sebelum berangkat.',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: entries.length,
            onReorder: (oldIndex, newIndex) =>
                setState(() => _onReorderPending(oldIndex, newIndex)),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final totalCount = routeCounts[entry.routeKey] ?? 1;
              final isSplitCard = totalCount > 1 && !entry.isMergedCard;

              return Card(
                key: ValueKey(
                  entry.isMergedCard
                      ? 'merged-${entry.routeKey}'
                      : entry.visitIds.first,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    entry.isMergedCard
                        ? '${entry.routeName} (${entry.visitIds.length})'
                        : entry.routeName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: entry.isMergedCard
                      ? const Text('Rute digabung otomatis')
                      : (isSplitCard
                            ? const Text('Rute sedang dipisah')
                            : null),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry.isMergedCard)
                        TextButton(
                          onPressed: () => _setRouteSplit(entry.routeKey, true),
                          child: const Text('Split'),
                        )
                      else if (isSplitCard)
                        TextButton(
                          onPressed: () =>
                              _setRouteSplit(entry.routeKey, false),
                          child: const Text('Gabung'),
                        ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton.icon(
            onPressed: _mulaiTugas,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Kunci Rute & Mulai Tugas'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveKunjunganView() {
    final active = _kunjunganList.firstWhere(
      (k) => k['id'] == _activeKunjunganId,
      orElse: () => <String, dynamic>{},
    );

    if (active.isEmpty) {
      return _buildCompletedSummary();
    }

    final statusKunjungan = (active['status_kunjungan'] ?? active['status'])
        .toString();
    final isPendingKunjungan = statusKunjungan == 'pending';

    final klien = SyncService.instance.daftarKlien.value.firstWhere(
      (k) => k['id'] == active['klien_id'],
      orElse: () => {},
    );
    final alamat = klien['alamat']?.toString() ?? 'Alamat tidak tersedia';

    final urutanTujuan = _kunjunganList.indexOf(active) + 1;

    final items = SyncService.instance.daftarTugasItem.value
        .where((e) => e['kunjungan_id'] == active['id'])
        .toList();
    final barangById = {
      for (final b in SyncService.instance.daftarBarang.value) b['id']: b,
    };

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        const int sensitivity = 8;
        if (details.primaryVelocity! > sensitivity) {
          _geserKunjunganSelesai(
            -1,
          ); // Swipe Kanan -> Mundur ke klien sebelumnya
        } else if (details.primaryVelocity! < -sensitivity) {
          _geserKunjunganSelesai(1); // Swipe Kiri -> Maju ke klien berikutnya
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isPendingKunjungan
                      ? Colors.blue.shade200
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              color: isPendingKunjungan
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isPendingKunjungan
                                ? Colors.blue.shade600
                                : Colors.grey.shade600,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _geserKunjunganSelesai(-1),
                                child: const Icon(
                                  Icons.chevron_left,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  'Tujuan $urutanTujuan dari ${_kunjunganList.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _geserKunjunganSelesai(1),
                                child: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isPendingKunjungan)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusKunjungan == 'delivered'
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusKunjungan.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: statusKunjungan == 'delivered'
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      active['nama_klien'] ?? '-',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alamat,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.blueGrey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isPendingKunjungan) ...[
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => _bukaMaps(alamat),
                        icon: const Icon(Icons.map),
                        label: const Text('Buka Rute di Maps'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              isPendingKunjungan
                  ? 'Input Drop Pengiriman'
                  : 'Detail Drop Pengiriman',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),

            ...items.map((item) {
              final barangId = item['barang_id'];
              final sisaDiMobil = barangId != null
                  ? _getSisaMuatan(barangId)
                  : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _qtyCtrls[item['id']],
                  keyboardType: TextInputType.number,
                  readOnly:
                      !isPendingKunjungan, // Lock the textfield if completed
                  decoration: InputDecoration(
                    labelText: isPendingKunjungan
                        ? '${barangById[barangId]?['nama'] ?? 'Barang'} (Diminta: ${item['qty_diminta']} | Sisa di Mobil: $sisaDiMobil)'
                        : '${barangById[barangId]?['nama'] ?? 'Barang'} (Dikirim / Diminta: ${item['qty_diminta']})',
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                    border: const OutlineInputBorder(),
                    filled: !isPendingKunjungan,
                    fillColor: !isPendingKunjungan
                        ? Colors.grey.shade100
                        : null,
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _metode,
              decoration: InputDecoration(
                labelText: 'Metode Pembayaran',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.payment),
                filled: !isPendingKunjungan,
                fillColor: !isPendingKunjungan ? Colors.grey.shade100 : null,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'transfer',
                  child: Text('Transfer Bank'),
                ),
                DropdownMenuItem(value: 'cash', child: Text('Tunai (Cash)')),
                DropdownMenuItem(value: 'tempo', child: Text('Jatuh Tempo')),
              ],
              onChanged: isPendingKunjungan
                  ? (val) => setState(() => _metode = val ?? 'transfer')
                  : null, // Disable dropdown if completed
            ),
            if (_metode == 'cash') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _tunaiCtrl,
                keyboardType: TextInputType.number,
                readOnly: !isPendingKunjungan,
                decoration: InputDecoration(
                  labelText: 'Diterima Tunai',
                  prefixText: 'Rp ',
                  border: const OutlineInputBorder(),
                  filled: !isPendingKunjungan,
                  fillColor: !isPendingKunjungan ? Colors.grey.shade100 : null,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Logika Visibilitas Tombol Aksi
            if (isPendingKunjungan)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _onTapGagal(active),
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text(
                        'Gagal',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _onTapSelesaiDrop(active, items),
                      icon: const Icon(Icons.check_circle),
                      label: Text(
                        _isLastPending ? 'Selesaikan Tugas' : 'Selesai Drop',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusKunjungan == 'delivered'
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusKunjungan == 'delivered'
                            ? Colors.green.shade300
                            : Colors.red.shade300,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          statusKunjungan == 'delivered'
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: statusKunjungan == 'delivered'
                              ? Colors.green
                              : Colors.red,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kunjungan ini telah selesai dan dikunci.',
                          style: TextStyle(
                            color: statusKunjungan == 'delivered'
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_kunjunganList.every(
                    (k) => (k['status_kunjungan'] ?? k['status']) != 'pending',
                  )) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _activeKunjunganId =
                              null; // Forces fallback to Summary View
                        });
                      },
                      child: const Text('Lihat Ringkasan Seluruh Klien'),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatTanggalJam(dynamic rawWaktu) {
    if (rawWaktu == null) return '-';
    final parsed = DateTime.tryParse(rawWaktu.toString());
    if (parsed == null) return '-';
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatWaktuSelesai(Map<String, dynamic> kunjungan) {
    final raw = kunjungan['waktu_selesai'] ?? kunjungan['completed_at_local'];

    if (raw == null) {
      return 'Waktu Penyelesaian: - (belum tersedia)';
    }

    String timeString = raw.toString();

    if (!timeString.endsWith('Z') && !timeString.contains('+')) {
      timeString += 'Z';
    }

    final parsed = DateTime.tryParse(timeString);
    if (parsed == null) {
      return 'Waktu Penyelesaian: - (format waktu tidak valid)';
    }

    final local = parsed.toLocal();
    return 'Waktu Penyelesaian: ${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? _rekapKunjunganById(String kunjunganId) {
    for (final r in SyncService.instance.daftarTugasKunjunganRekap.value) {
      if ((r['id'] ?? r['tugas_kunjungan_id'])?.toString() == kunjunganId) {
        return r;
      }
    }
    return null;
  }

  String _formatNominal(dynamic value) {
    final number = double.tryParse(value?.toString() ?? '');
    if (number == null) return '-';
    final asInt = number.toInt();
    final text = number == asInt ? asInt.toString() : number.toStringAsFixed(2);
    return 'Rp$text';
  }

  Widget _buildCompletedSummary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Card(
            color: Colors.green,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Tugas Telah Selesai',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ringkasan Pengiriman per Klien',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sentuh kartu klien untuk melihat detail inputannya secara penuh.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ..._kunjunganList.map((k) {
            final items = SyncService.instance.daftarTugasItem.value
                .where((ti) => ti['kunjungan_id'] == k['id'])
                .toList();

            final statusKunjungan =
                (k['status_kunjungan'] ?? k['status'] ?? '-').toString();
            final isDelivered = statusKunjungan == 'delivered';

            return GestureDetector(
              onTap: () {
                // Menjadikan Summary View clickable untuk melihat detail histori form per-klien
                setState(() {
                  _activeKunjunganId = k['id'];
                  _populateFormsFor(_activeKunjunganId!);
                });
              },
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDelivered
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              k['nama_klien'] ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDelivered
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusKunjungan.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDelivered
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      ...items.map((item) {
                        final barangId = item['barang_id'];
                        final barang = SyncService.instance.daftarBarang.value
                            .firstWhere(
                              (b) => b['id'] == barangId,
                              orElse: () => <String, dynamic>{},
                            );
                        final namaBarang = barang['nama'] ?? 'Barang';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $namaBarang: Diminta ${item['qty_diminta'] ?? 0}, Dikirim ${item['qty_dikirim'] ?? 0}',
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final rekap = _rekapKunjunganById(
                            k['id']?.toString() ?? '',
                          );
                          final metodeBayar =
                              (rekap?['metode_bayar'] ?? k['metode_bayar'])
                                  ?.toString()
                                  .trim();
                          final totalTagihan =
                              rekap?['total_tagihan_kunjungan'] ??
                              k['total_tagihan_kunjungan'];
                          final totalDibayar =
                              rekap?['total_dibayar'] ?? k['total_dibayar'];
                          final kembalian =
                              rekap?['kembalian'] ?? k['kembalian'];
                          final showKembalian =
                              (double.tryParse(kembalian?.toString() ?? '') ??
                                  0) >
                              0;
                          final isCash =
                              (metodeBayar ?? '').toLowerCase() == 'cash';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Tagihan: ${_formatNominal(totalTagihan)}',
                              ),
                              Text(
                                'Metode Bayar: ${metodeBayar?.isNotEmpty == true ? metodeBayar : '-'}',
                              ),
                              if (isCash)
                                Text(
                                  'Total Dibayar: ${_formatNominal(totalDibayar)}',
                                ),
                              if (showKembalian)
                                Text('Kembalian: ${_formatNominal(kembalian)}'),
                            ],
                          );
                        },
                      ),
                      if (k['catatan'] != null &&
                          k['catatan'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Catatan/Alasan:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(k['catatan']),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        _formatWaktuSelesai(k),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isLoading
          ? null
          : AppBar(
              title: Text(
                _isPending
                    ? 'Susun Rute Anda'
                    : (_statusTugas() == 'completed'
                          ? 'Detail Tugas'
                          : 'Tugas Berjalan'),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 1,
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _isPending
                ? _buildPendingReorderView()
                : _buildActiveKunjunganView(),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isLoading,
              child: AnimatedOpacity(
                opacity: _isLoading ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                child: Container(
                  color: Colors.white,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 24),
                        Text(
                          'Menyimpan rute & Memulai tugas...',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String hint;

  const _ReasonDialog({required this.title, required this.hint});

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (_ctrl.text.trim().isEmpty) return;
            Navigator.pop(context, _ctrl.text.trim());
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
