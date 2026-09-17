
 --================================================
 --  Archivo: 02_calidad_datos.sql
 -- Moisés Arrieta
 -- 17-09-2026
 --================================================
/*
   Este archivo hace dos cosas:
   1. Revisa que los datos esten bien (reglas de calidad)
   2. Pasa los datos buenos de la tabla "cruda" (stg_) a la tabla limpia (historia)

   Lo que no pasa una regla, no se borra: se guarda en una tabla
   de cuarentena (q_historia o q_retiros) junto con el motivo del rechazo.

   Problemas que se encontraron en el archivo real:
   1. Una fila duplicada exacta (mismo cliente, mismo mes, mismo saldo)
   2. Un duplicado con saldos distintos (571.481 vs 1.142.962)
      -> esto es importante porque cambia el nivel del cliente de N1 a N2
   3. Un retiro con una identificacion que no existe en la tabla de historia
   4. 14 casos donde el cliente tiene saldo despues de su fecha de retiro
*/


/*
   PASO 1: revisar que cada fila tenga lo minimo para ser valida.

   Si algo esta mal (identificacion vacia, fecha invalida, saldo negativo,
   o el corte de mes no es un fin de mes real), la fila se manda a
   cuarentena junto con la razon exacta del rechazo.
*/
INSERT INTO q_historia (identificacion, corte_mes, saldo, motivo)
SELECT identificacion, corte_mes, saldo,
       CASE
           WHEN identificacion IS NULL OR TRIM(identificacion) = ''
               THEN 'identificacion vacia'
           WHEN corte_mes IS NULL
               THEN 'la fecha no se pudo leer'
           WHEN saldo IS NULL
               THEN 'saldo vacio'
           WHEN saldo < 0
               THEN 'saldo negativo, no se puede clasificar'
           WHEN corte_mes <> DATE(corte_mes, 'start of month', '+1 month', '-1 day')
               THEN 'la fecha no es un fin de mes'
       END
FROM stg_historia
WHERE identificacion IS NULL OR TRIM(identificacion) = ''
   OR corte_mes IS NULL
   OR saldo IS NULL
   OR saldo < 0
   OR corte_mes <> DATE(corte_mes, 'start of month', '+1 month', '-1 day');


/*
   PASO 2: resolver los duplicados (mismo cliente, mismo mes, varias filas).

   Regla que decidimos: si hay dos saldos distintos para el mismo
   cliente en el mismo mes, nos quedamos con el MAS ALTO.
   Razon: en un tema de deudas, es mejor sobreestimar que subestimar
   lo que debe un cliente.

   Como se hace: a cada fila del mismo cliente+mes se le pone un
   numero (1, 2, 3...) empezando por el saldo mas alto. Nos quedamos
   solo con las que les toco el numero 1.
*/
DROP TABLE IF EXISTS tmp_historia_ranked;
CREATE TEMP TABLE tmp_historia_ranked AS
WITH valida AS (
    SELECT identificacion, corte_mes, CAST(saldo AS INTEGER) AS saldo
    FROM stg_historia
    WHERE identificacion IS NOT NULL AND TRIM(identificacion) <> ''
      AND corte_mes IS NOT NULL
      AND saldo IS NOT NULL
      AND saldo >= 0
      AND corte_mes = DATE(corte_mes, 'start of month', '+1 month', '-1 day')
)
SELECT
    identificacion,
    corte_mes,
    saldo,
    ROW_NUMBER() OVER (
        PARTITION BY identificacion, corte_mes
        ORDER BY saldo DESC
    ) AS rn,
    /*
       SQLite no permite contar valores distintos (COUNT DISTINCT)
       dentro de estas funciones de ventana. Para saber si dos filas
       del mismo grupo tienen saldos diferentes, comparamos el minimo
       contra el maximo: si son iguales, es un duplicado exacto;
       si son distintos, hay que decidir cual usar.
    */
    MIN(saldo) OVER (PARTITION BY identificacion, corte_mes) AS saldo_min,
    MAX(saldo) OVER (PARTITION BY identificacion, corte_mes) AS saldo_max
FROM valida;

INSERT INTO q_historia (identificacion, corte_mes, saldo, motivo)
SELECT identificacion, corte_mes, saldo,
       CASE WHEN saldo_min = saldo_max
            THEN 'fila repetida exactamente igual, se descarta la copia'
            ELSE 'habia dos saldos distintos, se dejo el mas alto'
       END
FROM tmp_historia_ranked
WHERE rn > 1;

INSERT INTO historia (identificacion, corte_mes, saldo)
SELECT identificacion, corte_mes, saldo
FROM tmp_historia_ranked
WHERE rn = 1;


/*
   PASO 3: revisar los retiros.

   Un retiro solo sirve si el cliente existe en la tabla de historia.
   Si la identificacion no aparece ahi, no se puede usar ese retiro
   y se manda a cuarentena.

   Decision importante: no se intenta "adivinar" a que cliente
   pertenece una identificacion rara con base en que se parezca a otra.
   Eso podria asignarle una fecha de retiro a la persona equivocada.
   Se aisla y ya, para que alguien revise el dato de origen.
*/
INSERT INTO q_retiros (identificacion, fecha_retiro, motivo)
SELECT s.identificacion, s.fecha_retiro,
       CASE
           WHEN s.identificacion IS NULL OR TRIM(s.identificacion) = ''
               THEN 'identificacion vacia'
           WHEN s.fecha_retiro IS NULL
               THEN 'la fecha de retiro no se pudo leer'
           ELSE 'esta identificacion no existe en la tabla de historia'
       END
FROM stg_retiros s
WHERE s.identificacion IS NULL OR TRIM(s.identificacion) = ''
   OR s.fecha_retiro IS NULL
   OR NOT EXISTS (
        SELECT 1 FROM historia h WHERE h.identificacion = s.identificacion
   );

/* Si un mismo cliente tuviera mas de una fecha de retiro, nos quedamos
   con la mas antigua, porque esa fue la primera vez que se retiro. */
INSERT INTO retiros (identificacion, fecha_retiro)
SELECT s.identificacion, MIN(s.fecha_retiro)
FROM stg_retiros s
WHERE s.identificacion IS NOT NULL AND TRIM(s.identificacion) <> ''
  AND s.fecha_retiro IS NOT NULL
  AND EXISTS (SELECT 1 FROM historia h WHERE h.identificacion = s.identificacion)
GROUP BY s.identificacion;


/*
   PASO 4: una vista que resume todo lo que paso en la carga.
   Sirve para el ejercicio 2 (el de calidad de datos), como base
   para mostrar en un tablero cuantos datos entraron, cuantos
   se limpiaron bien y cuantos se rechazaron.
*/
DROP VIEW IF EXISTS v_reporte_calidad;
CREATE VIEW v_reporte_calidad AS
    SELECT 'historia: filas que llegaron' AS metrica, COUNT(*) AS valor FROM stg_historia
    UNION ALL
    SELECT 'historia: filas que quedaron buenas', COUNT(*) FROM historia
    UNION ALL
    SELECT 'historia: filas rechazadas', COUNT(*) FROM q_historia
    UNION ALL
    SELECT 'historia: clientes distintos', COUNT(DISTINCT identificacion) FROM historia
    UNION ALL
    SELECT 'retiros: filas que llegaron', COUNT(*) FROM stg_retiros
    UNION ALL
    SELECT 'retiros: filas que quedaron buenas', COUNT(*) FROM retiros
    UNION ALL
    SELECT 'retiros: filas rechazadas', COUNT(*) FROM q_retiros
    UNION ALL
    /* Este caso no se rechaza, solo se reporta como alerta:
       son saldos que aparecen despues de que el cliente ya se
       habia retirado. No se borran porque es informacion real,
       pero la consulta de rachas los va a ignorar. */
    SELECT 'alerta: saldos despues del retiro', COUNT(*)
    FROM historia h
    JOIN retiros r USING (identificacion)
    WHERE h.corte_mes > r.fecha_retiro;