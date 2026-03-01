import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/design_system/widgets/aurum_app_bar_title.dart';
import '../../../../core/design_system/widgets/aurum_card.dart';
import '../../../../core/design_system/widgets/aurum_empty_state.dart';
import '../../../../core/services/checkout_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/presentation/providers/orders_provider.dart';
import '../../data/repositories/cart_stock_repository.dart';
import '../../data/repositories/coupon_repository.dart';
import '../providers/cart_provider.dart';
import '../../../../core/design_system/widgets/aurum_loader.dart';

final couponRepositoryProvider = Provider<CouponRepository>((ref) {
  return CouponRepository(Supabase.instance.client);
});

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _couponController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  bool _saveInfo = true;

  @override
  void initState() {
    super.initState();
    _hydrateProfileFields();
  }

  Future<void> _hydrateProfileFields() async {
    final user = ref.read(currentUserProvider);
    final profile = await ref.read(profileProvider.future);
    if (!mounted) return;

    _emailController.text = user?.email ?? profile?.email ?? '';
    _fullNameController.text = profile?.fullName ?? '';
    _phoneController.text = profile?.phone ?? '';
    _addressController.text = profile?.address ?? '';
    _cityController.text = profile?.city ?? '';
    _postalCodeController.text = profile?.postalCode ?? '';
  }

  @override
  void dispose() {
    _couponController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final shippingCents = cart.items.isEmpty ? 0 : 500;
    final totalCents = cart.totalCents + shippingCents;

    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(title: const AurumAppBarTitle(AppStrings.carrito)),
      body: cart.items.isEmpty
          ? AurumEmptyState(
              icon: Icons.shopping_bag_outlined,
              title: AppStrings.carritoVacio,
              description: AppStrings.carritoVacioDesc,
              actionLabel: AppStrings.tienda,
              onActionTap: () => context.go('/home'),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...cart.items.map(
                        (item) => _CartItemTile(itemId: item.id),
                      ),
                      const SizedBox(height: 10),
                      _buildCouponCard(cart),
                      const SizedBox(height: 12),
                      _buildShippingForm(),
                      const SizedBox(height: 12),
                      _buildSummaryCard(cart, shippingCents, totalCents),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: cart.isLoading ? null : _handleCheckout,
                      child: cart.isLoading
                          ? const AurumLoader(color: Colors.white)
                          : const Text(AppStrings.continuarPago),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCouponCard(CartState cart) {
    return AurumCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _couponController,
              decoration: const InputDecoration(
                labelText: AppStrings.cuponCodigo,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () => _validateCoupon(cart),
            child: const Text(AppStrings.validarCupon),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingForm() {
    return AurumCard(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.datosEnvio,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: AppStrings.correo),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Introduce un correo';
                }
                if (!value.contains('@')) return 'Correo invalido';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: AppStrings.nombreCompleto,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Campo obligatorio'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: AppStrings.telefono),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Campo obligatorio'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: AppStrings.direccion,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Campo obligatorio'
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: AppStrings.ciudad,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Campo obligatorio'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _postalCodeController,
                    decoration: const InputDecoration(
                      labelText: AppStrings.codigoPostal,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Campo obligatorio'
                        : null,
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              value: _saveInfo,
              contentPadding: EdgeInsets.zero,
              title: const Text(AppStrings.guardarDatos),
              onChanged: (value) => setState(() => _saveInfo = value ?? true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(CartState cart, int shippingCents, int totalCents) {
    final subtotal = cart.subtotalCents / 100;
    final discount = cart.discountCents / 100;
    final shipping = shippingCents / 100;
    final total = totalCents / 100;
    return AurumCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _SummaryRow(
            label: AppStrings.subtotal,
            value: Formatters.euro(subtotal),
          ),
          _SummaryRow(
            label: AppStrings.descuento,
            value: '-${Formatters.euro(discount)}',
          ),
          _SummaryRow(
            label: AppStrings.gastosEnvio,
            value: Formatters.euro(shipping),
          ),
          const Divider(height: 16),
          _SummaryRow(
            label: AppStrings.totalPagar,
            value: Formatters.euro(total),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Future<void> _validateCoupon(CartState cart) async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    try {
      final result = await ref
          .read(couponRepositoryProvider)
          .validateCoupon(code: code, cartTotal: cart.subtotalCents);

      if (!mounted) return;
      if (!result.valid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'No se pudo validar el cupon'),
          ),
        );
        return;
      }

      ref
          .read(cartControllerProvider.notifier)
          .applyCoupon(
            code: result.code ?? code,
            discountCents: result.discountAmount,
          );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.cuponAplicado)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de cupon: $e')));
    }
  }

  Future<void> _handleCheckout() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.iniciarSesionComprar)),
      );
      context.go('/login');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final cart = ref.read(cartControllerProvider);
    if (cart.items.isEmpty) return;

    final stockRepo = ref.read(cartStockRepositoryProvider);
    final stock = await stockRepo.getStockForItems(
      cart.items.map((e) => (e.productId, e.size)).toList(),
    );

    final invalid = cart.items.any((item) {
      final key = buildVariantKey(productId: item.productId, size: item.size);
      return item.quantity > (stock[key] ?? 0);
    });
    if (invalid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.stockInsuficiente)),
      );
      return;
    }

    ref.read(cartControllerProvider.notifier).setLoading(true);
    try {
      final result = await CheckoutService.instance.startCartCheckout(
        items: cart.items
            .map(
              (item) => CheckoutLineItem(
                productId: item.productId,
                name: item.name,
                priceInCents: item.unitPriceCents,
                quantity: item.quantity,
                size: item.size,
              ),
            )
            .toList(),
        shipping: CheckoutShippingData(
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          postalCode: _postalCodeController.text.trim(),
          email: _emailController.text.trim(),
          saveInfo: _saveInfo,
        ),
        couponCode: cart.couponCode,
      );

      try {
        await CheckoutService.instance.confirmOrderAfterPayment(
          result.paymentIntentId,
        );
      } on OrderConfirmationDeferredException {
        // Payment already succeeded in Stripe. Do not block UX waiting for DB sync.
      }

      if (!mounted) return;
      ref.invalidate(customerOrdersProvider);

      await ref.read(cartControllerProvider.notifier).clear();
      if (!mounted) return;
      _couponController.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.compraExitosa)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${AppStrings.pagoError}: $e')));
    } finally {
      ref.read(cartControllerProvider.notifier).setLoading(false);
    }
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final item = cart.items.firstWhere((e) => e.id == itemId);
    final stockAsync = ref.watch(
      stockByVariantProvider((productId: item.productId, size: item.size)),
    );

    final canIncrease = stockAsync.maybeWhen(
      data: (stock) => item.quantity < stock,
      orElse: () => false,
    );
    final stockValue = stockAsync.valueOrNull ?? 0;
    final stockLabel = stockAsync.when(
      data: (stock) => 'Stock: ${stock < 0 ? 0 : stock}',
      loading: () => 'Stock: ...',
      error: (_, __) => 'Stock no disponible',
    );

    return AurumCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: (item.image?.isNotEmpty ?? false)
                  ? CachedNetworkImage(
                      imageUrl: item.image!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.checkroom),
                    )
                  : const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFFF2F2F2)),
                      child: Icon(Icons.checkroom),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  'Talla: ${item.size}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  stockLabel,
                  style: TextStyle(
                    color: stockAsync.hasError
                        ? Colors.red[700]
                        : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  Formatters.euro(item.unitPriceCents / 100),
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => ref
                    .read(cartControllerProvider.notifier)
                    .removeItem(item.id),
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => ref
                        .read(cartControllerProvider.notifier)
                        .setQuantity(item.id, item.quantity - 1),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('${item.quantity}'),
                  IconButton(
                    onPressed: canIncrease
                        ? () {
                            ref
                                .read(cartControllerProvider.notifier)
                                .setQuantity(
                                  item.id,
                                  item.quantity + 1,
                                  maxStock: stockValue,
                                );
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
      color: isTotal ? AppTheme.navyBlue : Colors.black87,
      fontSize: isTotal ? 17 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
