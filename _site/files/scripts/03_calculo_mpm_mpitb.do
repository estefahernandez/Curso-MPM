/*==================================================================
 PROYECTO:  IPM/MPM - QNG - Guinea Ecuatorial
 SCRIPT:    03_calculo_mpm_mpitb.do
 --------------------------------------------------------------------
 PROPÓSITO
   Este es el script CENTRAL del pipeline: calcula el Índice de
   Pobreza Multidimensional (IPM/MPM) usando el método Alkire-Foster
   (2011) a través del paquete oficial `mpitb` (Multidimensional
   Poverty Index Toolbox, OPHI/Banco Mundial).

   El método Alkire-Foster, en resumen:
     1) Se define una matriz de privaciones (0/1) por hogar/indicador.
     2) Cada indicador tiene un peso (aquí: pesos iguales entre
        dimensiones, y iguales entre indicadores dentro de cada
        dimensión -weights(equal)-).
     3) Se calcula el "puntaje de privación" c_h de cada hogar: la
        suma ponderada de sus privaciones.
     4) Un hogar es identificado como "pobre multidimensional" si
        c_h >= k, donde k es el umbral de corte (aquí, k=33%: el
        hogar debe estar privado en al menos 1/3 del total de
        privaciones ponderadas posibles).
     5) A partir de esa identificación se calculan las medidas
        estándar: 
        H (headcount ratio: % de población pobre multidimensional), 
        A (intensidad promedio de privación entre los pobres), 
        M0 = H*A (el índice ajustado, "MPM"), además de
        headcounts censurados/no censurados por indicador (hd, hdk) y
        las contribuciones de cada indicador/dimensión al M0 (actb,
        pctb).

 INPUTS ESPERADOS
   - "${gdData}/Data Clean $MPM/DataDeprivations${MPM}.dta"
     generado por 02_privaciones.do: 1 fila por hogar con las 6
     variables de privación (dep_educ_com, dep_educ_enr, dep_infra_elec,
     dep_infra_imps, dep_infra_impw, dep_poor1), ponderador de hogar
     (weight_hh), tamaño del hogar (hhsize), y variables de
     desagregación geográfica (cod_CV_CP -area-, cod_provincia -prov-,
     cities).
   - Paquete `mpitb` instalado (ssc install mpitb).

 OUTPUTS GENERADOS
   - "${gdData}/${MPM}_results.dta"
     Resultados agregados: 1 fila por combinación de medida (H, A, M0,
     hd, hdk, actb, pctb, etc.) x nivel de desagregación (nat/area/
     prov/cities) x indicador, con su estimación (b) y error estándar (se).
   - "${gdData}/${MPM}_results_microdata.dta"
     Microdato a nivel de hogar con el puntaje de privación censurado
     (c_equal) y la identificación final de pobreza multidimensional
     (poor_multi).

 DEPENDENCIAS DE VARIABLES/GLOBALS PREVIOS
   - $gdData, $MPM definidos en 00_maestro.do.
==================================================================*/

* 1 fila por hogar con las privaciones ya construidas (02_privaciones.do)
use "${gdStata}/Data Clean $MPM/DataDeprivations${MPM}.dta",clear

* Nos quedamos solo con las variables necesarias para `mpitb`: privaciones,
* ponderadores, y variables de desagregación geográfica/socioeconómica.
keep hhid provincia provincia cod_provincia cod_CV_CP age hhsize weight_hh ///
     pcexp_ppp educat7 asistencia_escolar electricity imp_san_rec imp_wat_rec ///
     dep_educ_com educ_enr_size dep_educ_enr dep_infra_elec dep_infra_imps ///
     dep_infra_impw dep_poor1 quintile ruralprov cities //welfare_ppp

* `mpitb` espera nombres de variable con el prefijo del indicador SIN el
* prefijo "dep_"/"infra_"/"educ_" (los nombres cortos e_com, i_elec, etc. son
* los que luego aparecen en las tablas de resultados). Por eso se renombran:
rename dep_* *      // dep_educ_com -> educ_com, dep_infra_elec -> infra_elec, dep_poor1 -> poor1, etc.
rename infra_* i_*  // infra_elec -> i_elec, infra_imps -> i_imps, infra_impw -> i_impw
rename educ_* e_*   // educ_com -> e_com, educ_enr -> e_enr

* Aseguramos 1 fila por hogar (requisito de mpitb: la unidad de análisis es
* el hogar, no el individuo).
duplicates drop hhid, force

*-------------------------------------------------------------------
* `mpitb set`: DEFINE la estructura del índice (dimensiones, indicadores
* y cómo se agrupan). No calcula nada todavía, solo registra el "diseño"
* del índice bajo el nombre "GNQ" para usarlo luego en `mpitb est`.
*   d1(e_com e_enr, na(educ))           -> Dimensión 1 "educ": 2 indicadores
*   d2(i_elec i_imps i_impw, na(infra)) -> Dimensión 2 "infra": 3 indicadores
*   d3(poor1, na(mon))                  -> Dimensión 3 "mon": 1 indicador
* Por defecto cada dimensión recibe el mismo peso (1/3), y dentro de cada
* dimensión los indicadores también se pesan por igual (esto se confirma
* explícitamente más abajo con la opción weights(equal) en `mpitb est`).
*-------------------------------------------------------------------
mpitb set, name(GNQ) d1(e_com e_enr, na(educ)) d2(i_elec i_imps i_impw, na(infra)) d3(poor1, na(mon))

* Ponderador expandido a nivel de PERSONAS (peso de hogar x tamaño del
* hogar): así los resultados representan a la POBLACIÓN, no solo a los
* hogares, que es el estándar habitual de reporte del IPM (headcount de
* personas, no de hogares).
gen hhweight = weight_hh*hhsize

* `strata`: variable de estratificación del diseño muestral, construida
* como la combinación de provincia x área (urbano/rural). Es necesaria
* para que `svyset` calcule errores estándar correctos (ver más abajo).
egen strata= group(cod_provincia cod_CV_CP)

* `svyset`: declara el diseño muestral complejo de la encuesta (ponderador
* + estratos) para que las estimaciones posteriores (con la opción `svy`
* de `mpitb est`) tengan errores estándar correctamente ajustados por el
* diseño, no los de muestreo aleatorio simple.
svyset hhid [iw= hhweight], clear strata(strata)

* Renombramos las variables de desagregación geográfica a los nombres
* cortos que se usarán en `over()` más abajo.
rename (cod_CV_CP cod_provincia) (area prov)

*-------------------------------------------------------------------
* `mpitb est`: CALCULA el índice definido en `mpitb set` bajo el diseño
* "QNG". Opciones clave:
*   klist(33)           -> el umbral de identificación k = 33% (1/3): un
*                        hogar es pobre multidimensional si su puntaje
*                        de privación ponderado es >= 33%.
*   weights(equal)      -> pesos iguales entre dimensiones e indicadores
*                        (el "IPM clásico" de Alkire-Foster; existen
*                        otras opciones para ponderar dimensiones de
*                        forma distinta, no usadas aquí).
*   measures(all)       -> calcula TODAS las medidas estándar: H, A, M0,
*                        etc. a nivel agregado.
*   indmeas(all)        -> además, calcula las medidas por INDICADOR
*                        (headcount censurado/no censurado hd/hdk,
*                        contribución al M0 actb/pctb, etc.).
*   aux(hd)             -> guarda también el headcount no censurado (hd)
*                        como medida auxiliar.
*   svy                 -> usa el diseño muestral declarado con `svyset`
*                        (ponderadores + estratos) para el cálculo de
*                        errores estándar.
*   lsave(...)          -> guarda los resultados "largos" (1 fila por
*                        medida x nivel x indicador) en un .dta, y los
*                        deja además cargados en memoria bajo el frame
*                        "myresults" (lfr).
*   over(area prov cities) -> además del nivel nacional, calcula los
*                        resultados desagregados por área (urbano/rural),
*                        provincia, y la clasificación cities (Malabo /
*                        Otro urbano / Rural).
*   dtasave(...)        -> guarda además el microdato a nivel de hogar
*                        con el puntaje de privación (c_equal) usado para
*                        identificar a los pobres multidimensionales.
*-------------------------------------------------------------------

*****

mpitb est, name(GNQ) klist(33) weights(equal) measures(all) indmeas(all) aux(hd) svy lsave("${gdStata}/${MPM}_results.dta", replace) lfr(myresults) over(area prov cities) dtasave("${gdStata}/${MPM}_results_microdata.dta", replace)

* `cwf`: cambia el frame de trabajo activo al frame "myresults" que dejó
* `mpitb est` (Stata 16+ permite tener varios "frames"/bases en memoria
* simultáneamente). Aquí solo se usa para inspeccionar rápidamente los
* resultados recién calculados.
cwf myresults
d
tab measure loa
* H, A y M0 a nivel nacional (loa=="nat"), para el umbral k=33
li measure b se if inlist(measure,"M0","H","A") & loa == "nat" & k == 33 , noob
* Headcount por indicador (hd = no censurado, hdk = censurado a k=33) @estefania, good to add here the dictionary of the variable measure)
tabdisp indicator measure if inlist(measure,"hd","hdk") & loa == "nat" & inlist(k,33,.) , cell(b)

* Reordenamos y volvemos a guardar los resultados agregados, para que
* queden en un orden consistente (medida, nivel de agregación, subgrupo)
* al ser leídos por 04_exportar_figuras.do.
use "${gdStata}/${MPM}_results.dta", clear
sort measure loa subg
save "${gdStata}/${MPM}_results.dta", replace

* En el microdato de hogares, construimos la identificación final de
* pobreza multidimensional: poor_multi=1 si el puntaje de privación
* ponderado (c_equal, generado por mpitb) es >= 1/3 (el mismo k=33% usado
* arriba). Esta variable es la que usa 04_exportar_figuras.do (poor_multi)
* para, por ejemplo, calcular el % de población pobre por provincia o
* generar los diagramas de Venn.
use "${gdStata}/${MPM}_results_microdata.dta"
keep hhid prov weight_hh hhsize electricity imp_wat_rec imp_san_rec area cities ///
     pcexp_ppp provincia quintile asistencia_escolar educat7 e_com e_enr_size ///
     e_enr i_elec i_imps i_impw poor1 ruralprov hhweight strata c_equal //welfare_ppp
gen poor_multi = (c_equal>=1/3)
save "${gdStata}/${MPM}_results_microdata.dta", replace

@estefania: teh variable "subg" produce by the mptib does not have labels, how can be added?  (This is for sec 2)
@estefania: take the examples of how to use the mptib from teh paper to dig a little further (This is for section 2)