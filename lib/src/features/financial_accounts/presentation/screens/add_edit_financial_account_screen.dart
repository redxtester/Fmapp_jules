import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart';
import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart';
import 'package:fmapp/src/features/financial_accounts/presentation/state/financial_account_controller.dart';
import 'package:fmapp/src/features/sim_cards/presentation/state/sim_card_controller.dart';
import 'package:fmapp/src/features/sim_cards/data/models/sim_card.dart';
import 'package:fmapp/src/features/transactions/presentation/state/transaction_controller.dart'; // For currentBalanceProvider
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/core/presentation/widgets/custom_text_form_field.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';

class AddEditFinancialAccountScreen extends ConsumerStatefulWidget {
  final FinancialAccount? account;
  const AddEditFinancialAccountScreen({super.key, this.account});

  @override
  ConsumerState<AddEditFinancialAccountScreen> createState() => _AddEditFinancialAccountScreenState();
}

class _AddEditFinancialAccountScreenState extends ConsumerState<AddEditFinancialAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _accountNameController;
  late TextEditingController _accountIdentifierController;
  late TextEditingController _initialBalanceController;
  late TextEditingController _dateAddedController;

  AccountType _selectedAccountType = AccountType.bankAccount;
  String? _selectedLinkedSimSupabaseId;
  DateTime _selectedDateAdded = DateTime.now();

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    _accountNameController = TextEditingController(text: widget.account?.accountName ?? '');
    _accountIdentifierController = TextEditingController(text: widget.account?.accountIdentifier ?? '');
    _initialBalanceController = TextEditingController(text: widget.account?.initialBalance.toStringAsFixed(2) ?? '0.00');
    _selectedAccountType = widget.account?.accountType ?? AccountType.bankAccount;
    _selectedLinkedSimSupabaseId = widget.account?.linkedSimSupabaseId;
    _selectedDateAdded = widget.account?.dateAdded ?? DateTime.now();
    _dateAddedController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(_selectedDateAdded));
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountIdentifierController.dispose();
    _initialBalanceController.dispose();
    _dateAddedController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDateAdded,
      firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDateAdded) {
      setState(() { _selectedDateAdded = picked; _dateAddedController.text = DateFormat('yyyy-MM-dd').format(_selectedDateAdded); });
    }
  }

  Future<void> _saveAccount() async {
    if (_formKey.currentState!.validate()) {
      final currentUserId = ref.read(authControllerProvider).value?.id;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: User not authenticated.')));
        return;
      }
      final now = DateTime.now();
      final initialBalance = double.tryParse(_initialBalanceController.text.trim()) ?? 0.0;
      final accountData = FinancialAccount(
        isarId: widget.account?.isarId ?? Isar.autoIncrement, supabaseId: widget.account?.supabaseId,
        userId: currentUserId, accountName: _accountNameController.text.trim(),
        accountIdentifier: _accountIdentifierController.text.trim().isNotEmpty ? _accountIdentifierController.text.trim() : null,
        accountType: _selectedAccountType, linkedSimSupabaseId: _selectedLinkedSimSupabaseId,
        initialBalance: initialBalance, dateAdded: _selectedDateAdded,
        currency: widget.account?.currency ?? 'ETB', isArchived: widget.account?.isArchived ?? false,
        createdAt: widget.account?.createdAt ?? now, updatedAt: now,
      );
      try {
        final notifier = ref.read(financialAccountControllerProvider.notifier);
        if (_isEditing) {
          await notifier.updateFinancialAccount(accountData);
        } else {
          await notifier.addFinancialAccount(accountData);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account ${_isEditing ? "updated" : "added"}!')));
          Navigator.of(context).pop();
        }
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'))); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(financialAccountControllerProvider).isLoading;
    final simCardsAsyncValue = ref.watch(simCardsStreamProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: 'ETB ');

    // Get current balance if editing
    final currentBalance = _isEditing && widget.account?.supabaseId != null
        ? ref.watch(currentBalanceProvider(widget.account!.supabaseId!))
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Account' : 'Add New Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CustomTextFormField(controller: _accountNameController, labelText: 'Account Name*', prefixIcon: Icons.account_balance_outlined, validator: (v) => (v==null||v.isEmpty)?'Required':null),
              CustomTextFormField(controller: _accountIdentifierController, labelText: 'Account Identifier', prefixIcon: Icons.perm_identity_outlined),
              DropdownButtonFormField<AccountType>(
                value: _selectedAccountType,
                decoration: InputDecoration(labelText: 'Account Type*', prefixIcon: Icon(Icons.category_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), filled: true, fillColor: Colors.white),
                items: AccountType.values.map((t) => DropdownMenuItem<AccountType>(value: t, child: Text(t.name))).toList(),
                onChanged: (v) => setState(() => _selectedAccountType = v!),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              CustomTextFormField(controller: _initialBalanceController, labelText: 'Initial Balance*', keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))], prefixIcon: Icons.attach_money_outlined, validator: (v) => (v==null||v.isEmpty)?'Required':(double.tryParse(v)==null?'Invalid num':null)),
              if (_isEditing && currentBalance != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("Current Balance: ${currencyFormat.format(currentBalance)}",
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
              CustomTextFormField(controller: _dateAddedController, labelText: 'Date Account Added*', readOnly: true, onTap: () => _selectDate(context), prefixIcon: Icons.calendar_today_outlined, validator: (v) => (v==null||v.isEmpty)?'Required':null),
              simCardsAsyncValue.when(
                data: (simCards) {
                    if (simCards.isEmpty) return const SizedBox.shrink();
                    return DropdownButtonFormField<String?>(
                        value: _selectedLinkedSimSupabaseId,
                        decoration: InputDecoration(labelText: 'Link to SIM (Optional)', prefixIcon: Icon(Icons.sim_card_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), filled: true, fillColor: Colors.white),
                        hint: const Text('Select SIM'), isExpanded: true,
                        items: [const DropdownMenuItem<String?>(value: null, child: Text('None')), ...simCards.map((s) => DropdownMenuItem<String?>(value: s.supabaseId, child: Text('${s.simNickname} (${s.phoneNumber})'))).toList()],
                        onChanged: (v) => setState(() => _selectedLinkedSimSupabaseId = v),
                    );
                },
                loading: () => const Text("Loading SIMs..."),
                error: (e,s) => Text('Error SIMs: $e'),
              ),
              const SizedBox(height: 24),
              isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton.icon(icon: Icon(_isEditing ? Icons.save_alt : Icons.add_circle_outline), onPressed: _saveAccount, label: Text(_isEditing ? 'Save Changes' : 'Add Account')),
            ],
          ),
        ),
      ),
    );
  }
}
