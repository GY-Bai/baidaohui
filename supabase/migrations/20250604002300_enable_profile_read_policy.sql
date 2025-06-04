-- This script enables Row Level Security (RLS) for the 'profiles' table
-- and creates a policy to allow authenticated users to read their own profile.

-- UP migration
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated users to read their own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- DOWN migration
DROP POLICY IF EXISTS "Allow authenticated users to read their own profile" ON public.profiles;
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
