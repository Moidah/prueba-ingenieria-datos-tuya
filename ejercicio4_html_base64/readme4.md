# Ejercicio 4 - Convertir imagenes de HTML a base64

## El problema

Cuando un archivo HTML usa imagenes con una ruta normal (`<img src="logo.png">`), esa imagen es un archivo aparte. Si uno quiere mandar ese HTML por correo, o guardarlo como un solo archivo sin depender de una carpeta con imagenes al lado, conviene meter la imagen directamente adentro del HTML, convertida a texto (base64). Asi el archivo queda completo por si solo, sin depender de nada mas.

Lo que pide el ejercicio es un programa que:

- reciba una lista de archivos HTML, o carpetas donde buscar HTML (incluyendo subcarpetas)
- encuentre las imagenes de cada archivo
- las convierta a base64
- genere un archivo NUEVO con las imagenes ya convertidas, sin tocar el original
- al final, devuelva un resultado que diga que imagenes se convirtieron bien y cuales fallaron

Con una restriccion importante: solo se puede usar lo que ya viene incluido en Python, sin instalar nada externo.

## La solucion

El programa tiene dos partes chiquitas.

La primera busca las etiquetas `<img>` dentro del HTML. Aca la decision clave fue no usar una expresion regular (buscar el patron de texto a mano), sino usar `html.parser`, que ya viene con Python y entiende de verdad la estructura del HTML. Esto evita errores como confundir una imagen real con una que este escrita dentro de un comentario.

La segunda parte toma cada imagen encontrada, la lee del disco, la convierte a base64, y arma lo que se llama un "data URI" (el formato que entienden los navegadores para mostrar una imagen incrustada directamente en el texto, sin archivo aparte).

Con eso ya convertido, se reemplaza unicamente el `src` original dentro de la etiqueta, dejando todos los demas atributos intactos (como `alt` o `width`). El resultado se guarda en un archivo nuevo, agregando `.inline` al nombre, para nunca tocar el original.

Si una imagen no se puede convertir (por ejemplo, porque el archivo no existe), no se detiene todo el proceso: se anota el error para esa imagen en particular y se sigue con las demas.

## Como correrlo

Con un archivo HTML suelto:

```
python procesador_imagenes.py mi_pagina.html
```

Con una carpeta completa (busca tambien en las subcarpetas):

```
python procesador_imagenes.py mi_carpeta
```

Se le pueden pasar varias rutas juntas:

```
python procesador_imagenes.py archivo1.html carpeta2 carpeta3
```

Por cada HTML encontrado, se genera un archivo nuevo con el mismo nombre mas `.inline` antes de la extension. Por ejemplo, `pagina.html` genera `pagina.inline.html`.

Al final se imprime un resumen con esta forma:

```json
{
  "success": {
    "pagina.html": ["logo.png"]
  },
  "fail": {
    "pagina.html": {
      "no_existe.png": "no se encontro el archivo: ..."
    }
  }
}
```

## Ejemplo incluido

En la carpeta `ejemplo` hay un HTML de prueba con una imagen que si existe y otra que no, para poder ver el comportamiento completo del programa (el caso que funciona y el caso que falla) en una sola corrida.

## Como se podria hacer mas grande esta solucion

Esta version quedo en un solo archivo con dos clases, pensada para que sea facil de leer y de entender. Si el proyecto creciera (por ejemplo, si se necesitara procesar miles de archivos, o traer imagenes desde internet ademas de las locales, o guardar en un log cada conversion), se podria separar el mismo trabajo en varios archivos mas pequeños, cada uno con una sola responsabilidad:

- un archivo que solo se encargue de buscar los HTML (archivos y carpetas)
- un archivo que solo busque las etiquetas `<img>` dentro de un HTML
- un archivo que solo se encargue de convertir una imagen a base64, y que pueda tener varias formas de traer esa imagen (desde el disco, desde internet, etc, cada una en su propia clase)
- un archivo que junte todo eso y arme el archivo final

Esta forma de dividir el codigo en piezas mas chicas tiene una ventaja grande: si mañana hay que agregar, por ejemplo, la opcion de traer imagenes desde internet, se agrega una clase nueva sin tener que tocar el codigo que ya funciona y ya esta probado. Para esta prueba tecnica no hacia falta llegar a ese nivel de detalle, pero es el camino natural si el proyecto se vuelve mas grande o lo va a usar mas gente con el tiempo.