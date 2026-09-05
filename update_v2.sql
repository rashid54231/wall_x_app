-- ============================================
-- WALL-X APP UPDATE V2: FAVORITES & TAGS
-- ============================================

-- 1. ADD TAGS COLUMN TO WALLPAPERS
ALTER TABLE wallpapers
ADD COLUMN IF NOT EXISTS tags TEXT;

-- 2. USER FAVORITES TABLE
CREATE TABLE IF NOT EXISTS user_favorites (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  wallpaper_id BIGINT REFERENCES wallpapers(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, wallpaper_id) -- Prevent duplicate favorites
);

ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;

-- Users can read their own favorites
CREATE POLICY "Users can read own favorites"
  ON user_favorites FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own favorites
CREATE POLICY "Users can insert own favorites"
  ON user_favorites FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own favorites
CREATE POLICY "Users can delete own favorites"
  ON user_favorites FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================
-- DONE!
-- ============================================
