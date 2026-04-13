class ItemPesanan {
  ItemPesanan({
    required this.id,
    required this.idTugas,
    required this.namaBarang,
    required this.qtyPesanan,
    this.qtyDropReal,
  });

  final String id;
  final String idTugas;
  final String namaBarang;
  final int qtyPesanan;
  final int? qtyDropReal;

  factory ItemPesanan.fromJson(Map<String, dynamic> json) {
    return ItemPesanan(
      id: json['id'] as String,
      idTugas: json['id_tugas'] as String,
      namaBarang: json['nama_barang'] as String,
      qtyPesanan: (json['qty_pesanan'] as num).toInt(),
      qtyDropReal: (json['qty_drop_real'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_tugas': idTugas,
      'nama_barang': namaBarang,
      'qty_pesanan': qtyPesanan,
      'qty_drop_real': qtyDropReal,
    };
  }
}
