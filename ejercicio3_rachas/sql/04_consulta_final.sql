/*
   Archivo: 04_consulta_final.sql

   Esta es la consulta que da el resultado final del ejercicio.
   Necesita que ya se hayan corrido los archivos anteriores
   (especialmente 03_vistas_rachas.sql, porque usa la vista v_rachas).

   Que hace:
   1. Se queda solo con las rachas que sean iguales o mas largas que "n"
   2. Si un cliente tiene mas de una racha que cumple, elige UNA sola,
      con este criterio de desempate:
      a) primero, la racha mas larga
      b) si hay empate en la longitud, la que haya terminado mas reciente
*/

WITH rachas_elegibles AS (
    SELECT
        identificacion,
        racha,
        fecha_fin,
        nivel,
        /*
           A cada racha de un mismo cliente se le pone un numero de
           orden: la numero 1 es la que gana, segun el criterio de
           desempate (primero la mas larga, despues la mas reciente).
        */
        ROW_NUMBER() OVER (
            PARTITION BY identificacion
            ORDER BY racha DESC, fecha_fin DESC
        ) AS prioridad
    FROM v_rachas
    WHERE racha >= (SELECT n_minimo FROM parametros)
)
SELECT
    identificacion,
    racha,
    fecha_fin,
    nivel
FROM rachas_elegibles
WHERE prioridad = 1
ORDER BY racha DESC, fecha_fin DESC, identificacion