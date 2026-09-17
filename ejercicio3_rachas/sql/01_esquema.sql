--===============================================
-- 01_esquema - Definicion de tablas
-- Date : 16-09-2026
-- Moisés David Arrieta
--==============================================


-- ------------------------- CAPA STAGING ------------------
/* Copia fiel del Excel. Todo llega como TEXT para no perder informacion
por conversiones implicitas y poder auditar el dato original.*/

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

-- --------------------------- CAPA CORE -----------------------------
/*La llave primaria compuesta muestra la regla de negocio:
un cliente solo tiene un saldo por corte de mes.*/

DROP TABLE IF EXISTS historia;
CREATE TABLE historia (
    identificacion TEXT    NOT NULL,
    corte_mes      TEXT    NOT NULL,   -- ISO 'YYYY-MM-DD' fin de mes 
    saldo          INTEGER NOT NULL CHECK (saldo >= 0),
    PRIMARY KEY (identificacion, corte_mes)
)

DROP TABLE IF EXISTS retiros;
CREATE TABLE retiros (
    identificacion TEXT NOT NULL PRIMARY KEY,
    fecha_retiro   TEXT NOT NULL
)

CREATE INDEX IF NOT EXISTS idx_historia_corte ON historia (corte_mes)

-- ------------------------ CAPA CUARENTENA ----------------------------
/* Ningún registro se descarta sin hacerlo saber.
Lo que no cumple las reglas se guarda junto con el motivo por el cual fue rechazado.*/

DROP TABLE IF EXISTS q_historia
CREATE TABLE q_historia (
    identificacion TEXT,
    corte_mes      TEXT,
    saldo          NUMERIC,
    motivo         TEXT NOT NULL
)

DROP TABLE IF EXISTS q_retiros
CREATE TABLE q_retiros (
    identificacion TEXT,
    fecha_retiro   TEXT,
    motivo         TEXT NOT NULL
)

-- ------------------------- PARAMETROS ----------------------
/* fecha_base y n viven en una tabla para que la consulta sea
reejecutable sin editar el SQL. */

DROP TABLE IF EXISTS parametros;
CREATE TABLE parametros (
    id         INTEGER PRIMARY KEY CHECK (id = 1),
    fecha_base TEXT    NOT NULL,
    n_minimo   INTEGER NOT NULL CHECK (n_minimo >= 1)
)

INSERT INTO parametros (id, fecha_base, n_minimo) VALUES (1, '2024-12-31', 3);
