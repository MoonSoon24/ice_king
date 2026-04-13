import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'supabase_config.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final Uuid _uuid = const Uuid();
  late SharedPreferences _prefs;

  final ValueNotifier<bool> sedangSinkron = ValueNotifier(false);
  final ValueNotifier<List<Map<String, dynamic>>> daftarTugas = ValueNotifier(
    [],
  );
  final ValueNotifier<List<Map<String, dynamic>>> daftarItem = ValueNotifier(
    [],
  );
  final ValueNotifier<List<Map<String, dynamic>>> daftarKaryawan =
      ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> daftarBarang = ValueNotifier(
    [],
  );
  final ValueNotifier<List<Map<String, dynamic>>> daftarKlien = ValueNotifier(
    [],
  );

  bool isOnline = true;

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
      await tarikSemuaDariCloud();
      await sinkronkanSemua();
    }
  }

  String generateId() => _uuid.v4();

  void _loadCache() {
    daftarTugas.value = _decodeList(_prefs.getString('cache_tugas_kunjungan'));
    daftarItem.value = _decodeList(_prefs.getString('cache_item_pesanan'));
    daftarKaryawan.value = _decodeList(_prefs.getString('cache_karyawan'));
    daftarBarang.value = _decodeList(_prefs.getString('cache_barang'));
    daftarKlien.value = _decodeList(_prefs.getString('cache_klien'));
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
            .order('created_at', ascending: false),
        SupabaseConfig.client.from('tugas').select(),
        SupabaseConfig.client.from('item_pesanan').select(),
        SupabaseConfig.client.from('karyawan').select(),
        SupabaseConfig.client.from('barang').select(),
        SupabaseConfig.client.from('klien').select(),
      ]);

      final kunjungan = List<Map<String, dynamic>>.from(hasil[0] as List);
      final tugas = List<Map<String, dynamic>>.from(hasil[1] as List);
      final itemPesanan = List<Map<String, dynamic>>.from(hasil[2] as List);
      final karyawan = List<Map<String, dynamic>>.from(hasil[3] as List);
      final barang = List<Map<String, dynamic>>.from(hasil[4] as List);
      final klien = List<Map<String, dynamic>>.from(hasil[5] as List);

      final tugasById = {for (final t in tugas) t['id']: t};
      final karyawanById = {for (final k in karyawan) k['id']: k};
      final klienById = {for (final k in klien) k['id']: k};

      daftarTugas.value = kunjungan.map((k) {
        final tugasRow = tugasById[k['tugas_id']];
        final driverId = tugasRow?['karyawan_id'];
        final driver = driverId != null ? karyawanById[driverId] : null;
        return {
          ...k,
          'nama_tugas': tugasRow?['nama_tugas'] ?? '-',
          'tanggal_tugas':
              tugasRow?['tanggal']?.toString() ?? k['created_at']?.toString(),
          'status_tugas': tugasRow?['status'] ?? 'pending',
          'id_driver': driverId,
          'nama_driver': driver?['nama'],
          'nama_klien': klienById[k['klien_id']]?['nama'],
          'metode_pembayaran': k['metode_bayar'],
          'jumlah_pembayaran_tunai': k['total_dibayar'],
        };
      }).toList();

      daftarItem.value = itemPesanan;
      daftarKaryawan.value = karyawan;
      daftarBarang.value = barang;
      daftarKlien.value = klien;

      await _prefs.setString(
        'cache_tugas_kunjungan',
        jsonEncode(daftarTugas.value),
      );
      await _prefs.setString(
        'cache_item_pesanan',
        jsonEncode(daftarItem.value),
      );
      await _prefs.setString(
        'cache_karyawan',
        jsonEncode(daftarKaryawan.value),
      );
      await _prefs.setString('cache_barang', jsonEncode(daftarBarang.value));
      await _prefs.setString('cache_klien', jsonEncode(daftarKlien.value));
    } catch (e) {
      debugPrint('Gagal tarik data cloud: $e');
    }
  }

  // FIXED: Moved this outside mutateData
  void _mutateLokal(String tabel, String aksi, Map<String, dynamic> data) {
    if (tabel == 'tugas') {
      final listBaru = List<Map<String, dynamic>>.from(daftarTugas.value);
      if (aksi == 'delete') {
        listBaru.removeWhere((e) => e['tugas_id'] == data['id']);
      } else {
        final index = listBaru.indexWhere((e) => e['tugas_id'] == data['id']);
        if (index != -1) {
          listBaru[index] = {
            ...listBaru[index],
            'status_tugas': data['status'] ?? listBaru[index]['status_tugas'],
            'nama_tugas': data['nama_tugas'] ?? listBaru[index]['nama_tugas'],
            'tanggal_tugas':
                data['tanggal']?.toString() ?? listBaru[index]['tanggal_tugas'],
            'id_driver': data['karyawan_id'] ?? listBaru[index]['id_driver'],
          };
        }
      }
      daftarTugas.value = listBaru;
      _prefs.setString('cache_tugas_kunjungan', jsonEncode(listBaru));
      return;
    }

    ValueNotifier<List<Map<String, dynamic>>>? notifier;
    if (tabel == 'tugas_kunjungan') {
      notifier = daftarTugas;
    } else if (tabel == 'item_pesanan') {
      notifier = daftarItem;
    } else if (tabel == 'karyawan') {
      notifier = daftarKaryawan;
    } else if (tabel == 'barang') {
      notifier = daftarBarang;
    } else if (tabel == 'klien') {
      notifier = daftarKlien;
    }
    if (notifier == null) return;

    final listBaru = List<Map<String, dynamic>>.from(notifier.value);
    if (aksi == 'insert') {
      if (tabel == 'tugas_kunjungan') {
        listBaru.insert(0, {
          ...data,
          'nama_tugas': data['nama_tugas'] ?? '-',
          'tanggal_tugas':
              data['tanggal_tugas']?.toString() ??
              data['created_at']?.toString(),
          'status_tugas': data['status_tugas'] ?? data['status'] ?? 'pending',
          'metode_pembayaran':
              data['metode_pembayaran'] ?? data['metode_bayar'],
          'jumlah_pembayaran_tunai':
              data['jumlah_pembayaran_tunai'] ?? data['total_dibayar'],
        });
      } else {
        listBaru.insert(0, data);
      }
    } else if (aksi == 'update') {
      final i = listBaru.indexWhere((e) => e['id'] == data['id']);
      if (i != -1) {
        listBaru[i] = tabel == 'tugas_kunjungan'
            ? {
                ...listBaru[i],
                ...data,
                'status_tugas':
                    data['status_tugas'] ??
                    data['status'] ??
                    listBaru[i]['status_tugas'],
                'metode_pembayaran':
                    data['metode_pembayaran'] ??
                    data['metode_bayar'] ??
                    listBaru[i]['metode_pembayaran'],
                'jumlah_pembayaran_tunai':
                    data['jumlah_pembayaran_tunai'] ??
                    data['total_dibayar'] ??
                    listBaru[i]['jumlah_pembayaran_tunai'],
              }
            : data;
      }
    } else if (aksi == 'delete') {
      listBaru.removeWhere((e) => e['id'] == data['id']);
    }

    notifier.value = listBaru;
    final cacheKey = tabel == 'tugas_kunjungan'
        ? 'cache_tugas_kunjungan'
        : 'cache_$tabel';
    _prefs.setString(cacheKey, jsonEncode(listBaru));
  }

  // FIXED: Moved this outside mutateData
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
        'tanggal',
        'created_at',
      };
    } else if (tabel == 'tugas_kunjungan') {
      allowed = {
        'id',
        'tugas_id',
        'klien_id',
        'status',
        'metode_bayar',
        'total_dibayar',
        'created_at',
      };
    } else if (tabel == 'item_pesanan') {
      allowed = {
        'id',
        'id_tugas',
        'nama_barang',
        'qty_pesanan',
        'qty_drop_real',
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
    Map<String, dynamic> data,
  ) async {
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
  }

  // FIXED: Moved this outside mutateData
  Future<void> sinkronkanSemua() async {
    if (!isOnline || sedangSinkron.value) return;
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
          await SupabaseConfig.client.from(tabel).insert(data);
        } else if (aksi == 'update') {
          await SupabaseConfig.client
              .from(tabel)
              .update(data)
              .eq('id', data['id']);
        } else if (aksi == 'delete') {
          await SupabaseConfig.client.from(tabel).delete().eq('id', data['id']);
        }
      } catch (_) {
        gagal.add(item);
      }
    }

    await _prefs.setStringList('antrean_sinkron', gagal);
    await tarikSemuaDariCloud();
    sedangSinkron.value = false;
  }
}
