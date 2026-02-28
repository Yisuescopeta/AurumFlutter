import 'dart:math';

import 'package:image_picker/image_picker.dart';
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
  static const _productImagesBucket = 'product-images';
  final _random = Random();

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

  String _slugify(String input) {
    final lowered = input.toLowerCase().trim();
    final dashed = lowered.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final cleaned = dashed.replaceAll(RegExp(r'-+'), '-');
    return cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _randomAlphaNum(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(length, (_) => chars[_random.nextInt(chars.length)])
        .join();
  }

  String _extensionOf(String fileName) {
    final idx = fileName.lastIndexOf('.');
    if (idx < 0 || idx == fileName.length - 1) return 'jpg';
    return fileName.substring(idx + 1).toLowerCase();
  }

  String _contentTypeForExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
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

  Future<List<Map<String, dynamic>>> getCategories() async {
    return _asMapList(
      await _supabase
          .from('categories')
          .select('id,name')
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 20)),
    );
  }

  Future<void> createCategory({
    required String name,
    String? slug,
    String? description,
    String? imageUrl,
    bool isActive = true,
  }) async {
    final normalizedName = name.trim();
    final normalizedSlug = (slug == null || slug.trim().isEmpty)
        ? _slugify(normalizedName)
        : _slugify(slug);

    if (normalizedName.length < 3) {
      throw Exception('El nombre debe tener al menos 3 caracteres');
    }
    if (normalizedSlug.isEmpty) {
      throw Exception('El slug no es valido');
    }

    await _supabase.from('categories').insert({
      'name': normalizedName,
      'slug': normalizedSlug,
      'description': (description == null || description.trim().isEmpty)
          ? null
          : description.trim(),
      'image_url': (imageUrl == null || imageUrl.trim().isEmpty)
          ? null
          : imageUrl.trim(),
      'is_active': isActive,
    }).timeout(const Duration(seconds: 20));
  }

  Future<String> generateUniqueSlug(
    String name, {
    String? currentProductId,
  }) async {
    final base = _slugify(name);
    if (base.isEmpty) throw Exception('No se pudo generar slug');

    var candidate = base;
    var suffix = 2;
    while (true) {
      final existing = await _supabase
          .from('products')
          .select('id')
          .eq('slug', candidate)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
      if (existing == null) return candidate;
      final foundId = existing['id']?.toString();
      if (currentProductId != null && foundId == currentProductId) {
        return candidate;
      }
      candidate = '$base-$suffix';
      suffix += 1;
    }
  }

  Future<String> generateUniqueSku() async {
    for (var i = 0; i < 6; i++) {
      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      final candidate = 'AUR-$y$m$d-${_randomAlphaNum(4)}';

      final existing = await _supabase
          .from('products')
          .select('id')
          .eq('sku', candidate)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
      if (existing == null) return candidate;
    }
    throw Exception('No se pudo generar SKU unico');
  }

  Future<String> createProductBase(Map<String, dynamic> payload) async {
    final created = await _supabase
        .from('products')
        .insert(payload)
        .select('id')
        .single()
        .timeout(const Duration(seconds: 20));
    return created['id'].toString();
  }

  Future<void> updateProductCore(
    String productId,
    Map<String, dynamic> payload,
  ) async {
    await _supabase
        .from('products')
        .update(payload)
        .eq('id', productId)
        .timeout(const Duration(seconds: 20));
  }

  Future<void> saveProductImages({
    required String productId,
    required List<String> imageUrls,
  }) async {
    await _supabase
        .from('products')
        .update({'images': imageUrls})
        .eq('id', productId)
        .timeout(const Duration(seconds: 20));
  }

  Future<List<String>> uploadProductImages({
    required String productId,
    required List<XFile> files,
  }) async {
    if (files.isEmpty) return const [];
    final storage = _supabase.storage.from(_productImagesBucket);
    final uploaded = <String>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final ext = _extensionOf(file.name);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = 'products/$productId/${ts}_${_randomAlphaNum(6)}.$ext';
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: false,
          contentType: _contentTypeForExt(ext),
        ),
      );
      uploaded.add(storage.getPublicUrl(path));
    }
    return uploaded;
  }

  Future<void> upsertProductVariantsAndStock({
    required String productId,
    required List<Map<String, dynamic>> variants,
  }) async {
    await _supabase
        .from('product_variants')
        .delete()
        .eq('product_id', productId)
        .timeout(const Duration(seconds: 20));

    if (variants.isNotEmpty) {
      final rows = variants
          .map(
            (v) => {
              'product_id': productId,
              'size': v['size'],
              'stock': v['stock'],
              'sku_variant': v['sku_variant'],
            },
          )
          .toList();
      await _supabase
          .from('product_variants')
          .insert(rows)
          .timeout(const Duration(seconds: 20));
    }

    final totalStock = variants.fold<int>(
      0,
      (sum, v) => sum + _toInt(v['stock']),
    );
    await _supabase
        .from('products')
        .update({'stock': totalStock})
        .eq('id', productId)
        .timeout(const Duration(seconds: 20));
  }

  Future<String> saveProduct({
    String? productId,
    required Map<String, dynamic> productData,
    required List<Map<String, dynamic>> variants,
  }) async {
    late final String id;
    if (productId == null) {
      id = await createProductBase(productData);
    } else {
      await updateProductCore(productId, productData);
      id = productId;
    }
    await upsertProductVariantsAndStock(productId: id, variants: variants);
    return id;
  }

  Future<void> softDeleteProduct(String productId) async {
    await _supabase
        .from('products')
        .update({'is_active': false})
        .eq('id', productId);
  }

  Future<void> deleteProductIfNoOrders(String productId) async {
    final linkedOrderItem = await _supabase
        .from('order_items')
        .select('id')
        .eq('product_id', productId)
        .limit(1)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));

    if (linkedOrderItem != null) {
      throw Exception(
        'No se puede eliminar: este producto tiene pedidos asociados.',
      );
    }

    await _supabase
        .from('products')
        .delete()
        .eq('id', productId)
        .timeout(const Duration(seconds: 20));
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
    List<Map<String, dynamic>> rows;
    try {
      rows = _asMapList(
        await _supabase
            .from('coupons')
            .select()
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 20)),
      );
    } on PostgrestException catch (e) {
      final code = e.code ?? '';
      final message = e.message.toLowerCase();

      // New/partial DBs might not have this module migrated yet.
      if (code == '42P01' || message.contains('relation') && message.contains('coupons')) {
        return const [];
      }

      // Fallback for schemas without created_at in coupons.
      if (code == '42703' || message.contains('column') && message.contains('created_at')) {
        rows = _asMapList(
          await _supabase
              .from('coupons')
              .select()
              .timeout(const Duration(seconds: 20)),
        );
      } else {
        rethrow;
      }
    }

    if (query.trim().isEmpty) return rows;
    final q = query.toLowerCase();
    return rows.where((c) => (c['code']?.toString().toLowerCase() ?? '').contains(q)).toList();
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
