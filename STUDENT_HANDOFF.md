# Handoff para estudiante — SERV TinyML Sky130

## Objetivo del proyecto

Convertir esta variante del SoC `SERV RV32I + MAC INT8 + memoria SPI externa`
en una solicitud reproducible de Tiny Tapeout para Sky130. El demostrador
actual ejecuta un clasificador INT8 smoke `4 -> 3`; el objetivo posterior es
una red `256 -> 16 -> 10`.

## Lectura obligatoria

1. [`README.md`](README.md): propósito y estructura del repositorio.
2. [`SKY130_MIGRATION.md`](SKY130_MIGRATION.md): diferencias de proceso y
   bloqueos de tapeout.
3. [`PROJECT_GUIDE.md`](PROJECT_GUIDE.md): arquitectura, mapa de memoria y
   plan general.
4. [`src/project.v`](src/project.v): wrapper Tiny Tapeout y pinout.
5. [`src/soc/serv_extmem_soc.v`](src/soc/serv_extmem_soc.v): integración de
   CPU, SPI y mecanismo de espera.

## Mapa rápido

| Componente | Ruta | Qué hace |
|---|---|---|
| Wrapper Tiny Tapeout | `src/project.v` | Conecta los 26 pines estándar al SoC. |
| SoC y bus | `src/soc/` | SERV, MMIO, UART y puente de memoria. |
| CPU | `src/cpu/` | Configuración local y fuentes fijadas de SERV. |
| Acelerador | `src/accel/` | MAC signed INT8 y registros MMIO. |
| Memoria serie | `src/mem/` | Flash/PSRAM SPI y arbitraje de bus. |
| Firmware | `firmware/` | Startup, linker, C bare-metal y imagen hex. |
| Modelo | `model/` | Referencia Python bit-exact y vector smoke. |
| Pruebas | `test/` | Cocotb, RTL, memoria serie y boot. |

## Preparar el entorno

1. Instalar Git y Docker Desktop, o abrir el repositorio en el devcontainer.
2. Confirmar que Docker está iniciado antes de simular.
3. Ejecutar desde `test/` las regresiones especificadas en
   [`test/README.md`](test/README.md), y guardar el resultado relevante en la
   descripción del cambio.
4. No editar `src/cpu/serv/`: es una copia fijada de SERV. Las adaptaciones van
   en `src/cpu/serv_cpu.v` o en los módulos del SoC.

## Límites de autonomía

El estudiante puede añadir tests, documentación, scripts de análisis y cambios
locales de RTL. Debe solicitar revisión antes de modificar:

- el top module, el pinout o `info.yaml`;
- el tamaño de tiles o el tag de shuttle;
- la configuración de SERV, el linker o el protocolo SPI;
- la arquitectura de reloj (un único dominio `clk`);
- pesos/modelos usados como demostrador oficial.

## Criterio de entrega de cada tarea

- Cambio pequeño y descrito.
- Prueba automática nueva o actualizada cuando cambie RTL/firmware.
- Regresión aplicable aprobada.
- Actualización de `TASKS.md` y `PROJECT_GUIDE.md` si cambia un hito.
