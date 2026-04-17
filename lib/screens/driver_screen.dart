import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

class _DriverTugasDetailScreenState extends State<DriverTugasDetailScreen> {
  List<Map<String, dynamic>> _kunjunganList = [];
  bool _isPending = true;
  bool _isLoading = false;

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

    raw.sort((a, b) => (a['urutan'] ?? 0).compareTo(b['urutan'] ?? 0));
    _kunjunganList = List.from(raw);

    _refreshActiveForm();
  }

  void _refreshActiveForm() {
    if (_isPending) return;

    final active = _kunjunganList.firstWhere(
      (k) => (k['status_kunjungan'] ?? k['status']) == 'pending',
      orElse: () => <String, dynamic>{},
    );

    if (active.isNotEmpty && _activeKunjunganId != active['id']) {
      _activeKunjunganId = active['id'];
      _qtyCtrls.clear();
      _tunaiCtrl.clear();
      _metode = 'transfer';

      final items = SyncService.instance.daftarTugasItem.value
          .where((e) => e['kunjungan_id'] == active['id'])
          .toList();
      for (final item in items) {
        _qtyCtrls[item['id']] = TextEditingController(
          text: (item['qty_diminta'] ?? '').toString(),
        );
      }
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

    for (int i = 0; i < _kunjunganList.length; i++) {
      await SyncService.instance.mutateData('tugas_kunjungan', 'update', {
        'id': _kunjunganList[i]['id'],
        'urutan': i,
      }, showSnackbar: false);
    }

    await SyncService.instance.mutateData('tugas', 'update', {
      'id': widget.tugas['id'],
      'status': 'in_progress',
    });

    widget.tugas['status'] = 'in_progress';
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    setState(() {
      _isPending = false;
      _isLoading = false;
      _loadData();
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
      'waktu_selesai': DateTime.now().toIso8601String(),
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
      'waktu_selesai': DateTime.now().toIso8601String(),
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
      await SyncService.instance.mutateData('tugas', 'update', {
        'id': widget.tugas['id'],
        'status': 'completed',
      }, showSnackbar: false);
      if (mounted) {
        Navigator.pop(context);
        _showPrettySnackbar(
          'Tugas selesai! Semua kunjungan sudah diproses.',
          type: AppSnackbarType.success,
        );
      }
    } else {
      if (!mounted) return;
      setState(() {
        _loadData();
        if (!lanjutKeKlienBerikutnya) {
          _activeKunjunganId = null;
        }
      });
      _showPrettySnackbar(
        lanjutKeKlienBerikutnya
            ? 'Lanjut ke klien berikutnya.'
            : 'Drop tersimpan. Anda tetap di halaman detail.',
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

    final lanjut = await _askContinueModal();
    if (lanjut == null) return;

    await _tandaiGagal(activeKunjungan, alasan, lanjut);
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

    final lanjut = await _askContinueModal();
    if (lanjut == null) return;

    await _selesaikanKunjunganSaatIni(
      activeKunjungan,
      items,
      catatanTambahan,
      lanjut,
    );
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

  // --- UI BUILDERS ---

  Widget _buildPendingReorderView() {
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
                  'Tahan dan geser (drag) baris ke atas/bawah untuk menyusun rute terbaik Anda sebelum berangkat.',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: _kunjunganList.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _kunjunganList.removeAt(oldIndex);
                _kunjunganList.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final k = _kunjunganList[index];
              return Card(
                key: ValueKey(k['id']),
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
                    k['nama_klien'] ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.drag_handle),
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
      (k) => (k['status_kunjungan'] ?? k['status']) == 'pending',
      orElse: () => <String, dynamic>{},
    );

    // KETIKA TIDAK ADA KUNJUNGAN AKTIF, TAMPILKAN SUMMARY DETAIL SEPERTI ADMIN
    if (active.isEmpty) {
      return _buildCompletedSummary();
    }

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.blue.shade200, width: 2),
            ),
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(20),
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
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Input Drop Pengiriman',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),

          ...items.map((item) {
            final barangId = item['barang_id'];
            final sisaDiMobil = barangId != null ? _getSisaMuatan(barangId) : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _qtyCtrls[item['id']],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      '${barangById[barangId]?['nama'] ?? 'Barang'} (Diminta: ${item['qty_diminta']} | Sisa di Mobil: $sisaDiMobil)',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _metode,
            decoration: const InputDecoration(
              labelText: 'Metode Pembayaran',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payment),
            ),
            items: const [
              DropdownMenuItem(value: 'transfer', child: Text('Transfer Bank')),
              DropdownMenuItem(value: 'cash', child: Text('Tunai (Cash)')),
              DropdownMenuItem(value: 'tempo', child: Text('Jatuh Tempo')),
            ],
            onChanged: (val) => setState(() => _metode = val ?? 'transfer'),
          ),
          if (_metode == 'cash') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _tunaiCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Diterima Tunai',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
          ],

          const SizedBox(height: 32),
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
                  label: const Text('Selesai Drop'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatWaktuSelesai(Map<String, dynamic> kunjungan) {
    final raw = kunjungan['completed_at_local'];
    if (raw == null) {
      return 'Waktu Penyelesaian: - (offline timestamp belum tersedia)';
    }

    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null)
      return 'Waktu Penyelesaian: - (format waktu tidak valid)';

    final local = parsed.toLocal();
    return 'Waktu Penyelesaian: ${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  // UPDATED: Menampilkan detil ringkasan untuk seluruh klien bila selesai tugas layaknya Admin Screen
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
          const SizedBox(height: 12),
          ..._kunjunganList.map((k) {
            final items = SyncService.instance.daftarTugasItem.value
                .where((ti) => ti['kunjungan_id'] == k['id'])
                .toList();

            final statusKunjungan =
                (k['status_kunjungan'] ?? k['status'] ?? '-').toString();
            final isDelivered = statusKunjungan == 'delivered';

            return Card(
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
    // Controller dihancurkan dengan aman hanya ketika widget dialog sudah benar-benar selesai beranimasi & hilang
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
