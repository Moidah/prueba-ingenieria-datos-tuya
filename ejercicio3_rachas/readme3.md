# Ejercicio 3 - Rachas por nivel de saldo

## Como correrlo

```bash
pip install -r ../requirements.txt

python src/cargar_datos.py --excel data/Rachas.xlsx --db data/rachas.db
python src/consultar_rachas.py --fecha-base 2024-12-31 --n 6
python src/validar_rachas.py
```

Se uso **SQLite**, que ya viene incluido con Python, no hay que instalar ni configurar ningun servidor aparte.

## Los archivos SQL, en orden

| Archivo | Que hace |
|---|---|
| `01_esquema.sql` | Crea las tablas (las crudas, las limpias, las de cuarentena y la de parametros) |
| `02_calidad_datos.sql` | Aplica las reglas de calidad y pasa los datos buenos a las tablas limpias |
| `03_vistas_rachas.sql` | Arma el calendario, calcula desde cuando hasta cuando cuenta cada cliente, y encuentra las rachas |
| `04_consulta_final.sql` | Filtra el resultado y entrega lo que pide el ejercicio |

## Las tablas principales

**`historia`** - el saldo de cada cliente, mes a mes

| Campo | Que es |
|---|---|
| `identificacion` | el cliente |
| `corte_mes` | el mes del saldo (siempre el ultimo dia del mes) |
| `saldo` | cuanto debia ese mes |

**`retiros`** - cuando un cliente se dio de baja

| Campo | Que es |
|---|---|
| `identificacion` | el cliente |
| `fecha_retiro` | el dia exacto en que se retiro |

**`parametros`** - aqui se configuran los dos valores que pide el ejercicio

| Campo | Que es |
|---|---|
| `fecha_base` | la fecha en la que uno se "para" para hacer el analisis |
| `n_minimo` | cuantos meses seguidos minimo debe durar una racha para contar |

## Los niveles de saldo

| Nivel | Rango |
|---|---|
| N0 | de 0 hasta menos de 300.000 |
| N1 | de 300.000 hasta menos de 1.000.000 |
| N2 | de 1.000.000 hasta menos de 3.000.000 |
| N3 | de 3.000.000 hasta menos de 5.000.000 |
| N4 | 5.000.000 o mas |

## Problemas que se encontraron en los datos

Revisando el archivo antes de programar, aparecieron 4 problemas:

**1. Una fila repetida exactamente igual.** Un cliente aparece dos veces en el mismo mes con el mismo saldo. Se guarda una sola vez y la copia se manda a la tabla de cuarentena.

**2. Un cliente con dos saldos distintos en el mismo mes.** Uno era 571.481 y el otro 1.142.962. Esto si importa, porque un valor cae en el nivel N1 y el otro en N2 - cambia el resultado para ese cliente. El enunciado no dice que hacer en este caso, asi que se decidio quedarse con el saldo mas alto, pensando que en temas de deuda es mejor pasarse por exceso que por defecto.

**3. Un retiro que no corresponde a ningun cliente.** La identificacion tenia 19 caracteres, mientras que todas las demas tienen 17. Se parece mucho a una identificacion que si existe, pero se decidio no adivinar ni corregirla, porque eso podria terminar poniendole una fecha de retiro a la persona equivocada. Se aisla el dato y punto.

**4. 14 casos de saldo reportado despues del retiro.** El cliente ya se habia dado de baja, pero sigue apareciendo con saldo en meses posteriores. No se borra el dato porque es informacion real, pero la consulta de rachas no lo tiene en cuenta, ya que el enunciado dice que despues del retiro el cliente ya no cuenta.

## Como funciona la consulta

**Paso 1: se arma un calendario.** Se generan todos los fin de mes desde el primer dato hasta la fecha_base, incluso los meses donde nadie reporto saldo, porque esos meses tambien cuentan (todos serian N0).

**Paso 2: se calcula la vigencia de cada cliente.** Desde su primer mes con saldo, hasta la fecha_base o su retiro (lo que llegue primero).

**Paso 3: se arma una tabla sin huecos.** Se cruza cada cliente con todos los meses de su vigencia. Donde no hay saldo reportado, se le pone 0, que cae automaticamente en N0.

**Paso 4: se agrupan los meses seguidos con el mismo nivel.** Aqui se usa un truco: a cada mes se le pone un numero segun su posicion en la lista completa del cliente, y otro numero segun su posicion dentro de los meses de ese mismo nivel. Mientras el nivel no cambie, la resta entre esos dos numeros se mantiene igual. Cuando el nivel cambia, la resta cambia tambien. Asi se puede saber donde empieza y donde termina cada racha.

Ejemplo con un cliente que tuvo estos niveles seguidos: N1, N1, N2, N2, N2, N1

| Mes | Nivel | Resta |
|---|---|---|
| 1 | N1 | 0 |
| 2 | N1 | 0 |
| 3 | N2 | 2 |
| 4 | N2 | 2 |
| 5 | N2 | 2 |
| 6 | N1 | 3 |

Resultado: tres rachas. Una de N1 con 2 meses, una de N2 con 3 meses, y otra de N1 con 1 mes.

**Paso 5: se filtra y se elige la mejor racha por cliente.** Solo quedan las rachas que tengan igual o mas meses que el `n` pedido. Si un cliente tiene varias que cumplen, se elige la mas larga, y si hay empate, la que haya terminado mas reciente.

## Como se comprobo que esta bien

Se volvio a calcular todo el resultado, pero con otro metodo totalmente distinto: en vez de SQL, se hizo con Python y pandas. Se compararon los dos resultados en 5 casos distintos y coincidieron exactamente en todos:

```
OK   fecha_base=2024-12-31 n= 3 -> 91 clientes
OK   fecha_base=2024-12-31 n= 6 -> 2 clientes
OK   fecha_base=2024-06-30 n= 4 -> 29 clientes
OK   fecha_base=2023-12-31 n= 2 -> 140 clientes
OK   fecha_base=2024-12-31 n=24 -> 0 clientes
```

Que dos formas de calcular lo mismo, hechas de manera totalmente distinta, den el mismo resultado, da mucha mas confianza de que la logica esta bien hecha.

## Ejemplo de resultado

Con `fecha_base = 2024-12-31` y `n = 6`:

| identificacion | racha | fecha_fin | nivel |
|---|---|---|---|
| IGOQX9YBSRDMOZXT | 6 | 2023-12-31 | N4 |
| DWJ0GFUKS12L7Y0G9 | 6 | 2023-11-30 | N2 |

## Si el archivo fuera mucho mas grande

Con las 2.925 filas de este ejercicio, SQLite funciona sin problema. Si en vez de eso fueran millones de filas, la misma idea se puede llevar a una herramienta como Spark, con algunos ajustes:

- Guardar la tabla del paso 3 (la de sin huecos) ya calculada, en vez de calcularla cada vez que se hace una consulta.
- Dividir los datos por cliente, ya que toda la logica trabaja cliente por cliente. Esto evita que el sistema tenga que mover datos de un lado a otro innecesariamente.
- Si en el futuro hay uno o pocos clientes con muchisimos mas registros que el resto, eso podria hacer que el proceso se vuelva lento en esa parte especifica, y tocaria revisarlo aparte.