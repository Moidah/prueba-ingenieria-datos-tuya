--===============================================
-- 01_esquema - Definicion de tablas
-- Date : 16-09-2026
-- Moisés David Arrieta
--==============================================


-- ------------------------- CAPA STAGING ------------------
-- Copia fiel del Excel. Todo llega como TEXT para no perder informacion
-- por conversiones implicitas y poder auditar el dato original.

DROP TABLE IF EXISTS stg_historia;
CREATE TABLE stg_historia (
    identificacion TEXT,
    corte_mes      TEXT,
    saldo          NUMERIC
);

DROP TABLE IF EXISTS stg_retiros;
CREATE TABLE stg_retiros (
    identificacion TEXT,
    fecha_retiro   TEXT
)

