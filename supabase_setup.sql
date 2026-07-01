-- ============================================
-- WALL-X APP: FULL SUPABASE SQL + RLS SETUP
-- ============================================
-- Run this in Supabase SQL Editor (https://supabase.com/dashboard)
-- This creates all tables, roles, and security policies.

-- ============================================
-- 1. USER ROLES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS user_roles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-insert user role when a new user signs up
CREATE OR REPLACE FUNCTION handle_new_user_role()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'user')
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user_role();

-- RLS for user_roles
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

-- Users can only read their own role
CREATE POLICY "Users can read own role"
  ON user_roles FOR SELECT
  USING (auth.uid() = user_id);

-- Admins can read all roles
CREATE POLICY "Admins can read all roles"
  ON user_roles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Insert is handled by trigger, no direct insert policy needed
-- Admins can update roles
CREATE POLICY "Admins can update roles"
  ON user_roles FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- 2. CATEGORIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS categories (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- Everyone can read categories
CREATE POLICY "Anyone can read categories"
  ON categories FOR SELECT
  USING (true);

-- Only admins can insert/update/delete
CREATE POLICY "Admins can insert categories"
  ON categories FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update categories"
  ON categories FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete categories"
  ON categories FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- 3. WALLPAPERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS wallpapers (
  id BIGSERIAL PRIMARY KEY,
  url TEXT NOT NULL,
  category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL,
  is_premium BOOLEAN DEFAULT false,
  is_animated BOOLEAN DEFAULT false,
  fav_count INT DEFAULT 0,
  downloads INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE wallpapers ENABLE ROW LEVEL SECURITY;

-- Everyone can read wallpapers
CREATE POLICY "Anyone can read wallpapers"
  ON wallpapers FOR SELECT
  USING (true);

-- Only admins can insert/update/delete
CREATE POLICY "Admins can insert wallpapers"
  ON wallpapers FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update wallpapers"
  ON wallpapers FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete wallpapers"
  ON wallpapers FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- 4. CATALOGS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS catalogs (
  id BIGSERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  cover_url TEXT,
  category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE catalogs ENABLE ROW LEVEL SECURITY;

-- Everyone can read catalogs
CREATE POLICY "Anyone can read catalogs"
  ON catalogs FOR SELECT
  USING (true);

-- Only admins can manage
CREATE POLICY "Admins can insert catalogs"
  ON catalogs FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update catalogs"
  ON catalogs FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete catalogs"
  ON catalogs FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- 5. CATALOG WALLPAPERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS catalog_wallpapers (
  id BIGSERIAL PRIMARY KEY,
  catalog_id BIGINT REFERENCES catalogs(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  is_premium BOOLEAN DEFAULT false,
  is_animated BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE catalog_wallpapers ENABLE ROW LEVEL SECURITY;

-- Everyone can read
CREATE POLICY "Anyone can read catalog wallpapers"
  ON catalog_wallpapers FOR SELECT
  USING (true);

-- Only admins can manage
CREATE POLICY "Admins can insert catalog wallpapers"
  ON catalog_wallpapers FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete catalog wallpapers"
  ON catalog_wallpapers FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- 6. NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
  id BIGSERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Everyone can read notifications
CREATE POLICY "Anyone can read notifications"
  ON notifications FOR SELECT
  USING (true);

-- Only admins can send
CREATE POLICY "Admins can insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- 7. USER SUBSCRIPTIONS TABLE (Premium tracking)
-- ============================================
CREATE TABLE IF NOT EXISTS user_subscriptions (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  is_active BOOLEAN DEFAULT false,
  provider TEXT DEFAULT 'revenuecat',
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can read their own subscription
CREATE POLICY "Users can read own subscription"
  ON user_subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- Admins can read all
CREATE POLICY "Admins can read all subscriptions"
  ON user_subscriptions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- 8. STORAGE BUCKETS (Run separately)
-- ============================================
-- Go to Supabase Dashboard > Storage > New Bucket
-- Create bucket: "wallpapers" (Public: YES)
-- Create bucket: "catalog_covers" (Public: YES)

-- Storage RLS policies for wallpapers bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('wallpapers', 'wallpapers', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) VALUES ('catalog_covers', 'catalog_covers', true)
ON CONFLICT (id) DO NOTHING;

-- Allow public read access
CREATE POLICY "Public read access for wallpapers"
  ON storage.objects FOR SELECT
  USING (bucket_id IN ('wallpapers', 'catalog_covers'));

-- Only admins can upload
CREATE POLICY "Admins can upload to wallpapers"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id IN ('wallpapers', 'catalog_covers')
    AND EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Only admins can delete
CREATE POLICY "Admins can delete from wallpapers"
  ON storage.objects FOR DELETE
  USING (
    bucket_id IN ('wallpapers', 'catalog_covers')
    AND EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- 9. MAKE YOURSELF ADMIN
-- ============================================
-- Replace 'YOUR_EMAIL' with your actual email used to sign up
-- Run this AFTER you've created your account in the app

-- INSERT INTO user_roles (user_id, role)
-- SELECT id, 'admin' FROM auth.users WHERE email = 'YOUR_EMAIL'
-- ON CONFLICT (user_id) DO UPDATE SET role = 'admin';

-- ============================================
-- 10. PREMIUM REQUESTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS premium_requests (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  transaction_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE premium_requests ENABLE ROW LEVEL SECURITY;

-- Users can read their own requests
CREATE POLICY "Users can read own premium requests"
  ON premium_requests FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own requests
CREATE POLICY "Users can insert own premium requests"
  ON premium_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Admins can read all requests
CREATE POLICY "Admins can read all premium requests"
  ON premium_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can update (approve/reject) requests
CREATE POLICY "Admins can update premium requests"
  ON premium_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================
-- DONE! All tables and RLS policies created.
-- ============================================
