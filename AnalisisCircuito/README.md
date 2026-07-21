# Análisis de la cadena analógica

Este directorio procesa exclusivamente las capturas nuevas cuyo nombre contiene `to` dentro de `Crudos/Osciloscopio`.

## Procesamiento

1. Lee CH1=PGA, CH2=BP, CH3=compensador y CH4=LP sin modificar los CSV crudos.
2. Conserva la escala original de los cuatro canales; no aplica conversión ×2.
3. Grafica para cada barrido los cuatro canales temporales superponiendo, en la misma figura, la señal cruda del CSV y su versión centrada y procesada (`osciloscopio_*.fig/.png`).
4. Aplica a todos los canales el mismo Butterworth de orden 4 mediante `filtfilt`, con banda aproximada `0.5*Start` a `1.5*Stop`.
5. Estima la frecuencia de red alrededor de 50 Hz y resta por mínimos cuadrados sólo los armónicos que caen dentro del pasabanda Butterworth, siguiendo el método del `master` ESP.
6. Para no borrar el estímulo, excluye del ajuste un entorno de tres ciclos alrededor de cada cruce del sweep. También omite la regresión cuando el registro no contiene al menos dos ciclos de la fundamental de red.
7. Estima y combina las FRF crudas y procesadas antes de ajustar BP, el compensador `CH3/CH1`, LP y la cadena completa PGA→ADC con `tfest`.
8. La cadena PGA→ADC se mide directamente como `CH4/CH1` y se compara con `HLP*HSUM*(1/7.5k + HBP/8.2k)`.
9. La cadena GEO→ADC se calcula como `Hgeo nominal * CH4/CH1` y se compara con `HGEO*HLP*HSUM*(1/7.5k + HBP/8.2k)`, usando `zeta=0.25` y `w0=2*pi*10 rad/s`. No es una quinta FRF medida.

## Modelo del operacional

Las Bode comparan tres referencias: operacional matemáticamente ideal, PSoC 5LP High con GBW de 8 MHz y una curva conservadora con el GBW mínimo de datasheet de 3 MHz. El modelo High usa `A0=90 dB`, un polo dominante en `GBW/A0`, `Rin=35 MOhm`, `Rout=20 Ohm` y `Cin=18 pF` (máximo de datasheet). BP y LP se resuelven por nodos con sus topologías reales; el sumador usa la realimentación `27 kOhm || 15 nF`.

## Compensador medido respecto de PGA

No se identifica una transferencia a partir de una corriente sintética. La única verificación de CH3 es directamente `CH3/CH1`. La referencia pedida, llevada a la ganancia y al antialias físicos, es:

```text
CH3/PGA = (-27k/7.5k)
          * (s² + 2*zeta0*w0*s + w0²)/(s² + 2*zeta1*w0*s + w0²)
          * 1/(1 + s*27k*15n)
```

`zeta0=0.25`; `w0` y `zeta1` se calculan del denominador nominal corregido del BP: `Rin=43 kOhm`, `Rf=47 kOhm`, `Cin=680 uF` y `Cf=177 pF`. La ganancia DC es `-3.6 V/V` y el polo antialias es `392.975 Hz`. Con esos valores se obtiene `zeta1=937.396`. La combinación `Ru=7.5 kOhm`, `Rbp≈8.2 kOhm` realiza analíticamente `zeta≈0.266`; el valor exacto para `zeta0=0.25` es `Rbp≈8199.86 Ohm`. `Rbp` representa el conjunto de `7.5 kOhm` más el reóstato calibrado, no una resistencia fija. `parametros_compensador.csv` deja registrados estos cálculos.

El slew rate de 4.3 V/us —y la referencia mínima de datasheet de 3 V/us— se trata como límite no lineal de amplitud senoidal, no como un polo de una TF lineal. `preprocesamiento.csv` registra un margen conservador por canal y `limite_slew_rate.csv` tabula la amplitud máxima frente a frecuencia. El ruido típico de entrada de 45 nV/sqrt(Hz) y el offset máximo de 3 mV se documentan, pero no se agrega ruido sintético a los datos medidos.

La búsqueda fina de la fundamental de red sólo se habilita cuando el registro contiene al menos 50 ciclos de 50 Hz. En registros más cortos se usa 50 Hz nominal para no confundir resolución insuficiente con un desplazamiento real de la red.

## Varias capturas y saturación

Se pueden guardar varias adquisiciones dentro de una misma carpeta de banda, por ejemplo `ALL0000`, `ALL0001`, etc. Cada conjunto de cuatro CSV recibe un identificador único y sus gráficos no se sobrescriben.

La saturación se detecta de forma directa: durante el tramo central del sweep, un canal se marca saturado si alcanza `|V| >= 2.3 V`, como margen frente a los rieles de aproximadamente `±2.5 V`. Las capturas se conservan en los gráficos temporales, pero se omiten selectivamente de las FRF:

- CH1 saturado: descarta BP, compensador, LP y las cadenas completas.
- CH2 saturado: descarta BP, compensador, LP y las cadenas completas.
- CH3 saturado: conserva BP; descarta compensador, LP y cadenas completas.
- CH4 saturado: conserva BP y compensador; descarta LP y cadenas completas.

`saturacion_canales.csv` contiene los indicadores automáticos y `uso_capturas_por_etapa.csv` dice exactamente qué aportó cada grabación. Si la decisión automática necesita corregirse, se agrega una fila a `saturation_overrides.csv` usando `SATURATED` o `VALID`; `AUTO` deja la decisión automática.

`ganancia_medicion_recomendada.csv` calcula, para cada captura existente, cuánto podría multiplicarse la amplitud actual del generador para que el canal limitante llegue aproximadamente a `2.0 V pico`, dejando margen antes del umbral de `2.3 V`. Es una estimación lineal basada en las mediciones actuales; si una etapa real recorta antes, el descarte automático prevalece.

## Fusión de barridos solapados

Cada captura aporta únicamente entre su frecuencia Start y Stop; fuera de esa banda su peso es cero. Cuando dos o más sweeps se solapan, cada FRF local se pondera por `coherencia^2 × excitación × ventana de cobertura`. La ventana de cobertura es máxima en el centro logarítmico del sweep y baja suavemente hasta 0.05 en sus extremos. De este modo domina la captura que está trabajando en su zona central, mientras las vecinas sostienen las transiciones entre bandas.

## Tolerancias Monte Carlo

Cada gráfica de identificación incluye la envolvente mínima-máxima de 4000 realizaciones uniformes e independientes. Los valores usados son resistencias `-1/+1 %`, cerámicos de hasta 100 nF `-20/+20 %` y electrolíticos mayores de 100 nF `-40/+10 %`. Los lados negativo y positivo son campos independientes en `defaultConfig`. El archivo `resultados/05_tablas_reportes/configuracion_tolerancias.csv` registra los valores usados en cada corrida.

## Ejecución

```matlab
cd('C:/Github/Tesis/src/matlab/AnalisisCircuito')
results = analizar_sweeps_circuito;
```

Los resultados quedan organizados así:

```text
resultados/
├── 00_cache/
├── 01_osciloscopio_tiempo/
├── 02_preprocesamiento_espectral/
├── 03_identificacion_etapas/
│   ├── BP/
│   ├── COMPENSADOR_PGA/
│   └── LP/
├── 04_cadena_adc/
│   ├── PGA_a_ADC/
│   └── GEO_a_ADC/
└── 05_tablas_reportes/
```

Los gráficos temporales y las Bode muestran simultáneamente la versión cruda y la procesada para comprobar que el filtrado no introduzca un sesgo relevante.

El programa guarda una caché en `resultados/00_cache/analisis_circuito.mat`. La clave SHA-256 incluye los CSV, `saturation_overrides.csv`, la configuración y los dos archivos MATLAB del análisis. Si nada cambió y los artefactos siguen presentes, una ejecución posterior carga directamente el resultado anterior y no repite filtros, identificación ni Monte Carlo. Las figuras interactivas `.fig` se vuelven a abrir desde la caché.

Las figuras se muestran durante la ejecución, permanecen abiertas en MATLAB para usar zoom y cursores, y se guardan simultáneamente como `.fig` y `.png`.

Después de cargar la nueva campaña, el informe debe indicar `Bandas faltantes: ninguna`; de lo contrario se repiten únicamente las bandas listadas.
