import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart';
import 'package:fmapp/src/features/financial_accounts/data/models/financial_account.dart';
import 'package:fmapp/src/features/financial_accounts/presentation/state/financial_account_controller.dart';
import 'package:fmapp/src/features/sim_cards/presentation/state/sim_card_controller.dart'; // For SIM card list
import 'package:fmapp/src/features/sim_cards/data/models/sim_card.dart'; // For SimCard type
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/core/presentation/widgets/custom_text_form_field.dart';
import 'package:isar/isar.dart'; // For Id type
import 'package:intl/intl.dart'; // For date formatting

class AddEditFinancialAccountScreen extends ConsumerStatefulWidget {
  final FinancialAccount? account; // Null if adding, populated if editing

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
  String? _selectedLinkedSimSupabaseId; // Store Supabase ID of the linked SIM
  DateTime _selectedDateAdded = DateTime.now();

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    _accountNameController = TextEditingController(text: widget.account?.accountName ?? '');
    _accountIdentifierController = TextEditingController(text: widget.account?.accountIdentifier ?? '');
    _initialBalanceController = TextEditingController(
        text: widget.account?.initialBalance.toStringAsFixed(2) ?? '0.00');

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
      context: context,
      initialDate: _selectedDateAdded,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)), // Allow future date for scheduled start? PRD implies past/present
    );
    if (picked != null && picked != _selectedDateAdded) {
      setState(() {
        _selectedDateAdded = picked;
        _dateAddedController.text = DateFormat('yyyy-MM-dd').format(_selectedDateAdded);
      });
    }
  }

  Future<void> _saveAccount() async {
    if (_formKey.currentState!.validate()) {
      final currentUserId = ref.read(authControllerProvider).value?.id;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not authenticated.')),
        );
        return;
      }

      final now = DateTime.now();
      final initialBalance = double.tryParse(_initialBalanceController.text.trim()) ?? 0.0;

      final accountData = FinancialAccount(
        isarId: widget.account?.isarId ?? Isar.autoIncrement,
        supabaseId: widget.account?.supabaseId,
        userId: currentUserId,
        accountName: _accountNameController.text.trim(),
        accountIdentifier: _accountIdentifierController.text.trim().isNotEmpty
            ? _accountIdentifierController.text.trim()
            : null,
        accountType: _selectedAccountType,
        linkedSimSupabaseId: _selectedLinkedSimSupabaseId,
        initialBalance: initialBalance,
        dateAdded: _selectedDateAdded, // From date picker
        currency: widget.account?.currency ?? 'ETB', // Keep existing or default
        isArchived: widget.account?.isArchived ?? false,
        createdAt: widget.account?.createdAt ?? now,
        updatedAt: now,
      );

      try {
        final notifier = ref.read(financialAccountControllerProvider.notifier);
        if (_isEditing) {
          await notifier.updateFinancialAccount(accountData);
        } else {
          await notifier.addFinancialAccount(accountData);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Account ${_isEditing ? "updated" : "added"} successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving account: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(financialAccountControllerProvider).isLoading;
    // Fetch SIM cards for the dropdown
    final simCardsAsyncValue = ref.watch(simCardsStreamProvider);


    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Account' : 'Add New Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CustomTextFormField(
                controller: _accountNameController,
                labelText: 'Account Name*',
                hintText: 'e.g., CBE Savings, My Wallet',
                prefixIcon: Icons.account_balance_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Account name is required';
                  return null;
                },
              ),
              CustomTextFormField(
                controller: _accountIdentifierController,
                labelText: 'Account Identifier',
                hintText: 'e.g., Account No., Phone No. (Optional)',
                prefixIcon: Icons.perm_identity_outlined,
              ),
              DropdownButtonFormField<AccountType>(
                value: _selectedAccountType,
                decoration: InputDecoration(
                  labelText: 'Account Type*',
                  prefixIcon: Icon(Icons.category_outlined),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                   filled: true,
                   fillColor: Colors.white,
                ),
                items: AccountType.values.map((AccountType type) {
                  return DropdownMenuItem<AccountType>(
                    value: type,
                    child: Text(type.name), // Using .name for display
                  );
                }).toList(),
                onChanged: (AccountType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedAccountType = newValue;
                    });
                  }
                },
                validator: (value) => value == null ? 'Account type is required' : null,
              ),
              const SizedBox(height: 8),
              CustomTextFormField(
                controller: _initialBalanceController,
                labelText: 'Initial Balance*',
                hintText: '0.00',
                prefixIcon: Icons.attach_money_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Initial balance is required';
                  if (double.tryParse(value) == null) return 'Enter a valid number';
                  return null;
                },
              ),
               CustomTextFormField(
                controller: _dateAddedController,
                labelText: 'Date Account Added*',
                hintText: 'Select Date',
                prefixIcon: Icons.calendar_today_outlined,
                readOnly: true,
                onTap: () => _selectDate(context),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Date added is required';
                  return null;
                },
              ),
              simCardsAsyncValue.when(
                data: (simCards) {
                  if (simCards.isEmpty) return const SizedBox.shrink(); // No SIMs to link
                  return DropdownButtonFormField<String?>(
                    value: _selectedLinkedSimSupabaseId,
                    decoration: InputDecoration(
                      labelText: 'Link to SIM Card (Optional)',
                      prefixIcon: Icon(Icons.sim_card_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    hint: const Text('Select SIM Card'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null, // Option to not link any SIM
                        child: Text('None'),
                      ),
                      ...simCards.map((SimCard sim) {
                        return DropdownMenuItem<String?>(
                          value: sim.supabaseId, // Store supabaseId
                          child: Text('${sim.simNickname} (${sim.phoneNumber})'),
                        );
                      }).toList(),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedLinkedSimSupabaseId = newValue;
                      });
                    },
                  );
                },
                loading: () => const Padding(padding: EdgeInsets.all(8.0), child: Text("Loading SIMs...")),
                error: (err, stack) => Padding(padding: const EdgeInsets.all(8.0), child: Text('Error loading SIMs: $err')),
              ),
              const SizedBox(height: 24),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: Icon(_isEditing ? Icons.save_alt : Icons.add_circle_outline),
                      onPressed: _saveAccount,
                      label: Text(_isEditing ? 'Save Changes' : 'Add Account'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
