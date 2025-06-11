import 'package:fmapp/src/features/friends/data/models/friend.dart';
import 'package:fmapp/src/features/friends/presentation/screens/add_edit_friend_screen.dart';
import 'package:fmapp/src/features/friends/presentation/state/friend_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fmapp/src/core/presentation/widgets/loading_indicator.dart';

class FriendListScreen extends ConsumerWidget {
  const FriendListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsyncValue = ref.watch(friendsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing friends...')),
              );
              try {
                await ref.read(friendControllerProvider.notifier).syncFriends();
                if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Friends synced successfully!')),
                    );
                }
              } catch (e) {
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error syncing friends: $e')),
                    );
                 }
              }
            },
            tooltip: 'Sync with Cloud',
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddEditFriendScreen()),
              );
            },
            tooltip: 'Add New Friend',
          ),
        ],
      ),
      body: friendsAsyncValue.when(
        data: (friends) {
          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No friends found.', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Tap the "+" icon to add your first friend.', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                   ElevatedButton.icon(
                     icon: const Icon(Icons.person_add),
                     label: const Text("Add Friend"),
                     onPressed: (){
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const AddEditFriendScreen()),
                        );
                     }
                   )
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColorLight,
                    child: Text(friend.friendName.isNotEmpty ? friend.friendName[0].toUpperCase() : 'F'),
                  ),
                  title: Text(friend.friendName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(friend.friendPhoneNumber ?? 'No phone number'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => AddEditFriendScreen(friend: friend)),
                        );
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirm Delete'),
                            content: Text('Are you sure you want to delete friend "${friend.friendName}"? This might affect associated loans (not yet implemented).'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && friend.supabaseId != null) {
                          try {
                            await ref.read(friendControllerProvider.notifier).deleteFriend(friend.supabaseId!, friend.isarId);
                            if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Friend "${friend.friendName}" deleted.')),
                                );
                            }
                          } catch (e) {
                             if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error deleting friend: $e. Check if friend is used in loans.')),
                                );
                             }
                          }
                        } else if (friend.supabaseId == null && context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('Error: Cannot delete. Friend not synced.')),
                             );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                  onTap: () {
                    // TODO: Navigate to a friend detail screen or loan list for this friend later
                    print("Tapped on friend: ${friend.friendName}");
                  },
                ),
              );
            },
          );
        },
        loading: () => const LoadingIndicator(message: 'Loading friends...'),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              const Text('Error loading friends:', style: TextStyle(fontSize: 18, color: Colors.red)),
              Padding(padding: const EdgeInsets.all(8.0), child: Text(error.toString(), textAlign: TextAlign.center)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => ref.invalidate(friendsStreamProvider), child: const Text("Retry"))
            ],
          ),
        ),
      ),
    );
  }
}
