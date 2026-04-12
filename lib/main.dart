import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  // Required to ensure plugin services are initialized before `runApp`
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IceAdminApp());
}

class IceAdminApp extends StatelessWidget {
  const IceAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ice Admin POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue.shade600,
          background: Colors.blueGrey.shade50,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const PosHomeScreen(),
    );
  }
}

// --- DATABASE HELPER ---
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ice_admin.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, filePath);

    return await openDatabase(fullPath, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE warehouse (
        id $idType,
        name $textType,
        quantity $integerType
      )
    ''');

    await db.execute('''
      CREATE TABLE deliveries (
        id $idType,
        driverName $textType,
        itemId $integerType,
        itemName $textType,
        packsLoaded $integerType,
        packsDelivered $integerType,
        packsReturned $integerType,
        status $textType,
        timestamp $textType
      )
    ''');

    // Insert initial dummy data
    await db.insert('warehouse', {'name': '1kg Cube Pack', 'quantity': 500});
    await db.insert('warehouse', {'name': '5kg Block', 'quantity': 150});
    await db.insert('warehouse', {'name': 'Crushed Ice (Bag)', 'quantity': 80});
  }

  // Warehouse CRUD
  Future<int> insertWarehouseItem(WarehouseItem item) async {
    final db = await instance.database;
    return await db.insert('warehouse', item.toMap());
  }

  Future<List<WarehouseItem>> getWarehouseItems() async {
    final db = await instance.database;
    final maps = await db.query('warehouse');
    return maps.map((map) => WarehouseItem.fromMap(map)).toList();
  }

  Future<int> updateWarehouseItem(WarehouseItem item) async {
    final db = await instance.database;
    return db.update(
      'warehouse',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteWarehouseItem(int id) async {
    final db = await instance.database;
    return await db.delete('warehouse', where: 'id = ?', whereArgs: [id]);
  }

  // Delivery CRUD
  Future<int> insertDelivery(Delivery delivery) async {
    final db = await instance.database;
    return await db.insert('deliveries', delivery.toMap());
  }

  Future<List<Delivery>> getDeliveries() async {
    final db = await instance.database;
    final maps = await db.query('deliveries', orderBy: 'id DESC');
    return maps.map((map) => Delivery.fromMap(map)).toList();
  }

  Future<int> updateDelivery(Delivery delivery) async {
    final db = await instance.database;
    return db.update(
      'deliveries',
      delivery.toMap(),
      where: 'id = ?',
      whereArgs: [delivery.id],
    );
  }
}

// --- DATA MODELS ---

class WarehouseItem {
  int? id;
  String name;
  int quantity;

  WarehouseItem({this.id, required this.name, required this.quantity});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'quantity': quantity};
  }

  factory WarehouseItem.fromMap(Map<String, dynamic> map) {
    return WarehouseItem(
      id: map['id'],
      name: map['name'],
      quantity: map['quantity'],
    );
  }
}

class Delivery {
  int? id;
  String driverName;
  int itemId;
  String itemName;
  int packsLoaded;
  int packsDelivered;
  int packsReturned;
  String status;
  DateTime timestamp;

  Delivery({
    this.id,
    required this.driverName,
    required this.itemId,
    required this.itemName,
    required this.packsLoaded,
    this.packsDelivered = 0,
    this.packsReturned = 0,
    this.status = 'In Transit',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'driverName': driverName,
      'itemId': itemId,
      'itemName': itemName,
      'packsLoaded': packsLoaded,
      'packsDelivered': packsDelivered,
      'packsReturned': packsReturned,
      'status': status,
      'timestamp': timestamp.toIso8601String(), // Store as ISO String
    };
  }

  factory Delivery.fromMap(Map<String, dynamic> map) {
    return Delivery(
      id: map['id'],
      driverName: map['driverName'],
      itemId: map['itemId'],
      itemName: map['itemName'],
      packsLoaded: map['packsLoaded'],
      packsDelivered: map['packsDelivered'],
      packsReturned: map['packsReturned'],
      status: map['status'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

// --- MAIN SCREEN (STATE MANAGER) ---

class PosHomeScreen extends StatefulWidget {
  const PosHomeScreen({super.key});

  @override
  State<PosHomeScreen> createState() => _PosHomeScreenState();
}

class _PosHomeScreenState extends State<PosHomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;

  List<WarehouseItem> warehouseItems = [];
  List<Delivery> deliveries = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final items = await DatabaseHelper.instance.getWarehouseItems();
    final delivs = await DatabaseHelper.instance.getDeliveries();

    setState(() {
      warehouseItems = items;
      deliveries = delivs;
      _isLoading = false;
    });
  }

  // --- WAREHOUSE LOGIC ---
  Future<void> _saveWarehouseItem(
    WarehouseItem item, {
    bool isNew = false,
  }) async {
    if (isNew) {
      await DatabaseHelper.instance.insertWarehouseItem(item);
    } else {
      await DatabaseHelper.instance.updateWarehouseItem(item);
    }
    _refreshData();
  }

  Future<void> _deleteWarehouseItem(int id) async {
    await DatabaseHelper.instance.deleteWarehouseItem(id);
    _refreshData();
  }

  // --- DELIVERY LOGIC ---
  Future<void> _dispatchDelivery(Delivery delivery) async {
    WarehouseItem itemToDeduct = warehouseItems.firstWhere(
      (i) => i.id == delivery.itemId,
    );

    if (itemToDeduct.quantity < delivery.packsLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error: Insufficient warehouse stock for this dispatch.',
          ),
        ),
      );
      return;
    }

    // 1. Deduct quantity and update warehouse
    itemToDeduct.quantity -= delivery.packsLoaded;
    await DatabaseHelper.instance.updateWarehouseItem(itemToDeduct);

    // 2. Save delivery record
    await DatabaseHelper.instance.insertDelivery(delivery);

    _refreshData();
  }

  Future<void> _reconcileDelivery(int id, int delivered, int returned) async {
    Delivery deliveryToUpdate = deliveries.firstWhere((d) => d.id == id);

    deliveryToUpdate.packsDelivered = delivered;
    deliveryToUpdate.packsReturned = returned;
    deliveryToUpdate.status = 'Completed';

    await DatabaseHelper.instance.updateDelivery(deliveryToUpdate);

    _refreshData();
  }

  // --- BOTTOM SHEETS ---
  void _showWarehouseForm({WarehouseItem? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WarehouseFormModal(
        item: item,
        onSave: (newItem) {
          _saveWarehouseItem(newItem, isNew: item == null);
          Navigator.pop(ctx);
        },
        onDelete: item != null
            ? () {
                _deleteWarehouseItem(item.id!);
                Navigator.pop(ctx);
              }
            : null,
      ),
    );
  }

  void _showDispatchForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DispatchDeliveryModal(
        warehouseItems: warehouseItems,
        onDispatch: (delivery) {
          _dispatchDelivery(delivery);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showReconcileForm(Delivery delivery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReconcileModal(
        delivery: delivery,
        onSave: (id, delivered, returned) {
          _reconcileDelivery(id, delivered, returned);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget activeTab;

    if (_isLoading) {
      activeTab = const Center(child: CircularProgressIndicator());
    } else if (_currentIndex == 0) {
      activeTab = WarehouseTab(
        items: warehouseItems,
        onEdit: (item) => _showWarehouseForm(item: item),
      );
    } else if (_currentIndex == 1) {
      activeTab = DeliveriesTab(
        deliveries: deliveries,
        onReconcile: (delivery) => _showReconcileForm(delivery),
      );
    } else {
      activeTab = ReportsTab(
        deliveries: deliveries,
        warehouseItems: warehouseItems,
      );
    }

    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ice Admin POS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'SQLite Active',
              style: TextStyle(color: Colors.blue.shade200, fontSize: 12),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.blue.shade500,
              radius: 16,
              child: const Text(
                'A',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: activeTab,
      floatingActionButton: _currentIndex == 0 && !_isLoading
          ? FloatingActionButton(
              onPressed: () => _showWarehouseForm(),
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : _currentIndex == 1 && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _showDispatchForm,
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.local_shipping),
              label: const Text(
                'Dispatch',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.blue.shade600,
        unselectedItemColor: Colors.blueGrey.shade400,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Warehouse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Deliveries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

// --- TABS ---

class WarehouseTab extends StatelessWidget {
  final List<WarehouseItem> items;
  final Function(WarehouseItem) onEdit;

  const WarehouseTab({super.key, required this.items, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    int totalStock = items.fold(0, (sum, item) => sum + item.quantity);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Inventory',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalStock units',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              Icon(Icons.inventory_2, size: 48, color: Colors.blue.shade300),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'CURRENT STOCK',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade500,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Warehouse is empty.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...items.map(
            (item) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blueGrey.shade100),
              ),
              child: ListTile(
                onTap: () => onEdit(item),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('ID: ${item.id}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.quantity < 20
                            ? Colors.red.shade50
                            : Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${item.quantity}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: item.quantity < 20
                              ? Colors.red.shade700
                              : Colors.blueGrey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.blueGrey.shade300),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class DeliveriesTab extends StatelessWidget {
  final List<Delivery> deliveries;
  final Function(Delivery) onReconcile;

  const DeliveriesTab({
    super.key,
    required this.deliveries,
    required this.onReconcile,
  });

  @override
  Widget build(BuildContext context) {
    var activeDeliveries = deliveries
        .where((d) => d.status == 'In Transit')
        .toList();
    var completedDeliveries = deliveries
        .where((d) => d.status == 'Completed')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'IN TRANSIT (${activeDeliveries.length})',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade500,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (activeDeliveries.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.blueGrey.shade300,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.blueGrey.shade50,
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.local_shipping, size: 32, color: Colors.blueGrey),
                  SizedBox(height: 8),
                  Text(
                    'No active deliveries.',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
          )
        else
          ...activeDeliveries.map(
            (delivery) => GestureDetector(
              onTap: () => onReconcile(delivery),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: Colors.amber, width: 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          delivery.driverName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'In Transit',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            delivery.itemName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${delivery.packsLoaded} loaded',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Reconcile Delivery',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.blue.shade600,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'RECENT COMPLETED',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade500,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...completedDeliveries.map(
          (delivery) => Opacity(
            opacity: 0.7,
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blueGrey.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          delivery.driverName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Done',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      delivery.itemName,
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Loaded: ${delivery.packsLoaded}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Delivered: ${delivery.packsDelivered}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (delivery.packsReturned > 0)
                          Text(
                            'Returned: ${delivery.packsReturned}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ReportsTab extends StatelessWidget {
  final List<Delivery> deliveries;
  final List<WarehouseItem> warehouseItems;

  const ReportsTab({
    super.key,
    required this.deliveries,
    required this.warehouseItems,
  });

  @override
  Widget build(BuildContext context) {
    int totalDelivered = 0;
    int totalReturned = 0;
    int totalLoaded = 0;

    for (var d in deliveries) {
      totalLoaded += d.packsLoaded;
      if (d.status == 'Completed') {
        totalDelivered += d.packsDelivered;
        totalReturned += d.packsReturned;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'DAILY SUMMARY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade500,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Delivered',
                value: totalDelivered.toString(),
                valueColor: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Returned',
                value: totalReturned.toString(),
                valueColor: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: 'Total Dispatched',
          value: totalLoaded.toString(),
          valueColor: Colors.blue.shade700,
        ),
        const SizedBox(height: 24),
        Text(
          'INVENTORY STATUS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade500,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Column(
            children: warehouseItems.map((item) {
              return ListTile(
                title: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Text(
                  '${item.quantity}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: item.quantity < 20
                        ? Colors.red
                        : Colors.blueGrey.shade800,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey.shade500,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// --- MODALS (BOTTOM SHEETS) ---

class BottomSheetLayout extends StatelessWidget {
  final String title;
  final Widget child;

  const BottomSheetLayout({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.only(bottom: 24),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade50,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class WarehouseFormModal extends StatefulWidget {
  final WarehouseItem? item;
  final Function(WarehouseItem) onSave;
  final VoidCallback? onDelete;

  const WarehouseFormModal({
    super.key,
    this.item,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<WarehouseFormModal> createState() => _WarehouseFormModalState();
}

class _WarehouseFormModalState extends State<WarehouseFormModal> {
  late TextEditingController nameController;
  late TextEditingController qtyController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.item?.name ?? '');
    qtyController = TextEditingController(
      text: widget.item?.quantity.toString() ?? '',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetLayout(
      title: widget.item != null ? 'Edit Inventory Item' : 'Add New Item',
      child: Column(
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Item Name',
              border: OutlineInputBorder(),
              hintText: 'e.g. 5kg Block',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Current Quantity',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (widget.onDelete != null) ...[
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: widget.onDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty &&
                        qtyController.text.isNotEmpty) {
                      widget.onSave(
                        WarehouseItem(
                          id: widget
                              .item
                              ?.id, // ID is auto-generated by SQLite if null
                          name: nameController.text,
                          quantity: int.parse(qtyController.text),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Save Item',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DispatchDeliveryModal extends StatefulWidget {
  final List<WarehouseItem> warehouseItems;
  final Function(Delivery) onDispatch;

  const DispatchDeliveryModal({
    super.key,
    required this.warehouseItems,
    required this.onDispatch,
  });

  @override
  State<DispatchDeliveryModal> createState() => _DispatchDeliveryModalState();
}

class _DispatchDeliveryModalState extends State<DispatchDeliveryModal> {
  final driverController = TextEditingController();
  final packsController = TextEditingController();
  WarehouseItem? selectedItem;

  @override
  void initState() {
    super.initState();
    if (widget.warehouseItems.isNotEmpty) {
      selectedItem = widget.warehouseItems.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    int requestedPacks = int.tryParse(packsController.text) ?? 0;
    bool isExceeding =
        selectedItem != null && requestedPacks > selectedItem!.quantity;

    return BottomSheetLayout(
      title: 'Dispatch Driver',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: driverController,
            decoration: const InputDecoration(
              labelText: 'Driver Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<WarehouseItem>(
            decoration: const InputDecoration(
              labelText: 'Item to Load',
              border: OutlineInputBorder(),
            ),
            value: selectedItem,
            items: widget.warehouseItems
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text('${item.name} (Stock: ${item.quantity})'),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => selectedItem = val),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: packsController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Packs Loaded',
              border: OutlineInputBorder(),
            ),
          ),
          if (isExceeding)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.red, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Exceeds available stock',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (!isExceeding &&
                      driverController.text.isNotEmpty &&
                      packsController.text.isNotEmpty &&
                      selectedItem != null)
                  ? () {
                      widget.onDispatch(
                        Delivery(
                          driverName: driverController.text,
                          itemId: selectedItem!.id!,
                          itemName: selectedItem!.name,
                          packsLoaded: int.parse(packsController.text),
                          timestamp: DateTime.now(),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Confirm Dispatch',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReconcileModal extends StatefulWidget {
  final Delivery delivery;
  final Function(int id, int delivered, int returned) onSave;

  const ReconcileModal({
    super.key,
    required this.delivery,
    required this.onSave,
  });

  @override
  State<ReconcileModal> createState() => _ReconcileModalState();
}

class _ReconcileModalState extends State<ReconcileModal> {
  final deliveredController = TextEditingController();
  final returnedController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    int delivered = int.tryParse(deliveredController.text) ?? 0;
    int returned = int.tryParse(returnedController.text) ?? 0;
    int totalEntered = delivered + returned;
    bool hasWarning =
        (deliveredController.text.isNotEmpty &&
            returnedController.text.isNotEmpty) &&
        (totalEntered != widget.delivery.packsLoaded);

    return BottomSheetLayout(
      title: 'Reconcile Delivery',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver: ${widget.delivery.driverName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Item: ${widget.delivery.itemName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.delivery.packsLoaded} Packs Loaded',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: deliveredController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Packs Successfully Delivered',
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.green.shade500),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: returnedController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Packs Returned (Melted/Damaged)',
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red.shade500),
              ),
            ),
          ),
          if (hasWarning)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Warning: Entered total ($totalEntered) does not match Loaded (${widget.delivery.packsLoaded}).',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (deliveredController.text.isNotEmpty &&
                      returnedController.text.isNotEmpty &&
                      totalEntered <= widget.delivery.packsLoaded)
                  ? () =>
                        widget.onSave(widget.delivery.id!, delivered, returned)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Mark Completed',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
