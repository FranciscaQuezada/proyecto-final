
# Autor: Francisca Quezada
# Fecha: 2026-11-17
# Qué hace: abre la base de rendimiento 2024, confirma las variables del Hito,
# filtra Biobío y enseñanza media, y guarda el conteo en output/tablas/

library(dplyr)

base <- read.csv2("data/raw/rendimiento_2024.csv")
nrow(base)  # 3.568.930 registros en el pais
ncol(base)  # 38 variables

# Revisar que los nombres de variables coincidan con los del Hito
names(base)

# Filtro del Hito: Biobío, enseñanza media, establecimiento funcionando
base_biobio <- base |>
  filter(COD_REG_RBD == 8,
         COD_ENSE2 %in% c(5, 7),
         ESTADO_ESTAB == 1)

# N° de casos: estudiantes de enseñanza media en el Biobío
nrow(base_biobio)          # 93.874 estudiantes en la region del Biobío

# n establecimientos: RBD distintos
n_distinct(base_biobio$RBD) # 253 establecimientos

# Para guardar
dir.create("output/tablas", recursive = TRUE, showWarnings = FALSE)

verificacion <- data.frame(
  registros_pais   = nrow(base),
  variables        = ncol(base),
  casos_biobio     = nrow(base_biobio),
  establecimientos = n_distinct(base_biobio$RBD)
)

verificacion
write.csv(verificacion, "output/tablas/verificacion_datos.csv", row.names = FALSE)

