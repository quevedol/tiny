# Guía del proyecto SERV TinyML para Sky130

## Estado general

- Shuttle: **Tiny Tapeout Sky130**; la etiqueta exacta se fijará al abrir la solicitud.
- Proceso: **SkyWater SKY130A 130 nm**.
- Área reservada: **4x2 (8 tiles)**.
- Arquitectura: **SERV RV32I + MAC INT8 + QSPI Flash/PSRAM externa**.
- Usuario GitHub y prefijo del top module: **quevedol**.
- Frecuencia objetivo inicial: **50 MHz internos, QSPI hasta 25 MHz**.
- Demostrador inicial: **MNIST 16x16, red densa 256 -> 16 -> 10**.
- Rama de trabajo: `main`.
- Fecha interna de congelamiento propuesta: **19 de septiembre de 2026**.
- Fecha de cierre del shuttle: **por confirmar para el shuttle Sky130 seleccionado**.

Esta guía es la fuente de verdad del proyecto. Cada fase debe actualizarse cuando cambie de estado y las decisiones que afecten área, pinout, ISA o formato de memoria deben registrarse aquí.

## Definición de terminado

El diseño estará listo para enviar cuando:

1. Queda en un bloque `4x2` con utilización y congestión aceptables.
2. Arranca firmware RISC-V desde QSPI Flash.
3. Lee y escribe la PSRAM del QSPI Pmod.
4. Ejecuta firmware bare-metal compilado desde C.
5. El MAC INT8 coincide bit a bit con el modelo de referencia Python.
6. Ejecuta una inferencia MNIST 16x16 completa.
7. RTL, gate-level simulation, timing y verificaciones físicas pasan.
8. La documentación permite reproducir la programación y la prueba del chip.

## Arquitectura base seleccionada

```text
QSPI Flash/PSRAM
       |
controlador QSPI
       |
   bus memoria
       |
  SERV RV32I ---- bus MMIO ---- MAC INT8 / UART / GPIO
```

La primera revisión será deliberadamente sencilla: la CPU cargará cada par activación/peso al MAC mediante MMIO. Un lector autónomo o DMA será una mejora opcional y solo se incorporará si sobra área y tiempo.

## Mapa de memoria propuesto

| Rango | Uso |
|---|---|
| `0x0000_0000-0x00ff_ffff` | QSPI Flash: firmware, pesos e imágenes |
| `0x1000_0000-0x107f_ffff` | PSRAM A: activaciones y buffers |
| `0x1080_0000-0x10ff_ffff` | PSRAM B: buffers opcionales |
| `0x2000_0000-0x2000_003f` | Acelerador MAC |
| `0x2000_0100-0x2000_011f` | UART |
| `0x2000_0200-0x2000_021f` | GPIO, identificación y debug |

## Pinout objetivo

| Pin | Uso |
|---|---|
| `uio[0]` | Flash CS |
| `uio[1]` | QSPI SD0/MOSI |
| `uio[2]` | QSPI SD1/MISO |
| `uio[3]` | QSPI clock |
| `uio[4]` | QSPI SD2 |
| `uio[5]` | QSPI SD3 |
| `uio[6]` | PSRAM A CS |
| `uio[7]` | PSRAM B CS |
| `ui[0]` | UART RX |
| `ui[1]` | Inicio/manual |
| `ui[2]` | Modo de prueba |
| `uo[0]` | UART TX |
| `uo[4:1]` | Clase predicha |
| `uo[5]` | Inferencia terminada |
| `uo[6]` | Error |
| `uo[7]` | CPU activa/debug |

Durante el bring-up inicial el wrapper usa temporalmente `ui_in` y `uio_in` como operandos del MAC. Este arnés se eliminará cuando se integre el bus MMIO.

## Fase 0 - Reserva y control de riesgo

- [ ] Confirmar disponibilidad de `4x2` tiles en el shuttle Sky130 seleccionado.
- [x] Confirmar precio y reservar/comprar el espacio.
- [ ] Confirmar disponibilidad física del QSPI Pmod.
- [ ] Confirmar la fecha interna de congelamiento propuesta antes del cierre.
- [ ] Congelar formalmente las funciones obligatorias y opcionales.

Funciones obligatorias:

- Boot desde QSPI Flash.
- Lectura y escritura de PSRAM.
- UART TX.
- SERV ejecutando firmware C.
- MAC signed INT8 con acumulador de 32 bits.
- Una inferencia completa y reproducible.

Funciones opcionales, en orden de prioridad:

1. UART RX.
2. Contadores de ciclos.
3. Segunda PSRAM.
4. Interrupción del MAC.
5. DMA o lector autónomo de pesos.

## Fase 1 - Base del repositorio

- [x] Aplicar la infraestructura oficial `ttsky-verilog-template`.
- [x] Inicializar la rama principal `main`.
- [x] Configurar `4x2`, 50 MHz y top module inicial.
- [x] Registrar el pinout objetivo en `info.yaml`.
- [x] Añadir estructura inicial para RTL, firmware y modelo.
- [x] Ejecutar el primer test RTL en el entorno local.
- [ ] Confirmar que GitHub Actions genera documentación y GDS.

Validación inicial: compilación con Icarus Verilog y pruebas Cocotb aprobadas a 50 MHz. El hardening 3x4 alcanzó 35.310% de utilización y generó GDS; el siguiente experimento mide el tamaño 4x2 antes de congelar el área final.

## Fase 2 - SERV y firmware mínimo

- [x] Importar una versión fijada de SERV conservando licencias.
- [x] Auditar el register file y documentar si será RV32I completo o un perfil reducido.
- [x] Ejecutar pruebas dirigidas de ALU, branches, loads y stores.
- [x] Crear startup, linker script y flags del compilador.
- [x] Ejecutar `SERV alive` desde una memoria RTL ideal.
- [x] Producir salida UART desde firmware C.

Revisión fijada: SERV `1.4.0`, commit `41e8aeedfd1e9ad5f95902c5b0dfc83d1c99e5d2`, licencia ISC. Los 18 archivos del fileset oficial se conservan sin modificaciones en `src/cpu/serv/`; la configuración local está aislada en `src/cpu/serv_cpu.v`.

Resultado de la auditoría: se mantienen los 32 GPR y la ABI estándar `rv32i/ilp32`. La configuración inicial usa `W=1`, `RF_WIDTH=2`, `WITH_CSR=0`, `DEBUG=0`, `MDU=0`, `COMPRESSED=0` y `ALIGN=0`. Una síntesis lógica genérica de SERV aislado reportó 3 729 celdas, de las cuales 3 153 corresponden al register file inferido. El número sirve para identificar el riesgo dominante, pero no sustituye la síntesis física SKY130.

Prueba de arranque del 18 de agosto de 2026: el firmware C generado con GCC ejercitó suma, resta, XOR, shift, comparaciones, branches, loads y stores; usó el MAC por MMIO, ejecutó el modelo INT8 smoke `4 -> 3` desde PSRAM, transmitió `SML1\n` por UART y después escribió la firma `0x534d4c31` (`SML1`) a `0x2000_0200`. El presupuesto de la prueba sobre memoria RTL ideal es 60 000 ciclos para incluir esa inferencia.

La síntesis lógica del SoC parcial `SERV + MAC MMIO + UART TX` reportó 5 396 celdas genéricas. El register file y el MAC son los bloques que dominan el coste; falta el controlador QSPI, por lo que debe ejecutarse una síntesis SKY130 temprana antes de congelar esa integración.

Puerta de avance: un binario bare-metal compilado con GCC ejecuta desde memoria ideal y transmite por UART.

## Fase 3 - Bus y periféricos

- [x] Implementar la primera decodificación del mapa de memoria.
- [ ] Implementar handshake y timeout del bus.
- [x] Integrar UART TX.
- [ ] Añadir registro de identificación `0x534d4c31` (`SML1`).
- [ ] Añadir salidas de clase, done y error.
- [ ] Verificar accesos MMIO de 8 y 32 bits.

## Fase 4 - QSPI Flash/PSRAM

- [x] Implementar la primera lectura SPI de Flash (`0x03`, 24 bits) compatible con el QSPI Pmod.
- [x] Crear un modelo RTL dirigido de Flash para validar comando, dirección y palabra leída.
- [ ] Evolucionar el lector a Fast Read Quad/QSPI y fijar sus ciclos dummy.
- [ ] Crear el modelo RTL de PSRAM APS6404L.
- [ ] Implementar inicialización de Flash en lectura continua.
- [ ] Implementar inicialización de PSRAM en modo QPI.
- [ ] Mantener SERV en reset hasta `memory_ready`.
- [x] Conectar Flash de instrucciones y PSRAM A de datos al bus de SERV.
- [x] Establecer el orden little-endian entre RV32I y la memoria serie.
- [x] Ejecutar firmware C desde Flash en el modelo integrado de boot.
- [x] Leer y escribir datos en PSRAM en el modelo integrado de boot.
- [ ] Validar transferencias de 8, 16 y 32 bits.
- [ ] Probar recuperación por timeout/error.

El Pmod objetivo contiene Flash W25Q128JV de 16 MB y dos PSRAM APS6404L de 8 MB. La primera ruta validada usa `SPI mode 0`, comandos `0x03` (lectura) y `0x02` (programación), SD0 como MOSI y SD1 como MISO. `spi_mem_bridge` arbitra el bus de instrucciones (Flash) y datos (PSRAM, con prioridad de datos), y el linker coloca `.text`/`.rodata` en Flash y `.data`/`.bss`/pila en PSRAM A. Sigue siendo una ruta conservadora: aún faltan quad, la segunda PSRAM, subpalabras y timeouts para la versión de producción.

Hallazgo y solución de arquitectura: SERV configurado con `W=1` no puede avanzar durante la latencia de una transacción SPI. `spi_mem_bridge` expone `cpu_wait_o` mientras reúne una palabra serie; `serv_extmem_soc` pausa solamente el reloj de SERV y deja al controlador SPI sobre el reloj de sistema. Al completarse la palabra, el puente emite exactamente un `ack` y SERV reanuda la ejecución. El boot integrado ejecutó el firmware C desde Flash, copió el modelo smoke a PSRAM, transmitió `SML1\n` y publicó la firma `SML1` tras 2 652 440 ns en RTL (Flash/PSRAM serie modeladas). La síntesis lógica genérica del top completo reportó 6 094 celdas; es una estimación preliminar y la compuerta RTL debe reemplazarse o validarse con una solución de clock-gating SKY130 durante síntesis física.

## Fase 5 - MAC INT8

- [x] Crear el primer MAC signed `8x8` con acumulador de 32 bits.
- [x] Añadir bias, ReLU, shift y saturación INT8.
- [x] Añadir detección explícita de overflow.
- [x] Definir e implementar los registros MMIO.
- [x] Crear driver C.
- [x] Ejecutar 10 000 vectores aleatorios contra la referencia Python, por MMIO.

Registros MAC (`0x2000_0000`): `CMD` +`0x00` (`clear`, `load_bias`, `mac_valid`), activación +`0x04`, peso +`0x08`, bias +`0x0c`, acumulador +`0x10`, resultado INT8 con extensión de signo +`0x14`, estado (`done`, `overflow`, `busy`) +`0x18` y configuración (`relu`, `shift`) +`0x1c`. El comando `mac_valid` conserva la transacción MMIO hasta terminar: cada producto usa ocho ciclos de reloj para reducir área física; el firmware no requiere espera adicional.

## Fase 6 - Modelo TinyML

- [x] Fijar referencia aritmética INT8 bit-exact con el RTL y un modelo smoke 4 -> 3.
- [x] Implementar y ejecutar el kernel firmware del modelo smoke desde PSRAM.
- [x] Alinear la imagen inicializada de PSRAM a palabra para el bootloader `lw/sw`.
- [ ] Entrenar y cuantizar el clasificador objetivo `256 -> 16 -> 10`.

- [ ] Entrenar la red `256 -> 16 -> 10`.
- [ ] Cuantizar pesos y activaciones a INT8 y biases a INT32.
- [ ] Reemplazar escalas generales por shifts cuando sea posible.
- [ ] Exportar `weights.bin`, `biases.bin` y `test_images.bin`.
- [ ] Crear referencia entera bit-exacta en Python.
- [ ] Alcanzar al menos 90 % de precisión en el conjunto reducido.

## Fase 7 - Runtime de inferencia

- [ ] Implementar `dense_int8`.
- [ ] Implementar requantización y ReLU.
- [ ] Implementar argmax.
- [ ] Almacenar pesos en Flash y activaciones en PSRAM.
- [ ] Reportar clase y ciclos por UART.
- [ ] Coincidir con Python para al menos 100 imágenes.

## Fase 8 - Verificación

- [ ] Tests unitarios de MAC, UART, bus y QSPI.
- [ ] Boot completo desde reset.
- [ ] Test de reset durante una inferencia.
- [ ] Test de `ena` y salidas seguras.
- [ ] Regresión de 100 imágenes en RTL.
- [ ] Gate-level simulation del boot y varias inferencias.
- [ ] Comprobar ausencia de estados `X` después de reset.

## Fase 9 - Síntesis y área

- [ ] Ejecutar síntesis temprana con CPU, QSPI y MAC.
- [ ] Mantener utilización preferiblemente por debajo de 70 %.
- [ ] Obtener slack positivo a 50 MHz o justificar una frecuencia menor.
- [ ] Revisar congestión, hold, antenas, DRC y LVS.

Orden de reducción si el diseño no cabe:

1. Quitar PSRAM B.
2. Quitar UART RX.
3. Quitar debug y contadores.
4. Cambiar el multiplicador por uno iterativo.
5. Bajar la frecuencia objetivo a 32 MHz.

## Fase 10 - FPGA y hardware externo

- [ ] Probar el QSPI Pmod en FPGA si el calendario lo permite.
- [ ] Programar Flash con firmware, pesos e imágenes.
- [ ] Probar ambas PSRAM.
- [ ] Ejecutar 100 inferencias y comparar con simulación.

## Fase 11 - Congelamiento y envío

- [ ] Completar `docs/info.md` y procedimiento de prueba.
- [ ] Ejecutar todas las regresiones desde un checkout limpio.
- [ ] Confirmar GDS, timing y verificaciones físicas.
- [ ] Crear tag `ttsky-tapeout-v1`.
- [ ] Enviar exactamente el commit revisado.

## Calendario

| Fechas | Resultado esperado |
|---|---|
| 18-20 agosto | Base del repositorio y primer test |
| 21-25 agosto | SERV ejecutando C con memoria ideal |
| 26-30 agosto | QSPI Flash/PSRAM en simulación |
| 31 agosto-4 septiembre | MAC MMIO, driver y síntesis temprana |
| 5-8 septiembre | Modelo cuantizado y exportador |
| 9-12 septiembre | Inferencia completa y regresiones |
| Pendiente de shuttle | Place-and-route SKY130 y timing |
| 17-18 septiembre | Gate-level y documentación |
| 19 septiembre | Congelamiento y envío interno |
| 20-21 septiembre | Contingencia |

## Decisiones pendientes

1. Confirmar el nombre público del autor; por ahora se usa el usuario GitHub `quevedol`.
2. Confirmar si ya se dispone del QSPI Pmod.
