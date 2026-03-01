-- Custom functions needed for RLS
CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN (
        SELECT role = 'admin'
        FROM profiles
        WHERE id = auth.uid()
    );
END;
$function$;

-- Enable RLS for all tables
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_report_subscriptions ENABLE ROW LEVEL SECURITY;

-- Create extracted policies
CREATE POLICY "Lectura pública de categorías activas" ON public.categories FOR SELECT TO public USING ((is_active = true));
CREATE POLICY "Admin gestiona categorías" ON public.categories FOR ALL TO public USING (is_admin());
CREATE POLICY "Lectura pública de productos activos" ON public.products FOR SELECT TO public USING ((is_active = true));
CREATE POLICY "Admin gestiona productos" ON public.products FOR ALL TO public USING (is_admin());
CREATE POLICY "Admin full access coupons" ON public.coupons FOR ALL TO authenticated USING ((( SELECT profiles.role
   FROM profiles
  WHERE (profiles.id = auth.uid())) = 'admin'::text)) WITH CHECK ((( SELECT profiles.role
   FROM profiles
  WHERE (profiles.id = auth.uid())) = 'admin'::text));
CREATE POLICY "Lectura pública de variantes" ON public.product_variants FOR SELECT TO public USING (true);
CREATE POLICY "Admin gestiona variantes" ON public.product_variants FOR ALL TO public USING (is_admin());
CREATE POLICY "Admin full access user_coupons" ON public.user_coupons FOR ALL TO authenticated USING ((( SELECT profiles.role
   FROM profiles
  WHERE (profiles.id = auth.uid())) = 'admin'::text)) WITH CHECK ((( SELECT profiles.role
   FROM profiles
  WHERE (profiles.id = auth.uid())) = 'admin'::text));
CREATE POLICY "Admin gestiona pedidos" ON public.orders FOR ALL TO public USING (is_admin());
CREATE POLICY "Admin gestiona items" ON public.order_items FOR ALL TO public USING (is_admin());
CREATE POLICY "Admin ve todo el historial" ON public.order_status_history FOR SELECT TO public USING (is_admin());
CREATE POLICY "Admin crea historial" ON public.order_status_history FOR INSERT TO public WITH CHECK (is_admin());
CREATE POLICY "Public Profiles Access" ON public.profiles FOR SELECT TO public USING (true);
CREATE POLICY "Lectura pública de site_settings" ON public.site_settings FOR SELECT TO public USING (true);
CREATE POLICY "Admin gestiona site_settings" ON public.site_settings FOR ALL TO public USING (is_admin());
CREATE POLICY "Admin ve todos los favoritos" ON public.favorites FOR SELECT TO public USING (is_admin());
CREATE POLICY "Usuario actualiza su perfil" ON public.profiles FOR UPDATE TO public USING ((( SELECT auth.uid() AS uid) = id));
CREATE POLICY "Usuarios ven sus propios favoritos" ON public.favorites FOR SELECT TO public USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "Usuarios agregan sus propios favoritos" ON public.favorites FOR INSERT TO public WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "Usuarios eliminan sus propios favoritos" ON public.favorites FOR DELETE TO public USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "Usuario ve sus pedidos" ON public.orders FOR SELECT TO public USING (((( SELECT auth.uid() AS uid) = user_id) OR (user_id IS NULL)));
CREATE POLICY "Usuario ve items de sus pedidos" ON public.order_items FOR SELECT TO public USING ((EXISTS ( SELECT 1
   FROM orders
  WHERE ((orders.id = order_items.order_id) AND ((orders.user_id = ( SELECT auth.uid() AS uid)) OR (orders.user_id IS NULL))))));
CREATE POLICY "Usuario ve historial de sus pedidos" ON public.order_status_history FOR SELECT TO public USING ((EXISTS ( SELECT 1
   FROM orders
  WHERE ((orders.id = order_status_history.order_id) AND ((orders.user_id = ( SELECT auth.uid() AS uid)) OR (orders.user_id IS NULL))))));
CREATE POLICY "Users can view own notification history" ON public.notification_history FOR SELECT TO public USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "Users can view own preferences" ON public.user_notification_preferences FOR SELECT TO public USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "Users can insert own preferences" ON public.user_notification_preferences FOR INSERT TO public WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "Users can update own preferences" ON public.user_notification_preferences FOR UPDATE TO public USING ((( SELECT auth.uid() AS uid) = user_id));
CREATE POLICY "Admin crea perfiles" ON public.profiles FOR INSERT TO public WITH CHECK ((((( SELECT auth.jwt() AS jwt) ->> 'role'::text) = 'service_role'::text) OR is_admin()));
CREATE POLICY "Admin actualiza perfiles" ON public.profiles FOR UPDATE TO public USING ((((( SELECT auth.jwt() AS jwt) ->> 'role'::text) = 'service_role'::text) OR is_admin()));
CREATE POLICY "Admins can view their own subscriptions" ON public.admin_report_subscriptions FOR SELECT TO public USING ((auth.uid() = admin_user_id));
CREATE POLICY "Admins can insert their own subscriptions" ON public.admin_report_subscriptions FOR INSERT TO public WITH CHECK ((auth.uid() = admin_user_id));
CREATE POLICY "Admins can update their own subscriptions" ON public.admin_report_subscriptions FOR UPDATE TO public USING ((auth.uid() = admin_user_id)) WITH CHECK ((auth.uid() = admin_user_id));
CREATE POLICY "Admins can delete their own subscriptions" ON public.admin_report_subscriptions FOR DELETE TO public USING ((auth.uid() = admin_user_id));
CREATE POLICY "Users can view own orders" ON public.orders FOR SELECT TO authenticated USING ((auth.uid() = user_id));
CREATE POLICY "Users can view own order items" ON public.order_items FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM orders
  WHERE ((orders.id = order_items.order_id) AND (orders.user_id = auth.uid())))));
CREATE POLICY "Public read active coupons" ON public.coupons FOR SELECT TO public USING (true);
CREATE POLICY "Users read own usage" ON public.user_coupons FOR SELECT TO public USING ((auth.uid() = user_id));
