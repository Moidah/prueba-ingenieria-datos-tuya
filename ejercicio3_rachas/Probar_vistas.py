import sqlite3
import pandas as pd

conn = sqlite3.connect('data/rachas.db')

with open('sql/03_vistas_rachas.sql', encoding='utf-8') as f:
    contenido = f.read()

conn.executescript(contenido)

resultado = pd.read_sql_query(
    "SELECT * FROM v_rachas ORDER BY identificacion, fecha_inicio", conn
)
print(resultado.head(20))
print(resultado.shape)

# # Verificar un cliente puntual a mano
# cliente = pd.read_sql_query(
#     "SELECT * FROM v_panel_mensual WHERE identificacion = '09SYGN7IXDQV5X9IP' ORDER BY corte_mes",
#     conn
# )
# print(cliente.to_string(index=False))