# Prueba tecnica - Ingenieria de Datos jr

Este repositorio tiene la solucion a la prueba tecnica. Aqui te cuento de que trata cada parte.

## Ejercicio 1 - Dataset de telefonos de clientes

El problema principal no es tecnico, es que las distintas areas de la empresa (CRM, originacion, cobranza, etc) tienen numeros distintos para el mismo cliente, y ninguna fuente es "la correcta" siempre.

La solucion propuesta organiza el dato en capas: primero se guarda tal cual llega (sin tocarlo, para no perder informacion), despues se normaliza a un formato unico, luego se revisan reglas de calidad, y al final queda una sola tabla con el mejor numero por cliente. Para decidir cual numero es el mejor cuando hay varios, se usa un puntaje que tiene en cuenta que tan reciente es el dato, si el cliente contesto cuando lo llamaron, y que tan confiable es la fuente de donde salio.

Tambien se explica como este proceso se automatiza con un pipeline que revisa la calidad antes de publicar cualquier cambio, para que nunca se suba un dato malo a produccion sin que alguien se de cuenta.

Ver el detalle completo en [`docs/01_dataset_telefonos.md`](docs/01_dataset_telefonos.md).

## Ejercicio 2 - Como revisar la calidad de los datos

Este ejercicio responde una pregunta practica: si el dataset del ejercicio 1 ya existe, como hace alguien de negocio para confiar en el sin tener que preguntarle siempre al equipo de datos.

La propuesta es un sistema con dos partes. La primera mide que tan buena es la calidad del dato en distintos aspectos (si falta informacion, si tiene el formato correcto, si hay duplicados raros, si esta actualizado, etc), y guarda ese historial para poder ver si la calidad mejora o empeora con el tiempo. La segunda parte permite buscar un cliente puntual y ver de donde salio su dato y por que se eligio ese numero y no otro.

Todo esto se muestra en un tablero con distintas vistas, pensado para que cada tipo de usuario vea lo que realmente necesita, sin saturar a nadie con informacion que no le sirve.

Ver el detalle completo en [`docs/02_kpis_calidad.md`](docs/02_kpis_calidad.md).

## Ejercicio 3 - Rachas de saldo

### El problema

En el archivo `Rachas.xlsx` hay informacion de saldos de clientes mes a mes. Con eso hay que armar una consulta que encuentre, para cada cliente, la racha mas larga de meses seguidos en la que se mantuvo en el mismo nivel de deuda (los niveles van de N0 a N4, segun el monto del saldo).

Ademas, si el cliente no aparece reportado en algun mes, se asume que su saldo es N0 (a menos que ya se hubiera retirado antes de esa fecha). Y todo el ejercicio se puede correr como si uno estuviera "parado" en cualquier fecha, no solo en la fecha de hoy.

Antes de escribir cualquier consulta, se reviso el archivo con cuidado y aparecieron 4 problemas reales en los datos:

1. Una fila que estaba duplicada exactamente igual (mismo cliente, mismo mes, mismo saldo).
2. Un cliente con dos saldos distintos en el mismo mes (571.481 y 1.142.962). Esto no es un detalle menor, porque un saldo cae en el nivel N1 y el otro en N2, asi que la decision que se tome si afecta el resultado.
3. Un retiro con un numero de identificacion que no existe en la tabla de saldos. Se parece mucho a otro numero que si existe, pero se decidio no corregirlo adivinando, porque eso podria terminar asignandole una fecha de retiro a la persona equivocada.
4. 14 casos donde el cliente sigue apareciendo con saldo despues de la fecha en la que ya se habia retirado.

### La solucion

Los datos se cargan a una base de datos SQLite en tres capas: primero se guardan tal cual vienen del Excel, despues se aplican las reglas de calidad (lo que no pasa se manda a una tabla aparte con el motivo del rechazo, nunca se borra en silencio), y al final queda una tabla limpia con la que se trabaja.

La consulta de rachas usa un patron conocido en SQL llamado "gaps and islands", que basicamente agrupa los meses seguidos donde el cliente se mantuvo en el mismo nivel. El resultado se filtra para quedarse solo con las rachas que cumplan el minimo de meses pedido, y si un cliente tiene mas de una racha que cumple, se elige la mas larga (y si hay empate, la mas reciente).

Para confirmar que todo esta bien calculado, se hizo la misma logica dos veces por caminos completamente distintos: una vez en SQL y otra en Python con pandas. Los dos resultados coinciden en varios escenarios de prueba, lo cual da confianza de que la consulta esta bien hecha.

### Como correrlo

Necesitas Python instalado, con las librerias `pandas` y `openpyxl`. Si no las tienes:

```
pip install pandas openpyxl
```

Despues, parado dentro de la carpeta `ejercicio3_rachas`, corres estos tres comandos en orden:

```
python src/cargar_datos.py --excel data/Rachas.xlsx --db data/rachas.db
python src/consultar_rachas.py --fecha-base 2024-12-31 --n 6
python src/validar_rachas.py
```

El primero carga el Excel a la base de datos y aplica las reglas de calidad. El segundo corre la consulta de rachas, y puedes cambiar la fecha y el numero minimo de meses como quieras. El tercero corre la validacion cruzada contra pandas, para confirmar que el resultado es correcto.

Si quieres ver el detalle completo de como esta armada la consulta paso a paso, esta explicado en [`ejercicio3_rachas/README.md`](ejercicio3_rachas/README.md).

## Ejercicio 4 - Imagenes de HTML a base64

Un programa que busca archivos HTML (sueltos o dentro de carpetas), encuentra sus imagenes, las convierte a base64, y genera un archivo nuevo con las imagenes ya incrustadas, sin tocar el original. Al final entrega un resumen de que imagenes se convirtieron bien y cuales fallaron. Se hizo usando solo lo que ya viene incluido en Python, sin instalar nada externo.

Mas detalle en [`ejercicio4_html_base64/README.md`](ejercicio4_html_base64/README.md).

## Sobre la organizacion de este repositorio

Cada ejercicio tiene su propia carpeta, y adentro de cada una hay un `README.md` que explica con mas detalle el problema, la solucion y como correr el codigo. Este archivo de aca es solo un resumen general para tener una vista rapida de todo el proyecto.
