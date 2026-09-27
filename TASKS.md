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
  - Aceptación: `2x2` queda descartado; el próximo hardening será `3x2`.

- [ ] **Ejecutar gate-level simulation Sky130.**
  - Responsable: estudiante.
  - Entrega: resultado de `GATES=yes` y cualquier corrección de testbench.
  - Aceptación: la simulación usa `sky130_fd_sc_hd` y no bibliotecas IHP.

## Prioridad 1 — cerrar riesgos de tapeout

- [x] **Mantener la regresión de pausa CPU/SPI.**
  - Responsable: nosotros.
  - Entrega: `test_serv_extmem.py` comprueba que `cpu_wait` congela SERV,
    mantiene estables los buses de CPU y deja progresar el controlador SPI.
  - Aceptación: pasa antes y después de sustituir el clock-gating.

- [x] **Implementar el clock-gating de SERV.**
  - Entrega: wrapper con latch RTL e ICG `sky130_fd_sc_hd__dlclkp_4`, más test
    que verifica que no se trunca el pulso cuando inicia una espera SPI.
  - Pendiente de aceptación: RTL, gate-level y timing sin reloj lógico.

- [ ] **Obtener margen de área en 3x2.**
  - Responsable: nosotros.
  - Entrega: P&R 3x2 y, si hace falta, rediseño de la ruta de datos de mayor
    área.
  - Aceptación: P&R bajo 80% antes de CTS, con margen suficiente para ruteo.

- [ ] **Confirmar el tamaño definitivo.**
  - Responsable: supervisor, basado en el reporte físico.
  - Entrega: `info.yaml` congelado en 3x2, 3x3 u otra alternativa.
  - Aceptación: P&R y timing aprobados para ese tamaño.

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
Sky130 y el clock-gating estén cerrados.
