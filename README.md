
# Hito 1 - Proyecto final
## Fecha: 2026-11-17

## Título: Asistencia Escolar en el Biobío

## Equipo: Francisca Quezada

## Pregunta
En la region del Biobío ¿cuantos puntos porcentuales de asistencia anual se asocian
con estudiar en un establecimiento municipal, particular subvencionado o particular
pagado, y con estudiar en zona rural, entre estudiantes de enseñanza media del año
escolar 2024, a igual sexo y curso?

## ¿Por qué es importante?
La inasistencia reiterada es una señal temprana de desvinculación escolar, que el 
Mineduc monitorea con reportes de asistencia. Saber en qué tipos de colegio y zonas 
hace falta más ayuda, permite decidir dónde focalizar los programas de retención. Le 
sirve a quienes diseñan política educativa regional y a los sostenedores.

## Datos
- Fuente: 	Rendimiento por estudiante, Centro de Estudios del Ministerio de Educación 
(Datos Abiertos Mineduc)
- Enlace: 	https://datosabiertos.mineduc.cl/rendimiento-por-estudiante-2/
- Fecha de descarga: 16-11-2026
- Formato: CSV, codificación UTF-8
- Unidad y cobertura: estudiantes, un registro por estudiante y año; todos los
establecimientos reconocidos del país. 3.568.930 registros en total.
- Casos del proyecto. Falta anotar 93.874 estudiantes en 253 establecimientos.
- Variables: 
  - Resultado: asistencia anual en % “ASISTENCIA” 
  - Explicativas: dependencia “COD_DEPE2” y ruralidad “RURAL_RBD”
  - Controles: sexo “GEN_ALU” y curso “COD_GRADO”
  - Para filtrar: región “COD_REG_RBD” =8, enseñanza “COD_ENSE2” =5 y 7 y el estado 
  del establecimiento “ESTADO_ESTAB” =1; Identificador: Establecimiento “RBD”.

## Estructura
proyecto-final/
├── data/
│   ├── raw/          <- datos originales
│   └── processed/    <- datos limpios que generan los scripts
├── scripts/
│   ├── 00_explorar_datos.R      (R)       listo
│   ├── 01_limpiar.R             (R)       pendiente
│   ├── 02_describir.R           (R)       pendiente
│   ├── 03_modelar.do            (Stata)   pendiente
│   └── 04_figuras_tablas.R      (R)       pendiente
└── output/
    ├── tablas/
    └── figuras/
├── informe.tex	-> informe.pdf	(LaTeX)
├── presentacion.qmd -> presentacion.html (Quarto)
└── README.md

## Justificacion de R y STATA
El trabajo se reparte por etapa: R hace 4 de los 5 scripts (explorar, limpiar, 
describir y comunicar) y Stata hace solo la estimacion.

## Cómo reproducir
Descargar el CSV desde el enlace de Datos Abiertos Mineduc.
Guardarlo como data/raw/rendimiento_2024.csv (la carpeta data/raw/ no se sube a 
GitHub por el tamaño del archivo).
Abrir proyecto-final.Rproj en RStudio y ejecutar los scripts en orden, del 00 al 04.

## Modelo
ASISTENCIA ~ COD_DEPE2 + RURAL_RBD + GEN_ALU + COD_GRADO

Regresión lineal con errores estándar agrupados por establecimiento (RBD). COD_DEPE2 
entra como variable categórica con municipal como categoría base, RURAL_RBD como indicadora
(1 = rural), y GEN_ALU y COD_GRADO son los controles. Los coeficientes se leen como
diferencias en puntos porcentuales y como asociaciones, no como efectos causales.

## Declaración de autoría y uso de IA
La pregunta, los controles y las decisiones del análisis son míos. Usé Claude (Anthropic)
para entender errores de código y la sintaxis de los comandos, y para revisar la redacción 
y la estructura de los documentos.


## Hito 2 - Avance

### Cómo reproducir
1. Abrir `proyecto-final.Rproj`.
2. `install.packages(c("dplyr", "broom", "modelsummary"))`
3. Correr en orden: `scripts/00_explorar_datos.R` → `01_limpieza.R` → `02_modelo.R`.

### Limpieza (`01_limpieza.R`)
- Promedio = 0 y asistencia = 0 pasan a NA (7.291 casos, estudiantes sin año completo registrado).
- Los 1.548 con asistencia menor a 50 % se mantienen y se usan en la robustez.
- Casos completos: se pierde 7,8 %; quedan 86.582 estudiantes.
- Bitácora en `output/tablas/limpieza_log.csv`; base limpia en `data/processed/`.

### Modelo (`02_modelo.R`)
Tres regresiones: simple, con controles y sin asistencia < 50 %. Con controles, 10 puntos
porcentuales más de asistencia se asocian con 0,217 puntos más de promedio (IC 95 %: 0,214 a
0,220), unas 0,33 desviaciones estándar; R² = 0,198. Es una asociación, no causal.
Tabla en `output/tablas/t_modelos_rendimiento.csv`.