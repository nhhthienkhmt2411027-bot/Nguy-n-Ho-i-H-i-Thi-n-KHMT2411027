import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' hide context;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Expense Manager',
      debugShowCheckedModeBanner: false,
      home: MainNavigator(),
    );
  }
}

// ============================================================================
// 1. DATABASE HELPER - XỬ LÝ ĐẦY ĐỦ CRUD (THÊM, SỬA, XÓA, ĐỌC)
// ============================================================================
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
  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('transactions', row);
  }

  // Đọc danh sách (Read)
  Future<List<Map<String, dynamic>>> readAllTransactions() async {
    final db = await instance.database;
    return await db.query('transactions', orderBy: 'id DESC');
  }

  // Cập nhật giao dịch (Update)
  Future<int> updateTransaction(Map<String, dynamic> row, int id) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      row,
      where: 'id = ?',
      whereArgs: [id],
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

// ============================================================================
// 2. MAIN NAVIGATOR - QUẢN LÝ ĐIỀU HƯỚNG VÀ TRUYỀN DỮ LIỆU
// ============================================================================
enum AppScreen { dashboard, form }

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  AppScreen currentScreen = AppScreen.dashboard;
  Map<String, dynamic>? selectedTransaction; // Dùng để truyền dữ liệu qua trang Sửa

  void _navigateToAdd() {
    setState(() {
      selectedTransaction = null; // Trống nghĩa là trạng thái Thêm
      currentScreen = AppScreen.form;
    });
  }

  void _navigateToEdit(Map<String, dynamic> transaction) {
    setState(() {
      selectedTransaction = transaction; // Có dữ liệu nghĩa là trạng thái Sửa
      currentScreen = AppScreen.form;
    });
  }

  void _navigateToDashboard() {
    setState(() {
      currentScreen = AppScreen.dashboard;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (currentScreen) {
      case AppScreen.dashboard:
        return DashboardScreen(
          onAddTransaction: _navigateToAdd,
          onEditTransaction: _navigateToEdit,
        );
      case AppScreen.form:
        return TransactionFormScreen(
          transactionData: selectedTransaction,
          onBack: _navigateToDashboard,
          onSaveSuccess: _navigateToDashboard,
        );
    }
  }
}

// ============================================================================
// 3. MÀN HÌNH DASHBOARD (LOAD VÀ HIỂN THỊ DỮ LIỆU)
// ============================================================================
class DashboardScreen extends StatefulWidget {
  final VoidCallback onAddTransaction;
  final Function(Map<String, dynamic>) onEditTransaction;

  const DashboardScreen({
    super.key,
    required this.onAddTransaction,
    required this.onEditTransaction,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  Map<String, dynamic> getCategoryConfig(String categoryName) {
    switch (categoryName) {
      case 'Ăn uống': return {'icon': Icons.restaurant, 'color': const Color(0xFFEC7A2E)};
      case 'Di chuyển': return {'icon': Icons.directions_car_filled, 'color': const Color(0xFF4294F7)};
      case 'Mua sắm': return {'icon': Icons.shopping_cart, 'color': const Color(0xFFA64BF4)};
      case 'Giáo dục': return {'icon': Icons.school, 'color': const Color(0xFF4C9A9A)};
      case 'Thu nhập': return {'icon': Icons.monetization_on, 'color': const Color(0xFF53A653)};
      default: return {'icon': Icons.category, 'color': const Color(0xFF888888)};
    }
  }

  // Hàm Refresh màn hình khi Xóa thành công
  void _refreshData() {
    setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFD),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          // Gọi lệnh Read DB để Load dữ liệu lên màn hình
            future: DatabaseHelper.instance.readAllTransactions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text("Đã xảy ra lỗi khi tải dữ liệu"));
              }

              final transactions = snapshot.data ?? [];

              int totalIncome = 0;
              int totalExpense = 0;
              for (var t in transactions) {
                int amt = t['amount'] as int;
                if (t['isIncome'] == 1) totalIncome += amt;
                else totalExpense += amt;
              }
              int balance = totalIncome - totalExpense;

              return Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header (Giữ thiết kế chuẩn)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 10, 20, 14),
                        child: Row(
                          children: [
                            Icon(Icons.account_circle, size: 30, color: Color(0xFF4268D6)),
                            SizedBox(width: 15),
                            Text('Quản lý thu chi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Khối số dư (Lấy từ code cũ)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: const LinearGradient(colors: [Color(0xFF4268D6), Color(0xFF2850C4)]),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('SỐ DƯ HIỆN TẠI', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 10),
                                    Text('${formatCurrency(balance)} đ', style: const TextStyle(fontSize: 29, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Tổng thu/chi
                              Row(
                                children: [
                                  Expanded(child: _buildSummaryCard('TỔNG THU', totalIncome, const Color(0xFF428A33), const Color(0xFFF1F7ED))),
                                  const SizedBox(width: 14),
                                  Expanded(child: _buildSummaryCard('TỔNG CHI', totalExpense, const Color(0xFFC23A3B), const Color(0xFFFDF1F1))),
                                ],
                              ),
                              const SizedBox(height: 22),

                              const Text('Giao dịch gần đây', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),

                              if (transactions.isEmpty)
                                const Center(child: Padding(padding: EdgeInsets.all(30), child: Text("Chưa có giao dịch nào"))),

                              // Danh sách giao dịch
                              if (transactions.isNotEmpty)
                                Container(
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEAECF0))),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: transactions.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF4F5F8), indent: 16, endIndent: 16),
                                    itemBuilder: (context, index) {
                                      final item = transactions[index];
                                      final isIncome = item['isIncome'] == 1;
                                      final config = getCategoryConfig(item['category']);
                                      final title = (item['note'] != null && item['note'].toString().isNotEmpty) ? item['note'] : item['category'];

                                      // Tính năng vuốt để xóa chuyên nghiệp (Swipe to Delete)
                                      return Dismissible(
                                        key: Key(item['id'].toString()),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 20),
                                          color: Colors.red.shade400,
                                          child: const Icon(Icons.delete, color: Colors.white),
                                        ),
                                        onDismissed: (direction) async {
                                          await DatabaseHelper.instance.deleteTransaction(item['id']);
                                          _refreshData();
                                        },
                                        // Nhấn vào giao dịch để SỬA
                                        child: InkWell(
                                          onTap: () => widget.onEditTransaction(item),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                            child: Row(
                                              children: [
                                                CircleAvatar(backgroundColor: config['color'], child: Icon(config['icon'], color: Colors.white, size: 20)),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                                                      const SizedBox(height: 4),
                                                      Text('${item['category']} • ${item['date']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  '${isIncome ? '+' : '-'}${formatCurrency(item['amount'])} đ',
                                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isIncome ? const Color(0xFF428A33) : const Color(0xFFC23A3B)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Nút nổi thêm giao dịch
                  Positioned(
                    right: 26, bottom: 20,
                    child: FloatingActionButton(
                      onPressed: widget.onAddTransaction,
                      backgroundColor: const Color(0xFF2850C4),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              );
            }
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, int amount, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Text('${formatCurrency(amount)} đ', style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. MÀN HÌNH FORM (XỬ LÝ CHUNG CẢ THÊM VÀ SỬA)
// ============================================================================
class TransactionFormScreen extends StatefulWidget {
  final Map<String, dynamic>? transactionData; // Nhận dữ liệu nếu là Sửa
  final VoidCallback onBack;
  final VoidCallback onSaveSuccess;

  const TransactionFormScreen({
    super.key,
    this.transactionData, // Nếu null => Thêm mới, nếu có data => Sửa
    required this.onBack,
    required this.onSaveSuccess
  });

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  bool isExpense = true;
  String selectedCategory = 'Ăn uống';
  late TextEditingController amountController;
  late TextEditingController noteController;

  // Biến lưu trữ ngày thực tế
  DateTime selectedDate = DateTime.now();

  final List<String> categories = ['Ăn uống', 'Di chuyển', 'Mua sắm', 'Nhà cửa', 'Thu nhập', 'Giáo dục'];

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController();
    noteController = TextEditingController();

    // Logic kiểm tra: Nếu có dữ liệu truyền vào -> Đây là tính năng SỬA
    if (widget.transactionData != null) {
      final data = widget.transactionData!;
      isExpense = data['isIncome'] == 0;
      selectedCategory = data['category'];
      amountController.text = data['amount'].toString();
      noteController.text = data['note'] ?? '';

      // Parse chuỗi ngày (dd/mm/yyyy) về đối tượng DateTime
      try {
        final parts = data['date'].toString().split('/');
        selectedDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } catch (e) {
        selectedDate = DateTime.now();
      }
    }
  }

  // Hàm chọn ngày chuyên nghiệp bằng UI chuẩn của hệ thống
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  // Hàm lưu dữ liệu
  void _saveDataToDB() async {
    // Validate form
    if (amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập số tiền!')));
      return;
    }

    int amount = int.tryParse(amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số tiền không hợp lệ!')));
      return;
    }

    // Format ngày về chuỗi dd/MM/yyyy
    String formattedDate = "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}";

    Map<String, dynamic> row = {
      'category': selectedCategory,
      'amount': amount,
      'isIncome': isExpense ? 0 : 1,
      'date': formattedDate,
      'note': noteController.text.trim(),
    };

    if (widget.transactionData != null) {
      // Đã có ID -> Cập nhật dữ liệu
      await DatabaseHelper.instance.updateTransaction(row, widget.transactionData!['id']);
    } else {
      // Chưa có -> Thêm mới
      await DatabaseHelper.instance.insertTransaction(row);
    }

    widget.onSaveSuccess();
  }

  @override
  Widget build(BuildContext context) {
    // Đổi Tiêu đề dựa vào việc Đang Thêm hay Đang Sửa
    final isEditMode = widget.transactionData != null;
    final String formattedDateStr = "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: widget.onBack),
        title: Text(isEditMode ? 'Sửa giao dịch' : 'Thêm giao dịch', style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh chọn Thu/Chi
              Container(
                  height: 45, padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                      children: [
                        Expanded(child: GestureDetector(onTap: () => setState(() => isExpense = true), child: Container(decoration: BoxDecoration(color: isExpense ? const Color(0xFFEF4444) : Colors.transparent, borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: Text('Chi tiêu', style: TextStyle(fontWeight: FontWeight.w600, color: isExpense ? Colors.white : Colors.grey))))),
                        Expanded(child: GestureDetector(onTap: () => setState(() => isExpense = false), child: Container(decoration: BoxDecoration(color: !isExpense ? const Color(0xFF53A653) : Colors.transparent, borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: Text('Thu nhập', style: TextStyle(fontWeight: FontWeight.w600, color: !isExpense ? Colors.white : Colors.grey)))))
                      ]
                  )
              ),
              const SizedBox(height: 22),

              const Text('Danh mục', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                  height: 50, padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEAECF0))),
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                          value: selectedCategory, isExpanded: true,
                          items: categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                          onChanged: (v) => setState(() => selectedCategory = v!)
                      )
                  )
              ),
              const SizedBox(height: 18),

              const Text('Số tiền (đ)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                  height: 50, padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEAECF0))),
                  child: TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Nhập số tiền', border: InputBorder.none))
              ),
              const SizedBox(height: 18),

              const Text('Ngày giao dịch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
// Nút Date Picker Chuyên nghiệp
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  height: 50, padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEAECF0))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formattedDateStr, style: const TextStyle(fontSize: 15)),
                      const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              const Text('Ghi chú', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                  height: 100, padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEAECF0))),
                  child: TextField(controller: noteController, maxLines: 3, decoration: const InputDecoration(hintText: 'Nhập ghi chú...', border: InputBorder.none))
              ),

              const Spacer(),
              SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                      onPressed: _saveDataToDB,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2850C4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text(isEditMode ? 'Lưu thay đổi' : 'Thêm giao dịch', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))
                  )
              ),
            ],
          ),
        ),
      ),
    );
  }
}