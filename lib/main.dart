import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const StockInventoryApp());
}

class StockInventoryApp extends StatelessWidget {
  const StockInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Inventory Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2457A6)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const InventoryHomePage(),
    );
  }
}

const List<String> stockCategories = [
  'Electronics',
  'Stationery',
  'Hardware',
  'Grocery',
];

class InventoryHomePage extends StatefulWidget {
  const InventoryHomePage({super.key});

  @override
  State<InventoryHomePage> createState() => _InventoryHomePageState();
}

class _InventoryHomePageState extends State<InventoryHomePage> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _reorderController = TextEditingController();

  String? _selectedCategory;
  bool _isSaving = false;

  final _searchController = TextEditingController();
  String _selectedFilterCategory = 'All';
  bool _lowStockOnly = false;
  bool _ascending = true;

  CollectionReference<Map<String, dynamic>> get _stockCollection =>
      FirebaseFirestore.instance.collection('stockItems');

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _reorderController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? _validateSku(String? value) {
    final input = (value ?? '').trim();
    if (!RegExp(r'^STK-\d{3}$').hasMatch(input)) {
      return 'Enter SKU in the format STK-101.';
    }
    return null;
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().length < 3) {
      return 'Item name must contain at least 3 characters.';
    }
    return null;
  }

  String? _validateInteger(String? value, String fieldName) {
    final input = (value ?? '').trim();
    final number = int.tryParse(input);
    if (input.isEmpty) return '$fieldName is required.';
    if (number == null) return '$fieldName must be a whole number.';
    if (number < 0) return '$fieldName cannot be negative.';
    return null;
  }

  String? _validatePrice(String? value) {
    final input = (value ?? '').trim();
    if (input.isEmpty) return 'Unit price is required.';
    final number = double.tryParse(input);
    if (number == null || number <= 0) {
      return 'Enter a valid price greater than RM 0.';
    }
    return null;
  }

  Future<void> _saveItem() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _stockCollection.add({
        'sku': _skuController.text.trim().toUpperCase(),
        'itemName': _nameController.text.trim(),
        'category': _selectedCategory,
        'quantity': int.parse(_quantityController.text.trim()),
        'unitPrice': double.parse(_priceController.text.trim()),
        'reorderLevel': int.parse(_reorderController.text.trim()),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _formKey.currentState!.reset();
      _skuController.clear();
      _nameController.clear();
      _quantityController.clear();
      _priceController.clear();
      _reorderController.clear();
      setState(() => _selectedCategory = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock item saved successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save item. Please try again. ($error)')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final keyword = _searchController.text.trim().toLowerCase();

    final filtered = documents.where((document) {
      final data = document.data();
      final sku = (data['sku'] ?? '').toString().toLowerCase();
      final name = (data['itemName'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString();
      final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
      final reorderLevel = (data['reorderLevel'] as num?)?.toInt() ?? 0;

      final matchesKeyword =
          keyword.isEmpty || name.contains(keyword) || sku.contains(keyword);
      final matchesCategory = _selectedFilterCategory == 'All' ||
          category == _selectedFilterCategory;
      final matchesLowStock = !_lowStockOnly || quantity <= reorderLevel;

      return matchesKeyword && matchesCategory && matchesLowStock;
    }).toList();

    filtered.sort((a, b) {
      final quantityA = (a.data()['quantity'] as num?)?.toInt() ?? 0;
      final quantityB = (b.data()['quantity'] as num?)?.toInt() ?? 0;
      return _ascending
          ? quantityA.compareTo(quantityB)
          : quantityB.compareTo(quantityA);
    });
    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedFilterCategory = 'All';
      _lowStockOnly = false;
      _ascending = true;
    });
  }

  Widget _buildEntryForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add stock item', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _skuController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'SKU',
                  hintText: 'STK-101',
                  prefixIcon: Icon(Icons.qr_code),
                ),
                validator: _validateSku,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: stockCategories
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
                validator: (value) =>
                    value == null ? 'Please select a category.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) => _validateInteger(value, 'Quantity'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Unit price (RM)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: _validatePrice,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reorderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reorder level',
                  prefixIcon: Icon(Icons.warning_amber_outlined),
                ),
                validator: (value) => _validateInteger(value, 'Reorder level'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveItem,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search and filter', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by item name or SKU',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Clear keyword',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedFilterCategory,
              decoration: const InputDecoration(labelText: 'Category filter'),
              items: ['All', ...stockCategories]
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedFilterCategory = value ?? 'All'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Low-stock items only'),
              subtitle: const Text('Quantity is less than or equal to reorder level'),
              value: _lowStockOnly,
              onChanged: (value) => setState(() => _lowStockOnly = value),
            ),
            Row(
              children: [
                const Text('Sort quantity:'),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Ascending')),
                      ButtonSegment(value: false, label: Text('Descending')),
                    ],
                    selected: {_ascending},
                    onSelectionChanged: (selection) =>
                        setState(() => _ascending = selection.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Clear Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stockCollection.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Could not load inventory. Check your connection and Firestore rules.'),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final documents = snapshot.data?.docs ?? [];
        if (documents.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No stock items saved yet. Add your first item above.')),
            ),
          );
        }

        final visibleItems = _filterItems(documents);
        if (visibleItems.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No matching stock items. Try changing or clearing the filters.')),
            ),
          );
        }

        return Column(
          children: visibleItems.map((document) {
            final data = document.data();
            final sku = (data['sku'] ?? '').toString();
            final name = (data['itemName'] ?? '').toString();
            final category = (data['category'] ?? '').toString();
            final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
            final price = (data['unitPrice'] as num?)?.toDouble() ?? 0;
            final reorder = (data['reorderLevel'] as num?)?.toInt() ?? 0;
            final isLow = quantity <= reorder;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isLow
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    isLow ? Icons.warning_amber : Icons.inventory_2,
                    color: isLow
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '$sku  •  $category\nQty: $quantity  •  Reorder: $reorder  •  RM ${price.toStringAsFixed(2)}',
                ),
                isThreeLine: true,
                trailing: isLow
                    ? const Chip(label: Text('Low stock'))
                    : const Icon(Icons.check_circle_outline),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Inventory Manager'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildEntryForm(),
                  const SizedBox(height: 20),
                  _buildSearchControls(),
                  const SizedBox(height: 12),
                  Text('Saved inventory', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  _buildInventoryList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
