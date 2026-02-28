import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.totalProducts,
    required this.inventoryValueCents,
    required this.totalOrders,
    required this.lowStockVariants,
    required this.recentProducts,
  });

  final int totalProducts;
  final int inventoryValueCents;
  final int totalOrders;
  final int lowStockVariants;
  final List<Map<String, dynamic>> recentProducts;
}

class ProductListResult {
  const ProductListResult({
    required this.products,
    required this.categories,
  });

  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> categories;
}

class AdminRepository {
  AdminRepository(this._supabase);

  final SupabaseClient _supabase;

  List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<AdminDashboardStats> getDashboardStats() async {
    final productsCountRows = await _supabase.from('products').select('id');
    final ordersCountRows = await _supabase.from('orders').select('id');
    final lowStockRows =
        await _supabase.from('product_variants').select('id').lt('stock', 10);

    final products = await _supabase
        .from('products')
        .select('id,price,sale_price,is_on_sale');
    final variants =
        await _supabase.from('product_variants').select('product_id,stock');

    final stockByProduct = <String, int>{};
    for (final v in (variants as List)) {
      final map = v as Map<String, dynamic>;
      final id = map['product_id']?.toString();
      if (id == null) continue;
      stockByProduct[id] = (stockByProduct[id] ?? 0) + _toInt(map['stock']);
    }

    var inventoryValue = 0;
    for (final p in (products as List)) {
      final map = p as Map<String, dynamic>;
      final id = map['id']?.toString();
      if (id == null) continue;
      final stock = stockByProduct[id] ?? 0;
      final isOnSale = map['is_on_sale'] == true;
      final unit = _toInt(isOnSale ? map['sale_price'] : map['price']);
      inventoryValue += (unit * stock);
    }

    final recentProducts = _asMapList(
      await _supabase
          .from('products')
          .select('id,name,images,created_at,price,is_on_sale,sale_price,categories(name)')
          .order('created_at', ascending: false)
          .limit(8),
    );

    return AdminDashboardStats(
      totalProducts: (productsCountRows as List).length,
      inventoryValueCents: inventoryValue,
      totalOrders: (ordersCountRows as List).length,
      lowStockVariants: (lowStockRows as List).length,
      recentProducts: recentProducts,
    );
  }

  Future<ProductListResult> getProducts({
    String query = '',
    String? categoryId,
    String stockFilter = 'all',
    String statusFilter = 'all',
  }) async {
    var req = _supabase.from('products').select('*');

    if (query.trim().isNotEmpty) {
      final q = query.trim();
      req = req.or('name.ilike.%$q%,slug.ilike.%$q%,sku.ilike.%$q%');
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      req = req.eq('category_id', categoryId);
    }

    if (statusFilter == 'active') {
      req = req.eq('is_active', true);
    } else if (statusFilter == 'inactive') {
      req = req.eq('is_active', false);
    }

    final products = _asMapList(
      await req.order('created_at', ascending: false).timeout(
            const Duration(seconds: 20),
          ),
    );

    final categories = _asMapList(
      await _supabase
          .from('categories')
          .select('id,name')
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 20)),
    );
    final categoriesById = <String, Map<String, dynamic>>{
      for (final c in categories) c['id']?.toString() ?? '': c,
    };

    final productIds =
        products.map((e) => e['id']?.toString()).whereType<String>().toList();
    List<Map<String, dynamic>> variants = const [];
    if (productIds.isNotEmpty) {
      variants = _asMapList(
        await _supabase
            .from('product_variants')
            .select('product_id,size,stock')
            .inFilter('product_id', productIds)
            .timeout(const Duration(seconds: 20)),
      );
    }

    final variantsByProduct = <String, List<Map<String, dynamic>>>{};
    for (final v in variants) {
      final productId = v['product_id']?.toString();
      if (productId == null) continue;
      variantsByProduct.putIfAbsent(productId, () => <Map<String, dynamic>>[]);
      variantsByProduct[productId]!.add(v);
    }

    final enriched = products.map((p) {
      final m = Map<String, dynamic>.from(p);
      final id = m['id']?.toString() ?? '';
      final categoryIdValue = m['category_id']?.toString();
      m['categories'] = categoryIdValue == null
          ? null
          : categoriesById[categoryIdValue];
      m['product_variants'] = variantsByProduct[id] ?? const <Map<String, dynamic>>[];
      return m;
    }).toList();

    List<Map<String, dynamic>> filtered = enriched;
    if (stockFilter != 'all') {
      filtered = enriched.where((p) {
        final productVariants = _asMapList(p['product_variants']);
        final total = productVariants.fold<int>(
          0,
          (sum, v) => sum + _toInt(v['stock']),
        );
        if (stockFilter == 'out') return total == 0;
        if (stockFilter == 'low') return total > 0 && total < 10;
        return true;
      }).toList();
    }

    return ProductListResult(products: filtered, categories: categories);
  }

  Future<Map<String, dynamic>> getProductById(String id) async {
    final product = await _supabase
        .from('products')
        .select('*')
        .eq('id', id)
        .single()
        .timeout(const Duration(seconds: 20));
    final variants = _asMapList(
      await _supabase
          .from('product_variants')
          .select('id,size,stock,sku_variant')
          .eq('product_id', id)
          .timeout(const Duration(seconds: 20)),
    );
    final map = Map<String, dynamic>.from(product);
    map['product_variants'] = variants;
    return map;
  }

  Future<String> saveProduct({
    String? productId,
    required Map<String, dynamic> productData,
    required List<Map<String, dynamic>> variants,
  }) async {
    late final String id;
    if (productId == null) {
      final created =
          await _supabase.from('products').insert(productData).select('id').single();
      id = created['id'].toString();
    } else {
      await _supabase.from('products').update(productData).eq('id', productId);
      id = productId;
    }

    await _supabase.from('product_variants').delete().eq('product_id', id);
    if (variants.isNotEmpty) {
      final rows = variants
          .map(
            (v) => {
              'product_id': id,
              'size': v['size'],
              'stock': v['stock'],
              'sku_variant': v['sku_variant'],
            },
          )
          .toList();
      await _supabase.from('product_variants').insert(rows);
    }

    final totalStock = variants.fold<int>(
      0,
      (sum, v) => sum + _toInt(v['stock']),
    );
    await _supabase.from('products').update({'stock': totalStock}).eq('id', id);

    return id;
  }

  Future<void> softDeleteProduct(String productId) async {
    await _supabase
        .from('products')
        .update({'is_active': false})
        .eq('id', productId);
  }

  Future<List<Map<String, dynamic>>> getClients({
    String query = '',
    String roleFilter = 'all',
  }) async {
    var req = _supabase.from('profiles').select();
    if (roleFilter == 'admin' || roleFilter == 'customer') {
      req = req.eq('role', roleFilter);
    }
    final rows = _asMapList(
      await req.order('created_at', ascending: false).timeout(
            const Duration(seconds: 20),
          ),
    );
    if (query.trim().isEmpty) return rows;
    final q = query.toLowerCase();
    return rows.where((p) {
      final name = p['full_name']?.toString().toLowerCase() ?? '';
      final email = p['email']?.toString().toLowerCase() ?? '';
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getCoupons({String query = ''}) async {
    final rows = _asMapList(
      await _supabase
          .from('coupons')
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 20)),
    );
    if (query.trim().isEmpty) return rows;
    final q = query.toLowerCase();
    return rows
        .where((c) => (c['code']?.toString().toLowerCase() ?? '').contains(q))
        .toList();
  }

  Future<void> createCoupon(Map<String, dynamic> payload) async {
    await _supabase.from('coupons').insert(payload);
  }

  Future<void> updateCoupon(String id, Map<String, dynamic> payload) async {
    await _supabase.from('coupons').update(payload).eq('id', id);
  }

  Future<void> deleteCoupon(String id) async {
    await _supabase.from('coupons').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> sendBroadcastCampaign(
    Map<String, dynamic> payload,
  ) async {
    final res =
        await _supabase.functions.invoke('send-broadcast-campaign', body: payload);
    if (res.data is! Map) {
      throw Exception('Respuesta invalida del envio');
    }
    return Map<String, dynamic>.from(res.data as Map);
  }
}
