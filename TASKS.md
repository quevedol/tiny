# Backlog de trabajo — Sky130

Cada tarea tiene un resultado comprobable. No se deben mezclar tareas de
infraestructura, arquitectura y modelo en un mismo cambio.

## Prioridad 0 — establecer el flujo Sky130

- [x] **Fijar la síntesis lógica de referencia.**
  - Resultado: Yosys 0.57 completa el top con 6 094 celdas genéricas; el
    register file de SERV concentra 3 153.
  - Nota: no es un resultado físico Sky130.

- [ ] **Seleccionar el shuttle Sky130.**
  - Responsable: supervisor.
  - Entrega: tag oficial de Tiny Tapeout, fecha límite, límite de tiles y
    actualización de `.github/workflows/`.

- [x] **Ejecutar el primer hardening Sky130.**
  - Responsable: estudiante.
  - Entrega: diagnóstico reproducible: `GPL-0301`, 124.941% de utilización
    (`88 282.219 um^2` de celdas sobre `72 564.595 um^2` de core 2x2).
  - Aceptación: `2x2` queda descartado; se evaluó `3x2` y un baseline 3x4.

- [x] **Ejecutar gate-level simulation Sky130.**
  - Entrega: `test/Makefile.board GATES=yes` ejecuta las 5 pruebas de placa
    sobre un netlist `sky130_fd_sc_hd`; pasan sobre el netlist de síntesis.
  - Aceptación final: el job `gl_test` de GitHub Actions (netlist post-ruteo).

## Prioridad 1 — cerrar riesgos de tapeout

- [x] **Mantener la regresión de espera CPU/SPI.**
  - Entrega: `test_serv_extmem.py` comprueba que SERV mantiene estable su
    petición mientras el puente reúne la palabra, sin `ack` anticipado y con
    exactamente un `ack` al final.

- [x] **Eliminar el clock-gating de SERV.**
  - Motivo: la compuerta creaba un segundo dominio de reloj (1 191
    flip-flops) cuyo desfase impedía cerrar hold en 3x2. SERV ya espera el
    `ack` de Wishbone, así que la pausa de reloj no era necesaria.
  - Entrega: diseño con un único reloj; regresiones RTL y de placa aprobadas.

- [x] **Confirmar el tamaño definitivo.**
  - Entrega: `info.yaml` y la documentación en `3x2`.

- [x] **Cerrar el hardening 3x2.**
  - Entrega: commit `c853560`: `gds`, `precheck` y `gl_test` aprobados; DRC,
    LVS y antenas limpios; hold cerrado en las 9 esquinas; utilización 82.9%.
  - Pendiente menor: un camino falla setup por 9.5 ps solo en
    `max_ss_100C_1v60` (aviso). Detalle en `SKY130_MIGRATION.md`.

- [ ] **Validar el hardware externo.**
  - Responsable: estudiante.
  - Entrega: tabla de conexiones del Pmod/devkit del shuttle y prueba de
    compatibilidad eléctrica a 3.3 V.
  - Aceptación: SPI, UART y señales reservadas están documentadas y no exceden
    la especificación del devkit.

## Prioridad 2 — ampliar el demostrador TinyML

- [ ] **Medir el smoke model en ciclos.**
  - Responsable: estudiante.
  - Entrega: contador o registro de ciclos y resultado por UART.
  - Aceptación: el número coincide entre simulación ideal y serial, dentro de
    la latencia esperada de SPI.

- [ ] **Exportar un modelo denso pequeño desde Python.**
  - Responsable: estudiante.
  - Entrega: pesos INT8, biases INT32, vector de entrada y salida esperada.
  - Aceptación: Python, firmware y MAC producen el mismo resultado.

- [ ] **Evaluar el objetivo `256 -> 16 -> 10`.**
  - Responsable: supervisor + estudiante.
  - Entrega: estimación de Flash, PSRAM, ciclos y precisión antes de entrenar.
  - Aceptación: decisión explícita de mantenerlo, reducirlo o cambiarlo.

## No empezar todavía

- QSPI de cuatro líneas.
- Segunda PSRAM.
- DMA de pesos.
- Modelo MNIST final.

Estas extensiones se reconsideran únicamente después de que el hardening
Sky130 3x2 esté cerrado.
