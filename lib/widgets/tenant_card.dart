import 'package:flutter/material.dart';
import '../data/models/tenant_model.dart';

class TenantCard extends StatelessWidget {
  final TenantModel tenant;

  const TenantCard({
    super.key,
    required this.tenant,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text(
          tenant.name ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tenant.domain != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Domain: ${tenant.domain}'),
              ),
            if (tenant.phone != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Phone: ${tenant.phone}'),
              ),
            if (tenant.email != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Email: ${tenant.email}'),
              ),
            if (tenant.city != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('City: ${tenant.city}'),
              ),
          ],
        ),
      ),
    );
  }
}

