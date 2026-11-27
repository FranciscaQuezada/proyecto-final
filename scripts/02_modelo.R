
# Que hace: estima y compara modelos de regresión lineal con broom y dplyr, a partir
# de la base limpia que deja 01_limpieza.R..

# Entrada: data/processed/rendimiento_biobio_limpio.rds
# Salidas: output/tablas/t_modelos_rendimiento.csv y .tex
# Correr desde la RAÍZ del proyecto.
# Regresión: rendimiento 2024, Biobío

library(dplyr)
library(broom)
library(modelsummary)

## Parte A — Carga

datos <- readRDS("data/processed/rendimiento_biobio_limpio.rds")

# Revisar que la base tenga lo que esperamos
names(datos)
nrow(datos)
summary(datos$prom_gral)
summary(datos$asistencia)


## Parte B — Modelos

### B1. Tres modelos
m1 <- lm(prom_gral ~ asistencia, data = datos)

m2 <- lm(prom_gral ~ asistencia + genero + edad + dependencia + rural, data = datos)

# Robustez: sin los estudiantes con asistencia menor a 50 % (los outliers que
# 01_limpieza.R dejó marcados pero no eliminó)
m3 <- datos |>
  filter(asistencia >= 50) |>
  lm(prom_gral ~ asistencia + genero + edad + dependencia + rural, data = _)

modelos <- list(simple = m1, controles = m2, sin_baja = m3)

### B2. La tabla de coeficientes, con broom + dplyr
tabla_m2 <- tidy(m2, conf.int = TRUE) |>
  filter(term != "(Intercept)") |>
  arrange(p.value) |>
  mutate(significativo = p.value < 0.05,
         across(c(estimate, conf.low, conf.high), ~ round(.x, 4)),
         p.value = round(p.value, 3)) |>
  select(term, estimate, conf.low, conf.high, p.value, significativo)

tabla_m2

### B3. Comparar modelos
lapply(modelos, glance) |>
  bind_rows(.id = "modelo") |>
  select(modelo, r.squared, adj.r.squared, nobs)

# Comentario: el R² pasa de 0.140 en el modelo simple a 0.198 con controles.
# Siempre sube al agregar variables, así que por sí solo no prueba que el modelo
# sea mejor; pero el R² ajustado también sube (0.140 a 0.198), por lo que los
# controles sí aportan información. Aun así, el modelo explica cerca de 20 % de
# la variación de los promedios y el resto depende de otros factores. El modelo
# sin_baja (R² 0.160) usa 85.034 estudiantes, 1.548 menos, así que su R² no es
# directamente comparable con los otros dos.

### B4. ¿Cambió el coeficiente de asistencia?
bind_rows(simple = tidy(m1, conf.int = TRUE),
          controles = tidy(m2, conf.int = TRUE),
          sin_baja = tidy(m3, conf.int = TRUE), .id = "modelo") |>
  filter(term == "asistencia") |>
  mutate(por_10pp = estimate * 10) |>
  select(modelo, estimate, por_10pp, conf.low, conf.high, p.value)

# Comentario: el coeficiente de asistencia es 0.0215 en el modelo simple, 0.0217
# con controles y 0.0231 sin asistencia < 50 %. Casi no cambia al agregar
# controles. Por cada 10 puntos porcentuales más de asistencia, el promedio se
# asocia con 0.217 puntos más (IC 95 %: 0.214 a 0.220).

## Parte C — Diagnóstico

### C1. Las tres personas peor predichas
augment(m2) |>
  arrange(desc(abs(.resid))) |>
  select(prom_gral, asistencia, genero, dependencia, .fitted, .resid) |>
  head(3)

# Comentario:  las tres tienen residuo negativo (-4.55, -4.01 y -3.94): el modelo
# les predice 5.5 a 6.0 y tienen entre 1.0 y 2.1, con asistencia de 80 a 85 %.
# La asistencia no explica esas notas tan bajas.

### C2. Distancia de Cook y apalancamiento máximos
augment(m2) |>
  summarise(max_cooksd = max(.cooksd),
            max_hat    = max(.hat))
# Cook máxima 0.0026 y apalancamiento máximo 0.0011: ninguna
# observación influye por sí sola en el modelo.

### C3. Regresión por grupo: ¿cambia la asociación según la dependencia?
dif_dependencia <- datos |>
  group_by(dependencia) |>
  group_modify(~ tidy(lm(prom_gral ~ asistencia, data = .x), conf.int = TRUE)) |>
  filter(term == "asistencia") |>
  ungroup() |>
  mutate(across(c(estimate, conf.low, conf.high), ~ round(.x, 4)),
         distinta_de_cero = conf.high < 0 | conf.low > 0) |>
  select(dependencia, estimate, conf.low, conf.high, distinta_de_cero) |>
  arrange(desc(estimate))

dif_dependencia

# Comentario: la asociación es parecida entre dependencias (cerca de 0.021 a
# 0.023, o sea 0.21 a 0.23 puntos por cada 10 puntos porcentuales de
# asistencia) y distinta de cero en todas.

## Parte D — Interpretación

sd(datos$prom_gral)   # para juzgar si la magnitud es grande o pequeña

# En el modelo con controles, 10 puntos porcentuales más de asistencia se asocian
# con 0.217 puntos más de promedio (IC 95 %: 0.214 a 0.220), a igual género, edad,
# dependencia y ruralidad.
# Con más de 86.000 estudiantes todo es significativo, así que importa el tamaño:
# 0.217 puntos son cerca de 0.33 desviaciones estándar (0.217 / 0.664), una
# asociación moderada. El R² es 0.198.
# Limitaciones: es una asociación, no causal; lm() no considera que los
# estudiantes de un mismo colegio se parecen; faltan variables como el nivel
# socioeconómico; se descartó 7.8 % de los casos.

## Parte E — Comunicar

# 1. Tabla con modelsummary() que muestra los modelos lado a lado
modelsummary(modelos, stars = TRUE,
             coef_omit = "dependencia",
             gof_map = c("nobs", "r.squared"))

# 2. Exportar
dir.create("output/tablas", recursive = TRUE, showWarnings = FALSE)

modelsummary(modelos, output = "output/tablas/t_modelos_rendimiento.csv")
modelsummary(modelos, stars = TRUE, coef_omit = "dependencia",
             gof_map = c("nobs", "r.squared"),
             output = "output/tablas/t_modelos_rendimiento.tex")
