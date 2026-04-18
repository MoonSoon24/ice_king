import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'supabase_config.dart';
import '../widgets/app_snackbar.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final Uuid _uuid = const Uuid();
  late SharedPreferences _prefs;

  final ValueNotifier<bool> sedangSinkron = ValueNotifier(false);
  final ValueNotifier<List<Map<String, dynamic>>> daftarTugas = ValueNotifier(
    [],
  );
  // DIHAPUS: daftarItem (item_pesanan)
  final ValueNotifier<List<Map<String, dynamic>>> daftarTugasItem =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> daftarTugasKunjungan =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> daftarMuatanTugas =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> daftarKaryawan =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> daftarBarang = ValueNotifier(
    [],
  );
  final ValueNotifier<List<Map<String, dynamic>>> daftarKlien = ValueNotifier(
    [],
  );
  final ValueNotifier<List<Map<String, dynamic>>> daftarAuditLog =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> daftarTugasKunjunganRekap =
      ValueNotifier([]);

  bool isOnline = true;

  int get pendingSyncCount =>
      (_prefs.getStringList('antrean_sinkron') ?? []).length;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadCache();

    final hasil = await Connectivity().checkConnectivity();
    isOnline = hasil.isNotEmpty && hasil.first != ConnectivityResult.none;

    Connectivity().onConnectivityChanged.listen((results) {
      final terkoneksi =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      if (terkoneksi && !isOnline) {
        isOnline = true;
        sinkronkanSemua();
      } else if (!terkoneksi) {
        isOnline = false;
      }
    });

    if (isOnline) {
      await sinkronkanSemua();
      final antrean = _prefs.getStringList('antrean_sinkron') ?? [];
      if (antrean.isEmpty) {
        await tarikSemuaDariCloud();
      }
    }
  }

  String generateId() => _uuid.v4();

  void _loadCache() {
    daftarTugas.value = _decodeList(_prefs.getString('cache_tugas'));
    daftarTugasKunjungan.value = _decodeList(
      _prefs.getString('cache_tugas_kunjungan'),
    );
    // DIHAPUS: load cache_item_pesanan
    daftarTugasItem.value = _decodeList(_prefs.getString('cache_tugas_item'));
    daftarMuatanTugas.value = _decodeList(
      _prefs.getString('cache_muatan_tugas'),
    );
    daftarKaryawan.value = _decodeList(_prefs.getString('cache_karyawan'));
    daftarBarang.value = _decodeList(_prefs.getString('cache_barang'));
    daftarKlien.value = _decodeList(_prefs.getString('cache_klien'));
    daftarAuditLog.value = _decodeList(_prefs.getString('cache_audit_log'));
    daftarTugasKunjunganRekap.value = _decodeList(
      _prefs.getString('cache_tugas_kunjungan_rekap'),
    );
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw) as List<dynamic>);
  }

  Future<void> tarikSemuaDariCloud() async {
    try {
      final hasil = await Future.wait([
        SupabaseConfig.client
            .from('tugas_kunjungan')
            .select()
            .order('created_at', ascending: false), // Index 0
        SupabaseConfig.client
            .from('tugas')
            .select()
            .order('created_at', ascending: false), // Index 1
        // DIHAPUS: item_pesanan
        SupabaseConfig.client.from('tugas_item').select(), // Index 2
        SupabaseConfig.client.from('muatan_tugas').select(), // Index 3
        SupabaseConfig.client.from('karyawan').select(), // Index 4
        SupabaseConfig.client.from('barang').select(), // Index 5
        SupabaseConfig.client.from('klien').select(), // Index 6
        SupabaseConfig.client
            .from('audit_log')
            .select()
            .order('created_at', ascending: false), // Index 7
        SupabaseConfig.client.from('tugas_kunjungan_rekap').select(), // Index 8
      ]);

      final kunjungan = List<Map<String, dynamic>>.from(hasil[0] as List);
      final tugas = List<Map<String, dynamic>>.from(hasil[1] as List);
      // PERBAIKAN INDEX: Shift semua data turun 1 karena item_pesanan dihapus
      final tugasItem = List<Map<String, dynamic>>.from(hasil[2] as List);
      final muatanTugas = List<Map<String, dynamic>>.from(hasil[3] as List);
      final karyawan = List<Map<String, dynamic>>.from(hasil[4] as List);
      final barang = List<Map<String, dynamic>>.from(hasil[5] as List);
      final klien = List<Map<String, dynamic>>.from(hasil[6] as List);
      final auditLog = List<Map<String, dynamic>>.from(hasil[7] as List);
      final kunjunganRekap = List<Map<String, dynamic>>.from(hasil[8] as List);

      final karyawanById = {for (final k in karyawan) k['id']: k};
      final klienById = {for (final k in klien) k['id']: k};

      daftarTugas.value = tugas.map((t) {
        final driverId = t['karyawan_id'];
        final driver = driverId != null ? karyawanById[driverId] : null;
        return {...t, 'nama_driver': driver?['nama'] ?? 'Unknown Driver'};
      }).toList();

      daftarTugasKunjungan.value = kunjungan.map((k) {
        final klienData = klienById[k['klien_id']];
        return {...k, 'nama_klien': klienData?['nama'] ?? 'Unknown Klien'};
      }).toList();

      // DIHAPUS: Assign daftarItem
      daftarTugasItem.value = tugasItem;
      daftarMuatanTugas.value = muatanTugas;
      daftarKaryawan.value = karyawan;
      daftarBarang.value = barang;
      daftarKlien.value = klien;
      daftarAuditLog.value = auditLog;
      daftarTugasKunjunganRekap.value = kunjunganRekap;

      await _prefs.setString('cache_tugas', jsonEncode(daftarTugas.value));
      await _prefs.setString(
        'cache_tugas_kunjungan',
        jsonEncode(daftarTugasKunjungan.value),
      );

      // DIHAPUS: Simpan cache_item_pesanan
      await _prefs.setString(
        'cache_tugas_item',
        jsonEncode(daftarTugasItem.value),
      );
      await _prefs.setString(
        'cache_muatan_tugas',
        jsonEncode(daftarMuatanTugas.value),
      );
      await _prefs.setString(
        'cache_karyawan',
        jsonEncode(daftarKaryawan.value),
      );
      await _prefs.setString('cache_barang', jsonEncode(daftarBarang.value));
      await _prefs.setString('cache_klien', jsonEncode(daftarKlien.value));
      await _prefs.setString(
        'cache_audit_log',
        jsonEncode(daftarAuditLog.value),
      );
      await _prefs.setString(
        'cache_tugas_kunjungan_rekap',
        jsonEncode(daftarTugasKunjunganRekap.value),
      );
    } catch (e) {
      debugPrint('Gagal tarik data cloud: $e');
    }
  }

  void _mutateLokal(String tabel, String aksi, Map<String, dynamic> data) {
    ValueNotifier<List<Map<String, dynamic>>>? notifier;

    if (tabel == 'tugas') {
      notifier = daftarTugas;
    } else if (tabel == 'tugas_kunjungan') {
      notifier = daftarTugasKunjungan;
      // DIHAPUS: Blok item_pesanan
    } else if (tabel == 'tugas_item') {
      notifier = daftarTugasItem;
    } else if (tabel == 'muatan_tugas') {
      notifier = daftarMuatanTugas;
    } else if (tabel == 'karyawan') {
      notifier = daftarKaryawan;
    } else if (tabel == 'barang') {
      notifier = daftarBarang;
    } else if (tabel == 'klien') {
      notifier = daftarKlien;
    }

    if (notifier == null) return;

    final listBaru = List<Map<String, dynamic>>.from(notifier.value);

    final dataEnriched = _enrichRelasiLokal(tabel, data);

    if (tabel == 'muatan_tugas') {
      _replicateTriggerLokal(aksi, data);
    }

    if (aksi == 'insert') {
      listBaru.insert(0, dataEnriched);
    } else if (aksi == 'update') {
      final i = listBaru.indexWhere((e) => e['id'] == dataEnriched['id']);
      if (i != -1) {
        listBaru[i] = _enrichRelasiLokal(tabel, {
          ...listBaru[i],
          ...dataEnriched,
        });
      }
    } else if (aksi == 'delete') {
      listBaru.removeWhere((e) => e['id'] == dataEnriched['id']);
    }

    notifier.value = listBaru;
    if (tabel == 'klien') _refreshNamaKlienDiKunjungan();
    if (tabel == 'karyawan') _refreshNamaDriverDiTugas();

    _prefs.setString('cache_$tabel', jsonEncode(listBaru));
  }

  Map<String, dynamic> _enrichRelasiLokal(
    String tabel,
    Map<String, dynamic> data,
  ) {
    if (tabel == 'tugas_kunjungan') {
      final klienId = data['klien_id'];
      final klien = daftarKlien.value.firstWhere(
        (k) => k['id'] == klienId,
        orElse: () => <String, dynamic>{},
      );
      return {
        ...data,
        if (klien.isNotEmpty)
          'nama_klien': klien['nama']?.toString() ?? 'Unknown Klien',
      };
    }

    if (tabel == 'tugas') {
      final karyawanId = data['karyawan_id'];
      final karyawan = daftarKaryawan.value.firstWhere(
        (k) => k['id'] == karyawanId,
        orElse: () => <String, dynamic>{},
      );
      return {
        ...data,
        if (karyawan.isNotEmpty)
          'nama_driver': karyawan['nama']?.toString() ?? 'Unknown Driver',
      };
    }
    return data;
  }

  void _refreshNamaKlienDiKunjungan() {
    final klienById = {for (final k in daftarKlien.value) k['id']: k};
    final kunjunganBaru = daftarTugasKunjungan.value.map((k) {
      final klien = klienById[k['klien_id']];
      return {
        ...k,
        'nama_klien': klien?['nama']?.toString() ?? (k['nama_klien'] ?? '-'),
      };
    }).toList();
    daftarTugasKunjungan.value = kunjunganBaru;
    _prefs.setString('cache_tugas_kunjungan', jsonEncode(kunjunganBaru));
  }

  void _refreshNamaDriverDiTugas() {
    final driverById = {for (final k in daftarKaryawan.value) k['id']: k};
    final tugasBaru = daftarTugas.value.map((t) {
      final driver = driverById[t['karyawan_id']];
      return {
        ...t,
        'nama_driver': driver?['nama']?.toString() ?? (t['nama_driver'] ?? '-'),
      };
    }).toList();
    daftarTugas.value = tugasBaru;
    _prefs.setString('cache_tugas', jsonEncode(tugasBaru));
  }

  void _replicateTriggerLokal(String aksi, Map<String, dynamic> data) {
    final barangId = data['barang_id'];
    if (barangId == null) return;

    final listBarang = List<Map<String, dynamic>>.from(daftarBarang.value);
    final i = listBarang.indexWhere((b) => b['id'] == barangId);

    if (i != -1) {
      final barang = Map<String, dynamic>.from(listBarang[i]);
      int stokSekarang = (barang['stok_gudang'] as num?)?.toInt() ?? 0;

      if (aksi == 'insert') {
        int qtyBawa = (data['qty_bawa'] as num?)?.toInt() ?? 0;
        barang['stok_gudang'] = stokSekarang - qtyBawa;
      } else if (aksi == 'update') {
        int qtySisa = (data['qty_sisa'] as num?)?.toInt() ?? 0;
      }

      listBarang[i] = barang;
      daftarBarang.value = listBarang;
      _prefs.setString('cache_barang', jsonEncode(listBarang));
    }
  }

  Map<String, dynamic> _sanitizeCloudData(
    String tabel,
    Map<String, dynamic> data,
  ) {
    Set<String> allowed;
    if (tabel == 'tugas') {
      allowed = {
        'id',
        'karyawan_id',
        'nama_tugas',
        'modal_awal',
        'status',
        'created_at',
        'waktu_selesai',
      };
    } else if (tabel == 'tugas_kunjungan') {
      allowed = {
        'id',
        'tugas_id',
        'klien_id',
        'status',
        'catatan',
        'metode_bayar',
        'total_dibayar',
        'created_at',
        'urutan',
        'waktu_selesai',
      };
      // DIHAPUS: Blok item_pesanan
    } else if (tabel == 'tugas_item') {
      allowed = {
        'id',
        'kunjungan_id',
        'barang_id',
        'qty_diminta',
        'qty_dikirim',
        'harga_total',
        'created_at',
      };
    } else if (tabel == 'muatan_tugas') {
      allowed = {
        'id',
        'tugas_id',
        'barang_id',
        'qty_bawa',
        'qty_sisa',
        'created_at',
      };
    } else if (tabel == 'karyawan') {
      allowed = {'id', 'nama', 'role', 'created_at'};
    } else if (tabel == 'barang') {
      allowed = {
        'id',
        'nama',
        'kategori',
        'harga_satuan',
        'stok_gudang',
        'created_at',
      };
    } else if (tabel == 'klien') {
      allowed = {'id', 'nama', 'alamat', 'kontak', 'created_at'};
    } else {
      allowed = data.keys.toSet();
    }
    return Map<String, dynamic>.fromEntries(
      data.entries.where((entry) => allowed.contains(entry.key)),
    );
  }

  Future<void> mutateData(
    String tabel,
    String aksi,
    Map<String, dynamic> data, {
    bool showSnackbar = true,
  }) async {
    _mutateLokal(tabel, aksi, data);

    final antrean = _prefs.getStringList('antrean_sinkron') ?? [];
    antrean.add(
      jsonEncode({
        'tabel': tabel,
        'aksi': aksi,
        'data': _sanitizeCloudData(tabel, data),
      }),
    );
    await _prefs.setStringList('antrean_sinkron', antrean);

    if (isOnline) {
      await sinkronkanSemua();
    }
    if (showSnackbar) {
      final namaTabel = tabel.replaceAll('_', ' ');
      if (aksi == 'insert') {
        AppSnackbar.showGlobal(
          'Data $namaTabel berhasil ditambahkan.',
          type: AppSnackbarType.success,
        );
      } else if (aksi == 'update') {
        AppSnackbar.showGlobal(
          'Data $namaTabel berhasil diperbarui.',
          type: AppSnackbarType.success,
        );
      } else if (aksi == 'delete') {
        AppSnackbar.showGlobal(
          'Data $namaTabel berhasil dihapus.',
          type: AppSnackbarType.success,
        );
      }
    }
  }

  Future<({int total, int sukses, int gagal})> sinkronkanSemua() async {
    if (!isOnline || sedangSinkron.value) {
      final antreanSaatIni = _prefs.getStringList('antrean_sinkron') ?? [];
      return (
        total: antreanSaatIni.length,
        sukses: 0,
        gagal: antreanSaatIni.length,
      );
    }
    sedangSinkron.value = true;

    final antrean = _prefs.getStringList('antrean_sinkron') ?? [];
    final gagal = <String>[];

    for (final item in antrean) {
      final payload = jsonDecode(item) as Map<String, dynamic>;
      final tabel = payload['tabel'] as String;
      final aksi = payload['aksi'] as String;
      final data = Map<String, dynamic>.from(payload['data'] as Map);

      try {
        if (aksi == 'insert') {
          await SupabaseConfig.client
              .from(tabel)
              .upsert(data, onConflict: 'id');
        } else if (aksi == 'update') {
          final id = data['id'];
          if (id == null) continue;
          final dataUpdate = Map<String, dynamic>.from(data)..remove('id');
          if (dataUpdate.isEmpty) continue;
          await SupabaseConfig.client
              .from(tabel)
              .update(dataUpdate)
              .eq('id', id);
        } else if (aksi == 'delete') {
          final id = data['id'];
          if (id == null) continue;
          await SupabaseConfig.client.from(tabel).delete().eq('id', id);
        }
      } catch (e) {
        debugPrint('Sinkronisasi gagal [$tabel:$aksi]: $e');
        gagal.add(item);
      }
    }

    await _prefs.setStringList('antrean_sinkron', gagal);
    if (gagal.isEmpty) {
      await tarikSemuaDariCloud();
    }
    sedangSinkron.value = false;
    return (
      total: antrean.length,
      sukses: antrean.length - gagal.length,
      gagal: gagal.length,
    );
  }
}
