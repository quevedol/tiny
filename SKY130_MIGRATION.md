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
- El reloj de SERV se pausa con un wrapper de clock-gating. En RTL usa un
  latch transparente en fase baja; durante hardening, `VERILOG_DEFINES` activa
  la celda integrada `sky130_fd_sc_hd__dlclkp_4`.

## Línea base verificable

- La regresión de boot externo y la prueba de pausa CPU/SPI pasan. Esta última
  verifica que `cpu_wait` detiene SERV, mantiene estables sus buses y deja al
  controlador SPI progresar.
- Una síntesis genérica con Yosys 0.57 del top completo termina sin errores:
  6 094 celdas, 5 556 wires y 8 951 bits de wire. El register file de SERV
  representa 3 153 celdas genéricas. Esta es una línea base de lógica, no una
  medición de área, congestión o timing Sky130.
- El primer hardening Sky130 confirmó que el diseño actual **no cabe en 2x2**:
  `88 282.219 um^2` de celdas frente a `72 564.595 um^2` de core, o `124.941%`
  de utilización. El fallo fue `GPL-0301`, antes de ruteo, timing o DRC. La
  siguiente iteración usa `3x2`: estima `81.2%` de utilización antes de CTS,
  con `PL_TARGET_DENSITY_PCT=80`; deberá validarse con P&R completo.

## Bloqueos antes de aplicar a tapeout

1. **Fijar el shuttle.** Los workflows usan las etiquetas del template Sky130
   vigente. Antes de publicar, hay que sustituirlas por las que correspondan
   exactamente al shuttle aceptando solicitudes en Tiny Tapeout.
2. **Harden `3x2`.** El primer P&R excede `2x2` por 24.941%. El tamaño `3x2`
   es el nuevo candidato y debe superar colocación, ruteo, timing, DRC y LVS.
3. **Validar el clock-gating.** `serv_extmem_soc.v` ahora usa una ICG Sky130
   durante hardening. Aún debe completar RTL, gate-level y timing.
4. **Comprobar hardware externo.** El diseño usa 50 MHz de reloj de entrada y
   genera `SCK=12.5 MHz` con `SPI_CLK_DIV=2`; verificar el Pmod y el devkit
   asociados al shuttle elegido antes de fijar la documentación final.

## Orden de trabajo recomendado

1. Ejecutar el workflow Sky130 y resolver lint/precheck.
2. Ejecutar gate-level simulation con el netlist generado.
3. Inspeccionar área, congestión y slack; decidir si `3x2` cabe.
4. Implementar o validar la solución Sky130 de clock-gating.
5. Actualizar el tag del shuttle, `info.yaml` y la solicitud de Tiny Tapeout.
