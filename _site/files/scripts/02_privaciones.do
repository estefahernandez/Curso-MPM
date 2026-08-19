/*==================================================================
 PROYECTO:  IPM/MPM - QNG - Guinea Ecuatorial
 SCRIPT:    02_privaciones.do
 --------------------------------------------------------------------
 PROPÓSITO
   Transformar los indicadores base construidos en 01_limpieza_indicadores.do
   en variables BINARIAS de privación (0 = no privado, 1 = privado) para
   cada uno de los 6 indicadores del IPM, agrupados en 3 dimensiones:
     Dimensión 1 (Educación):        dep_educ_com, dep_educ_enr
     Dimensión 2 (Infraestructura):  dep_infra_elec, dep_infra_imps, dep_infra_impw
     Dimensión 3 (Monetaria):        dep_poor1
   Estas 6 variables 0/1 son el insumo directo del método Alkire-Foster:
   cada hogar es "identificado" como pobre multidimensional si la suma
   ponderada de sus privaciones supera un umbral k (ver 03_calculo_mpm_mpitb.do).

   El comportamiento de cada indicador cambia levemente según la variante
   del índice ($MPM = "MPM", "MPMplus" o "MPM685"), definida en 00_maestro.do:
     - "MPM"      -> línea de pobreza monetaria más baja (3.00 USD PPA) y
                     umbrales educativos menos exigentes (primaria).
     - "MPMplus"  -> línea de pobreza más alta (8.30 USD PPA) y umbrales
                     educativos más exigentes (secundaria/ESBA), además de
                     un indicador de electricidad más estricto (incluye
                     cortes de luz) y de agua más estricto (excluye pozos).

 INPUTS ESPERADOS
   - "${gdStata}/Data Clean $MPM/DataClean$MPM.dta" generado por 01_limpieza_indicadores.do.
   - Globals: $MPM, $gdData.

 OUTPUTS GENERADOS
   - "${gdStata}/Data Clean $MPM/DataComplete_with_Deprivations.dta"
     Base completa (a nivel individuo) con las 6 privaciones + variables
     auxiliares.
   - "${gdStata}/Data Clean $MPM/DataDeprivations${MPM}.dta"
     Versión recortada (subconjunto de variables) que es la que
     efectivamente usa 03_calculo_mpm_mpitb.do para correr `mpitb`.

 DEPENDENCIAS DE VARIABLES/GLOBALS PREVIOS
   - $MPM, $gdData definidos en 00_maestro.do.
   - Variables individuales: age, q3_05_grado, q1_03_edad, educat7,
     asistencia_escolar, rezago_escolar, electricity, q2_33_SinElect,
     imp_san_rec, q2_25_aguaTomar, q2_27_tratamientoAgua, pcexp_ppp,
     GTpc_dr, zref, Provincia, cod_CV_CP, cod_provincia, quintile,
     cities, hhsize, weight_hh (todas provenientes de la base limpia
     de la encuesta y de 01_limpieza_indicadores.do).
==================================================================*/

use "${gdStata}/Data Clean $MPM/DataClean${MPM}.dta", clear


*************************************************************
****************** Parámetros por variante de MPM ***********
*************************************************************
* Estos globals definen las edades de corte y el año de precios
* internacionales (icpyr) usados en los indicadores de educación.
* Se agrupan aquí, al inicio, porque varios bloques posteriores los
* reutilizan.
if "$MPM"== "MPMplus"{
    global icpyr 2022 // @estefania creo que icpyr no se usa abajo nunca mas, ensayar y si no borrarlo 
    global lbage 7
    global ubage 14
    global eduage 20     // edad mínima para considerar "adulto" en educación
}
else {
    global icpyr 2022  // @estefania creo que icpyr no se usa abajo nunca mas, ensayar y si no borrarlo 
    global lbage 7
    global ubage 14
    global eduage 15     // edad mínima para considerar "adulto" en educación
}
display "$eduage"

* Simple renombre del identificador de hogar para usar en el comando pitb, etc
ren interview__key hhid

***********************************************************
** Dimensión 1: Educación (requiere definir grupos de edad)
***********************************************************

        **1a) Indicador: ningún adulto completó el nivel educativo requerido
        // Todos los adultos del hogar (edad >= $eduage)
    
    if "$MPM"== "MPMplus"{
        * temp2 = 1 si la persona es adulta (>=$eduage) y alcanzó ESBA/secundaria
        gen temp2 = 1 if age>=$eduage & age~=. & q3_05_grado>=11 & q3_05_grado~=.
        * temp3 = conteo de esos adultos por hogar (bys...egen sum: agregación
        * a nivel de grupo, ver explicación detallada en 01_limpieza_indicadores.do)
        bys hhid: egen temp3 = sum(temp2) // no hay missings en temp3: todo hogar
                                           // tiene al menos 1 persona >= $eduage

        // Excepción: el hogar se considera NO privado si es un hogar donde
        // hay personas mayores de 18 años pero nadie mayor de 20 (por lo
        // tanto temp3 no captura adultos "formales"), y al menos una de esas
        // personas de 18+ ya tiene ESBA 4 o más.
        gen menores_ESBA = (q1_03_edad>=18 & q3_05_grado>=11 & q3_05_grado~=.)
        bys hhid: egen menores_ESBA_count = sum(menores_ESBA)
        gen check_adults = (q1_03_edad>=$eduage)
        bys hhid: egen adults_count = sum(check_adults)
        replace temp3 = 1 if menores_ESBA_count==1 & adults_count==0
            drop menores_ESBA menores_ESBA_count check_adults adults_count


        gen dep_educ_com = 0
        replace dep_educ_com = 1 if temp3==0

        drop temp2 temp3 // variables temporales de conteo, ya no se necesitan
        la var dep_educ_com "MPM+: Privado si el hogar NO tiene adultos $eduage+ con secundaria completa"
    }
    else {
        * Variante estándar: adulto = >=$eduage años; nivel requerido =
        * primaria completa (educat7>=3).
        gen temp2 = 1 if age>=$eduage & age~=. & educat7>=3 & educat7~=.
        bys hhid: egen temp3 = sum(temp2) // no hay missings en temp3: todo hogar
                                           // tiene al menos 1 persona >= $eduage.
                                           // Es decir, temp3==0 significa que
                                           // nadie completó primaria, NO que
                                           // falten adultos en el hogar.

        gen dep_educ_com = 0
        replace dep_educ_com = 1 if temp3==0

        drop temp2 temp3
        la var dep_educ_com "MPM: Privado si el hogar NO tiene adultos $eduage+ con primaria completa"
    }

        ****************************************************
        **1b) Indicador: niño/a en edad escolar actualmente no matriculado
    if "$MPM"== "MPMplus"{
        * Tamaño del grupo en edad escolar, por hogar (para distinguir
        * "hogar sin niños en edad escolar" de "hogar con niños, todos ok")
        gen temp2a = 1 if age>=$lbage & age<=$ubage
        bys hhid: egen educ_enr_size = sum(temp2a)

        * Privado si no está matriculado O si está matriculado con rezago
        gen temp2 = 1 if age>=$lbage & age<=$ubage & asistencia_escolar==0 // no matriculado
        replace temp2 = 1 if age>=$lbage & age<=$ubage & asistencia_escolar==1 & rezago_escolar==1 // matriculado con rezago
        bys hhid: egen temp3 = sum(temp2)

        gen dep_educ_enr = 0
        replace dep_educ_enr = 1 if temp3>0 & temp3~=.
        replace dep_educ_enr = 0 if educ_enr_size ==0 // hogar sin niños en edad escolar: no privado por este indicador

        drop temp2a temp2 temp3
        la var dep_educ_enr "MPM+: Privado si el hogar tiene al menos un niño/a en edad escolar no matriculado o con rezago"
    }
    else{
        gen temp2a = 1 if age>=$lbage & age<=$ubage
        bys hhid: egen educ_enr_size = sum(temp2a)

        gen temp2 = 1 if age>=$lbage & age<=$ubage & asistencia_escolar==0 // privado si no asiste (asistencia_escolar==0)
        bys hhid: egen temp3 = sum(temp2)

        gen dep_educ_enr = 0
        replace dep_educ_enr = 1 if temp3>0 & temp3~=.
        replace dep_educ_enr = 0 if educ_enr_size ==0

        drop temp2a temp2 temp3
        la var dep_educ_enr "MPM: Privado si el hogar tiene al menos un niño/a en edad escolar no matriculado"
    }


****************************************************
** Dimensión 2: Acceso a infraestructura
****************************************************
*@estefania, pendiente revisa que si tenga sentido este codigo dado lo que hay en el do-file 1. Si son lo mismo, podemos borrar la seccion 1 y reemplazarla por la explicacion de las variables originales 
        ****************************************************
        // Indicador: Electricidad
        if "$MPM"== "MPMplus"{
            gen dep_infra_elec = (electricity==0) if electricity~=.
            replace dep_infra_elec = 1 if electricity==1 & q2_33_SinElect!=. // también privado si tuvo corte de luz el último mes
            la var dep_infra_elec "MPM+: Privado si el hogar no tiene acceso a electricidad o tuvo corte de luz el último mes"
        }
        else{
            gen dep_infra_elec = (electricity==0) if electricity~=.
            la var dep_infra_elec "Privado si el hogar no tiene acceso a electricidad"
        }

        ****************************************************
        // Indicador: Saneamiento
        gen dep_infra_imps = (imp_san_rec==0) if imp_san_rec~=.
        if "$MPM"== "MPMplus"{
            la var dep_infra_imps "MPM+: Privado si el hogar no tiene acceso a saneamiento mejorado"
        }
        else{
                la var dep_infra_imps "MPM: Privado si el hogar no tiene acceso a saneamiento mejorado"
        }

        ****************************************************
        // Indicador: Agua
        if "$MPM"== "MPMplus"{
            drop water14
            * Recategorización de la fuente de agua (14 categorías estándar): 
            * en la variante MPM+ TODO pozo público se considera NO
            * mejorado, y el pozo privado se considera mejorado SOLO si
            * recibió algún tipo de tratamiento (ver `replace` justo abajo).
            recode q2_25_aguaTomar (1=1) (2=2) (3=3) (4=10) (5=5) (6=13) (7=9) (8=12) (9=7) (10=14) (11=14) (nonmissing= 0), gen(water14)

            * Excepción: pozo protegido (código 5) se reclasifica como NO
            * mejorado (código 10) salvo que declare tratamiento de agua.
            replace water14 = 10 if inlist(q2_25_aguaTomar, 5) & q2_27_tratamientoAgua!= "Ninguno"
            label var water14 "Fuente de agua: 14 categorías"
            label define water14 1 "Agua entubada dentro de la vivienda" 2 "Agua entubada al patio/parcela" 3 "Grifo o pilón público" 4 "Pozo entubado o perforado" 5 "Pozo protegido" 6 "Manantial protegido" 7 "Agua embotellada" 8 "Agua de lluvia" 9 "Manantial no protegido" 10 "Pozo no protegido" 11 "Carro con tanque/tambor pequeño" 12 "Camión cisterna" 13 "Agua superficial" 14  "Otro", replace
            label val water14 water14

            * Agua mejorada (recodificación desde water14)
            drop imp_wat_rec
            recode water14 (1/6 8=1 "Acceso a fuente de agua mejorada") (nonmissing=0 "Sin acceso a fuente de agua mejorada"), gen(imp_wat_rec)
            label var imp_wat_rec "Hogar con acceso a fuente de agua mejorada. Recodificada desde water14 siguiendo GMD. Igual a drinking_water"

            gen dep_infra_impw = (imp_wat_rec==0) if imp_wat_rec~=.
            la var dep_infra_impw "MPM+: Privado si el hogar no tiene acceso a agua potable mejorada (excluye pozo)"
        }
        else{
            gen dep_infra_impw = (imp_wat_rec==0) if imp_wat_rec~=.
            la var dep_infra_impw "MPM: Privado si el hogar no tiene acceso a agua potable mejorada"
        }

****************************************************
** Dimensión 3: Monetaria
****************************************************
       
        if "$MPM"== "MPM"{
            gen double welfare_ppp= pcexp_ppp
            gen dep_poor1 = welfare_ppp< 3 if welfare_ppp~=.
            label var dep_poor1 "Pobreza monetaria internacional. Línea: 3.00 USD - PPA 2021"
        }
        else if "$MPM"== "MPMplus"{
            gen double welfare_ppp= pcexp_ppp
            gen dep_poor1 = welfare_ppp< 8.30 if welfare_ppp~=.
            label var dep_poor1 "Pobreza monetaria internacional. Línea: 8.30 USD - PPA 2021"
        }
        
        * `apoverty` tambien sirve para sacar variables indicadoras de pobreza. Aca para la linea y el agregado de pobreza nacional 
        apoverty GTpc_dr [aw = weight_hh], varpl(zref) gen(monetary)

        save "${gdStata}/Data Clean $MPM/DataComplete_with_Deprivations.dta", replace

* Variable de área rural/urbana combinada con provincia (usada para el
* diseño muestral -strata- en 03_calculo_mpm_mpitb.do)
    tostring cod_CV_CP, gen(area_string)
    gen rural_prov = Provincia+ area_string // @estefania, estas variables que creas aca las vuelves a crear por segunda vez en el do-file 3, por lo que creo que no tiene sentido y mejor dejarlas en el do-file 3 
    encode rural_prov, gen(ruralprov) // @estefania, estas variables que creas aca las vuelves a crear por segunda vez en el do-file 3, por lo que creo que no tiene sentido y mejor dejarlas en el do-file 3 

* Recorte de variables: nos quedamos solo con lo necesario para calcular
* el IPM con `mpitb` (03_calculo_mpm_mpitb.do), evitando cargar toda la
* base de la encuesta en ese paso.
    preserve
        keep hhid provincia cod_provincia cod_CV_CP age hhsize weight_hh pcexp_ppp ///
            educat7 asistencia_escolar electricity imp_san_rec imp_wat_rec ///
            dep_educ_com educ_enr_size dep_educ_enr dep_infra_elec dep_infra_imps ///
            dep_infra_impw dep_poor1 quintile ruralprov cities monetary1  //welfare_ppp (se conserva comentado: no se usa en el paso de mpitb pero podría ser útil para chequeos)
        save "${gdStata}/Data Clean $MPM/DataDeprivations${MPM}.dta", replace
    restore
