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
// import 'package:uuid/uuid.dart'; // Not strictly needed here as repo handles ID

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? transactionToEdit; // Renamed for clarity
  final String? initialAccountId;

  const AddTransactionScreen({super.key, this.transactionToEdit, this.initialAccountId});

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
  String? _selectedAffectedAccountId; // Source account for transfers
  DateTime _selectedDate = DateTime.now();

  // New state for internal transfers
  bool _isInternalTransfer = false;
  String? _selectedCounterpartyAccountId; // Destination account for transfers

  bool get _isEditing => widget.transactionToEdit != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transactionToEdit;

    _amountController = TextEditingController(text: tx?.amount.toStringAsFixed(2) ?? '');
    _descriptionController = TextEditingController(text: tx?.descriptionNotes ?? '');
    _categoryController = TextEditingController(text: tx?.categoryTag ?? '');
    _payerSenderController = TextEditingController(text: tx?.payerSenderRaw ?? '');
    _payeeReceiverController = TextEditingController(text: tx?.payeeReceiverRaw ?? '');
    _referenceController = TextEditingController(text: tx?.referenceNumber ?? '');

    _selectedTransactionType = tx?.transactionType ?? TransactionType.expenseDebit;
    _selectedDate = tx?.transactionDate ?? DateTime.now();
    _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(_selectedDate));

    _selectedAffectedAccountId = tx?.affectedAccountId ?? widget.initialAccountId;
    _isInternalTransfer = tx?.isInternalTransfer ?? false;
    _selectedCounterpartyAccountId = tx?.counterpartyAccountId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accounts = ref.read(financialAccountsStreamProvider(false)).value ?? [];
      if (widget.initialAccountId != null && accounts.any((acc) => acc.supabaseId == widget.initialAccountId)) {
        if (_selectedAffectedAccountId == null) {
             setState(() => _selectedAffectedAccountId = widget.initialAccountId);
        }
      }
      // Ensure counterparty account is valid if editing an internal transfer
      if (_isEditing && _isInternalTransfer && _selectedCounterpartyAccountId != null) {
          if (!accounts.any((acc) => acc.supabaseId == _selectedCounterpartyAccountId)) {
              _selectedCounterpartyAccountId = null; // Reset if not found (e.g. account deleted)
          }
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose(); _dateController.dispose(); _descriptionController.dispose();
    _categoryController.dispose(); _payerSenderController.dispose(); _payeeReceiverController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDate,
      firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() { _selectedDate = picked; _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate); });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUserId = ref.read(authControllerProvider).value?.id;
    if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: User not authenticated.')));
        return;
    }
    if (_selectedAffectedAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an affected account.')));
        return;
    }
    if (_isInternalTransfer && _selectedCounterpartyAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a destination account for the transfer.')));
        return;
    }
    if (_isInternalTransfer && _selectedAffectedAccountId == _selectedCounterpartyAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source and destination accounts cannot be the same for a transfer.')));
        return;
    }


    final now = DateTime.now();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final transactionTypeForRecord = _isInternalTransfer ? TransactionType.expenseDebit : _selectedTransactionType;


    final transactionData = Transaction(
      userId: currentUserId,
      affectedAccountId: _selectedAffectedAccountId!,
      transactionDate: _selectedDate,
      amount: amount,
      transactionType: transactionTypeForRecord,
      currency: 'ETB',
      descriptionNotes: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      categoryTag: _isInternalTransfer ? "Internal Transfer" : (_categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : null),
      payerSenderRaw: _isInternalTransfer ? "Self" : (_payerSenderController.text.trim().isNotEmpty ? _payerSenderController.text.trim() : null),
      payeeReceiverRaw: _isInternalTransfer ? "Self" : (_payeeReceiverController.text.trim().isNotEmpty ? _payeeReceiverController.text.trim() : null),
      referenceNumber: _referenceController.text.trim().isNotEmpty ? _referenceController.text.trim() : null,
      isInternalTransfer: _isInternalTransfer,
      counterpartyAccountId: _isInternalTransfer ? _selectedCounterpartyAccountId : null,
      createdAt: _isEditing ? widget.transactionToEdit!.createdAt : now,
      updatedAt: now,
      supabaseId: _isEditing ? widget.transactionToEdit!.supabaseId : null,
    );

    try {
      final notifier = ref.read(transactionControllerProvider.notifier);
      String successMessage;
      if (_isEditing) {
        // await notifier.updateTransaction(transactionData, widget.transactionToEdit!.affectedAccountId); // Pass old for balance
        successMessage = "Transaction updated (Not implemented in P0)";
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
         return;
      } else {
        await notifier.addTransaction(transactionData);
        successMessage = "Transaction added successfully!";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(transactionControllerProvider).isLoading;
    final accountsAsyncValue = ref.watch(financialAccountsStreamProvider(false));

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SwitchListTile(
                title: const Text('Internal Transfer?'),
                value: _isInternalTransfer,
                onChanged: (bool value) {
                  setState(() {
                    _isInternalTransfer = value;
                    if (!value) _selectedCounterpartyAccountId = null;
                  });
                },
                secondary: const Icon(Icons.compare_arrows_outlined),
              ),
              const SizedBox(height: 8),

              accountsAsyncValue.when(
                data: (accounts) {
                  if (accounts.isEmpty) return const Center(child: Text("No accounts. Add one first."));

                  if (_selectedAffectedAccountId != null && !accounts.any((acc) => acc.supabaseId == _selectedAffectedAccountId)) {
                      _selectedAffectedAccountId = null;
                  }

                  return DropdownButtonFormField<String?>(
                    value: _selectedAffectedAccountId,
                    decoration: InputDecoration(
                      labelText: _isInternalTransfer ? 'From Account*' : 'Affected Account*',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      filled: true, fillColor: Colors.white,
                    ),
                    hint: const Text('Select Account'),
                    isExpanded: true,
                    items: accounts.map((acc) => DropdownMenuItem<String?>(value: acc.supabaseId, child: Text(acc.accountName))).toList(),
                    onChanged: (val) => setState(() => _selectedAffectedAccountId = val),
                    validator: (val) => val == null ? 'Required' : null,
                  );
                },
                loading: () => const Text("Loading accounts..."),
                error: (e,s) => Text('Error accounts: $e'),
              ),
              const SizedBox(height: 8),

              if (_isInternalTransfer)
                accountsAsyncValue.when(
                  data: (accounts) {
                    if (accounts.isEmpty) return const SizedBox.shrink();
                    final destinationOptions = accounts.where((acc) => acc.supabaseId != _selectedAffectedAccountId).toList();

                    if (_selectedCounterpartyAccountId != null && !destinationOptions.any((acc) => acc.supabaseId == _selectedCounterpartyAccountId)) {
                        _selectedCounterpartyAccountId = null;
                    }

                    return DropdownButtonFormField<String?>(
                      value: _selectedCounterpartyAccountId,
                      decoration: InputDecoration(
                        labelText: 'To Account*',
                        prefixIcon: Icon(Icons.arrow_forward_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        filled: true, fillColor: Colors.white,
                      ),
                      hint: const Text('Select Destination Account'),
                      isExpanded: true,
                      items: destinationOptions.map((acc) => DropdownMenuItem<String?>(value: acc.supabaseId, child: Text(acc.accountName))).toList(),
                      onChanged: (val) => setState(() => _selectedCounterpartyAccountId = val),
                      validator: (val) => _isInternalTransfer && val == null ? 'Destination account required' : null,
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e,s) => const SizedBox.shrink(),
                ),
              if (_isInternalTransfer) const SizedBox(height: 8),

              if (!_isInternalTransfer)
                DropdownButtonFormField<TransactionType>(
                  value: _selectedTransactionType,
                  decoration: InputDecoration(
                    labelText: 'Transaction Type*',
                    prefixIcon: Icon(Icons.swap_vert_circle_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    filled: true, fillColor: Colors.white,
                  ),
                  items: TransactionType.values.map((type) => DropdownMenuItem<TransactionType>(value: type, child: Text(type.displayName))).toList(),
                  onChanged: (val) => setState(() => _selectedTransactionType = val!),
                  validator: (val) => !_isInternalTransfer && val == null ? 'Type required' : null,
                ),
              if (!_isInternalTransfer) const SizedBox(height: 8),

              CustomTextFormField(controller: _amountController, labelText: 'Amount*', keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))], prefixIcon: Icons.monetization_on_outlined, validator: (v){ if(v==null||v.isEmpty)return 'Amount Required'; final d=double.tryParse(v); if(d==null)return 'Invalid Number'; if(d<=0)return 'Must be > 0'; return null;}),
              CustomTextFormField(controller: _dateController, labelText: 'Transaction Date*', readOnly: true, onTap: () => _selectDate(context), prefixIcon: Icons.calendar_today_outlined, validator: (v) => (v==null||v.isEmpty)?'Date Required':null),
              CustomTextFormField(controller: _descriptionController, labelText: 'Description/Notes', maxLines: 2, prefixIcon: Icons.description_outlined),

              if (!_isInternalTransfer)
                CustomTextFormField(controller: _categoryController, labelText: 'Category (Optional)', prefixIcon: Icons.label_outline),

              if (!_isInternalTransfer)
                CustomTextFormField(controller: _payerSenderController, labelText: 'Payer/Sender (Optional)', prefixIcon: Icons.person_pin_circle_outlined),
              if (!_isInternalTransfer)
                CustomTextFormField(controller: _payeeReceiverController, labelText: 'Payee/Receiver (Optional)', prefixIcon: Icons.storefront_outlined),

              CustomTextFormField(controller: _referenceController, labelText: 'Reference Number (Optional)', prefixIcon: Icons.receipt_long_outlined),
              const SizedBox(height: 24),
              isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton.icon(icon: Icon(_isEditing ? Icons.save_alt : Icons.add_circle_outline), onPressed: _saveTransaction, label: Text(_isEditing ? 'Save Changes' : 'Add Transaction')),
            ],
          ),
        ),
      ),
    );
  }
}
