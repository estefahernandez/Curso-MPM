# Proyecto MPM (Banco Mundial)

Guia practica para construir un indice de pobreza multidimensional (MPM) en Stata, siguiendo la logica metodologica utilizada por el Banco Mundial.

## Tabla de contenido
1. Descripcion y objetivo
2. Alcance metodologico y estructura de scripts
3. Ejecucion y reproducibilidad

## Descripcion y objetivo
Este proyecto documenta una ruta practica para aprender a construir un indice de pobreza multidimensional (MPM) con microdatos, siguiendo la metodologia del Banco Mundial. El objetivo es entender la implementacion operativa completa: desde la preparacion de datos hasta la generacion de resultados y figuras comparables.

## Alcance metodologico y estructura de scripts
El nucleo metodologico se desarrolla en cuatro do-files, mas un script final de exportacion.

Para facilitar la trazabilidad, cada script se documenta con la misma estructura: proposito, insumos, procesamiento y productos.

### 00_maestro.do
Proposito:
- Centralizar la configuracion del proyecto y ejecutar el flujo completo de forma estandar.

Insumos:
- Directorio raiz del proyecto y rutas de subcarpetas (datos, resultados, figuras, scripts).
- Parametros globales de ejecucion (nombres de archivos, anio/periodo, opciones de corrida y configuracion del ejercicio MPM).
- Disponibilidad de los scripts 01-04 en la carpeta de trabajo.

Procesamiento:
- Define macros globales/locales de rutas y control.
- Verifica consistencia basica de entorno (rutas y archivos esperados).
- Ejecuta secuencialmente 01_limpieza_indicadores.do, 02_privaciones.do, 03_calculo_mpm_mpitb.do y 04_exportar_figuras.do.

Productos:
- Ejecucion reproducible de punta a punta con orden metodologico fijo para el calculo del MPM.
- Registro trazable de productos intermedios y finales generados en cada etapa del MPM.

### 01_limpieza_indicadores.do
Proposito:
- Transformar microdatos de origen en una base analitica consistente para medir privaciones.

Insumos:
- Base(s) de microdatos en formato .dta (individuos/hogares) con variables crudas.
- Diccionario implicito de variables esperadas (identificadores, demografia, educacion, empleo, vivienda u otras dimensiones usadas).
- Reglas de limpieza: tratamiento de missings, codigos especiales y estandarizacion de categorias para construir indicadores comparables del MPM.

Procesamiento:
- Depuracion de registros y validaciones minimas de integridad.
- Recodificacion y homologacion de variables para asegurar comparabilidad interna.
- Construccion de indicadores base que alimentan la identificacion de privaciones.

Productos:
- Base limpia y armonizada para la identificacion de privaciones del MPM.
- Variables derivadas de indicadores con definiciones consistentes entre dimensiones de pobreza.
- (Opcional) tablas de control de calidad o conteos de verificacion del preprocesamiento.

### 02_privaciones.do
Proposito:
- Convertir indicadores base en variables de privacion por regla metodologica.

Insumos:
- Base limpia producida en 01_limpieza_indicadores.do.
- Definiciones de umbral por indicador/dimension.
- Esquema de ponderacion o agregacion intermedia, si aplica antes del calculo final del MPM.

Procesamiento:
- Aplicacion de puntos de corte para identificar carencia (privado/no privado).
- Generacion de variables binarias de privacion por indicador.
- Construccion de agregados de privacion por dimension o puntaje acumulado preliminar.

Productos:
- Matriz de privaciones a nivel unidad de analisis (persona u hogar).
- Agregados intermedios listos para identificar pobreza multidimensional segun la regla metodologica.
- Base preparada para el calculo del indice MPM en la etapa 03.

### 03_calculo_mpm_mpitb.do
Proposito:
- Estimar el indice de pobreza multidimensional y sus componentes principales.

Insumos:
- Matriz/agregados de privacion producidos en 02_privaciones.do.
- Parametros de identificacion del pobre multidimensional (por ejemplo, umbral k).
- Ponderaciones finales y reglas de agregacion definidas por la metodologia aplicada.

Procesamiento:
- Identificacion de la poblacion pobre multidimensional.
- Calculo de metricas troncales (incidencia H, intensidad A y medida compuesta).
- Desagregaciones o tabulados por grupos poblacionales/territoriales, si estan programados.

Productos:
- Base o tabla final con resultados del MPM.
- Indicadores listos para comparacion temporal, territorial o por subgrupos de la pobreza multidimensional.
- Productos analiticos formateados para reporte y visualizacion.

### 04_exportar_figuras.do
Proposito:
- Traducir resultados numericos del MPM en productos graficos y tabulares para comunicacion.

Insumos:
- Resultados finales (tablas/bases) generados en 03_calculo_mpm_mpitb.do.
- Parametros de formato de salida (tipos de grafico, etiquetas, rutas de exportacion).

Procesamiento:
- Construccion de tablas y figuras de resultados clave.
- Estandarizacion de formato visual para presentaciones o documentos.
- Exportacion a carpetas de resultados.

Productos:
- Figuras exportadas (por ejemplo, PNG/SVG/PDF, segun configuracion del script) que comunican los resultados del MPM.
- Tablas de reporte para documentos o presentaciones de pobreza multidimensional.
- Productos finales de comunicacion del ejercicio metodologico del MPM.

## Ejecucion y reproducibilidad
1. Ejecucion recomendada: correr 00_maestro.do para asegurar orden, consistencia y trazabilidad.
2. Ejecucion por etapas: 01 -> 02 -> 03 -> 04, util para depuracion metodologica.
3. Insumos minimos: microdatos .dta con variables necesarias para construir indicadores y privaciones del MPM.
4. Criterio de calidad: documentar cualquier cambio en umbrales, ponderaciones o reglas de agregacion para mantener comparabilidad temporal y entre ejercicios.
5. Si hay diferencias inesperadas en resultados: validar primero productos de 01 y 02, luego revisar parametrizacion de 03.

---
Si adaptas la metodologia a otro pais o encuesta, documenta los cambios de umbrales, ponderaciones y definiciones para preservar trazabilidad metodologica.
