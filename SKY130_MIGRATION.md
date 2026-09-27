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

## Línea base verificable

- La regresión de boot externo y la prueba de pausa CPU/SPI pasan. Esta última
  verifica que `cpu_wait` detiene SERV, mantiene estables sus buses y deja al
  controlador SPI progresar.
- Una síntesis genérica con Yosys 0.57 del top completo termina sin errores:
  6 094 celdas, 5 556 wires y 8 951 bits de wire. El register file de SERV
  representa 3 153 celdas genéricas. Esta es una línea base de lógica, no una
  medición de área, congestión o timing Sky130.

## Bloqueos antes de aplicar a tapeout

1. **Fijar el shuttle.** Los workflows usan las etiquetas del template Sky130
   vigente. Antes de publicar, hay que sustituirlas por las que correspondan
   exactamente al shuttle aceptando solicitudes en Tiny Tapeout.
2. **Harden `2x2`.** El tamaño `2x2` se conserva como hipótesis, no como área
   aprobada. El SoC completo tiene una estimación de 6 094 celdas genéricas y
   necesita un GDS Sky130 sin fallos de colocación, ruteo, DRC, LVS ni timing.
3. **Cerrar el clock-gating.** `serv_extmem_soc.v` pausa SERV mientras la
   memoria SPI completa una palabra. La expresión RTL `clk & !cpu_wait` fue
   válida para bring-up, pero el flujo Sky130 debe reemplazarla por una ICG
   Sky130 validada o por un mecanismo de espera que no genere un reloj lógico.
4. **Comprobar hardware externo.** El diseño usa 50 MHz de reloj de entrada y
   genera `SCK=12.5 MHz` con `SPI_CLK_DIV=2`; verificar el Pmod y el devkit
   asociados al shuttle elegido antes de fijar la documentación final.

## Orden de trabajo recomendado

1. Ejecutar el workflow Sky130 y resolver lint/precheck.
2. Ejecutar gate-level simulation con el netlist generado.
3. Inspeccionar área, congestión y slack; decidir si `2x2` cabe.
4. Implementar o validar la solución Sky130 de clock-gating.
5. Actualizar el tag del shuttle, `info.yaml` y la solicitud de Tiny Tapeout.
