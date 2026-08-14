// Bundle entry point. Re-exports only what the renderer actually uses, so the
// vendored bundle stays as small as the library allows.
export { createClient } from '@supabase/supabase-js';
