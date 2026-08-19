# Curso IPM · Guinea Ecuatorial

Sitio web del curso de tres sesiones sobre medición de la pobreza multidimensional
(método Alkire-Foster, OPHI), construido con [Quarto](https://quarto.org).

## Estructura del repositorio

```
.
├── _quarto.yml                     # Configuración del sitio web
├── index.qmd                       # Página única con las tres sesiones (pestañas)
├── files/                          # Materiales descargables (PDFs, do-files, imagen, datos)
│   ├── estructura_ipm.png
│   ├── presentacion_sesion1.pdf
│   ├── presentacion_sesion2.pdf
│   ├── presentacion_sesion3.pdf
│   ├── 01_limpieza_indicadores.do
│   ├── 02_privaciones.do
│   └── 03_calculo_mpm_mpitb.do
├── .github/workflows/publish.yml   # Publicación automática en GitHub Pages
├── .gitignore
└── README.md
```

## Ver el sitio en local

```bash
quarto preview
```

## Publicar en GitHub Pages

1. **Una vez, desde tu máquina**, con el repositorio clonado y Quarto instalado:

   ```bash
   quarto publish gh-pages
   ```

   Esto renderiza el sitio, crea la rama `gh-pages`, la sube y configura GitHub Pages.
   Al terminar te da la URL pública (`https://TU-USUARIO.github.io/NOMBRE-REPO/`).

2. **Automatización.** El archivo `.github/workflows/publish.yml` ya incluido reconstruye
   el sitio en cada `push` a `main`. En *Settings → Pages* del repositorio, fija la fuente
   en la rama `gh-pages`.

## Notas

- El código Stata se **muestra**, no se ejecuta (`execute: eval: false`). Por eso el servidor
  de CI solo necesita Quarto: no hace falta instalar Stata, R ni Python.
- Sustituye el enlace `https://ENLACE-A-TUS-DATOS` en `index.qmd` por la URL real de la base
  `.dta`, y añade `files/Cuestionario.xlsx` si quieres habilitar ese botón de descarga.
