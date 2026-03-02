import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subCategoryController = TextEditingController();
  final _picController = TextEditingController();
  final _tagsInputController = TextEditingController();
  final _tagsFocusNode = FocusNode();
  List<String> _tags = [];

  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategory;
  String? _selectedSubCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingCategories = true;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();

    // If editing, populate fields with existing data
    if (widget.transaction != null) {
      final txn = widget.transaction!;
      _amountController.text = txn.amount.toString();
      _descriptionController.text = txn.description ?? '';
      _picController.text = txn.pic ?? '';
      _tags = List<String>.from(txn.tags ?? []);
      _selectedType = txn.type;
      _selectedDate = txn.date;
      // Category and subcategory will be set after loading categories
    }
  }

  Future<void> _loadCategories() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getLookups('POS_KAS');

      if (response.statusCode == 200) {
        final dynamic data = response.data;
        List<Map<String, dynamic>> categoryList = [];

        // Handle different response structures
        if (data is Map) {
          if (data['data'] != null) {
            categoryList = (data['data'] as List)
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();
          }
        } else if (data is List) {
          categoryList = data
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }

        // sort categories by 'value' field alphabetically
        categoryList.sort((a, b) {
          final valA = a['value']?.toString() ?? '';
          final valB = b['value']?.toString() ?? '';
          return valA.compareTo(valB);
        });

        setState(() {
          _categories = categoryList;

          if (widget.transaction != null) {
            // When editing, match category by value (text) to find the correct ID
            final txnCategory = widget.transaction!.category;
            final matchedCat = categoryList.firstWhere(
              (cat) =>
                  cat['value']?.toString() == txnCategory ||
                  cat['id']?.toString() == txnCategory,
              orElse: () => categoryList.isNotEmpty ? categoryList[0] : {},
            );
            _selectedCategory = matchedCat['id']?.toString();

            // Load sub-categories for the matched category
            if (matchedCat['sub_lookup'] != null &&
                matchedCat['sub_lookup'] is List) {
              _subCategories = (matchedCat['sub_lookup'] as List)
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();

              final txnSubCategory = widget.transaction!.subCategory;
              if (txnSubCategory != null) {
                final matchedSub = _subCategories.firstWhere(
                  (sub) =>
                      sub['value']?.toString() == txnSubCategory ||
                      sub['id']?.toString() == txnSubCategory,
                  orElse: () => {},
                );
                _selectedSubCategory = matchedSub['id']?.toString();
              } else if (_subCategories.isNotEmpty) {
                _selectedSubCategory = _subCategories[0]['id']?.toString();
              }
            }
          } else {
            if (_categories.isNotEmpty) {
              // Default to "Umum", fallback to first item
              final umum = _categories.firstWhere(
                (cat) => cat['value']?.toString() == 'Umum',
                orElse: () => _categories[0],
              );
              _selectedCategory = umum['id']?.toString();
            }
          }

          _isLoadingCategories = false;
        });
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      setState(() {
        _isLoadingCategories = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _subCategoryController.dispose();
    _picController.dispose();
    _tagsInputController.dispose();
    _tagsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addTagFromInput() {
    final raw = _tagsInputController.text.trim().replaceAll(',', '').trim();
    if (raw.isNotEmpty && !_tags.contains(raw)) {
      setState(() {
        _tags.add(raw);
      });
    }
    _tagsInputController.clear();
    _tagsFocusNode.requestFocus();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      // Get category text (value) from the selected category ID
      final categoryText = _categories
              .firstWhere(
                (cat) => cat['id']?.toString() == _selectedCategory,
                orElse: () => {'value': _selectedCategory ?? ''},
              )['value']
              ?.toString() ??
          '';

      // Get subcategory text if from dropdown, otherwise use text input
      final subCategoryText = _subCategories.isNotEmpty
          ? (_selectedSubCategory != null
              ? _subCategories
                  .firstWhere(
                    (sub) => sub['id']?.toString() == _selectedSubCategory,
                    orElse: () => {'value': _selectedSubCategory ?? ''},
                  )['value']
                  ?.toString()
              : null)
          : (_subCategoryController.text.trim().isEmpty
              ? null
              : _subCategoryController.text.trim());

      final transaction = Transaction(
        title: '', // Not needed in backend model
        amount: double.parse(_amountController.text.trim()),
        type: _selectedType,
        category: categoryText,
        subCategory: subCategoryText,
        date: _selectedDate,
        description: _descriptionController.text.trim(),
        pic: _picController.text.trim().isEmpty
            ? null
            : _picController.text.trim(),
        tags: _tags.isEmpty ? null : _tags,
      );

      final provider = context.read<TransactionProvider>();
      final bool success;

      // Check if editing or adding
      if (widget.transaction != null) {
        success = await provider.updateTransaction(
          widget.transaction!.id!,
          transaction,
        );
      } else {
        success = await provider.addTransaction(transaction);
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.transaction != null
                  ? 'Transaction updated successfully!'
                  : 'Transaction added successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.error ??
                  (widget.transaction != null
                      ? 'Failed to update transaction'
                      : 'Failed to add transaction'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction != null ? 'Edit Transaction' : 'Add Transaction',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction Type Selector
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_downward, size: 18),
                              SizedBox(width: 8),
                              Text('Expense'),
                            ],
                          ),
                          selected: _selectedType == TransactionType.expense,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedType = TransactionType.expense;
                              });
                            }
                          },
                          selectedColor: Colors.red.shade100,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_upward, size: 18),
                              SizedBox(width: 8),
                              Text('Income'),
                            ],
                          ),
                          selected: _selectedType == TransactionType.income,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedType = TransactionType.income;
                              });
                            }
                          },
                          selectedColor: Colors.green.shade100,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value.trim());
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              _isLoadingCategories
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _categories.map((category) {
                        final code = category['id']?.toString() ?? '';
                        final name = category['value']?.toString() ?? code;
                        return DropdownMenuItem<String>(
                          value: code,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                          _selectedSubCategory = null;

                          // Load sub-categories if available
                          final selectedCat = _categories.firstWhere(
                            (cat) => cat['id']?.toString() == value,
                            orElse: () => {},
                          );

                          if (selectedCat['sub_lookup'] != null &&
                              selectedCat['sub_lookup'] is List) {
                            _subCategories = (selectedCat['sub_lookup'] as List)
                                .map(
                                  (item) =>
                                      Map<String, dynamic>.from(item as Map),
                                )
                                .toList();
                            if (_subCategories.isNotEmpty) {
                              _selectedSubCategory =
                                  _subCategories[0]['id']?.toString();
                            }
                          } else {
                            _subCategories = [];
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
              const SizedBox(height: 16),

              // Sub Category Field/Dropdown
              if (_subCategories.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedSubCategory,
                  decoration: const InputDecoration(
                    labelText: 'Sub Category',
                    prefixIcon: Icon(Icons.subdirectory_arrow_right),
                  ),
                  items: _subCategories.map((subCat) {
                    final code = subCat['id']?.toString() ?? '';
                    final name = subCat['value']?.toString() ?? code;
                    return DropdownMenuItem<String>(
                      value: code,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSubCategory = value;
                    });
                  },
                )
              else
                TextFormField(
                  controller: _subCategoryController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Sub Category (Optional)',
                    hintText: 'No sub-categories available',
                    prefixIcon: Icon(Icons.subdirectory_arrow_right),
                  ),
                ),
              const SizedBox(height: 16),

              // PIC Field
              TextFormField(
                controller: _picController,
                decoration: const InputDecoration(
                  labelText: 'PIC (Optional)',
                  hintText: 'Person in charge',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),

              // Tags Field
              // Tags Chip Input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Existing chips
                  if (_tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _tags.map((tag) {
                          return Chip(
                            label: Text(
                              '#$tag',
                              style: const TextStyle(fontSize: 13),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _tags.remove(tag);
                              });
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  // Text input for new tag
                  TextFormField(
                    controller: _tagsInputController,
                    focusNode: _tagsFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Tags (Optional)',
                      hintText: 'Type a tag and press Enter',
                      prefixIcon: const Icon(Icons.label_outline),
                      helperText: 'Press Enter or comma to add a tag',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addTagFromInput,
                      ),
                    ),
                    onFieldSubmitted: (_) => _addTagFromInput(),
                    onChanged: (value) {
                      // Auto-add on comma
                      if (value.endsWith(',')) {
                        _addTagFromInput();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date *',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Enter description',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              Consumer<TransactionProvider>(
                builder: (context, provider, child) {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: provider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Add Transaction',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
