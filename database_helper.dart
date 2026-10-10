import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_manager.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount INTEGER NOT NULL,
        isIncome INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT
      )
    ''');

    // Dữ liệu mẫu ban đầu
    await db.insert('transactions', {'category': 'Ăn uống', 'amount': 50000, 'isIncome': 0, 'date': '03/09/2026', 'note': 'Ăn trưa'});
    await db.insert('transactions', {'category': 'Thu nhập', 'amount': 8000000, 'isIncome': 1, 'date': '01/09/2026', 'note': 'Lương tháng 9'});
  }

  // Thêm giao dịch (Create)
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
  }

  // Đọc danh sách (Read)
  Future<List<TransactionModel>> readAllTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'id DESC');
    return result.map((row) => TransactionModel.fromMap(row)).toList();
  }

  // Cập nhật giao dịch (Update)
  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // Xóa giao dịch (Delete)
  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
