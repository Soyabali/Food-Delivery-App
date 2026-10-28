import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_routes.dart';
import '../../core/api/api_exception.dart';
import '../../core/connectivity/require_online.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/adaptive_dialogs.dart';
import '../../core/widgets/buttons.dart';
import '../../data/models.dart';
import '../../state/cart_controller.dart';
import '../../state/orders_controller.dart';
import '../../state/preferences_controller.dart';
import '../shell/sheets.dart';

/// Checkout. Validates the address, then POST /orders (which turns the
/// server cart into an order). No payment gateway is integrated: no money
/// moves in this phase.
Future<void> showPaymentSheet(BuildContext context) async {
  if (context.read<PreferencesController>().address == null) {
    showAppSnackBar(context, 'Please choose a delivery address first.');
    await showAddressSheet(context);
    return;
  }
  if (!await requireOnline(context, action: 'Placing an order')) return;
  if (!context.mounted) return;
  final orderId = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => const _PaymentSheet(),
  );
  // Replace the stack: Back from the confirmation must not reopen checkout.
  if (orderId != null && context.mounted) {
    context.go(AppRoutes.orderSuccess(orderId));
  }
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet();

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  PaymentMethod _method = PaymentMethod.upi;
  bool _paying = false;
  String? _error;

  Future<void> _pay() async {
    if (_paying) return;
    if (!await requireOnline(context, action: 'Placing an order')) return;
    if (!mounted) return;
    final address = context.read<PreferencesController>().address;
    if (address == null) {
      setState(() => _error = 'Please choose a delivery address.');
      return;
    }
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      final order = await context.read<OrdersController>().place(
            addressId: address.id,
            payment: _method,
          );
      if (!mounted) return;
      context.read<CartController>().markEmpty();
      Navigator.of(context).pop(order.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _paying = false;
          _error = toApiException(e).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = context.select<CartController, double>((c) => c.cart.total);
    final address = context.watch<PreferencesController>().address;
    const icons = {
      PaymentMethod.upi: Icons.qr_code_2,
      PaymentMethod.card: Icons.credit_card,
      PaymentMethod.cod: Icons.payments_outlined,
    };
    return PopScope(
      canPop: !_paying, // don't allow dismissing mid-order
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Choose payment method', style: AppText.titleMd),
              const SizedBox(height: 4),
              Text(
                'Delivering to ${address?.label ?? '—'}',
                style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: AppRadius.lg,
                ),
                child: Text(
                  'Demo checkout: no real payment is made.',
                  style: AppText.bodySm.copyWith(
                    color: AppColors.onPrimaryFixedVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final m in PaymentMethod.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: _method == m
                        ? AppColors.surfaceContainer
                        : AppColors.surfaceContainerLow,
                    borderRadius: AppRadius.xl,
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      enabled: !_paying,
                      leading: Icon(icons[m], color: AppColors.primary),
                      title: Text(m.label, style: AppText.labelMd),
                      trailing: Icon(
                        _method == m
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _method == m
                            ? AppColors.primaryContainer
                            : AppColors.outline,
                      ),
                      onTap: () => setState(() => _method = m),
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: AppText.bodySm.copyWith(color: AppColors.error),
                  ),
                ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: _method == PaymentMethod.cod
                    ? 'Place Order • ${rupees(total, decimals: true)}'
                    : 'Pay ${rupees(total, decimals: true)}',
                icon: Icons.lock_outline,
                loading: _paying,
                loadingLabel: 'Placing order…',
                onPressed: _pay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
