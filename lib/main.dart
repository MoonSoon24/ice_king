import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://uxtxzhcoicqbgislrugi.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV4dHh6aGNvaWNxYmdpc2xydWdpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNDc5NTksImV4cCI6MjA5MTYyMzk1OX0.E1f6G2HubLbFVcTAlqOco6BKXJzWjpkcnEbvqmpt1W8',
  );

  // Inisialisasi Service Sinkronisasi
  await SyncService.instance.init();

  runApp(const AdminApp());
}

final supabase = Supabase.instance.client;

// ==========================================
// SYNC ENGINE & OFFLINE MANAGER
// ==========================================
class SyncService {
  SyncService._privateConstructor();
  static final SyncService instance = SyncService._privateConstructor();

  late SharedPreferences _prefs;
  bool isOnline = true;
  final Uuid _uuid = const Uuid();

  // Melacak SEMUA 7 tabel di local cache (TERMASUK KARYAWAN)
  ValueNotifier<List<Map<String, dynamic>>> barangData = ValueNotifier([]);
  ValueNotifier<List<Map<String, dynamic>>> klienData = ValueNotifier([]);
  ValueNotifier<List<Map<String, dynamic>>> karyawanData = ValueNotifier(
    [],
  ); // <--- INI YANG BARU
  ValueNotifier<List<Map<String, dynamic>>> tugasData = ValueNotifier([]);
  ValueNotifier<List<Map<String, dynamic>>> tugasKunjunganData = ValueNotifier(
    [],
  );
  ValueNotifier<List<Map<String, dynamic>>> tugasItemData = ValueNotifier([]);
  ValueNotifier<List<Map<String, dynamic>>> pengeluaranData = ValueNotifier([]);

  ValueNotifier<bool> isSyncing = ValueNotifier(false);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final List<ConnectivityResult> connectivityResult = await (Connectivity()
        .checkConnectivity());
    isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    // Load semua dari cache lokal SECARA INSTAN
    _loadLocalCache('barang', barangData);
    _loadLocalCache('klien', klienData);
    _loadLocalCache('karyawan', karyawanData); // <--- INI YANG BARU
    _loadLocalCache('tugas', tugasData);
    _loadLocalCache('tugas_kunjungan', tugasKunjunganData);
    _loadLocalCache('tugas_item', tugasItemData);
    _loadLocalCache('pengeluaran', pengeluaranData);

    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      bool hasConnection =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      if (hasConnection && !isOnline) {
        isOnline = true;
        syncData();
      } else if (!hasConnection) {
        isOnline = false;
      }
    });

    if (isOnline) {
      await fetchAllFromCloud();
      await syncData();
    }
  }

  Future<void> fetchAllFromCloud() async {
    try {
      // Ambil semua tabel secara paralel agar lebih cepat
      final results = await Future.wait([
        supabase.from('barang').select(),
        supabase.from('klien').select(),
        supabase.from('karyawan').select(), // <--- INI YANG BARU
        supabase.from('tugas').select().order('tanggal', ascending: false),
        supabase.from('tugas_kunjungan').select(),
        supabase.from('tugas_item').select(),
        supabase
            .from('pengeluaran')
            .select()
            .order('tanggal', ascending: false),
      ]);

      barangData.value = List<Map<String, dynamic>>.from(results[0]);
      klienData.value = List<Map<String, dynamic>>.from(results[1]);
      karyawanData.value = List<Map<String, dynamic>>.from(
        results[2],
      ); // <--- INI YANG BARU
      tugasData.value = List<Map<String, dynamic>>.from(results[3]);
      tugasKunjunganData.value = List<Map<String, dynamic>>.from(results[4]);
      tugasItemData.value = List<Map<String, dynamic>>.from(results[5]);
      pengeluaranData.value = List<Map<String, dynamic>>.from(results[6]);

      _prefs.setString('cache_barang', jsonEncode(results[0]));
      _prefs.setString('cache_klien', jsonEncode(results[1]));
      _prefs.setString(
        'cache_karyawan',
        jsonEncode(results[2]),
      ); // <--- INI YANG BARU
      _prefs.setString('cache_tugas', jsonEncode(results[3]));
      _prefs.setString('cache_tugas_kunjungan', jsonEncode(results[4]));
      _prefs.setString('cache_tugas_item', jsonEncode(results[5]));
      _prefs.setString('cache_pengeluaran', jsonEncode(results[6]));
    } catch (e) {
      debugPrint("Gagal fetch cloud: $e");
    }
  }

  void _loadLocalCache(
    String table,
    ValueNotifier<List<Map<String, dynamic>>> notifier,
  ) {
    final cachedStr = _prefs.getString('cache_$table');
    if (cachedStr != null) {
      notifier.value = List<Map<String, dynamic>>.from(jsonDecode(cachedStr));
    }
  }

  Future<void> mutateData(
    String table,
    String action,
    Map<String, dynamic> data,
  ) async {
    _updateLocalState(table, action, data);

    final queueItem = {
      'table': table,
      'action': action,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    List<String> queue = _prefs.getStringList('sync_queue') ?? [];
    queue.add(jsonEncode(queueItem));
    await _prefs.setStringList('sync_queue', queue);

    if (isOnline) await syncData();
  }

  void _updateLocalState(
    String table,
    String action,
    Map<String, dynamic> data,
  ) {
    ValueNotifier<List<Map<String, dynamic>>> notifier;
    switch (table) {
      case 'barang':
        notifier = barangData;
        break;
      case 'klien':
        notifier = klienData;
        break;
      case 'karyawan':
        notifier = karyawanData;
        break; // <--- INI YANG BARU
      case 'tugas':
        notifier = tugasData;
        break;
      case 'tugas_kunjungan':
        notifier = tugasKunjunganData;
        break;
      case 'tugas_item':
        notifier = tugasItemData;
        break;
      case 'pengeluaran':
        notifier = pengeluaranData;
        break;
      default:
        return;
    }

    List<Map<String, dynamic>> currentList = List.from(notifier.value);

    if (action == 'insert')
      currentList.insert(0, data);
    else if (action == 'update') {
      int index = currentList.indexWhere((e) => e['id'] == data['id']);
      if (index != -1) currentList[index] = data;
    } else if (action == 'delete') {
      currentList.removeWhere((e) => e['id'] == data['id']);
    }

    notifier.value = currentList;
    _prefs.setString('cache_$table', jsonEncode(currentList));
  }

  Future<void> syncData() async {
    if (isSyncing.value || !isOnline) return;
    isSyncing.value = true;

    List<String> queue = _prefs.getStringList('sync_queue') ?? [];
    List<String> failedQueue = [];

    for (String itemStr in queue) {
      Map<String, dynamic> item = jsonDecode(itemStr);
      try {
        if (item['action'] == 'insert')
          await supabase.from(item['table']).insert(item['data']);
        else if (item['action'] == 'update')
          await supabase
              .from(item['table'])
              .update(item['data'])
              .eq('id', item['data']['id']);
        else if (item['action'] == 'delete')
          await supabase
              .from(item['table'])
              .delete()
              .eq('id', item['data']['id']);
      } catch (e) {
        debugPrint("Sync Error: $e");
        failedQueue.add(itemStr);
      }
    }

    await _prefs.setStringList('sync_queue', failedQueue);
    await fetchAllFromCloud();
    isSyncing.value = false;
  }

  String generateId() => _uuid.v4();
}

// ==========================================
// UI APLIKASI
// ==========================================
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Es & Air',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const MainAdminScreen(),
    );
  }
}

class TugasDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tugas;
  const TugasDetailScreen({super.key, required this.tugas});

  @override
  State<TugasDetailScreen> createState() => _TugasDetailScreenState();
}

class _TugasDetailScreenState extends State<TugasDetailScreen> {
  // Fungsi ini "merakit" data persis seperti Join Query di SQL, tapi pakai data lokal (Offline)
  List<Map<String, dynamic>> _buildRelationalData() {
    final sync = SyncService.instance;
    final String targetTugasId = widget.tugas['id'];

    // 1. Cari semua Kunjungan untuk Tugas ini
    List<Map<String, dynamic>> kunjunganLokal = sync.tugasKunjunganData.value
        .where((k) => k['tugas_id'] == targetTugasId)
        .toList();

    return kunjunganLokal.map((kunjungan) {
      // 2. Cari nama Klien
      final klien = sync.klienData.value.firstWhere(
        (k) => k['id'] == kunjungan['klien_id'],
        orElse: () => {'nama': 'Klien Dihapus/Tidak Ditemukan'},
      );

      // 3. Cari Item-item untuk Kunjungan ini
      final items = sync.tugasItemData.value
          .where((i) => i['kunjungan_id'] == kunjungan['id'])
          .toList()
          .map((item) {
            // 4. Cari nama Barang
            final barang = sync.barangData.value.firstWhere(
              (b) => b['id'] == item['barang_id'],
              orElse: () => {'nama': 'Barang Dihapus'},
            );
            return {...item, 'barang': barang}; // Gabungkan
          })
          .toList();

      // Gabungkan semuanya jadi satu objek utuh
      return {...kunjungan, 'klien': klien, 'tugas_item': items};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tugas['nama_tugas'])),
      // Gunakan AnimatedBuilder untuk memantau 3 tabel sekaligus. Jika ada perubahan di salah satu, layar update.
      body: AnimatedBuilder(
        animation: Listenable.merge([
          SyncService.instance.tugasKunjunganData,
          SyncService.instance.tugasItemData,
          SyncService.instance.klienData,
        ]),
        builder: (context, _) {
          final rakitanData = _buildRelationalData();

          if (rakitanData.isEmpty) {
            return const Center(
              child: Text('Belum ada rute klien untuk tugas ini.'),
            );
          }

          return ListView.builder(
            itemCount: rakitanData.length,
            itemBuilder: (context, index) {
              final k = rakitanData[index];
              final klien = k['klien'];
              final items = List.from(k['tugas_item'] ?? []);

              double estimasiTotal = 0;
              for (var item in items) {
                estimasiTotal += (item['harga_total'] ?? 0);
              }

              return ExpansionTile(
                leading: const Icon(Icons.location_on, color: Colors.red),
                title: Text(
                  klien['nama'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Status: ${k['status']} | Tagihan: Rp $estimasiTotal',
                ),
                children: items.map((item) {
                  final barang = item['barang'];
                  return ListTile(
                    title: Text(barang['nama']),
                    trailing: Text('${item['qty_diminta']} x'),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) =>
                FormTambahKunjungan(tugasId: widget.tugas['id']),
          );
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Tambah Klien'),
      ),
    );
  }
}

class FormTambahKunjungan extends StatefulWidget {
  final String tugasId;
  const FormTambahKunjungan({super.key, required this.tugasId});

  @override
  State<FormTambahKunjungan> createState() => _FormTambahKunjunganState();
}

class _FormTambahKunjunganState extends State<FormTambahKunjungan> {
  String? _selectedKlienId;
  String? _selectedKlienNama;
  String? _selectedBarangId;
  final TextEditingController _qtyController = TextEditingController();
  List<Map<String, dynamic>> _keranjang = [];

  void _showPilihKlienSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return KlienSearchSheet(
          // BACA DARI LOCAL CACHE
          klienList: SyncService.instance.klienData.value,
          onSelected: (id, nama) => setState(() {
            _selectedKlienId = id;
            _selectedKlienNama = nama;
          }),
          onCreated: (baruId, baruNama) => setState(() {
            _selectedKlienId = baruId;
            _selectedKlienNama = baruNama;
          }),
        );
      },
    );
  }

  void _tambahKeKeranjang() {
    if (_selectedBarangId == null || _qtyController.text.isEmpty) return;

    // BACA DARI LOCAL CACHE
    final barang = SyncService.instance.barangData.value.firstWhere(
      (b) => b['id'] == _selectedBarangId,
    );
    final qty = int.tryParse(_qtyController.text) ?? 0;

    setState(() {
      _keranjang.add({
        'barang_id': barang['id'],
        'nama': barang['nama'],
        'qty_diminta': qty,
        'harga_satuan': barang['harga_satuan'],
        'harga_total': qty * barang['harga_satuan'],
      });
      _selectedBarangId = null;
      _qtyController.clear();
    });
  }

  Future<void> _simpanKeDatabase() async {
    if (_selectedKlienId == null || _keranjang.isEmpty) return;

    try {
      final String kunjunganId = SyncService.instance.generateId();

      await SyncService.instance.mutateData('tugas_kunjungan', 'insert', {
        'id': kunjunganId,
        'tugas_id': widget.tugasId,
        'klien_id': _selectedKlienId,
        'status': 'pending',
      });

      for (var item in _keranjang) {
        await SyncService.instance.mutateData('tugas_item', 'insert', {
          'id': SyncService.instance.generateId(),
          'kunjungan_id': kunjunganId,
          'barang_id': item['barang_id'],
          'qty_diminta': item['qty_diminta'],
          'harga_total': item['harga_total'],
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ambil list barang dari cache lokal (Pastikan ini ada di dalam build agar responsif)
    final barangListLokal = SyncService.instance.barangData.value;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Atur Rute Klien',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          InkWell(
            onTap: _showPilihKlienSheet,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Pilih Klien Tujuan',
                border: OutlineInputBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedKlienNama ?? 'Cari atau tambah klien...',
                    style: TextStyle(
                      color: _selectedKlienNama == null
                          ? Colors.grey.shade600
                          : Colors.black,
                    ),
                  ),
                  const Icon(Icons.search),
                ],
              ),
            ),
          ),

          const Divider(height: 30),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedBarangId,
                  hint: const Text('Pilih Barang'),
                  isExpanded: true,
                  items: barangListLokal
                      .map(
                        (b) => DropdownMenuItem<String>(
                          value: b['id'],
                          child: Text(b['nama']),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedBarangId = val),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _qtyController,
                  decoration: const InputDecoration(labelText: 'Qty'),
                  keyboardType: TextInputType.number,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.blue,
                  size: 36,
                ),
                onPressed: _tambahKeKeranjang,
              ),
            ],
          ),

          const SizedBox(height: 10),
          ..._keranjang.map(
            (item) => ListTile(
              dense: true,
              title: Text(item['nama']),
              subtitle: Text(
                'Rp ${item['harga_satuan']} x ${item['qty_diminta']}',
              ),
              trailing: Text(
                'Rp ${item['harga_total']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: (_selectedKlienId != null && _keranjang.isNotEmpty)
                ? _simpanKeDatabase
                : null,
            child: const Text('Simpan Rute & Barang'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ==========================================
// WIDGET KHUSUS: BOTTOM SHEET PENCARIAN KLIEN
// ==========================================
class KlienSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> klienList;
  final Function(String id, String nama) onSelected;
  final Function(String id, String nama) onCreated;

  const KlienSearchSheet({
    super.key,
    required this.klienList,
    required this.onSelected,
    required this.onCreated,
  });

  @override
  State<KlienSearchSheet> createState() => _KlienSearchSheetState();
}

class _KlienSearchSheetState extends State<KlienSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filteredList = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredList = widget.klienList;
  }

  void _filterData(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredList = widget.klienList;
      } else {
        _filteredList = widget.klienList
            .where(
              (k) => k['nama'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
      }
    });
  }

  void _buatKlienBaru() async {
    final namaBaru = _searchCtrl.text.trim();
    if (namaBaru.isEmpty) return;

    final idBaru = SyncService.instance.generateId();

    // Gunakan offline sync service untuk membuat data klien baru
    await SyncService.instance.mutateData('klien', 'insert', {
      'id': idBaru,
      'nama': namaBaru,
      // Kolom alamat dan kontak dibiarkan kosong sementara
    });

    widget.onCreated(idBaru, namaBaru);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Cek apakah ketikan user persis sama dengan data yang sudah ada
    bool isExactMatch = widget.klienList.any(
      (k) => k['nama'].toString().toLowerCase() == _searchQuery.toLowerCase(),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Cari nama klien...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  _filterData('');
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: _filterData,
          ),
          const SizedBox(height: 10),

          // Container list dibatasi tingginya agar tidak menutupi seluruh layar
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                // Tampilkan opsi "Tambah Baru" di urutan paling atas jika tidak ada kecocokan persis
                if (_searchQuery.isNotEmpty && !isExactMatch)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.add, color: Colors.white),
                    ),
                    title: Text('Tambah "$_searchQuery" sebagai klien baru'),
                    onTap: _buatKlienBaru,
                  ),

                // Tampilkan hasil pencarian
                ..._filteredList.map(
                  (k) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(k['nama']),
                    onTap: () {
                      widget.onSelected(k['id'], k['nama']);
                      Navigator.pop(context);
                    },
                  ),
                ),

                if (_filteredList.isEmpty && _searchQuery.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                      child: Text('Ketik untuk mencari data klien.'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KaryawanSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> karyawanList;
  final Function(String id, String nama) onSelected;
  final Function(String id, String nama) onCreated;

  const KaryawanSearchSheet({
    super.key,
    required this.karyawanList,
    required this.onSelected,
    required this.onCreated,
  });

  @override
  State<KaryawanSearchSheet> createState() => _KaryawanSearchSheetState();
}

class _KaryawanSearchSheetState extends State<KaryawanSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filteredList = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredList = widget.karyawanList;
  }

  void _filterData(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredList = widget.karyawanList;
      } else {
        _filteredList = widget.karyawanList
            .where(
              (k) => k['nama'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
      }
    });
  }

  void _buatKaryawanBaru() async {
    final namaBaru = _searchCtrl.text.trim();
    if (namaBaru.isEmpty) return;

    final idBaru = SyncService.instance.generateId();

    // Default role sebagai 'driver' untuk karyawan baru yang dibuat dari form tugas
    await SyncService.instance.mutateData('karyawan', 'insert', {
      'id': idBaru,
      'nama': namaBaru,
      'role': 'driver',
    });

    widget.onCreated(idBaru, namaBaru);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    bool isExactMatch = widget.karyawanList.any(
      (k) => k['nama'].toString().toLowerCase() == _searchQuery.toLowerCase(),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Pilih Driver / Karyawan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Cari nama karyawan...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: _filterData,
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                if (_searchQuery.isNotEmpty && !isExactMatch)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person_add, color: Colors.white),
                    ),
                    title: Text('Tambah "$_searchQuery" sebagai Driver baru'),
                    onTap: _buatKaryawanBaru,
                  ),
                ..._filteredList.map(
                  (k) => ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(k['nama']),
                    subtitle: Text(k['role'] ?? 'driver'),
                    onTap: () {
                      widget.onSelected(k['id'], k['nama']);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MainAdminScreen extends StatefulWidget {
  const MainAdminScreen({super.key});

  @override
  State<MainAdminScreen> createState() => _MainAdminScreenState();
}

class _MainAdminScreenState extends State<MainAdminScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const GudangScreen(),
    const TugasScreen(),
    const LaporanScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          // INDIKATOR & TOMBOL SYNC MANUAL
          ValueListenableBuilder<bool>(
            valueListenable: SyncService.instance.isSyncing,
            builder: (context, isSyncing, child) {
              if (isSyncing) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Sinkronisasi Manual',
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mulai sinkronisasi...')),
                  );
                  await SyncService.instance.syncData();
                },
              );
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Gudang',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Tugas',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.insert_chart),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SCREEN 1: GUDANG
// ==========================================
class GudangScreen extends StatelessWidget {
  const GudangScreen({super.key});

  void _showForm(BuildContext context, [Map<String, dynamic>? item]) {
    final isEdit = item != null;
    final namaCtrl = TextEditingController(text: item?['nama']);
    final katCtrl = TextEditingController(text: item?['kategori']);
    final hargaCtrl = TextEditingController(
      text: item?['harga_satuan']?.toString(),
    );
    final stokCtrl = TextEditingController(
      text: item?['stok_gudang']?.toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit ? 'Edit Barang' : 'Tambah Barang',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: namaCtrl,
              decoration: const InputDecoration(labelText: 'Nama Barang'),
            ),
            TextField(
              controller: katCtrl,
              decoration: const InputDecoration(labelText: 'Kategori'),
            ),
            TextField(
              controller: hargaCtrl,
              decoration: const InputDecoration(labelText: 'Harga Satuan'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: stokCtrl,
              decoration: const InputDecoration(labelText: 'Stok Gudang'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final data = {
                  'id': isEdit ? item['id'] : SyncService.instance.generateId(),
                  'nama': namaCtrl.text,
                  'kategori': katCtrl.text,
                  'harga_satuan': double.tryParse(hargaCtrl.text) ?? 0,
                  'stok_gudang': int.tryParse(stokCtrl.text) ?? 0,
                };
                SyncService.instance.mutateData(
                  'barang',
                  isEdit ? 'update' : 'insert',
                  data,
                );
                Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: SyncService.instance.barangData,
        builder: (context, list, _) {
          if (list.isEmpty) return const Center(child: Text('Tidak ada data.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final b = list[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.ac_unit)),
                title: Text(
                  b['nama'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Stok: ${b['stok_gudang']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showForm(context, b),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => SyncService.instance.mutateData(
                        'barang',
                        'delete',
                        {'id': b['id']},
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ==========================================
// SCREEN 2: TUGAS
// ==========================================
class TugasScreen extends StatelessWidget {
  const TugasScreen({super.key});

  void _showTugasForm(BuildContext context, [Map<String, dynamic>? tugas]) {
    final isEdit = tugas != null;
    final namaController = TextEditingController(text: tugas?['nama_tugas']);
    final modalController = TextEditingController(
      text: tugas?['modal_awal']?.toString(),
    );

    // Variabel state lokal untuk form
    String? selectedKaryawanId = tugas?['karyawan_id'];
    String? selectedKaryawanNama;

    // Cari nama karyawan jika sedang edit
    if (isEdit && selectedKaryawanId != null) {
      final k = SyncService.instance.karyawanData.value.firstWhere(
        (e) => e['id'] == selectedKaryawanId,
        orElse: () => {'nama': 'Karyawan tidak ditemukan'},
      );
      selectedKaryawanNama = k['nama'];
    }

    String selectedStatus = tugas?['status'] ?? 'pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEdit ? 'Edit Tugas' : 'Tambah Tugas Rute',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),

                // INPUT KARYAWAN (DRIVER)
                InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => KaryawanSearchSheet(
                        karyawanList: SyncService.instance.karyawanData.value,
                        onSelected: (id, nama) => setStateSB(() {
                          selectedKaryawanId = id;
                          selectedKaryawanNama = nama;
                        }),
                        onCreated: (id, nama) => setStateSB(() {
                          selectedKaryawanId = id;
                          selectedKaryawanNama = nama;
                        }),
                      ),
                    );
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Pilih Driver / Karyawan',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedKaryawanNama ?? 'Cari atau tambah driver...',
                          style: TextStyle(
                            color: selectedKaryawanNama == null
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                        const Icon(Icons.person_search),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                TextField(
                  controller: namaController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Tugas/Rute',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: modalController,
                  decoration: const InputDecoration(
                    labelText: 'Modal Awal (Kembalian)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),

                if (isEdit) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('In Progress'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
                    ],
                    onChanged: (val) => setStateSB(() => selectedStatus = val!),
                    decoration: const InputDecoration(
                      labelText: 'Status Tugas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: (selectedKaryawanId == null)
                      ? null
                      : () async {
                          final data = {
                            'id': isEdit
                                ? tugas['id']
                                : SyncService.instance.generateId(),
                            'karyawan_id': selectedKaryawanId,
                            'nama_tugas': namaController.text,
                            'modal_awal':
                                double.tryParse(modalController.text) ?? 0,
                            'status': selectedStatus,
                            'tanggal': DateTime.now().toIso8601String().split(
                              'T',
                            )[0],
                          };

                          SyncService.instance.mutateData(
                            'tugas',
                            isEdit ? 'update' : 'insert',
                            data,
                          );
                          Navigator.pop(context);
                        },
                  child: const Text('Simpan Tugas'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: SyncService.instance.tugasData,
        builder: (context, list, _) {
          if (list.isEmpty)
            return const Center(child: Text('Tidak ada tugas.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final t = list[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    t['nama_tugas'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Status: ${t['status']}'),
                  onTap: () {
                    // Navigasi ke Halaman Detail Tugas
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TugasDetailScreen(tugas: t),
                      ),
                    );
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showTugasForm(context, t),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => SyncService.instance.mutateData(
                          'tugas',
                          'delete',
                          {'id': t['id']},
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTugasForm(context),
        child: const Icon(Icons.add_task),
      ),
    );
  }
}

// ==========================================
// SCREEN 3: LAPORAN
// ==========================================
class LaporanScreen extends StatelessWidget {
  const LaporanScreen({super.key});

  void _showForm(BuildContext context, [Map<String, dynamic>? item]) {
    final isEdit = item != null;
    final deskCtrl = TextEditingController(text: item?['deskripsi']);
    final nomCtrl = TextEditingController(text: item?['nominal']?.toString());
    String kat = item?['kategori'] ?? 'operasional_gudang';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEdit ? 'Edit Pengeluaran' : 'Catat Pengeluaran',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              DropdownButtonFormField<String>(
                value: kat,
                items:
                    [
                          'produksi',
                          'operasional_gudang',
                          'operasional_jalan',
                          'gaji',
                          'lain_lain',
                        ]
                        .map(
                          (k) => DropdownMenuItem(
                            value: k,
                            child: Text(k.toUpperCase()),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setStateSB(() => kat = v!),
              ),
              TextField(
                controller: deskCtrl,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
              TextField(
                controller: nomCtrl,
                decoration: const InputDecoration(labelText: 'Nominal (Rp)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final data = {
                    'id': isEdit
                        ? item['id']
                        : SyncService.instance.generateId(),
                    'kategori': kat,
                    'deskripsi': deskCtrl.text,
                    'nominal': double.tryParse(nomCtrl.text) ?? 0,
                    'tanggal': DateTime.now().toIso8601String().split('T')[0],
                  };
                  SyncService.instance.mutateData(
                    'pengeluaran',
                    isEdit ? 'update' : 'insert',
                    data,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Simpan'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: SyncService.instance.pengeluaranData,
        builder: (context, list, _) {
          if (list.isEmpty)
            return const Center(child: Text('Tidak ada pengeluaran.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final e = list[index];
              return ListTile(
                leading: const Icon(Icons.money_off, color: Colors.red),
                title: Text(
                  e['deskripsi'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${e['kategori']} | Rp ${e['nominal']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showForm(context, e),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => SyncService.instance.mutateData(
                        'pengeluaran',
                        'delete',
                        {'id': e['id']},
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
