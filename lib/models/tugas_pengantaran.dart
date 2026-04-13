class TugasPengantaran {
  TugasPengantaran({
    required this.id,
    required this.namaTugas,
    required this.tanggalTugas,
    required this.statusTugas,
    this.idDriver,
    this.namaDriver,
    this.metodePembayaran,
    this.jumlahPembayaranTunai,
  });

  final String id;
  final String namaTugas;
  final String tanggalTugas;
  final String statusTugas;
  final String? idDriver;
  final String? namaDriver;
  final String? metodePembayaran;
  final double? jumlahPembayaranTunai;

  factory TugasPengantaran.fromJson(Map<String, dynamic> json) {
    return TugasPengantaran(
      id: json['id'] as String,
      namaTugas: json['nama_tugas'] as String,
      tanggalTugas: json['tanggal_tugas'] as String,
      statusTugas: (json['status_tugas'] as String?) ?? 'menunggu',
      idDriver: json['id_driver'] as String?,
      namaDriver: json['nama_driver'] as String?,
      metodePembayaran: json['metode_pembayaran'] as String?,
      jumlahPembayaranTunai: (json['jumlah_pembayaran_tunai'] as num?)
          ?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama_tugas': namaTugas,
      'tanggal_tugas': tanggalTugas,
      'status_tugas': statusTugas,
      'id_driver': idDriver,
      'nama_driver': namaDriver,
      'metode_pembayaran': metodePembayaran,
      'jumlah_pembayaran_tunai': jumlahPembayaranTunai,
    };
  }

  TugasPengantaran copyWith({
    String? statusTugas,
    String? metodePembayaran,
    double? jumlahPembayaranTunai,
  }) {
    return TugasPengantaran(
      id: id,
      namaTugas: namaTugas,
      tanggalTugas: tanggalTugas,
      statusTugas: statusTugas ?? this.statusTugas,
      idDriver: idDriver,
      namaDriver: namaDriver,
      metodePembayaran: metodePembayaran ?? this.metodePembayaran,
      jumlahPembayaranTunai:
          jumlahPembayaranTunai ?? this.jumlahPembayaranTunai,
    );
  }
}
