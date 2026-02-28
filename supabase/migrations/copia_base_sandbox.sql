-- Copia de seguridad interna del esquema public en un esquema sandbox.
-- Uso recomendado: ejecutar en SQL Editor de Supabase sobre la base ACTUAL.
-- Resultado: crea un esquema nuevo con todas las tablas y datos actuales.
--
-- IMPORTANTE:
-- 1) Esta copia vive en la MISMA base de datos (no crea un proyecto nuevo).
-- 2) Si quieres aislarte totalmente de la web Astro, crea un proyecto/branch aparte
--    y ejecuta este script alli.
--
-- Personaliza el nombre del esquema destino aqui:
DO $$
DECLARE
  src_schema text := 'public';
  dst_schema text := 'sandbox_copy_2026_02_28';
  r record;
BEGIN
  EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', dst_schema);

  -- Elimina tablas previas del esquema destino para recrear la copia limpia.
  FOR r IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = dst_schema
    ORDER BY tablename
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS %I.%I CASCADE', dst_schema, r.tablename);
  END LOOP;

  -- Crea la estructura de cada tabla (columnas, defaults, constraints, indices)
  -- y luego copia los datos.
  FOR r IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = src_schema
      AND tablename NOT LIKE 'pg_%'
    ORDER BY tablename
  LOOP
    EXECUTE format(
      'CREATE TABLE %I.%I (LIKE %I.%I INCLUDING ALL)',
      dst_schema, r.tablename, src_schema, r.tablename
    );

    EXECUTE format(
      'INSERT INTO %I.%I SELECT * FROM %I.%I',
      dst_schema, r.tablename, src_schema, r.tablename
    );
  END LOOP;
END $$;

-- Verificacion rapida de conteos por tabla en el esquema copiado:
-- SELECT schemaname, tablename
-- FROM pg_tables
-- WHERE schemaname = 'sandbox_copy_2026_02_28'
-- ORDER BY tablename;
