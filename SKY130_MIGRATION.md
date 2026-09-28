# Migración a Tiny Tapeout Sky130

Esta carpeta es una copia independiente de la versión IHP. El RTL funcional,
firmware, modelo INT8 y regresiones se conservan; la infraestructura física se
ha cambiado para SkyWater `sky130A`.

## Cambios aplicados

- El flujo GDS, precheck, gate-level test y documentación usan la variante
  Sky130 del template de Tiny Tapeout.
- El contenedor declara `PDK=sky130A` y usa la versión de LibreLane indicada
  por el template Sky130 vigente.
- La simulación gate-level usa las bibliotecas
  `sky130_fd_sc_hd` y `USE_POWER_PINS`.
- La documentación identifica Sky130 como proceso destino; la interfaz del
  wrapper no cambia: `clk`, `rst_n`, 8 `ui`, 8 `uo` y 8 `uio`.
- Todo el diseño usa un único reloj, `clk`. SERV ya no se pausa con una
  compuerta de reloj: espera el `ack` de Wishbone mientras el puente SPI reúne
  la palabra (ver "Cierre de timing en 3x2").
- El MAC acumula en un ciclo propio: cada producto usa nueve ciclos (ocho de
  desplazamiento y suma, uno de acumulación de 32 bits).

## Tamaño: 3x2

Historia del dimensionamiento:

- `2x2`: no cabe. `88 282.219 um^2` de celdas frente a `72 564.595 um^2` de
  core (`124.941%`), fallo `GPL-0301` antes de ruteo.
- `3x2` (primeros intentos): la colocación detallada falló con
  `PL_TARGET_DENSITY_PCT` 80 y 90 (`DPL-0036`). El MAC dejó de usar un
  multiplicador paralelo y pasó a acumular por desplazamientos y sumas.
- `3x3` no es una geometría válida del template Sky130; `3x4` generó GDS con
  35.310% de utilización y sirvió como referencia de área.
- `3x2` (definitivo): coloca y rutea con DRC, LVS y antenas limpios.

## Cierre de timing en 3x2

1. Con la compuerta de reloj (`sky130_fd_sc_hd__dlclkp_4`) el flujo llegaba a
   signoff pero fallaba por **hold** en las esquinas `ff_n40C_1v95` (error
   fatal) y avisaba de **setup** en `ss_100C_1v60`. La compuerta dejaba 1 191
   flip-flops de SERV en un segundo dominio (`cpu_clk`) desfasado respecto de
   `clk`; 725 celdas de retardo no lograron compensarlo.
2. SERV no necesita la pausa de reloj: el arranque completo desde Flash/PSRAM
   serie y las pruebas de placa pasan igual con SERV sobre `clk`. Se eliminó
   la compuerta (el archivo `src/tech/sky130_clock_gate.v` queda en el
   repositorio sin usarse). Tras CTS, STA ya no muestra violaciones de setup y
   el peor hold es de solo -0.047 ns.
3. Un margen de hold de 0.1 ns antes del ruteo insertó 1 590 buffers (+17.9%
   de área) y la colocación detallada volvió a fallar (`DPL-0036`). Se repara
   solo el hold real antes del ruteo (`PL_RESIZER_HOLD_SLACK_MARGIN` = 0.0) y
   se mantiene 0.05 ns después (`GRT_RESIZER_HOLD_SLACK_MARGIN`).
4. El job `gds` imprime al final de su log el resumen de STA post-ruteo
   (paso "Timing summary").

## Línea base verificable

- Todas las regresiones RTL pasan, incluidas las de placa
  (`test/Makefile.board`: top module + modelo de Flash/PSRAM en los pines
  `uio`, con reloj de 50 MHz, UART a 115200 y SCK a 12,5 MHz).
- La prueba de espera CPU/SPI (`test_serv_extmem.py`) comprueba que SERV
  mantiene estable su petición, que no hay `ack` anticipado y que llega
  exactamente un `ack` por palabra.
- Una síntesis con Yosys y `sky130_fd_sc_hd` reporta unas 8 100 celdas y
  65 500 um^2 antes de colocar; las 5 pruebas de placa pasan también sobre ese
  netlist (gate-level de síntesis).

## Pendiente antes de aplicar a tapeout

1. **Fijar el shuttle.** Sustituir las etiquetas `ttsky26d`/`ttsky26c` de los
   workflows por las del shuttle que acepte la solicitud.
2. **Comprobar hardware externo.** Reloj de 50 MHz, `SCK = 12,5 MHz` con
   `SPI_CLK_DIV = 2`; verificar el Pmod y el devkit del shuttle elegido.
3. **Programación de la Flash.** Documentar cómo se carga el firmware en la
   Flash del Pmod antes de soltar el reset.
