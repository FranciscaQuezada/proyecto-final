
# Hito 2
# Que hace: lee la base cruda de rendimiento 2024 (sin editarla), aplica el filtro
# del Hito 1 (Biobío, enseñanza media, establecimiento funcionando), trata faltantes
# y outliers con justificación y guarda la base limpia en data/processed/.

# Entrada: data/raw/rendimiento_2024.csv
# Salidas: data/processed/rendimiento_biobio_limpio.rds (para R) y .csv (para Stata)
#          output/tablas/limpieza_log.csv (bitácora de cada paso)
# Correr desde la RAÍZ del proyecto (rutas relativas).
# Limpieza: rendimiento 2024, Biobío

library(dplyr)

## Parte A — Carga y filtro del Hito 1

### A1. Lectura (data/raw/ no se modifica nunca)
base <- read.csv2("data/raw/rendimiento_2024.csv")

### A2. Filtro del Hito 1
# COD_ENSE2: 5 = media científico-humanista, 7 = media técnico-profesional
# (niños y jóvenes). Confirmar contra el diccionario de la base.
datos <- base |>
  filter(COD_REG_RBD == 8,
         COD_ENSE2 %in% c(5, 7),
         ESTADO_ESTAB == 1) |>
  select(RBD, COD_DEPE2, RURAL_RBD, COD_ENSE2, COD_GRADO,
         GEN_ALU, EDAD_ALU, PROM_GRAL, ASISTENCIA)

nrow(datos)   # debe coincidir con los 93.874 del Hito 1


## Parte B — Auditoría antes de limpiar

### B1. Faltantes y rangos
datos |> summarise(across(everything(), ~ sum(is.na(.x))))

summary(datos$PROM_GRAL)
summary(datos$ASISTENCIA)
summary(datos$EDAD_ALU)

datos |> summarise(prom_cero    = sum(PROM_GRAL == 0, na.rm = TRUE),
                   prom_fuera   = sum(PROM_GRAL < 1 | PROM_GRAL > 7, na.rm = TRUE),
                   asis_cero    = sum(ASISTENCIA == 0, na.rm = TRUE),
                   asis_fuera   = sum(ASISTENCIA < 0 | ASISTENCIA > 100, na.rm = TRUE),
                   asis_menor50 = sum(ASISTENCIA > 0 & ASISTENCIA < 50, na.rm = TRUE),
                   edad_fuera   = sum(EDAD_ALU < 12 | EDAD_ALU > 25, na.rm = TRUE))

# 7.291 estudiantes (7,8 %) tienen PROM_GRAL = 0 y 7.289 tienen
# ASISTENCIA = 0; son casi los mismos, así que no son errores al azar sino
# estudiantes sin año completo registrado (probablemente retirados o trasladados).
# Se tratan como NA porque un 0 no es una nota real ni una asistencia plausible.
# No hay asistencias fuera de rango (asis_fuera = 0) y solo 5 edades fuera de
# [12, 25]. Hay 1.548 estudiantes (1,6 %) con asistencia entre 0 y 50 %: son
# válidos y se mantienen (marcados con asistencia_baja).


## Parte C — Limpieza con justificación

### C1. Rangos inválidos -> NA (son errores o códigos de "sin dato", no valores extremos)
# - PROM_GRAL fuera de [1, 7]: la escala chilena va de 1.0 a 7.0.
# - ASISTENCIA fuera de (0, 100]: es un porcentaje; 0 = no registrado.
# - EDAD_ALU fuera de [12, 25]: no es plausible en media regular de niños y jóvenes.
datos <- datos |>
  mutate(PROM_GRAL  = ifelse(PROM_GRAL >= 1 & PROM_GRAL <= 7, PROM_GRAL, NA),
         ASISTENCIA = ifelse(ASISTENCIA > 0 & ASISTENCIA <= 100, ASISTENCIA, NA),
         EDAD_ALU   = ifelse(EDAD_ALU >= 12 & EDAD_ALU <= 25, EDAD_ALU, NA))

### C2. Variables con etiquetas y nombres claros
datos <- datos |>
  mutate(dependencia = factor(COD_DEPE2, levels = 1:5,
                              labels = c("Municipal", "Particular subvencionado",
                                         "Particular pagado", "Corp. administración delegada",
                                         "Servicio Local de Educación")),
         genero      = factor(GEN_ALU, levels = c(1, 2), labels = c("Hombre", "Mujer")),
         rural       = factor(RURAL_RBD, levels = c(0, 1), labels = c("Urbano", "Rural")),
         tipo_ens    = factor(COD_ENSE2, levels = c(5, 7),
                              labels = c("Científico-humanista", "Técnico-profesional")),
         grado       = factor(COD_GRADO)) |>
  rename(rbd = RBD, prom_gral = PROM_GRAL, asistencia = ASISTENCIA, edad = EDAD_ALU)

### C3. Outliers extremos pero válidos: se marcan, NO se eliminan
# Un estudiante con asistencia menor a 50 % es real, y es justo el caso que más
# informa la relación asistencia-notas. Se marca para probar la sensibilidad
# en 02_modelo.R.
datos <- datos |>
  mutate(asistencia_baja = asistencia < 50) |>
  select(rbd, prom_gral, asistencia, asistencia_baja, genero, edad,
         dependencia, rural, tipo_ens, grado)

### C4. Faltantes: casos completos en las variables del modelo
datos_modelo <- datos |>
  filter(!is.na(prom_gral), !is.na(asistencia), !is.na(genero), !is.na(edad),
         !is.na(dependencia), !is.na(rural), !is.na(tipo_ens), !is.na(grado))

nrow(datos) - nrow(datos_modelo)                                  # casos perdidos
round(100 * (1 - nrow(datos_modelo) / nrow(datos)), 2)            # % perdido

# sería un problema si los faltantes no fueran aleatorios (por ejemplo, si los
# estudiantes con peores notas tienden a no tener asistencia registrada).

### C5. Chequeos: si algo se rompe, el script se detiene
stopifnot(nrow(datos_modelo) > 0,
          all(datos_modelo$prom_gral >= 1 & datos_modelo$prom_gral <= 7),
          all(datos_modelo$asistencia > 0 & datos_modelo$asistencia <= 100))

### C6. Bitácora de limpieza
log_limpieza <- tibble(
  paso = c("Base país", "Filtro Hito 1", "Rangos inválidos (algún campo -> NA)",
           "Asistencia < 50 % (se mantienen)", "Casos completos (muestra final)"),
  n = c(nrow(base), nrow(datos), sum(!complete.cases(datos |> select(prom_gral, asistencia, edad))),
        sum(datos$asistencia_baja, na.rm = TRUE), nrow(datos_modelo))
)
log_limpieza


## Parte D — Guardar
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tablas", recursive = TRUE, showWarnings = FALSE)

saveRDS(datos_modelo, "data/processed/rendimiento_biobio_limpio.rds")
write.csv(datos_modelo, "data/processed/rendimiento_biobio_limpio.csv", row.names = FALSE)
write.csv(log_limpieza, "output/tablas/limpieza_log.csv", row.names = FALSE)
