-- Enable uuid-ossp extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. profiles
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    full_name TEXT NULL,
    email TEXT NULL,
    phone TEXT NULL,
    address TEXT NULL,
    city TEXT NULL,
    postal_code TEXT NULL,
    avatar_url TEXT NULL,
    role TEXT DEFAULT 'customer'::text CHECK(role = ANY (ARRAY['admin'::text, 'customer'::text])),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
COMMENT ON TABLE public.profiles IS 'Perfiles de usuario. El rol solo puede ser admin o customer.';
COMMENT ON COLUMN public.profiles.role IS 'Rol del usuario. Solo el DBA puede asignar admin.';

-- 2. categories
CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL CHECK(char_length(name) >= 3),
    slug TEXT UNIQUE NOT NULL CHECK(slug ~* '^[a-z0-9-]+$'::text),
    description TEXT NULL,
    image_url TEXT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 3. products
CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID NULL REFERENCES public.categories(id),
    name TEXT NOT NULL CHECK(char_length(name) >= 3),
    slug TEXT UNIQUE NOT NULL CHECK(slug ~* '^[a-z0-9-]+$'::text),
    description TEXT NULL CHECK(char_length(description) <= 2000),
    price INTEGER NOT NULL CHECK(price > 0),
    compare_at_price INTEGER NULL,
    sku TEXT UNIQUE NULL,
    material TEXT NULL,
    stock INTEGER DEFAULT 0 CHECK(stock >= 0),
    sizes JSONB NULL,
    images TEXT[] DEFAULT '{}'::text[],
    colors TEXT[] DEFAULT '{}'::text[],
    is_featured BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    is_on_sale BOOLEAN DEFAULT false,
    sale_price INTEGER NULL,
    sale_started_at TIMESTAMP WITH TIME ZONE NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 4. product_variants
CREATE TABLE public.product_variants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES public.products(id),
    size TEXT NOT NULL,
    sku_variant TEXT NULL,
    stock INTEGER DEFAULT 0 CHECK(stock >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
COMMENT ON TABLE public.product_variants IS 'Stock de productos por talla. Cada producto tiene múltiples variantes.';
COMMENT ON COLUMN public.product_variants.size IS 'Talla del producto (S, M, L, XL, etc.)';
COMMENT ON COLUMN public.product_variants.stock IS 'Cantidad disponible de esta talla';

-- 5. site_settings
CREATE TABLE public.site_settings (
    id TEXT PRIMARY KEY DEFAULT 'main'::text,
    updated_by UUID NULL,
    show_flash_sales BOOLEAN DEFAULT false,
    flash_sales_title TEXT DEFAULT 'Ofertas Flash'::text,
    flash_sales_subtitle TEXT DEFAULT 'Descuentos por tiempo limitado'::text,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 6. favorites
CREATE TABLE public.favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    product_id UUID NOT NULL REFERENCES public.products(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 7. user_notification_preferences
CREATE TABLE public.user_notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id),
    favorites_on_sale BOOLEAN DEFAULT true,
    marketing_emails BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 8. notification_history
CREATE TABLE public.notification_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    product_id UUID NOT NULL REFERENCES public.products(id),
    email_sent_to VARCHAR NULL,
    notification_type VARCHAR NOT NULL DEFAULT 'favorite_on_sale'::character varying,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 9. orders
CREATE TABLE public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NULL REFERENCES auth.users(id),
    payment_intent_id TEXT NULL,
    stripe_session_id TEXT UNIQUE NULL,
    customer_email TEXT NULL,
    total_amount INTEGER NULL,
    status TEXT DEFAULT 'paid'::text CHECK(status = ANY (ARRAY['pending'::text, 'paid'::text, 'confirmed'::text, 'processing'::text, 'shipped'::text, 'delivered'::text, 'cancelled'::text, 'refunded'::text])),
    shipping_cost INTEGER DEFAULT 0,
    shipping_address TEXT DEFAULT 'No especificada'::text,
    shipping_city TEXT DEFAULT 'No especificada'::text,
    shipping_postal_code TEXT DEFAULT '00000'::text,
    shipping_phone TEXT NULL,
    notes TEXT NULL,
    tracking_number TEXT NULL,
    carrier TEXT NULL,
    estimated_delivery TIMESTAMP WITH TIME ZONE NULL,
    shipped_at TIMESTAMP WITH TIME ZONE NULL,
    delivered_at TIMESTAMP WITH TIME ZONE NULL,
    cancelled_at TIMESTAMP WITH TIME ZONE NULL,
    cancellation_reason TEXT NULL,
    refund_status TEXT NULL CHECK(refund_status = ANY (ARRAY[NULL::text, 'pending'::text, 'completed'::text, 'failed'::text])),
    refunded_at TIMESTAMP WITH TIME ZONE NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
ALTER TABLE public.orders ADD CONSTRAINT fk_orders_profiles FOREIGN KEY (user_id) REFERENCES public.profiles(id);
COMMENT ON COLUMN public.orders.tracking_number IS 'Número de seguimiento del transportista';
COMMENT ON COLUMN public.orders.carrier IS 'Nombre del transportista (Correos, SEUR, MRW, etc.)';
COMMENT ON COLUMN public.orders.estimated_delivery IS 'Fecha estimada de entrega';
COMMENT ON COLUMN public.orders.refund_status IS 'Estado del reembolso: pending, completed, failed';

-- 10. order_items
CREATE TABLE public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NULL REFERENCES public.orders(id),
    product_id UUID NULL REFERENCES public.products(id),
    product_name TEXT NULL,
    size TEXT NULL,
    quantity INTEGER NULL,
    price_at_purchase INTEGER NULL
);

-- 11. order_status_history
CREATE TABLE public.order_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES public.orders(id),
    status TEXT NOT NULL,
    notes TEXT NULL,
    created_by UUID NULL REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
COMMENT ON TABLE public.order_status_history IS 'Historial de cambios de estado de los pedidos para tracking detallado';

-- 12. admin_report_subscriptions
CREATE TABLE public.admin_report_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id),
    last_sent_at TIMESTAMP WITH TIME ZONE NULL,
    enabled BOOLEAN DEFAULT true,
    report_sales BOOLEAN DEFAULT true,
    report_new_customers BOOLEAN DEFAULT true,
    report_returns BOOLEAN DEFAULT true,
    report_low_stock BOOLEAN DEFAULT true,
    report_top_products BOOLEAN DEFAULT true,
    send_hour INTEGER DEFAULT 8 CHECK(send_hour >= 0 AND send_hour <= 23),
    send_minute INTEGER DEFAULT 0 CHECK(send_minute >= 0 AND send_minute <= 59),
    frequency_days INTEGER DEFAULT 1 CHECK(frequency_days >= 1 AND frequency_days <= 30),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 13. coupons
CREATE TABLE public.coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    discount_type TEXT NOT NULL CHECK(discount_type = ANY (ARRAY['percent'::text, 'fixed'::text])),
    discount_value NUMERIC NOT NULL,
    min_purchase_amount NUMERIC DEFAULT 0,
    expiration_date TIMESTAMP WITH TIME ZONE NULL,
    usage_limit INTEGER NULL,
    is_single_use BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 14. user_coupons
CREATE TABLE public.user_coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    coupon_id UUID NOT NULL REFERENCES public.coupons(id),
    used_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

