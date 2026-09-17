"""
Este script carga el archivo Rachas.xlsx a una base de datos SQLite,
aplicando las reglas de calidad antes de dejar el dato en las tablas
finales (historia y retiros).

Como usarlo:
    python src/cargar_datos.py --excel data/Rachas.xlsx --db data/rachas.db
"""

from __future__ import annotations

import argparse
import logging
import sqlite3
from pathlib import Path

import pandas as pd

logging.basicConfig(level=logging.INFO, format="%(levelname)s | %(message)s")
log = logging.getLogger("cargar_datos")

# Carpeta donde estan los archivos .sql
SQL_DIR = Path(__file__).resolve().parent.parent / "sql"


def leer_excel(ruta_excel: Path) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Lee las dos hojas del Excel, tal cual vienen, sin cambiarles nada todavia."""
    historia = pd.read_excel(ruta_excel, sheet_name="historia")
    retiros = pd.read_excel(ruta_excel, sheet_name="retiros")
    log.info("Excel leido: historia=%s filas, retiros=%s filas", len(historia), len(retiros))
    return historia, retiros


def normalizar(df: pd.DataFrame, columnas_fecha: list[str]) -> pd.DataFrame:
    """
    Deja las identificaciones sin espacios y en mayusculas, y las
    fechas en formato texto tipo 'YYYY-MM-DD', que es el formato
    que espera SQLite.
    """
    df = df.copy()
    df["identificacion"] = df["identificacion"].astype(str).str.strip().str.upper()
    for col in columnas_fecha:
        df[col] = pd.to_datetime(df[col], errors="coerce").dt.strftime("%Y-%m-%d")
    return df


def ejecutar_script(conn: sqlite3.Connection, nombre: str) -> None:
    """Lee un archivo .sql de la carpeta sql/ y lo ejecuta completo."""
    ruta = SQL_DIR / nombre
    conn.executescript(ruta.read_text(encoding="utf-8"))
    log.info("Script ejecutado: %s", nombre)


def cargar(ruta_excel: Path, ruta_db: Path) -> None:
    # Si ya existe una base de datos de una corrida anterior, se borra.
    # Asi cada corrida empieza desde cero y no se acumulan datos.
    ruta_db.parent.mkdir(parents=True, exist_ok=True)
    if ruta_db.exists():
        ruta_db.unlink()
        log.info("Base de datos anterior borrada, empezamos de cero")

    historia, retiros = leer_excel(ruta_excel)
    historia = normalizar(historia, ["corte_mes"])
    retiros = normalizar(retiros, ["fecha_retiro"])

    with sqlite3.connect(ruta_db) as conn:
        # Paso 1: crear las tablas vacias
        ejecutar_script(conn, "01_esquema.sql")

        # Paso 2: meter el Excel a las tablas "crudas" (stg_)
        historia.to_sql("stg_historia", conn, if_exists="append", index=False)
        retiros.to_sql("stg_retiros", conn, if_exists="append", index=False)
        log.info("Datos crudos cargados")

        # Paso 3: aplicar las reglas de calidad y pasar a las tablas finales
        ejecutar_script(conn, "02_calidad_datos.sql")

        # Paso 4: mostrar un resumen de como quedo todo
        reporte = pd.read_sql_query("SELECT * FROM v_reporte_calidad", conn)
        log.info("Reporte de calidad:\n%s", reporte.to_string(index=False))

    log.info("Todo listo, la base quedo en: %s", ruta_db)


def main() -> None:
    parser = argparse.ArgumentParser(description="Carga Rachas.xlsx a SQLite")
    parser.add_argument("--excel", type=Path, default=Path("data/Rachas.xlsx"))
    parser.add_argument("--db", type=Path, default=Path("data/rachas.db"))
    args = parser.parse_args()
    cargar(args.excel, args.db)


if __name__ == "__main__":
    main()