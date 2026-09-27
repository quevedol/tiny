# Reglas de contribución

## Flujo de cambios

1. Crear una rama con prefijo `student/` y nombre breve, por ejemplo
   `student/sky130-gate-sim`.
2. Trabajar una tarea de [`TASKS.md`](TASKS.md) por cambio.
3. Ejecutar las pruebas afectadas; no afirmar que el GDS funciona si el
   workflow Sky130 no se ha ejecutado.
4. Abrir una solicitud de revisión que indique: propósito, archivos tocados,
   comandos de prueba y resultados.

## Estándares RTL

- Mantener Verilog sintetizable y ``default_nettype none`` en módulos nuevos.
- Reset activo bajo `rst_n`.
- No introducir latches, clocks derivados ni macros de PDK sin revisión.
- Las interfaces de memoria deben mantener endianness little-endian y los
  tests de lectura/escritura existentes.

## Estándares de firmware y modelo

- Firmware: C bare-metal RV32I/ILP32, sin dependencias de biblioteca estándar.
- Modelo: INT8 para activaciones/pesos e INT32 para acumulador/bias.
- Toda modificación de aritmética debe compararse con
  `model/int8_reference.py`.

## Archivos protegidos

No modificar sin autorización explícita:

- `src/cpu/serv/`
- `info.yaml`
- `.github/workflows/gds.yaml`
- `src/project.v`
