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
    daftarTugas.value = _decodeList(
      _prefs.getString('cache_tugas_pengantaran'),
    );
    daftarItem.value = _decodeList(_prefs.getString('cache_item_pesanan'));
    daftarKaryawan.value = _decodeList(_prefs.getString('cache_karyawan'));
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw) as List<dynamic>);
  }

  Future<void> tarikSemuaDariCloud() async {
    try {
      final hasil = await Future.wait([
        SupabaseConfig.client
            .from('tugas_pengantaran')
            .select()
            .order('tanggal_tugas', ascending: false),
        SupabaseConfig.client.from('item_pesanan').select(),
        SupabaseConfig.client.from('karyawan').select(),
      ]);

      daftarTugas.value = List<Map<String, dynamic>>.from(
        hasil[0] as List<dynamic>,
      );
      daftarItem.value = List<Map<String, dynamic>>.from(
        hasil[1] as List<dynamic>,
      );
      daftarKaryawan.value = List<Map<String, dynamic>>.from(
        hasil[2] as List<dynamic>,
      );

      await _prefs.setString(
        'cache_tugas_pengantaran',
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
    } catch (e) {
      debugPrint('Gagal tarik data cloud: $e');
    }
  }

  Future<void> mutateData(
    String tabel,
    String aksi,
    Map<String, dynamic> data,
  ) async {
    _mutateLokal(tabel, aksi, data);

    final antrean = _prefs.getStringList('antrean_sinkron') ?? [];
    antrean.add(jsonEncode({'tabel': tabel, 'aksi': aksi, 'data': data}));
    await _prefs.setStringList('antrean_sinkron', antrean);

    if (isOnline) {
      await sinkronkanSemua();
    }
  }

  void _mutateLokal(String tabel, String aksi, Map<String, dynamic> data) {
    final notifier = switch (tabel) {
      'tugas_pengantaran' => daftarTugas,
      'item_pesanan' => daftarItem,
      'karyawan' => daftarKaryawan,
      _ => null,
    };
    if (notifier == null) return;

    final listBaru = List<Map<String, dynamic>>.from(notifier.value);
    if (aksi == 'insert') {
      listBaru.insert(0, data);
    } else if (aksi == 'update') {
      final i = listBaru.indexWhere((e) => e['id'] == data['id']);
      if (i != -1) listBaru[i] = data;
    } else if (aksi == 'delete') {
      listBaru.removeWhere((e) => e['id'] == data['id']);
    }

    notifier.value = listBaru;
    _prefs.setString('cache_$tabel', jsonEncode(listBaru));
  }

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
