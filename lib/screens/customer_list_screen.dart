import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/customer_controller.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsyncValue = ref.watch(customerControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers CRM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(customerControllerProvider.notifier).reload(),
          ),
        ],
      ),
      body: customersAsyncValue.when(
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(child: Text('No customers found. Database is currently empty.'));
          }
          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return ListTile(
                title: Text(customer.name),
                subtitle: Text(customer.email),
                trailing: Text(customer.status),
                leading: const CircleAvatar(child: Icon(Icons.person)),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Failed to connect to backend.\nEnsure Node.js is running and IP matches.\nError Details:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}
