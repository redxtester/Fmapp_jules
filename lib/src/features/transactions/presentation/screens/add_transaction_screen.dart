import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart';
import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart';
import 'package:fmapp/src/features/financial_accounts/presentation/state/financial_account_controller.dart';
import 'package:fmapp/src/features/transactions/data/models/transaction.dart';
import 'package:fmapp/src/features/transactions/presentation/state/transaction_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/core/presentation/widgets/custom_text_form_field.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:uuid/uuid.dart'; // For client-side ID generation if needed before repo

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? transaction; // Null if adding, populated if editing (editing not in this P0 step)
  final String? initialAccountId; // Optional pre-selected account

  const AddTransactionScreen({super.key, this.transaction, this.initialAccountId});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountController;
  late TextEditingController _dateController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _payerSenderController;
  late TextEditingController _payeeReceiverController;
  late TextEditingController _referenceController;

  TransactionType _selectedTransactionType = TransactionType.expenseDebit;
  String? _selectedAccountId; // Supabase ID of the FinancialAccount
  DateTime _selectedDate = DateTime.now();

  bool get _isEditing => widget.transaction != null; // Not used in P0

  @override
  void initState() {
    super.initState();
    // Initialize controllers, prefill if editing (not for P0)
    _amountController = TextEditingController(text: widget.transaction?.amount.toStringAsFixed(2) ?? '');
    _descriptionController = TextEditingController(text: widget.transaction?.descriptionNotes ?? '');
    _categoryController = TextEditingController(text: widget.transaction?.categoryTag ?? '');
    _payerSenderController = TextEditingController(text: widget.transaction?.payerSenderRaw ?? '');
    _payeeReceiverController = TextEditingController(text: widget.transaction?.payeeReceiverRaw ?? '');
    _referenceController = TextEditingController(text: widget.transaction?.referenceNumber ?? '');

    _selectedTransactionType = widget.transaction?.transactionType ?? TransactionType.expenseDebit;
    _selectedDate = widget.transaction?.transactionDate ?? DateTime.now();
    _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(_selectedDate));

    _selectedAccountId = widget.transaction?.affectedAccountId ?? widget.initialAccountId;

    // If initialAccountId is provided and no account is selected yet, try to validate it
    // by checking against available accounts.
    // This is important if navigating from a specific account's view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accounts = ref.read(financialAccountsStreamProvider(false)).value ?? [];
      if (widget.initialAccountId != null && accounts.any((acc) => acc.supabaseId == widget.initialAccountId)) {
        if (_selectedAccountId == null) { // only set if not already set (e.g. by editing mode)
             setState(() {
                _selectedAccountId = widget.initialAccountId;
             });
        }
      } else if (accounts.isNotEmpty && _selectedAccountId == null) {
        // Default to first account if no initial account is provided or valid
        // setState(() {
        //   _selectedAccountId = accounts.first.supabaseId;
        // });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _payerSenderController.dispose();
    _payeeReceiverController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)), // Allow future for scheduled? PRD not specific.
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      final currentUserId = ref.read(authControllerProvider).value?.id;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not authenticated.')),
        );
        return;
      }
      if (_selectedAccountId == null) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an account.')),
        );
        return;
      }

      final now = DateTime.now();
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

      final newTransaction = Transaction(
        // isarId and supabaseId will be handled by repository/isar/supabase
        userId: currentUserId,
        affectedAccountId: _selectedAccountId!,
        transactionDate: _selectedDate,
        amount: amount,
        transactionType: _selectedTransactionType,
        currency: 'ETB', // Default from PRD
        descriptionNotes: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        categoryTag: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : null,
        payerSenderRaw: _payerSenderController.text.trim().isNotEmpty ? _payerSenderController.text.trim() : null,
        payeeReceiverRaw: _payeeReceiverController.text.trim().isNotEmpty ? _payeeReceiverController.text.trim() : null,
        referenceNumber: _referenceController.text.trim().isNotEmpty ? _referenceController.text.trim() : null,
        createdAt: _isEditing ? widget.transaction!.createdAt : now,
        updatedAt: now,
        supabaseId: _isEditing ? widget.transaction!.supabaseId : null, // Repo handles new ID
      );

      try {
        final notifier = ref.read(transactionControllerProvider.notifier);
        if (_isEditing) {
          // await notifier.updateTransaction(newTransaction); // Not for P0
        } else {
          await notifier.addTransaction(newTransaction);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transaction ${_isEditing ? "updated" : "added"} successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving transaction: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(transactionControllerProvider).isLoading;
    final accountsAsyncValue = ref.watch(financialAccountsStreamProvider(false)); // Only active accounts

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add New Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Account Selector
              accountsAsyncValue.when(
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return const Center(child: Text("No financial accounts available. Please add an account first."));
                  }
                  // Ensure _selectedAccountId is valid or nullify if not in list
                  if (_selectedAccountId != null && !accounts.any((acc) => acc.supabaseId == _selectedAccountId)) {
                      _selectedAccountId = null;
                  }

                  return DropdownButtonFormField<String?>(
                    value: _selectedAccountId,
                    decoration: InputDecoration(
                      labelText: 'Affected Account*',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      filled: true, fillColor: Colors.white,
                    ),
                    hint: const Text('Select Account'),
                    isExpanded: true,
                    items: accounts.map((FinancialAccount acc) {
                      return DropdownMenuItem<String?>(
                        value: acc.supabaseId,
                        child: Text('${acc.accountName} (${acc.accountType.name})'),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedAccountId = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Please select an account' : null,
                  );
                },
                loading: () => const Text("Loading accounts..."),
                error: (err, stack) => Text('Error loading accounts: $err'),
              ),
              const SizedBox(height: 8),

              // Transaction Type Selector
              DropdownButtonFormField<TransactionType>(
                value: _selectedTransactionType,
                decoration: InputDecoration(
                  labelText: 'Transaction Type*',
                  prefixIcon: Icon(Icons.swap_vert_circle_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  filled: true, fillColor: Colors.white,
                ),
                items: TransactionType.values.map((TransactionType type) {
                  return DropdownMenuItem<TransactionType>(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (TransactionType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedTransactionType = newValue;
                    });
                  }
                },
                 validator: (value) => value == null ? 'Transaction type is required' : null,
              ),
              const SizedBox(height: 8),

              CustomTextFormField(
                controller: _amountController,
                labelText: 'Amount*',
                hintText: '0.00',
                prefixIcon: Icons.monetization_on_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Amount is required';
                  final double? amount = double.tryParse(value);
                  if (amount == null) return 'Enter a valid number';
                  if (amount <= 0) return 'Amount must be greater than zero';
                  return null;
                },
              ),
              CustomTextFormField(
                controller: _dateController,
                labelText: 'Transaction Date*',
                hintText: 'Select Date',
                prefixIcon: Icons.calendar_today_outlined,
                readOnly: true,
                onTap: () => _selectDate(context),
                validator: (value) => (value == null || value.isEmpty) ? 'Date is required' : null,
              ),
              CustomTextFormField(
                controller: _descriptionController,
                labelText: 'Description/Notes',
                hintText: 'e.g., Groceries, Salary for May',
                prefixIcon: Icons.description_outlined,
                maxLines: 2,
              ),
              CustomTextFormField(
                controller: _categoryController,
                labelText: 'Category/Tag (Optional)',
                hintText: 'e.g., Food, Transport, Income',
                prefixIcon: Icons.label_outline,
              ),
              CustomTextFormField(
                controller: _payerSenderController,
                labelText: 'Payer/Sender (Optional)',
                hintText: 'e.g., John Doe, Company XYZ',
                prefixIcon: Icons.person_pin_circle_outlined,
              ),
              CustomTextFormField(
                controller: _payeeReceiverController,
                labelText: 'Payee/Receiver (Optional)',
                hintText: 'e.g., Supermarket, Client A',
                prefixIcon: Icons.storefront_outlined,
              ),
              CustomTextFormField(
                controller: _referenceController,
                labelText: 'Reference Number (Optional)',
                hintText: 'e.g., Invoice #123, Order ID',
                prefixIcon: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 24),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: Icon(_isEditing ? Icons.save_alt : Icons.add_circle_outline),
                      onPressed: _saveTransaction,
                      label: Text(_isEditing ? 'Save Changes' : 'Add Transaction'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
