import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../main.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PremiumPurchaseScreen extends ConsumerStatefulWidget {
  const PremiumPurchaseScreen({super.key});

  @override
  ConsumerState<PremiumPurchaseScreen> createState() => _PremiumPurchaseScreenState();
}

class _PremiumPurchaseScreenState extends ConsumerState<PremiumPurchaseScreen> {
  final _nameController = TextEditingController();
  final _txnController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _submitted = false;
  String _selectedMethod = 'easypaisa';

  @override
  void dispose() {
    _nameController.dispose();
    _txnController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final user = ref.read(authProvider).user;
      if (user == null) {
        _showError("Pehle login karein!");
        return;
      }

      await Supabase.instance.client.from('premium_requests').insert({
        'user_id': user.id,
        'user_name': _nameController.text.trim(),
        'transaction_id': _txnController.text.trim(),
      });

      if (mounted) {
        setState(() => _submitted = true);
      }
    } catch (e) {
      _showError("Submit failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[800], behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bgColor = isDark ? AppColors.background : Colors.grey[50];
    final cardColor = isDark ? AppColors.surface : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Get Premium", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _submitted ? _buildSuccessView(isDark, cardColor, textColor) : _buildFormView(isDark, cardColor, textColor),
    );
  }

  Widget _buildSuccessView(bool isDark, Color cardColor, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 70),
            ),
            const SizedBox(height: 24),
            Text("Request Sent!", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              "Aapki premium request admin ko bhej di gayi hai.\nJaise hi admin approve karega, aapka premium unlock ho jayega.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Admin se approval ka wait karein. Aapko notification mil jayega.",
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Back to Home", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView(bool isDark, Color cardColor, Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B2FBE), Color(0xFF9B59B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.purpleAccent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 48),
                const SizedBox(height: 8),
                const Text("Premium Plan", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("1 month access to all premium wallpapers", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Payment Method
          Text("Payment Method", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _paymentMethodChip("easypaisa", "Easypaisa", Icons.account_balance_wallet_rounded, Colors.green),
              const SizedBox(width: 10),
              _paymentMethodChip("jazzcash", "JazzCash", Icons.phone_android_rounded, Colors.red),
            ],
          ),
          const SizedBox(height: 20),

          // Account Number
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Send Payment To:", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _selectedMethod == 'easypaisa' ? Icons.account_balance_wallet_rounded : Icons.phone_android_rounded,
                      color: _selectedMethod == 'easypaisa' ? Colors.green : Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedMethod == 'easypaisa' ? "Easypaisa" : "JazzCash", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          const Text("03135157773", style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: '03135157773'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Number copied!"), behavior: SnackBarBehavior.floating),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_money_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Text("Rs. 1,200 / month", style: TextStyle(color: Colors.amber[700], fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Form
          Text("Your Details", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: "Your Full Name",
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.person_rounded, color: Colors.grey),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (val) => val!.isEmpty ? "Name required" : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _txnController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: "Transaction ID",
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    hintText: "e.g. 1234567890",
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.receipt_long_rounded, color: Colors.grey),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (val) => val!.isEmpty ? "Transaction ID required" : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Payment karne ke baad transaction ID yahan daalein. Admin approve karega toh premium unlock ho jayega.",
                    style: TextStyle(color: Colors.grey[500], fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
              onPressed: _isSubmitting ? null : _submitRequest,
              child: _isSubmitting
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Submit Request", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _paymentMethodChip(String value, String label, IconData icon, Color color) {
    final isSelected = _selectedMethod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? color : Colors.grey.withValues(alpha: 0.2), width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: isSelected ? color : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
