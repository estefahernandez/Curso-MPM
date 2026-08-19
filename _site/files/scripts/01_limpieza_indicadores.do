/*==================================================================
 PROYECTO:  IPM/MPM - QNG - Guinea Ecuatorial
 SCRIPT:    01_limpieza_indicadores.do
 --------------------------------------------------------------------
 PROPÓSITO
   Construir, a partir de la base individual limpia de la encuesta
   ENH2-2023, los INDICADORES BASE que luego se convertirán
   en variables binarias de privación (ver 02_privaciones.do):
     - Dimensión 1 (Educación): logro educativo de adultos y
       matrícula escolar de niños/adolescentes en edad escolar.
     - Dimensión 2 (Infraestructura): acceso a electricidad,
       saneamiento mejorado y agua potable mejorada.
     - Dimensión 3 (Monetaria): pobreza monetaria internacional
       usando líneas de USD PPA 2021 (3.00 y 8.30).
   
 INPUTS 
   - "$gdData/Clean data/II-ENH-2023/CleanDB_Individual_POV.dta"
     Base individual con variables de la encuesta ya limpias:
     edad (q1_03_edad), nivel educativo (educat7, q3_05_grado),
     asistencia escolar (asistencia_escolar), grado cursado
     (q3_11_gradoAsistido), electricidad (electricity, q2_33_SinElect),
     saneamiento (imp_san_rec, q2_28_aseo, q2_29_aseoExclusivo),
     agua (imp_wat_rec, q2_25_aguaTomar), gasto per cápita en PPA
     (pcexp_ppp), ponderador de hogar (weight_hh), etc.
   - Globals definidos en 00_maestro.do: $gdData, $MPM.

 OUTPUTS 
   - "${gdStata}/Data Clean $MPM/DataClean$MPM.dta"
     Base individual con los indicadores base ya construidos, lista
     para que 02_privaciones.do construya las privaciones binarias.
   - Globals descriptivos: $Educational_attainment, $Educational_enrollment,
     $Electricity, $Sanitation, $Drinking_water (porcentajes de
     población/hogares en cada indicador, usados como chequeo).

 DEPENDENCIAS DE VARIABLES/GLOBALS PREVIOS
   - $gdData, $MPM deben estar definidos (ver 00_maestro.do).
==================================================================*/


* Base individual de la encuesta de hogares
use "$gdData/${database}", clear

*******************************************************************************
* Dimensión 1. Educación
*******************************************************************************

**# Logro educativo (Educational_attainment)
*******************************************************************************
* Indicador: "Ningún adulto del hogar (de la edad de grado 9 en adelante) ha
* completado la educación primaria". 
* Definicion de adulto basado en el grado 9, en Giunea Ecuatorial empezando a los 6 anios, implica que adultos tienen 15 anios 
    global age9grade 15 // inicio de primaria a los 7 años. Grado 9 = ESBA 3 
    global agegrade  20 // inicio de primaria a los 7 años. Grado 9 = ESBA 3
    tab q1_03_edad, mis  // chequeo: no hay missings en la variable de edad


    * Variable a nivel individuo: ¿la persona alcanzó el nivel básico de
    
    fre educat7
    
    * educación (educat7>=3, es decir primaria completa o más)
    gen hh_ind_educ = (educat7>=3 & educat7~=.)
        replace hh_ind_educ=. if q1_03_edad<$age9grade | q1_03_edad==. 
        // Se define como missing para menores de la edad de corte: no tiene
        // sentido evaluar "logro educativo de adulto" en niños.

    * La privacion se define a nivel de HOGAR: interview__key 
    * `bys ... egen ... sum()` suma el total de adultos con logro educativo. Donde cada fila del hogar recibe el mismo valor.
    bys interview__key: egen hh_educ_adults = sum(hh_ind_educ)

    * El hogar está PRIVADO si NINGÚN adulto alcanzó el nivel básico (hh_educ_adults==0). NOTESE que tambien si el hogar no tiene adultos (hh_educ_adults==.) se considera como Privado (Esto es una decision que se hace caso por caso y debe discutirse cuando el universo al que aplica=adultos, no esta presente en todos los hogares) 
    gen adult_9_grade = 0 // Se empieza asegurando que ningun hogar esta PRIVADO
        replace adult_9_grade = 1 if hh_educ_adults==0

        label var adult_9_grade "MPM: Adultos con educación primaria"
        label define adults_grade 0 "Adultos con educación básica" 1 "Ningún adulto con al menos educación básica"
        label val adult_9_grade adults_grade

    ** Descriptivo: logro educativo a nivel de HOGAR (no individuo)
    preserve
        duplicates drop interview__key, force // colapsa a 1 fila por hogar
        tab adult_9_grade cod_CV_CP [aw = weight_hh*hhsize], col nofreq
            sum  adult_9_grade [aw = weight_hh*hhsize]
            global Educational_attainment = 100 *`r(mean)'
    restore

* OP MPM+ : versión más exigente del indicador de logro educativo al usar ESBA/secundaria básica en vez de primaria como el minimo logro para al menos un adulto en el hogar. Se necesita una variable mas detallada para ver ESBA, q3_05_grado    
    fre q3_05_grado
    gen hh_ind_educ2 = (q3_05_grado>=11 & q3_05_grado~=.)
        replace hh_ind_educ2=. if q1_03_edad<$agegrade | q1_03_edad==.

    * Cantidad de adultos del hogar con ese nivel educativo
    bys interview__key: egen hh_educ_adults2 = sum(hh_ind_educ2)

    gen adult_9_grade2 = 0
        replace adult_9_grade2 = 1 if hh_educ_adults2==0
        
        // Regla de excepción: un hogar se considera NO privado si los adultos, a pesar de no tener 20 años, ya cuentan con el nivel educativo de ESBA.
        gen menores_ESBA = (q1_03_edad>=18 & q3_05_grado>=11 & q3_05_grado~=.)
        bys interview__key: egen menores_ESBA_count = sum(menores_ESBA)
        
        //adults following the rule of 20
        gen check_adults = (q1_03_edad>=$agegrade)
        bys interview__key: egen adults_count = sum(check_adults)
        
        // No privados si tienen 18-20 lo suficientemente educados y son los mas adultos del hogar (Sensibilidad que fue dificil de detectar en la data y depende de considerar muy bien los missing que se pueden volver cero)
        replace adult_9_grade2 = 0 if menores_ESBA_count==1 & adults_count==0
            drop menores_ESBA menores_ESBA_count check_adults adults_count

        label var adult_9_grade2 "MPM+: Adultos con educación secundaria"
        label define adults_grade2 0 "Adultos con educación ESBA" 1 "Ningún adulto con al menos educación ESBA"
        label val adult_9_grade2 adults_grade2

        tab adult_9_grade adult_9_grade2, m


    ** Descriptivo: logro educativo (variante MPM+) a nivel hogar
    ** NOTA: este bloque reasigna el mismo global $Educational_attainment que
    ** el bloque anterior (MPM estándar). Se conserva tal cual porque solo uno de los dos
    ** resultados (según $MPM) es el que efectivamente se usa aguas abajo.
    preserve
        duplicates drop interview__key, force
        tab adult_9_grade2 cod_CV_CP [aw = weight_hh*hhsize], col nofreq
            sum  adult_9_grade2 [aw = weight_hh*hhsize]
            global Educational_attainment = 100 *`r(mean)'
    restore

**# Matrícula escolar (Education_enrollment)
***********************************************
    global lbage 7  // edad de inicio de primaria
    global ubage 14 // se considera hasta 8vo grado (ESBA 2) como edad escolar

*** Indicador base: niño/adolescente en edad escolar debe estar matriculado
    * Definiendo el universo primero, ninios en "edad escolar" (entre $lbage y $ubage años)
    gen edad_escolar = (q1_03_edad>=$lbage & q1_03_edad<=$ubage)
    bys interview__key: egen cant_edadescolar = sum(edad_escolar)

    * No matriculado: está en edad escolar pero no asiste
    gen no_matriculado = (q1_03_edad>=$lbage & q1_03_edad<=$ubage & asistencia_escolar!=1)
        replace no_matriculado=. if q1_03_edad<$lbage | q1_03_edad>$ubage //asegurandose que si no esta en edad escolar no se le considere privado ni no privado, sino missing

    * Cantidad de niños no matriculados por hogar
    bys interview__key: egen cant_no_matriculados = sum(no_matriculado)

    * El hogar está privado si tiene AL MENOS un niño/adolescente en edad
    * escolar que no está matriculado (por esto se calcula la suma, para detectar al menos uno).
    gen matricula = 0
        replace matricula = 1 if cant_no_matriculados>0 // cant_no_matriculados~=. nunca es missing por como se crea en el bysort 
        replace matricula = 0 if cant_edadescolar==0 // hogares sin niños en edad escolar (universo de la privacion no estan en todos los hogares) no estan privados 

    la var matricula "MPM: Privado si el hogar tiene al menos un niño/adolescente en edad escolar no matriculado"
    label def matricula 1 "Hay niños/adolescentes no matriculados" 0 "Todos los niños/adolescentes están matriculados"
    label val matricula matricula

    ** Descriptivo
    preserve
        duplicates drop interview__key, force
        tab matricula cod_CV_CP [aw = weight_hh*hhsize], col nofreq
            sum  matricula [aw = weight_hh*hhsize]
            global Educational_enrollment = 100 *`r(mean)'
    restore

* OP2 MPM+ : versión más exigente, que además de "no matriculado" considera
* el REZAGO ESCOLAR (estar matriculado pero con 2+ años de atraso respecto
* al grado que le correspondería por edad).
    gen edad_n = q1_03_edad-1
        * "rezago" = diferencia entre la edad real (ajustada por el periodo de referencia de la ENH2) y la edad normativa, aquella esperada para el grado que cursa
        gen rezago = (edad_n - 6)  if q3_11_gradoAsistido == "Pre-escolar"
        replace rezago = (edad_n - 7)  if q3_11_gradoAsistido == "Grado 1 (primaria ciclo 1)"
        replace rezago = (edad_n - 8)  if q3_11_gradoAsistido == "Grado 2 (primaria ciclo 1)"
        replace rezago = (edad_n - 9)  if q3_11_gradoAsistido == "Grado 3 (primaria ciclo 1)"
        replace rezago = (edad_n - 10) if q3_11_gradoAsistido == "Grado 4 (primaria ciclo 2)"
        replace rezago = (edad_n - 11) if q3_11_gradoAsistido == "Grado 5 (primaria ciclo 2)"
        replace rezago = (edad_n - 12) if q3_11_gradoAsistido == "Grado 6 (primaria ciclo 2)"
        replace rezago = (edad_n - 13) if q3_11_gradoAsistido == "ESBA 1 (Educacion Secundaria Basica)"
        replace rezago = (edad_n - 14) if q3_11_gradoAsistido == "ESBA 2 (Educacion Secundaria Basica)"
        replace rezago = (edad_n - 15) if q3_11_gradoAsistido == "ESBA 3 (Educacion Secundaria Basica)"
        replace rezago = (edad_n - 16) if q3_11_gradoAsistido == "ESBA 4 (Educacion Secundaria Basica)"
        replace rezago = (edad_n - 17) if q3_11_gradoAsistido == "Bach 1 (Bachillerato)"
        replace rezago = (edad_n - 18) if q3_11_gradoAsistido == "Bach 2 (Bachillerato)"
        replace rezago = 0 if rezago < 0 // un rezago negativo (adelanto) no cuenta como rezago

        gen rezago_escolar = (rezago>=2) // definimos rezago como 2+ años de atraso

    * Definiendo personas en edad escolar para asegurarse hogares sin personas en edad escolar no sean definidos con privacion 
    gen edad_escolar2 = (q1_03_edad>=$lbage & q1_03_edad<=$ubage)
    bys interview__key: egen cant_edadescolar2 = sum(edad_escolar2)

    * Privado como quien esta en rezago (+2 anios) pero que esta en edad escolar
    gen no_matriculado2 = (q1_03_edad>=$lbage & q1_03_edad<=$ubage & asistencia_escolar!=1)
        replace no_matriculado2=. if q1_03_edad<$lbage | q1_03_edad>$ubage
        replace no_matriculado2= 1 if q1_03_edad>=$lbage & q1_03_edad<=$ubage & rezago_escolar==1

    bys interview__key: egen cant_no_matriculados2 = sum(no_matriculado2) 

    gen matricula2 = 0
        replace matricula2 = 1 if cant_no_matriculados2>0 & cant_no_matriculados2~=.
        replace matricula2 = 0 if cant_edadescolar2==0 // hogares sin niños en edad escolar no estan privados por el rezago

    la var matricula2 "MPM+: Privado si el hogar tiene al menos un niño en edad escolar que o no esta matriculado o esta en rezago"
    label def matricula2 1 "Privado en atencion escolar y rezago" 0 "No privado en atencion escolar y rezago", replace
    label val matricula2 matricula2
    tab matricula matricula2, m

    ** Descriptivo
    preserve
        duplicates drop interview__key, force
        tab matricula2 cod_CV_CP [aw = weight_hh*hhsize], col nofreq
            sum  matricula2 [aw = weight_hh*hhsize]
            global Educational_enrollment = 100 *`r(mean)'
    restore


*******************************************************************************
* Dimensión 2. Acceso a infraestructura básica
*******************************************************************************

**# Acceso a red eléctrica (Electricity)
***********************************************
* MPM (estándar): solo importa si el hogar tiene o no acceso a electricidad.
    * Resultado a nivel POBLACIÓN (ponderado por individuos)
    
    *@Estefania: @poner aca comentado la creacion de la variable de electricity

    tab electricity cod_CV_CP [aw = weight_hh], col nofreq

    * Resultado a nivel HOGAR
    preserve
        duplicates drop interview__key, force
        ta electricity cod_CV_CP [aw = weight_hh*hhsize], col nofreq
        sum  electricity [aw = weight_hh*hhsize]
        global Electricity = 100*`r(mean)'
    restore

* OP2 MPM+: además de "no tener acceso", también cuenta como privado si tuvo
* un corte de electricidad durante el último mes (q2_33_SinElect no missing).
    clonevar electricity2 = electricity
    replace electricity2=0 if  q2_33_SinElect!=.

    * Resultado a nivel población
    tab electricity2 cod_CV_CP [aw = weight_hh], col nofreq

    * Resultado a nivel hogar
    preserve
        duplicates drop interview__key, force
        ta electricity2 cod_CV_CP [aw = weight_hh*hhsize], col nofreq
        sum  electricity2 [aw = weight_hh*hhsize]
        global Electricity2 = 100*`r(mean)'
    restore


**# Saneamiento mejorado (Sanitation)
***********************************************
    tab q2_28_aseo, mis
    tab q2_29_aseoExclusivo q2_28_aseo, mis

    *@Estefania: @poner aca comentado una tabla con columna de la variable original y como se volvio en la variable nueva o el codigo de como fue definida la variable imp_san_rec pero todo comentado mas por legado para ser replicados.

    * imp_san_rec trata de definir "acceso a saneamiento mejorado" como se define en JMP/GMD (baño de uso exclusivo del hogar y de tecnología mejorada).
    * Resultado a nivel población
    ta imp_san_rec cod_CV_CP [aw = weight_hh], col nofreq

    * Resultado a nivel hogar
    preserve
        duplicates drop interview__key, force
        ta imp_san_rec cod_CV_CP [aw = weight_hh*hhsize], col nofreq
        sum  imp_san_rec [aw = weight_hh*hhsize]
        global Sanitation = 100* `r(mean)'
    restore


**# Agua mejorada (Drinking_water)
***********************************
    tab q2_25_aguaTomar, mis

    *@Estefania: @poner aca comentado una tabla con columna de la variable original y como se volvio en la variable nueva o el codigo de como fue definida la variable imp_wat_rec pero todo comentado mas por legado para ser replicados.
    * imp_wat_rec Variable  que resume "acceso a fuente de agua mejorada" (tubería, pozo protegido, agua embotellada,etc., excluyendo fuentes no protegidas). 
    tab imp_wat_rec cod_CV_CP [iw = weight_hh], col nofreq

    * Resultado a nivel hogar
    preserve
        duplicates drop interview__key, force
        tab imp_wat_rec cod_CV_CP [aw = weight_hh*hhsize], col nofreq
            sum  imp_wat_rec [aw = weight_hh*hhsize]
            global Drinking_water = 100* `r(mean)'
    restore

*******************************************************************************
* Dimensión 3. Monetaria
*******************************************************************************


/*@estefania esto es lo que propongo que vaya aca en pobreza
 gen ipc=xx
 gen ppp=xx
 gen welfare_ppp = pcexp/ipcf/ppp/365
*/

*# Pobreza monetaria
*********************
tab pcexp_ppp, mis


* Línea de pobreza internacional de USD 3.00 PPA 2021 (extrema pobreza),
* usada como umbral monetario del MPM estándar.
* Línea de pobreza internacional de USD 8.30 PPA 2021 (umbral más alto),
* usada en las variantes más exigentes del índice (MPM685 / MPMplus).

save "${gdStata}/Data Clean $MPM/DataClean$MPM.dta", replace
