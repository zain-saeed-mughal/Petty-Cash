DROP POLICY IF EXISTS users_read ON public.users;
CREATE POLICY users_read ON public.users FOR SELECT TO authenticated
USING (uid = auth.uid() OR public.current_user_role() IN ('super_admin', 'admin', 'finance', 'manager') OR role = 'manager');
