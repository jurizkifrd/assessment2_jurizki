import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(MyApp());
}

class TukangOjek {
  int? id;
  String nama;
  String nopol;

  TukangOjek({this.id, required this.nama, required this.nopol});

  Map<String, dynamic> toMap() {
    return {'id': id, 'nama': nama, 'nopol': nopol};
  }
}

class Transaksi {
  int? id;
  int tukangOjekId;
  int harga;
  String timestamp;

  Transaksi(
      {this.id, required this.tukangOjekId, required this.harga, required this.timestamp});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tukangOjekId': tukangOjekId,
      'harga': harga,
      'timestamp': timestamp
    };
  }
}

class DatabaseHelper {
  static Database? _database;
  static const String dbName = 'opangatimin.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initializeDatabase();
    return _database!;
  }

  Future<Database> initializeDatabase() async {
    WidgetsFlutterBinding.ensureInitialized();
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, dbName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE tukangojek(
            id INTEGER PRIMARY KEY,
            nama TEXT,
            nopol TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE transaksi(
            id INTEGER PRIMARY KEY,
            tukangojek_id INTEGER,
            harga INTEGER,
            timestamp TEXT,
            FOREIGN KEY (tukangojek_id) REFERENCES tukangojek(id)
          )
        ''');
      },
    );
  }

  Future<int> insertTukangOjek(TukangOjek tukangOjek) async {
    final db = await database;
    return await db.insert('tukangojek', tukangOjek.toMap());
  }

  Future<int> insertTransaksi(Transaksi transaksi) async {
    final db = await database;
    return await db.insert('transaksi', transaksi.toMap());
  }

  Future<int> getTotalOrdersForToday(int tukangOjekId) async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = await db.rawQuery(
        'SELECT COUNT(*) FROM transaksi WHERE tukangojek_id = ? AND timestamp >= ?',
        [tukangOjekId, today.toIso8601String()]);
    int? count = Sqflite.firstIntValue(result);
    return count ?? 0;
  }

  Future<int> getOmzetForToday(int tukangOjekId) async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = await db.rawQuery(
        'SELECT SUM(harga) FROM transaksi WHERE tukangojek_id = ? AND timestamp >= ?',
        [tukangOjekId, today.toIso8601String()]);
    int? omzet = Sqflite.firstIntValue(result);
    return omzet ?? 0;
  }

  Future<List<TukangOjek>> getAllTukangOjek() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tukangojek');
    return List.generate(maps.length, (i) {
      return TukangOjek(
        id: maps[i]['id'],
        nama: maps[i]['nama'],
        nopol: maps[i]['nopol'],
      );
    });
  }
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OPANGATIMIN App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DatabaseHelper databaseHelper = DatabaseHelper();
  late List<TukangOjek> tukangOjekList;
  bool sortByName = false; // state to toggle sorting by name

  @override
  void initState() {
    super.initState();
    updateTukangOjekList();
  }


  Future<void> updateTukangOjekList() async {
    final tukangOjeks = await databaseHelper.getAllTukangOjek();
    setState(() {
      tukangOjekList = tukangOjeks;
    });
  }

  Future<void> toggleSort() async {
    setState(() {
      sortByName = !sortByName;
      // Sort the tukang ojek list based on name or total orders (you need to implement this logic)
      // Example: if (sortByName) tukangOjekList.sort((a, b) => a.nama.compareTo(b.nama));
      // else tukangOjekList.sort((a, b) => getOrderCount(a.id!).compareTo(getOrderCount(b.id!)));
    });
  }

  Future<int> getOrderCount(int tukangOjekId) async {
    return databaseHelper.getTotalOrdersForToday(tukangOjekId);
  }

  Future<int> getOmzet(int tukangOjekId) async {
    return databaseHelper.getOmzetForToday(tukangOjekId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daftar Tukang Ojek'),
      ),
      body: FutureBuilder<List<TukangOjek>>(
        future: databaseHelper.getAllTukangOjek(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasData) {
            List<TukangOjek> tukangOjekList = snapshot.data!;
            return ListView.builder(
              itemCount: tukangOjekList.length,
              itemBuilder: (context, index) {
                return FutureBuilder<int>(
                  future: getOrderCount(tukangOjekList[index].id!),
                  builder: (context, orderSnapshot) {
                    if (orderSnapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        title: Text(tukangOjekList[index].nama),
                        subtitle: Text('Loading...'),
                      );
                    } else if (orderSnapshot.hasData) {
                      int totalOrders = orderSnapshot.data!;
                      return FutureBuilder<int>(
                        future: getOmzet(tukangOjekList[index].id!),
                        builder: (context, omzetSnapshot) {
                          if (omzetSnapshot.connectionState == ConnectionState.waiting) {
                            return ListTile(
                              title: Text(tukangOjekList[index].nama),
                              subtitle: Text('Loading...'),
                            );
                          } else if (omzetSnapshot.hasData) {
                            int omzet = omzetSnapshot.data!;
                            return ListTile(
                              title: Text(tukangOjekList[index].nama),
                              subtitle: Text('Jumlah order: $totalOrders | Omzet: $omzet'),
                            );
                          } else {
                            return ListTile(
                              title: Text(tukangOjekList[index].nama),
                              subtitle: Text('Error loading data'),
                            );
                          }
                        },
                      );
                    } else {
                      return ListTile(
                        title: Text(tukangOjekList[index].nama),
                        subtitle: Text('Error loading data'),
                      );
                    }
                  },
                );
              },
            );
          } else {
            return Center(child: Text('No data available'));
          }
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTukangOjekPage(),
                ),
              ).then((_) => updateTukangOjekList());
            },
            tooltip: 'Tambah Tukang Ojek',
            child: Icon(Icons.add),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTransaksiPage(),
                ),
              ).then((_) => updateTukangOjekList());
            },
            tooltip: 'Tambah Transaksi',
            child: Icon(Icons.add),
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              // Tambahkan fungsi atau perintah untuk tombol ketiga di sini
              // Contoh: untuk mereset urutan atau menghapus pengurutan yang telah dilakukan sebelumnya
              setState(() {
                sortByName = false; // Reset pengurutan
              });
            },
            tooltip: 'Reset Urutan Tampilan',
            child: Icon(Icons.refresh), // Icon untuk mereset urutan
          ),
        ],
      ),
    );
  }
}



class AddTukangOjekPage extends StatefulWidget {
  @override
  _AddTukangOjekPageState createState() => _AddTukangOjekPageState();
}

class _AddTukangOjekPageState extends State<AddTukangOjekPage> {
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nopolController = TextEditingController();
  DatabaseHelper databaseHelper = DatabaseHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tambah Tukang Ojek'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _namaController,
              decoration: InputDecoration(labelText: 'Nama'),
            ),
            TextField(
              controller: _nopolController,
              decoration: InputDecoration(labelText: 'Nomor Polisi'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                TukangOjek tukangOjek = TukangOjek(
                  nama: _namaController.text,
                  nopol: _nopolController.text,
                );
                databaseHelper.insertTukangOjek(tukangOjek);
                Navigator.pop(context);
              },
              child: Text('Simpan'),
            ),
          ],

        ),
      ),
    );
  }
}

class AddTransaksiPage extends StatefulWidget {
  @override
  _AddTransaksiPageState createState() => _AddTransaksiPageState();
}

class _AddTransaksiPageState extends State<AddTransaksiPage> {
  late TextEditingController _hargaController = TextEditingController();
  late DatabaseHelper databaseHelper = DatabaseHelper();
  late List<TukangOjek> tukangOjekList = []; // Deklarasikan variabel tukangOjekList

  @override
  void initState() {
    super.initState();
    fetchTukangOjek();
  }

  Future<void> fetchTukangOjek() async {
    List<TukangOjek> tukangOjeks = await databaseHelper.getAllTukangOjek();
    setState(() {
      tukangOjekList = tukangOjeks;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tambah Transaksi'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>( // Ubah tipe data menjadi int sesuai dengan tipe ID
              value: null, // Atur value atau ubah menjadi nullable jika tidak ada yang dipilih
              items: tukangOjekList.map((tukangOjek) {
                return DropdownMenuItem<int>(
                  value: tukangOjek.id!,
                  child: Text(tukangOjek.nama),
                );
              }).toList(),
              onChanged: (value) {
                // Lakukan sesuatu saat value berubah (jika diperlukan)
              },
              decoration: InputDecoration(
                labelText: 'Tukang Ojek',
                border: OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: _hargaController,
              decoration: InputDecoration(labelText: 'Harga'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                Transaksi transaksi = Transaksi(
                  tukangOjekId: 1, // Ganti dengan ID yang dipilih dari Dropdown
                  harga: int.parse(_hargaController.text),
                  timestamp: DateTime.now().toIso8601String(),
                );
                await databaseHelper.insertTransaksi(transaksi);
                Navigator.pop(context);
              },
              child: Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
