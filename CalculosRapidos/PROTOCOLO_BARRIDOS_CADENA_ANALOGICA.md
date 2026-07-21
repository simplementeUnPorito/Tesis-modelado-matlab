# Protocolo de barridos de la cadena analógica

## Conexiones

- CH1: salida PGA.
- CH2: salida BP.
- CH3: salida SUMMING OPA.
- CH4: salida LP.
- `SYNC` del Agilent 33220A: entrada `EXT TRIG` del Tektronix TDS2004B.
- Usar sondas compensadas en `10X` y configurar cada canal como `10X`. Las sondas en `1X` cargan de forma apreciable el nodo BP, porque su capacitancia puede ser comparable con `Cf = 177 pF`.

## Ajustes del generador

- Función: seno.
- Sweep: logarítmico y ascendente.
- Trigger source del sweep: `Manual`. Después de cada sweep, el 33220A queda entregando la frecuencia inicial mientras espera el siguiente disparo.
- Marker: `OFF`. En el 33220A, así el flanco ascendente de `SYNC` marca el comienzo del sweep.
- Load: `High Z` si la entrada del circuito es de alta impedancia.
- Empezar con `500 mVpp`. Aumentar sólo si CH3 queda enterrado en ruido; reducir si cualquier nodo toca un riel o sale de la pantalla.
- Offset: el que corresponda al punto de operación normal del circuito. No cambiarlo entre barridos.

## Barridos solicitados

El sweep ocupa ocho divisiones. Queda una división antes del comienzo y una después del final.

| Carpeta | Start | Stop | Sweep time | Marker | Osciloscopio M |
|---|---:|---:|---:|---:|---:|
| `100mHz_1Hz` | 100 mHz | 1 Hz | 200 s | OFF | 25 s/div |
| `500mHz_5Hz` | 500 mHz | 5 Hz | 40 s | OFF | 5 s/div |
| `2.5Hz_25Hz` | 2.5 Hz | 25 Hz | 8 s | OFF | 1 s/div |
| `10Hz_100Hz` | 10 Hz | 100 Hz | 2 s | OFF | 250 ms/div |
| `50Hz_500Hz` | 50 Hz | 500 Hz | 400 ms | OFF | 50 ms/div |
| `250Hz_2.5kHz` | 250 Hz | 2.5 kHz | 80 ms | OFF | 10 ms/div |
| `1kHz_10kHz` | 1 kHz | 10 kHz | 20 ms | OFF | 2.5 ms/div |
| `5kHz_50kHz` | 5 kHz | 50 kHz | 4 ms | OFF | 500 us/div |
| `20kHz_200kHz` | 20 kHz | 200 kHz | 800 us | OFF | 100 us/div |

Los dos últimos barridos son necesarios para observar el polo superior nominal de BP, cercano a 20.9 kHz. Los registros actuales terminan en 1 kHz y no pueden identificar ese polo.

## Precaución especial para SUM

En la banda donde `BP/PGA` es aproximadamente `-1`, las dos corrientes `BP/8.2k` y `PGA/7.5k` se cancelan en torno al 95 %. Por eso el cociente de SUM es muy sensible al ruido, al valor real de ambos resistores y a pequeños errores entre canales.

- Si se dispone de multímetro, medir los valores reales de 7.5 kohm y 8.2 kohm y usarlos en el script.
- Para una identificación sólida de SUM, la medición preferida es abrir temporalmente una de las dos ramas de entrada del sumador. Por ejemplo, abriendo la rama BP de 8.2 kohm se identifica `CH3/(CH1/R_U)` sin la cancelación. El análisis normal de cuatro canales sigue siendo útil como validación en la configuración final.
- La fórmula ideal recibida tiene signo positivo. Si el bloque físico es un sumador inversor y los bloques `-K` del diagrama no están incluidos en la definición de la entrada, el modelo de SUM debe llevar un signo negativo. El programa informa el error para ambas convenciones.

## Ajustes del osciloscopio

1. Trigger `EDGE`, fuente `EXT`, acoplamiento `DC`, flanco ascendente y modo `Normal`. Este último ajuste es crítico: con `Auto` y 100 ms/div o más lento el TDS2004B entra en modo Scan/Roll.
2. Colocar el instante de trigger en la primera división horizontal (10 % de pretrigger).
3. Modo de adquisición `Sample`, no `Peak Detect`.
4. Pulsar `Single Sequence` y esperar a que el osciloscopio quede armado. Luego pulsar `Manual Trigger` en el 33220A una sola vez.
5. Esperar a que el TDS2004B complete la adquisición y se detenga por sí solo. No detenerla con `Run/Stop`.
6. Ajustar cada escala vertical manualmente para ocupar aproximadamente 4 a 6 divisiones sin recorte. No usar `Autorange` entre repeticiones.
7. Guardar los cuatro CSV del mismo registro detenido antes de volver a adquirir.
8. Hacer tres repeticiones por banda cuando sea posible: `F0000CHx`, `F0001CHx` y `F0002CHx`.

## Control recomendado de sondas y canales

Antes de medir el circuito, conectar las cuatro puntas al mismo seno del generador y comprobar que CH2/CH1, CH3/CH1 y CH4/CH1 sean aproximadamente `1 ∠ 0°` en 100 Hz, 1 kHz, 20 kHz y 200 kHz. Esto detecta una sonda mal compensada o un error de escala antes de atribuirlo al circuito.

## Ejecución en MATLAB

```matlab
cd('C:/Github/Tesis/src/matlab/CalculosRapidos')
results = analizar_barridos_cadena_analogica;
```

Los resultados se escriben en `resultados_barridos`. El programa acepta automáticamente varias capturas por carpeta y compara BP tanto con `Cin = 680 uF` (valor recibido) como con `Cin = 680 nF` (hipótesis a verificar).
