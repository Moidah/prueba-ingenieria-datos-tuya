"""
Este programa busca archivos HTML, encuentra las imagenes que tienen
(etiquetas <img>), las convierte a base64, y genera un archivo nuevo
con esas imagenes ya incrustadas. El archivo original nunca se toca.

uso solo librerias que ya vienen con Python (no hace falta instalar nada).
"""

from __future__ import annotations

import base64
import json
import mimetypes
from html.parser import HTMLParser
from pathlib import Path


class BuscadorDeImagenes(HTMLParser):
    """
    Esta clase pequeña usa html.parser (que ya trae Python) para
    encontrar las etiquetas <img> dentro de un HTML.

    No se usa una expresion regular a proposito: una regex se puede
    confundir facilmente con un <img> que este dentro de un comentario
    o mal escrito, mientras que html.parser entiende la estructura
    real del documento.
    """

    def __init__(self) -> None:
        super().__init__()
        self.imagenes_encontradas = []  # aqui se van guardando

    def handle_starttag(self, tag, attrs):
        if tag.lower() != "img":
            return
        # attrs es una lista de tuplas, por ejemplo [("src", "foto.png"), ("alt", "perro")]
        for nombre, valor in attrs:
            if nombre.lower() == "src" and valor:
                # guardamos tambien el texto exacto de la etiqueta,
                # para poder reemplazarla despues sin dañar el resto del HTML
                self.imagenes_encontradas.append({
                    "src": valor,
                    "etiqueta_completa": self.get_starttag_text(),
                })
                break


class ProcesadorHTML:
    """
    Esta es la clase principal. Se encarga de:
    1. buscar los archivos HTML (en archivos sueltos o carpetas)
    2. procesarlos uno por uno
    3. llevar un registro de que imagenes se convirtieron bien y cuales no
    """

    def __init__(self):
        # Aca se va guardando el resultado final, con la forma que pide el ejercicio
        self.resultado = {"success": {}, "fail": {}}

    def buscar_archivos_html(self, rutas: list[str]) -> list[Path]:
        """
        Recibe una lista de rutas, que pueden ser archivos .html
        sueltos o carpetas. Si es una carpeta, busca todos los .html
        de adentro, incluyendo subcarpetas.
        """
        encontrados = []
        for ruta_texto in rutas:
            ruta = Path(ruta_texto)
            if ruta.is_file() and ruta.suffix.lower() in (".html", ".htm"):
                encontrados.append(ruta)
            elif ruta.is_dir():
                # rglob busca en la carpeta Y en todas sus subcarpetas
                encontrados.extend(ruta.rglob("*.html"))
                encontrados.extend(ruta.rglob("*.htm"))
        return encontrados

    def imagen_a_base64(self, ruta_imagen: Path) -> str:
        """
        Lee una imagen del disco y la convierte a un 'data URI',
        que es el formato que entienden los navegadores para mostrar
        una imagen incrustada directamente en el HTML, sin archivo aparte.

        Ejemplo de como se ve un data URI:
            data:image/png;base64,iVBORw0KGgoAAAANSUhEUgA...
        """
        datos = ruta_imagen.read_bytes()
        texto_base64 = base64.b64encode(datos).decode("ascii")

        # Adivinamos el tipo de imagen (png, jpg, etc) mirando la extension del archivo
        tipo, _ = mimetypes.guess_type(str(ruta_imagen))
        if tipo is None:
            tipo = "application/octet-stream"  # tipo generico si no se pudo adivinar

        return f"data:{tipo};base64,{texto_base64}"

    def procesar_un_archivo(self, ruta_html: Path) -> None:
        """
        Procesa un solo archivo HTML: busca sus imagenes, las convierte,
        y escribe un archivo NUEVO con las imagenes ya incrustadas.
        """
        texto_html = ruta_html.read_text(encoding="utf-8", errors="replace")

        buscador = BuscadorDeImagenes()
        buscador.feed(texto_html)

        html_nuevo = texto_html

        for imagen in buscador.imagenes_encontradas:
            src_original = imagen["src"]
            etiqueta_original = imagen["etiqueta_completa"]

            try:
                # la ruta de la imagen es relativa a donde esta el HTML
                ruta_imagen = ruta_html.parent / src_original

                if not ruta_imagen.is_file():
                    raise FileNotFoundError(f"no se encontro el archivo: {ruta_imagen}")

                data_uri = self.imagen_a_base64(ruta_imagen)

                # reemplazamos SOLO el src dentro del texto de la etiqueta,
                # dejando intactos los demas atributos (alt, width, etc)
                etiqueta_nueva = etiqueta_original.replace(src_original, data_uri)
                html_nuevo = html_nuevo.replace(etiqueta_original, etiqueta_nueva)

                self._anotar_exito(ruta_html, src_original)

            except Exception as error:
                self._anotar_fallo(ruta_html, src_original, str(error))

        # Se escribe un archivo NUEVO, el original queda intacto
        ruta_salida = ruta_html.with_name(ruta_html.stem + ".inline" + ruta_html.suffix)
        ruta_salida.write_text(html_nuevo, encoding="utf-8")
        print(f"Se genero: {ruta_salida}")

    def procesar(self, rutas: list[str]) -> dict:
        """
        Este es el metodo que se usa desde afuera. Recibe la lista de
        archivos o carpetas, procesa todo, y devuelve el resultado final.
        """
        archivos = self.buscar_archivos_html(rutas)

        if not archivos:
            print("No se encontro ningun archivo HTML en las rutas dadas.")

        for archivo in archivos:
            self.procesar_un_archivo(archivo)

        return self.resultado

    def _anotar_exito(self, archivo: Path, src: str) -> None:
        clave = str(archivo)
        self.resultado["success"].setdefault(clave, []).append(src)

    def _anotar_fallo(self, archivo: Path, src: str, motivo: str) -> None:
        clave = str(archivo)
        self.resultado["fail"].setdefault(clave, {})[src] = motivo


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Uso: python procesador_imagenes.py archivo_o_carpeta [otro_archivo_o_carpeta ...]")
        sys.exit(1)

    rutas_a_procesar = sys.argv[1:]

    procesador = ProcesadorHTML()
    resultado_final = procesador.procesar(rutas_a_procesar)

    print("\nResultado final:")
    print(json.dumps(resultado_final, indent=2, ensure_ascii=False))