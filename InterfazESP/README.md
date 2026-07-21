# InterfazESP — GUI MATLAB (red de geófonos)

App de App Designer programática (`uifigure`) para controlar y visualizar la red
**maestro + esclavos**. Se conecta por USB al **ESP maestro**.

## Ejecutar

```matlab
cd modelado/matlab/InterfazESP
InterfaceESP        % abre la GUI
```

Requiere MATLAB con `serialport` (R2019b+). Conectar el COM del maestro a 921600.

## Tabs

- **Maestro**: solo gateway — sin gráfico ni acelerómetro. Tiene "Debug COM
  Maestro" (abre el `Serial1` del maestro para ver su log en el tab Log).
- **Esclavo 1..3**: VDAC/calibración, PGA, FIR (post-proceso en MATLAB), cancelador
  50 Hz, y el botón **"Ver"** (captura única en vivo de ese nodo para calibrar VDAC).
- **Stream & Stats**: conexión, "Descubrir" (ARM), **Iniciar/Detener**, spinner
  **Batches** (N, hasta 65535), latencias, guardar `.mat`, canales visibles, gráficos.
- **Log**: log humano con timestamps (esclavos por su USB; maestro por Serial1).

## Protocolo (hacia el maestro)

- `psocCmd(cmd, param)` → 4 bytes `[0xAB cmd param cs]`.
- `psocCmd16(cmd, N)` → 5 bytes `[0xAB cmd n_lo n_hi cs]` (para `0xA2` ARM,
  `0xA3` start y `0xAE` set-N, **16 bits**).
- `enviarDirigido(ch, sub, param)` → 6 bytes `[0xAB 0xBD node sub param cs]`
  (`0xAA` VDAC, `0xA6` PGA, `0xA9` PGAvdac, `0xB2` **Ver**, `0xB3` debug PSoC,
  `0xB5` calibrar, `0xB6` EEPROM, `0xB9` blink LED).
- RX: paquetes de 6 bytes `[0x56 node type b2 b1 b0]` (`decodePkt`).

## Funcionalidad clave

- **N de 16 bits**: el spinner "Batches" admite hasta 65535; se manda con `psocCmd16`.
- **VDAC en cadena**: el VDAC por nodo se propaga MATLAB→maestro→esclavo→PSoC.
- **Ver**: `onVerNodo(ch)` fija N en el maestro y manda `0xB2`; el nodo muestrea N
  lotes y los grafica en pseudo-tiempo-real (disparo único, sin store-and-forward).
- **Log máquina**: las líneas `#M,…` que emiten maestro/esclavos se enrutan al log
  máquina (`drainDbgPort`); el resto al tab Log humano.
- **Latency probes**: mide RTT del START para estimar jitter de sincronización.
- **Starts múltiples** (`SCOPE_MULTI`): múltiples ciclos ARM/START automáticos para
  caracterizar jitter inter-nodo con osciloscopio.

## Parámetros leídos desde platformio.ini

`InterfaceESP.m` lee `HOTWAIT_QUERY_DELAY_MS`, `HOTWAIT_QUERY_TIMEOUT_MS`,
`HOTWAIT_QUERY_RETRIES`, `HOTWAIT_SETTLE_MS`, `SCOPE_MULTI_START_COUNT` y
`SCOPE_MULTI_START_GAP_MS` directamente del `master/platformio.ini` en tiempo
de ejecución (función `readBuildDefine`), para mantenerse en sync con el firmware.

## Estructura del código

`InterfaceESP.m` es un único archivo con **funciones anidadas** que comparten el
workspace (`S`, handles). Por esa arquitectura **no** se puede partir en varios
archivos sin reescribir el manejo de estado; la navegación se hace por secciones
(`%% ──`) y por los `function …` de cada callback.

## Scripts de análisis y utilidades

| Script | Función |
|--------|---------|
| `analisis_espectral.m` | Análisis MASW: f-k y MASW multichannel |
| `analisis_modelo.m` | Modelo teórico geófono SM-24 |
| `visor_rapido.m` | Visualización rápida de `.mat` guardados |
| `marcar_secuencia.m` | Marcado manual de ondas en secuencias de capturas |
| `migrar_campos.m` | Migración de campos entre versiones de archivos `.mat` |
| `monitor_slave.m` | Monitor de telemetría por esclavo desde MATLAB |
