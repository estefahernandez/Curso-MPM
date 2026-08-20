
/*==================================================================
  TABLA RESUMEN: MPM (H) — Nacional + todas las provincias
    Columna 2 → valores de referencia PEA (hardcoded)
    Columna 3 → valores calculados del microdato

  Variable de desagregación: provincia

  NOTA TÉCNICA: todos los di están dentro de un programa para que
  Stata muestre SOLO la tabla y no el código fuente de cada di.
==================================================================*/

*------------------------------------------------------------------
* ▶▶ EDITA AQUÍ: valores de referencia PEA por provincia (en %)
*    El orden debe coincidir con el que produce levelsof provincia
*    en tu base de datos
*------------------------------------------------------------------
if ("$MPM" == "MPM") {
    global ref_H_nat   = "19.9"   
    global ref_H_prov_1  = "20.6"  
    global ref_H_prov_2  = "3.1"   
    global ref_H_prov_3  = "19.0"  
    global ref_H_prov_4  = "37.3"  
    global ref_H_prov_5  = "47.8"  
    global ref_H_prov_6  = "11.6"  
    global ref_H_prov_7  = "22.8"  
}
else if ("$MPM" == "MPMplus") {
    global ref_H_nat   = "19.9"   
    global ref_H_prov_1  = "68.4"  
    global ref_H_prov_2  = "40.6"   
    global ref_H_prov_3  = "78.6"  
    global ref_H_prov_4  = "85.5"  
    global ref_H_prov_5  = "85.1"  
    global ref_H_prov_6  = "63.9"  
    global ref_H_prov_7  = "78.8"  
}

*------------------------------------------------------------------
* BLOQUE 1: Cálculo desde el microdato (todo en quietly)
*
*   H = proporción ponderada de pobres multidimensionales
*
*   Globals generados (valores en %):
*     mpm_H_nat                    — Nacional
*     mpm_H_prov_1 … mpm_H_prov_N — una por cada provincia
*     mpm_prov_lbl_1 … _N          — etiqueta/nombre de cada provincia
*     mpm_n_prov                   — número total de provincias
*------------------------------------------------------------------
quietly {
    use "${gdStata}/${MPM}_results_microdata.dta", clear
    svyset hhid [iw=hhweight], clear strata(strata)

    * Nacional
    svy: mean poor_multi
    global mpm_H_nat = e(b)[1,1] * 100

    * Por provincia — loop dinámico sobre todos los niveles de provincia
    local prov_type: type provincia
    levelsof provincia, local(prov_levels)
    local n = 0
    foreach p of local prov_levels {
        local ++n

        * Obtener etiqueta de valor si es numérica, o el valor si es string
        if strpos("`prov_type'", "str") > 0 {
            global mpm_prov_lbl_`n' = "`p'"
            svy, subpop(if provincia == "`p'"): mean poor_multi
        }
        else {
            local lbl: label (provincia) `p'
            if `"`lbl'"' == "" local lbl = "`p'"
            global mpm_prov_lbl_`n' = "`lbl'"
            svy, subpop(if provincia == `p'): mean poor_multi
        }
        global mpm_H_prov_`n' = e(b)[1,1] * 100
    }
    global mpm_n_prov = `n'
}

*------------------------------------------------------------------
* BLOQUE 2: Tabla por provincia — definir e invocar el programa
*------------------------------------------------------------------
quietly {
    capture program drop _tabla_mpm
    program _tabla_mpm
        di ""
        di "   {hline 65}"
        di "   {bf:${MPM} (H) por Provincia}"
        di "   {hline 65}"
        di "   {col 4}{bf:Provincia/Nivel}{col 36}{bf:Referencia PEA}{col 54}{bf:Calculado}"
        di "   {hline 65}"
        * Nacional
        if missing(${ref_H_nat}) {
            di "   {col 4}Nacional" _col(38) "  —  " _col(54) %5.1f ${mpm_H_nat} "%"
        }
        else {
            di "   {col 4}Nacional" _col(36) %5.1f ${ref_H_nat} "%" _col(54) %5.1f ${mpm_H_nat} "%"
        }
        di "   {hline 65}"
        * Una fila por provincia
        forvalues i = 1/${mpm_n_prov} {
            if missing(${ref_H_prov_`i'}) {
                di "   {col 4}${mpm_prov_lbl_`i'}" _col(38) "  —  " _col(54) %5.1f ${mpm_H_prov_`i'} "%"
            }
            else {
                di "   {col 4}${mpm_prov_lbl_`i'}" _col(36) %5.1f ${ref_H_prov_`i'} "%" _col(54) %5.1f ${mpm_H_prov_`i'} "%"
            }
        }
        di "   {hline 65}"
    end
}

* Invocamos el programa recién definido (fuera de `quietly`, para que la
* tabla sí se imprima en el log/Results).
_tabla_mpm


