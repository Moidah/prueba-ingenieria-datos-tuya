"""
Este script comprueba que el resultado de la consulta SQL sea correcto.

La idea es simple: se vuelve a calcular el mismo resultado, pero con
un metodo totalmente distinto (usando pandas en vez de SQL), y se
comparan los dos resultados. Si dan exactamente lo mismo en varios
casos distintos, es muy poco probable que los dos tengan el mismo
error por casualidad, asi que confirma que la logica esta bien.

Como usarlo:
    python src/validar_rachas.py
"""

from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from consultar_rachas import consultar  # esto reusa la funcion del script anterior

RUTA_DB = Path("data/rachas.db")

# Distintas combinaciones de fecha_base y n para probar varios escenarios,
# no solo uno. Incluye un caso extremo (n=24) donde no deberia salir nadie.
CASOS = [
    ("2024-12-31", 3),
    ("2024-12-31", 6),
    ("2024-06-30", 4),
    ("2023-12-31", 2),
    ("2024-12-31", 24),
]


def clasificar(saldo: float) -> str:
    """Misma escala de niveles que en el SQL, pero escrita en Python."""
    if saldo < 300_000:
        return "N0"
    if saldo < 1_000_000:
        return "N1"
    if saldo < 3_000_000:
        return "N2"
    if saldo < 5_000_000:
        return "N3"
    return "N4"


def rachas_pandas(db: Path, fecha_base: str, n_minimo: int) -> pd.DataFrame:
    """
    Calcula las rachas usando solo pandas, sin usar nada del archivo SQL.
    Sigue los mismos pasos que las vistas de SQL, pero con otro codigo.
    """
    with sqlite3.connect(db) as conn:
        historia = pd.read_sql_query("SELECT * FROM historia", conn)
        retiros = pd.read_sql_query("SELECT * FROM retiros", conn)

    historia["corte_mes"] = pd.to_datetime(historia["corte_mes"])
    retiros["fecha_retiro"] = pd.to_datetime(retiros["fecha_retiro"])
    fb = pd.Timestamp(fecha_base)

    # Paso 1: el calendario, igual que en el SQL
    calendario = pd.date_range(
        historia["corte_mes"].min(), fb + pd.offsets.MonthEnd(0), freq="ME"
    )

    # Paso 2: la vigencia de cada cliente (desde su primer mes hasta su retiro o fecha_base)
    vigencia = historia.groupby("identificacion")["corte_mes"].min().rename("inicio").reset_index()
    vigencia = vigencia.merge(retiros, on="identificacion", how="left")
    vigencia["fin"] = vigencia["fecha_retiro"].fillna(fb).clip(upper=fb)

    # Paso 3: armar el panel mensual, cliente por cliente, mes por mes
    filas = []
    for _, cli in vigencia.iterrows():
        meses = calendario[(calendario >= cli["inicio"]) & (calendario <= cli["fin"])]
        for mes in meses:
            filas.append({"identificacion": cli["identificacion"], "corte_mes": mes})
    panel = pd.DataFrame(filas)
    if panel.empty:
        return pd.DataFrame(columns=["identificacion", "racha", "fecha_fin", "nivel"])

    panel = panel.merge(historia, on=["identificacion", "corte_mes"], how="left")
    panel["saldo"] = panel["saldo"].fillna(0)
    panel["nivel"] = panel["saldo"].apply(clasificar)
    panel = panel.sort_values(["identificacion", "corte_mes"])

    # Paso 4: detectar las rachas. Aqui en vez del truco de las dos
    # posiciones (como en SQL), se hace mas directo: se marca una
    # racha nueva cada vez que el nivel cambia o cambia de cliente.
    cambio = (
        (panel["nivel"] != panel["nivel"].shift())
        | (panel["identificacion"] != panel["identificacion"].shift())
    )
    panel["isla"] = cambio.cumsum()

    rachas = (
        panel.groupby(["identificacion", "nivel", "isla"])
        .agg(racha=("corte_mes", "size"), fecha_fin=("corte_mes", "max"))
        .reset_index()
    )
    rachas = rachas[rachas["racha"] >= n_minimo]
    if rachas.empty:
        return pd.DataFrame(columns=["identificacion", "racha", "fecha_fin", "nivel"])

    # Mismo desempate que en el SQL: primero la racha mas larga,
    # despues la mas reciente
    rachas = rachas.sort_values(
        ["identificacion", "racha", "fecha_fin"], ascending=[True, False, False]
    )
    mejor = rachas.groupby("identificacion", as_index=False).first()
    mejor["fecha_fin"] = mejor["fecha_fin"].dt.strftime("%Y-%m-%d")
    return mejor[["identificacion", "racha", "fecha_fin", "nivel"]]


def normalizar(df: pd.DataFrame) -> pd.DataFrame:
    """Deja los dos resultados (SQL y pandas) en el mismo formato para poder compararlos."""
    if df.empty:
        return df
    df = df.copy()
    df["fecha_fin"] = df["fecha_fin"].astype(str).str[:10]
    df["racha"] = df["racha"].astype(int)
    return df.sort_values("identificacion").reset_index(drop=True)


def main() -> int:
    errores = 0
    for fecha_base, n in CASOS:
        esperado = normalizar(rachas_pandas(RUTA_DB, fecha_base, n))
        obtenido = normalizar(consultar(RUTA_DB, fecha_base, n))
        iguales = esperado.equals(obtenido)
        estado = "OK   " if iguales else "FALLA"
        print(f"{estado} fecha_base={fecha_base} n={n:>2} -> {len(obtenido)} clientes")
        if not iguales:
            errores += 1
            print("  Resultado de SQL:\n", obtenido.head(10))
            print("  Resultado de pandas:\n", esperado.head(10))
    print("\nResultado final:", "todo paso bien" if not errores else f"{errores} casos fallaron")
    return 1 if errores else 0


if __name__ == "__main__":
    raise SystemExit(main())