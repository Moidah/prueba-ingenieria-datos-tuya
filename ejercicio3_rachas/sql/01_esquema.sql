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

-- --------------------------- CAPA CORE -------------------------------
-- La llave primaria compuesta materializa la regla de negocio:
-- un cliente tiene a lo sumo un saldo por corte de mes.

DROP TABLE IF EXISTS historia;
CREATE TABLE historia (
    identificacion TEXT    NOT NULL,
    corte_mes      TEXT    NOT NULL,   -- ISO 'YYYY-MM-DD', siempre fin de mes
    saldo          INTEGER NOT NULL CHECK (saldo >= 0),
    PRIMARY KEY (identificacion, corte_mes)
);

DROP TABLE IF EXISTS retiros;
CREATE TABLE retiros (
    identificacion TEXT NOT NULL PRIMARY KEY,
    fecha_retiro   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_historia_corte ON historia (corte_mes)
