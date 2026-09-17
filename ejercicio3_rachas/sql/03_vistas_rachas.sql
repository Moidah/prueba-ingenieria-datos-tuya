-- ================================================
--   Archivo: 03_vistas_rachas.sql
-- Moisés Arrieta
-- 17/09/2026
-- ==============================0================

/*
   Aqui se arma la logica para encontrar las "rachas": meses
   seguidos en los que un cliente se mantuvo en el mismo nivel
   de saldo (N0, N1, N2, N3 o N4).

   Los parametros (fecha_base y n_minimo) se leen de la tabla
   "parametros", no estan escritos aqui. Para cambiarlos:

       UPDATE parametros SET fecha_base = '2024-06-30', n_minimo = 4;

   El plan tiene 4 pasos, cada uno es una vista (una consulta guardada):
   1. calendario -> lista de todos los fin de mes hasta la fecha_base
   2. vigencia -> desde cuando hasta cuando cuenta cada cliente
   3. panel -> una fila por cada cliente y cada mes, sin huecos
   4. islas -> agrupa los meses seguidos que tienen el mismo nivel
*/


/*
   PASO 1: crear el calendario.

   No usamos las fechas que ya estan en la tabla historia, porque
   si un mes no tiene NINGUN cliente con saldo reportado, ese mes
   tambien tiene que existir en el calendario (para poder ponerle
   N0 a todos los clientes ese mes). Por eso se genera la lista
   de fechas nosotros mismos, mes por mes, hasta llegar a fecha_base.
*/
DROP VIEW IF EXISTS v_calendario;
CREATE VIEW v_calendario AS
WITH RECURSIVE
limites AS (
    SELECT DATE((SELECT MIN(corte_mes) FROM historia),
                'start of month', '+1 month', '-1 day') AS corte_ini,
           DATE((SELECT fecha_base FROM parametros),
                'start of month', '+1 month', '-1 day') AS corte_fin
),
calendario (corte_mes) AS (
    SELECT corte_ini FROM limites
    UNION ALL
    SELECT DATE(corte_mes, '+1 day', 'start of month', '+1 month', '-1 day')
    FROM calendario
    WHERE corte_mes < (SELECT corte_fin FROM limites)
)
SELECT corte_mes FROM calendario


/*
   PASO 2: saber desde cuando hasta cuando cuenta cada cliente.

   inicio = el primer mes en que aparece ese cliente (antes de eso,
            no existia para nosotros, no le podemos poner N0)
   fin    = lo que sea mas temprano entre fecha_base y su fecha de retiro

   Importante: comparamos contra la fecha exacta del retiro, no
   solo el mes. Si un cliente se retiro el 10 de octubre, el corte
   del 31 de octubre ya es DESPUES de su retiro, asi que no cuenta.
*/
DROP VIEW IF EXISTS v_vigencia_cliente;
CREATE VIEW v_vigencia_cliente AS
SELECT
    h.identificacion,
    MIN(h.corte_mes) AS corte_inicio,
    MIN(
        (SELECT fecha_base FROM parametros),
        COALESCE(r.fecha_retiro, (SELECT fecha_base FROM parametros))
    ) AS fecha_fin_vigencia
FROM historia h
LEFT JOIN retiros r ON r.identificacion = h.identificacion
GROUP BY h.identificacion, r.fecha_retiro


/*
   PASO 3: armar una tabla con una fila por cada cliente y cada mes,
   sin huecos, desde su inicio hasta su fin de vigencia.

   Se cruza cada cliente con TODOS los meses del calendario (dentro
   de su rango de vigencia), y despues se le pega el saldo real si
   existe. Si no existe saldo ese mes, se le pone 0, que segun la
   escala cae automaticamente en N0.

   Este paso es clave: sin esta tabla "sin huecos", no se puede
   despues buscar meses seguidos facilmente.
*/
DROP VIEW IF EXISTS v_panel_mensual;
CREATE VIEW v_panel_mensual AS
SELECT
    v.identificacion,
    c.corte_mes,
    COALESCE(h.saldo, 0)          AS saldo,
    (h.identificacion IS NULL)    AS es_imputado,
    CASE
        WHEN COALESCE(h.saldo, 0) <  300000  THEN 'N0'
        WHEN COALESCE(h.saldo, 0) < 1000000  THEN 'N1'
        WHEN COALESCE(h.saldo, 0) < 3000000  THEN 'N2'
        WHEN COALESCE(h.saldo, 0) < 5000000  THEN 'N3'
        ELSE 'N4'
    END AS nivel
FROM v_vigencia_cliente v
JOIN v_calendario c
     ON c.corte_mes >= v.corte_inicio
    AND c.corte_mes <= v.fecha_fin_vigencia
LEFT JOIN historia h
     ON h.identificacion = v.identificacion
    AND h.corte_mes      = c.corte_mes


/*
   PASO 4: encontrar las rachas (meses seguidos con el mismo nivel).

   Este es el truco mas importante de todo el ejercicio, se llama
   "gaps and islands" (huecos e islas). Funciona asi:

   A cada mes de un cliente le ponemos dos numeros:
   - su posicion en la lista de TODOS sus meses (sin importar el nivel)
   - su posicion en la lista de solo los meses de ESE nivel

   Mientras el cliente se quede en el mismo nivel, estos dos numeros
   avanzan juntos, entonces la RESTA entre ellos siempre da el mismo
   resultado. En el momento que el cliente cambia de nivel, la resta
   cambia de valor.

   Ejemplo con un cliente que tuvo: N1, N1, N2, N2, N2, N1

   mes | nivel | posicion total | posicion en su nivel | resta
   ----|-------|-----------------|------------------------|------
   1   | N1    | 1               | 1                      | 0
   2   | N1    | 2               | 2                      | 0
   3   | N2    | 3               | 1                      | 2
   4   | N2    | 4               | 2                      | 2
   5   | N2    | 5               | 3                      | 2
   6   | N1    | 6               | 3                      | 3

   La columna "resta" queda igual mientras dura cada racha, y
   cambia cuando el nivel cambia. Por eso sirve para agrupar:
   agrupando por cliente + nivel + resta, cada grupo es una racha.
*/
DROP VIEW IF EXISTS v_rachas;
CREATE VIEW v_rachas AS
WITH marcado AS (
    SELECT
        identificacion,
        corte_mes,
        nivel,
        ROW_NUMBER() OVER (PARTITION BY identificacion        ORDER BY corte_mes)
      - ROW_NUMBER() OVER (PARTITION BY identificacion, nivel ORDER BY corte_mes)
          AS isla
    FROM v_panel_mensual
)
SELECT
    identificacion,
    nivel,
    COUNT(*)       AS racha,
    MIN(corte_mes) AS fecha_inicio,
    MAX(corte_mes) AS fecha_fin
FROM marcado
GROUP BY identificacion, nivel, isla