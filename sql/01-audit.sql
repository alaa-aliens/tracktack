-- Tamm: read-only health check of the live database.
-- Paste this whole file into Supabase > SQL Editor and press Run. It changes nothing.
-- Copy the single result cell (one JSON value) and send it back.

select jsonb_pretty(jsonb_build_object(
  'tables', (
    select jsonb_agg(jsonb_build_object(
      'table', c.relname,
      'rls_enabled', c.relrowsecurity,
      'rows_estimate', c.reltuples::bigint,
      'size', pg_size_pretty(pg_total_relation_size(c.oid))))
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'),
  'columns', (
    select jsonb_object_agg(table_name, cols) from (
      select table_name, jsonb_agg(column_name || ' ' || data_type order by ordinal_position) cols
      from information_schema.columns where table_schema = 'public' group by table_name) x),
  'policies', (
    select jsonb_agg(jsonb_build_object(
      'schema', schemaname, 'table', tablename, 'name', policyname, 'cmd', cmd,
      'roles', roles, 'using', qual, 'check', with_check))
    from pg_policies where schemaname in ('public', 'storage')),
  'functions', (
    select jsonb_agg(jsonb_build_object(
      'name', p.proname,
      'args', pg_get_function_arguments(p.oid),
      'security_definer', p.prosecdef,
      'anon_can_run', has_function_privilege('anon', p.oid, 'execute'),
      'body', pg_get_functiondef(p.oid)))
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'),
  'triggers', (
    select jsonb_agg(jsonb_build_object('table', event_object_table, 'name', trigger_name, 'action', action_statement))
    from information_schema.triggers where trigger_schema = 'public'),
  'buckets', (
    select jsonb_agg(jsonb_build_object('id', id, 'public', public,
      'file_size_limit', file_size_limit, 'allowed_mime_types', allowed_mime_types))
    from storage.buckets),
  'receipt_files', (select count(*) from storage.objects where bucket_id = 'receipts'),
  'shops', (select count(*) from public.businesses),
  'members_by_role', (select jsonb_object_agg(coalesce(role, 'null'), n) from (
      select role, count(*) n from public.members group by role) r),
  'users', (select count(*) from auth.users),
  'unconfirmed_users', (select count(*) from auth.users where email_confirmed_at is null),
  'largest_shop_data', (select pg_size_pretty(max(pg_column_size(data))::bigint) from public.business_data)
)) as tamm_health;
