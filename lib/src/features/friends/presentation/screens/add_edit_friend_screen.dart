import 'package:fmapp/src/features/auth/presentation/state/auth_controller.dart';
import 'package:fmapp/src/features/friends/data/models/friend.dart';
import 'package:fmapp/src/features/friends/presentation/state/friend_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/core/presentation/widgets/custom_text_form_field.dart';
import 'package:isar/isar.dart'; // For Id type

class AddEditFriendScreen extends ConsumerStatefulWidget {
  final Friend? friend; // Null if adding, populated if editing

  const AddEditFriendScreen({super.key, this.friend});

  @override
  ConsumerState<AddEditFriendScreen> createState() => _AddEditFriendScreenState();
}

class _AddEditFriendScreenState extends ConsumerState<AddEditFriendScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  bool get _isEditing => widget.friend != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.friend?.friendName ?? '');
    _phoneController = TextEditingController(text: widget.friend?.friendPhoneNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveFriend() async {
    if (_formKey.currentState!.validate()) {
      final currentUserId = ref.read(authControllerProvider).value?.id;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not authenticated.')),
        );
        return;
      }

      final now = DateTime.now();
      final friendData = Friend(
        isarId: widget.friend?.isarId ?? Isar.autoIncrement,
        supabaseId: widget.friend?.supabaseId,
        userId: currentUserId,
        friendName: _nameController.text.trim(),
        friendPhoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        createdAt: widget.friend?.createdAt ?? now,
        updatedAt: now,
      );

      try {
        final notifier = ref.read(friendControllerProvider.notifier);
        if (_isEditing) {
          await notifier.updateFriend(friendData);
        } else {
          await notifier.addFriend(friendData);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Friend ${_isEditing ? "updated" : "added"} successfully!')),
          );
          Navigator.of(context).pop(); // Go back after save
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving friend: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(friendControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Friend' : 'Add New Friend'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CustomTextFormField(
                controller: _nameController,
                labelText: 'Friend Name*',
                hintText: 'e.g., John Doe',
                prefixIcon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Friend name is required';
                  return null;
                },
              ),
              CustomTextFormField(
                controller: _phoneController,
                labelText: 'Phone Number (Optional)',
                hintText: 'e.g., 0911xxxxxx',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                // No specific validation for optional phone, can add format check if desired
              ),
              const SizedBox(height: 24),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      icon: Icon(_isEditing ? Icons.save_alt : Icons.add_circle_outline),
                      onPressed: _saveFriend,
                      label: Text(_isEditing ? 'Save Changes' : 'Add Friend'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
