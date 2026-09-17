"""
Ejecuta la consulta de rachas sobre la base ya cargada.

Como usarlo:
    python src/consultar_rachas.py --fecha-base 2024-12-31 --n 6
    python src/consultar_rachas.py --fecha-base 2024-06-30 --n 3 --csv salida.csv
"""

from __future__ import annotations

import argparse
import sqlite3
from datetime import date
from pathlib import Path

import pandas as pd

SQL_DIR = Path(__file__).resolve().parent.parent / "sql"


def fecha_valida(texto: str) -> str:
    """Revisa que la fecha tenga el formato correcto antes de usarla."""
    return date.fromisoformat(texto).isoformat()


def consultar(ruta_db: Path, fecha_base: str, n_minimo: int) -> pd.DataFrame:
    with sqlite3.connect(ruta_db) as conn:
        # Paso 1: actualizar los parametros con los valores pedidos
        conn.execute(
            "UPDATE parametros SET fecha_base = ?, n_minimo = ? WHERE id = 1",
            (fecha_base, n_minimo),
        )

        # Paso 2: volver a crear las vistas (para que usen los parametros nuevos)
        conn.executescript((SQL_DIR / "03_vistas_rachas.sql").read_text(encoding="utf-8"))

        # Paso 3: correr la consulta final y devolverla como tabla
        return pd.read_sql_query(
            (SQL_DIR / "04_consulta_final.sql").read_text(encoding="utf-8"), conn
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Consulta de rachas por nivel de saldo")
    parser.add_argument("--db", type=Path, default=Path("data/rachas.db"))
    parser.add_argument("--fecha-base", type=fecha_valida, default="2024-12-31",
                        help="Fecha en la que se 'para' el analisis (formato AAAA-MM-DD)")
    parser.add_argument("--n", type=int, default=3,
                        help="Cuantos meses seguidos minimo debe tener la racha")
    parser.add_argument("--csv", type=Path, default=None,
                        help="Si se pone, guarda el resultado en un archivo csv")
    args = parser.parse_args()

    if args.n < 1:
        parser.error("--n debe ser 1 o mas")

    resultado = consultar(args.db, args.fecha_base, args.n)

    print(f"\nfecha_base = {args.fecha_base} | n minimo = {args.n}")
    print(f"clientes con racha que cumple: {len(resultado)}\n")
    print(resultado.to_string(index=False) if not resultado.empty else "No hay resultados.")

    if args.csv:
        args.csv.parent.mkdir(parents=True, exist_ok=True)
        resultado.to_csv(args.csv, index=False)
        print(f"\nResultado guardado en {args.csv}")


if __name__ == "__main__":
    main()