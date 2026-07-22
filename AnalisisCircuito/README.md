# Análisis de la cadena analógica

Este directorio procesa exclusivamente las capturas nuevas cuyo nombre contiene `to` dentro de `data/raw/Osciloscopio`.

## Procesamiento

1. Lee CH1=PGA, CH2=BP, CH3=compensador y CH4=LP sin modificar los CSV crudos.
2. Conserva la escala original de los cuatro canales; no aplica conversión ×2.
3. Grafica para cada barrido los cuatro canales temporales superponiendo, en la misma figura, la señal cruda del CSV y su versión centrada y procesada (`osciloscopio_*.fig/.png`).
4. Aplica a todos los canales el mismo Butterworth de orden 4 mediante `filtfilt`, con banda aproximada `0.5*Start` a `1.5*Stop`.
5. Estima la frecuencia de red alrededor de 50 Hz y resta por mínimos cuadrados sólo los armónicos que caen dentro del pasabanda Butterworth, siguiendo el método del `master` ESP.
6. Para no borrar el estímulo, excluye del ajuste un entorno de tres ciclos alrededor de cada cruce del sweep. También omite la regresión cuando el registro no contiene al menos dos ciclos de la fundamental de red.
7. Estima y combina las FRF crudas y procesadas antes de ajustar BP, el compensador `CH3/CH1`, LP y la cadena completa PGA→ADC con `tfest`.
8. La cadena PGA→ADC se mide directamente como `CH4/CH1` y se compara con el modelo PSoC High completo usando `Ru=6.8 kOhm` y la rama `Rbp=6.8 kOhm + potenciómetro de 2 kOhm` calibrada.
9. La cadena GEO→ADC se calcula como `Hgeo nominal * CH4/CH1` y se compara con el mismo modelo PSoC High multiplicado por `HGEO`, usando `Hgeo(s)=zeta*w0*s/(s^2+2*zeta*w0*s+w0^2)`, `zeta=0.25` y `w0=2*pi*10 rad/s`. No es una quinta FRF medida.

## Modelo del operacional

Las Bode muestran una sola referencia: PSoC 5LP High con los componentes actuales. El modelo usa `A0=90 dB`, `GBW=8 MHz`, un polo dominante en `GBW/A0`, `Rin=35 MOhm`, `Rout=20 Ohm` y `Cin=18 pF`. BP y LP se resuelven por nodos con sus topologías reales; el sumador usa la realimentación `27 kOhm || 15 nF`. No se grafican el operacional matemáticamente ideal ni la variante de 3 MHz.

## Compensador medido respecto de PGA

No se identifica una transferencia a partir de una corriente sintética. La única verificación de CH3 es directamente `CH3/CH1`. La referencia pedida, llevada a la ganancia y al antialias físicos, es:

```text
CH3/PGA = (-27k/6.8k)
          * (s² + 2*zeta0*w0*s + w0²)/(s² + 2*zeta1*w0*s + w0²)
          * 1/(1 + s*27k*15n)
```

`zeta0=0.25`; `w0` y `zeta1` se calculan del BP `43 kOhm/47 kOhm`, `680 uF` y `177 pF`. La ganancia nominal es `-27k/6.8k≈-3.9706 V/V` y el polo antialias es `392.975 Hz`. Para `Ru=6.8 kOhm`, el total requerido es `Rbp≈7434.54 Ohm`: fija de `6.8 kOhm` más aproximadamente `634.54 Ohm` del potenciómetro. El nulo está cerca de `632.56 Ohm`; desde allí se aumentan aproximadamente `1.98 Ohm` para realizar `zeta0=0.25`. `parametros_compensador.csv` incluye además una estimación del cursor obtenida de CH1, CH2 y CH3 medidos.

`tfest` se ajusta exclusivamente a la FRF procesada; no usa el modelo teórico durante la identificación. El resumen informa por separado el residuo medición–`tfest` y el error entre `tfest` y la curva roja PSoC High completa.

Para dejar margen a las dinámicas observadas que no están en las funciones nominales, el orden se incrementa en dos por cada operacional comprendido en el camino. Se conserva el grado relativo nominal aumentando también el grado permitido del numerador: BP usa 4 polos/3 ceros, compensador 5/4, LP 4/2 y PGA→ADC 11/8 (tres operacionales). GEO→ADC no se vuelve a identificar: al componer el geófono 2/1 con PGA→ADC resulta 13/9. Los valores quedan registrados en `ordenes_tfest.csv`.

Para comprobar si una campaña mezcló posiciones distintas del cursor se puede ejecutar `verificar_calibracion_potenciometro(results)`. El auxiliar ajusta el valor usando BP/PGA y CH3/PGA de cada captura individual, guarda `calibracion_pot_por_captura.csv` y dibuja el residuo frente a todo el recorrido. Sólo etiqueta una estimación como confiable si tiene al menos ocho puntos y un residuo complejo relativo no mayor que 0.35; las demás deben confirmarse con multímetro.

El slew rate de 4.3 V/us —y la referencia mínima de datasheet de 3 V/us— se trata como límite no lineal de amplitud senoidal, no como un polo de una TF lineal. `preprocesamiento.csv` registra un margen conservador por canal y `limite_slew_rate.csv` tabula la amplitud máxima frente a frecuencia. El ruido típico de entrada de 45 nV/sqrt(Hz) y el offset máximo de 3 mV se documentan, pero no se agrega ruido sintético a los datos medidos.

La búsqueda fina de la fundamental de red sólo se habilita cuando el registro contiene al menos 50 ciclos de 50 Hz. En registros más cortos se usa 50 Hz nominal para no confundir resolución insuficiente con un desplazamiento real de la red.

## Varias capturas y saturación

Se pueden guardar varias adquisiciones dentro de una misma carpeta de banda, por ejemplo `ALL0000`, `ALL0001`, etc. Cada conjunto de cuatro CSV recibe un identificador único y sus gráficos no se sobrescriben.

La saturación se detecta de forma directa: durante el tramo central del sweep, un canal se marca saturado si alcanza `|V| >= 2.3 V`, como margen frente a los rieles de aproximadamente `±2.5 V`. Una captura saturada ya no se elimina completa: el programa amplía cada recorte un ciclo local a ambos lados, busca los intervalos lineales continuos restantes y los incorpora como submuestras independientes de la FRF. Sólo se descarta una etapa cuando no queda un tramo con suficientes muestras, ciclos y extensión de frecuencia.

- CH1 saturado: recorta esas frecuencias del compensador global CH3/CH1 y de las cadenas completas; BP todavía puede medirse respecto de la forma de onda CH1 realmente observada.
- CH2 saturado: recorta esas frecuencias de BP, del compensador global CH3/CH1 y de las cadenas completas; no afecta LP, que se mide localmente como CH4/CH3.
- CH3 saturado: conserva BP; recorta el compensador global y las cadenas completas, mientras LP todavía puede usar CH3 como excitación medida si CH4 permanece lineal.
- CH4 saturado: conserva BP y compensador; recorta esas frecuencias de LP y de las cadenas completas.

La regla no propaga ciegamente una saturación hacia las etapas posteriores. Una entrada local recortada se considera una excitación arbitraria medida y la captura queda sujeta a los filtros de coherencia y energía. Sin embargo, `CH3/CH2` no se usa como transferencia del sumador porque CH3 también depende de la rama directa CH1. Una identificación local del sumador requeriría la entrada compuesta medida `CH1/Ru + CH2/Rbp`; la verificación principal continúa siendo el compensador completo `CH3/CH1` solicitado.

`saturacion_canales.csv` contiene los indicadores automáticos y `uso_capturas_por_etapa.csv` dice exactamente qué aportó cada grabación, cuántas submuestras lineales produjo y qué fracción del sweep se conservó. Si la decisión automática necesita corregirse, se agrega una fila a `saturation_overrides.csv` usando `SATURATED` o `VALID`; `AUTO` deja la decisión automática.

`ganancia_medicion_recomendada.csv` calcula, para cada captura existente, cuánto podría multiplicarse la amplitud actual del generador para que el canal limitante llegue aproximadamente a `2.0 V pico`, dejando margen antes del umbral de `2.3 V`. Es una estimación lineal basada en las mediciones actuales; si una etapa real recorta antes, el descarte automático prevalece.

## Fusión de barridos solapados

Cada captura aporta únicamente entre su frecuencia Start y Stop; fuera de esa banda su peso es cero. Cuando dos o más sweeps se solapan, cada FRF local se pondera por `coherencia^2 × excitación × ventana de cobertura`. La ventana de cobertura es máxima en el centro logarítmico del sweep y baja suavemente hasta 0.05 en sus extremos. De este modo domina la captura que está trabajando en su zona central, mientras las vecinas sostienen las transiciones entre bandas.

## Tolerancias Monte Carlo y recorrido del potenciómetro

Cada gráfica de identificación contiene dos áreas. La azul es la envolvente mínima-máxima de 4000 realizaciones con resistencias `-1/+1 %`, cerámicos de hasta 100 nF `-20/+20 %` y electrolíticos mayores de 100 nF `-40/+10 %`; en cada realización el potenciómetro se recalibra, limitado a `0..2 kOhm`. La naranja vuelve a aplicar esas tolerancias pero además barre 41 posiciones que cubren todo el recorrido eléctrico del potenciómetro. Por tanto, una medición fuera de la azul pero dentro de la naranja puede ser compatible con componentes válidos y un cursor mal calibrado; fuera de ambas apunta a otra discrepancia del montaje, de la medición o del modelo. El resumen tabula por separado el porcentaje de puntos dentro de cada área.

## Gráficos normalizados

`06_graficos_normalizados` contiene una segunda versión de BP, compensador, LP, PGA→ADC y GEO→ADC destinada a comparar solamente la forma. La magnitud cruda, procesada, `tfest` y PSoC High se normaliza independientemente al máximo de cada curva dentro de la banda mostrada, de modo que cada una alcanza 0 dB. La fase y la coherencia permanecen sin normalizar. Estas figuras omiten deliberadamente las áreas Monte Carlo para no deformar una envolvente min–max mediante normalizaciones diferentes; las gráficas originales conservan la ganancia absoluta y ambas áreas de tolerancia.

## Ejecución

```matlab
cd('C:/Github/Tesis/modelado/matlab/AnalisisCircuito')
results = analizar_sweeps_circuito;
```

Cuando el potenciómetro cambió entre campañas, la carpeta primaria define la única tanda usada para `COMP`, PGA→ADC y GEO→ADC. Las campañas históricas pasadas en el cuarto argumento se incorporan exclusivamente a las etapas fijas BP y LP:

```matlab
primary = 'C:/Github/Tesis/data/raw/Osciloscopio_verificacion_calibracion_2026-07-21';
fixedHistory = {
    'C:/Github/Tesis/data/raw/Osciloscopio', ...
    'C:/Github/Tesis/data/raw/Osciloscopio_calibracion_2026-07-21'};
results = analizar_sweeps_circuito(primary, ...
    'C:/Github/Tesis/modelado/matlab/AnalisisCircuito/resultados_tanda_calibrada', ...
    true, fixedHistory);
```

`uso_capturas_por_etapa.csv` marca las capturas históricas como omitidas para las transferencias dependientes del potenciómetro. Los identificadores reciben un prefijo de campaña para evitar colisiones y sobreescritura de figuras.

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
├── 05_tablas_reportes/
└── 06_graficos_normalizados/
```

Los gráficos temporales y las Bode muestran simultáneamente la versión cruda y la procesada para comprobar que el filtrado no introduzca un sesgo relevante.

El programa guarda una caché en `resultados/00_cache/analisis_circuito.mat`. La clave SHA-256 incluye los CSV, `saturation_overrides.csv`, la configuración y los dos archivos MATLAB del análisis. Si nada cambió y los artefactos siguen presentes, una ejecución posterior carga directamente el resultado anterior y no repite filtros, identificación ni Monte Carlo. Las figuras interactivas `.fig` se vuelven a abrir desde la caché.

Las figuras se muestran durante la ejecución, permanecen abiertas en MATLAB para usar zoom y cursores, y se guardan simultáneamente como `.fig` y `.png`.

Después de cargar la nueva campaña, el informe debe indicar `Bandas faltantes: ninguna`; de lo contrario se repiten únicamente las bandas listadas.
