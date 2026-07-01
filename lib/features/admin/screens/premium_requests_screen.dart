import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';

class PremiumRequestsScreen extends StatefulWidget {
  const PremiumRequestsScreen({super.key});

  @override
  State<PremiumRequestsScreen> createState() => _PremiumRequestsScreenState();
}

class _PremiumRequestsScreenState extends State<PremiumRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('premium_requests')
          .select('*')
          .order('created_at', ascending: false);
      setState(() {
        _requests = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Load failed: $e"), backgroundColor: Colors.red[800]),
        );
      }
    }
  }

  Future<void> _updateStatus(int requestId, String status) async {
    try {
      await Supabase.instance.client
          .from('premium_requests')
          .update({'status': status}).eq('id', requestId);

      if (status == 'approved') {
        final request = _requests.firstWhere((r) => r['id'] == requestId);
        await Supabase.instance.client
            .from('user_subscriptions')
            .upsert({
              'user_id': request['user_id'],
              'is_active': true,
              'provider': 'manual',
              'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
            });
      }

      _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? "Premium approved!" : "Request rejected"),
            backgroundColor: status == 'approved' ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red[800]),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (_filter == 'all') return _requests;
    return _requests.where((r) => r['status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _requests.where((r) => r['status'] == 'pending').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Premium Requests", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (pendingCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 12, top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("$pendingCount", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip("Pending", "pending", Colors.orange),
                const SizedBox(width: 8),
                _filterChip("Approved", "approved", Colors.green),
                const SizedBox(width: 8),
                _filterChip("Rejected", "rejected", Colors.red),
                const SizedBox(width: 8),
                _filterChip("All", "all", Colors.grey),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[600]),
                            const SizedBox(height: 12),
                            Text("No ${_filter == 'all' ? '' : _filter} requests", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRequests,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredRequests.length,
                          itemBuilder: (context, index) => _requestCard(_filteredRequests[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, Color color) {
    final isSelected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: isSelected ? color : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            )),
          ),
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final status = request['status'] ?? 'pending';
    final statusColor = status == 'approved' ? Colors.green : status == 'rejected' ? Colors.red : Colors.orange;
    final createdAt = DateTime.tryParse(request['created_at'] ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withValues(alpha: 0.2),
                child: Icon(
                  status == 'approved' ? Icons.check_rounded : status == 'rejected' ? Icons.close_rounded : Icons.hourglass_top_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request['user_name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(request['user_id'].toString().substring(0, 8) + "...", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Text("TXN: ${request['transaction_id'] ?? 'N/A'}", style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}",
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),

          // Action Buttons (only for pending)
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _updateStatus(request['id'], 'approved'),
                    icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                    label: const Text("Approve", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _updateStatus(request['id'], 'rejected'),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    label: const Text("Reject", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
