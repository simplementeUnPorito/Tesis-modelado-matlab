# Resultado de la tanda calibrada — 2026-07-21

## Datos usados

- Tanda principal, una única posición declarada del potenciómetro: `Osciloscopio_verificacion_calibracion_2026-07-21`.
- Las campañas históricas `Osciloscopio` y `Osciloscopio_calibracion_2026-07-21` se agregaron exclusivamente a BP y LP.
- La tanda principal contiene 30 capturas completas. De la serie `XD` se conservan 17 capturas únicas (68 CSV), incluida `XD_ALL0017` de 0.01–0.05 Hz.
- `XD_ALL0006` era una copia SHA-256 exacta de `XD_ALL0005` en los cuatro canales y se eliminó de la base. No quedan CSV duplicados por contenido.
- En las capturas `XD`, sólo `XD_ALL0014` presenta saturación de CH4. BP y compensador se conservan completos; para LP y la cadena se recupera el 28.68 % lineal del sweep.

Desde la versión de caché 8, una saturación ya no elimina necesariamente la captura completa. Se excluye un ciclo local alrededor de cada recorte y los intervalos lineales continuos restantes se convierten en submuestras por etapa. `uso_capturas_por_etapa.csv` informa `LinearSubsamples` y `RetainedSweepFraction`.

En esta ejecución se recuperaron parcialmente 22 combinaciones captura-etapa correspondientes a 9 capturas saturadas: 5 aportes BP, 5 del compensador, 6 LP y 6 de la cadena. Sólo 5 combinaciones permanecieron descartadas porque conservaban entre 0.4 % y 2.3 % del sweep, insuficiente para formar una submuestra espectral confiable.

## Nueva banda 0.01–0.05 Hz

`XD_ALL0017` está libre de saturación y aporta 14 puntos procesados a cada transferencia, entre aproximadamente 0.01095 y 0.04567 Hz:

| Transferencia | Coherencia mediana | Error RMS contra PSoC High |
|---|---:|---:|
| BP, CH2/CH1 | 0.99516 | 0.960 dB |
| Compensador, CH3/CH1 | 0.98799 | 2.111 dB |
| LP, CH4/CH3 | 0.99975 | 0.330 dB |
| Cadena PGA-ADC, CH4/CH1 | 0.98813 | 2.340 dB |

La banda nueva es consistente y extiende las gráficas hasta 10 mHz. El ajuste global `tfest` conserva por ahora su límite inferior de 0.2 Hz para evitar que una única captura subsónica domine la identificación de la cadena completa; los puntos nuevos sí se muestran y se comparan directamente con el modelo.

## Coherencia de las capturas `XD`

| Transferencia | Capturas válidas | Mediana de coherencia | Percentil 10 |
|---|---:|---:|---:|
| BP, CH2/CH1 | 16 | 0.99962 | 0.85620 |
| Compensador, CH3/CH1 | 16 | 0.96892 | 0.92797 |
| LP, CH4/CH3 | 15 | 0.95813 | 0.90592 |
| Cadena PGA-ADC, CH4/CH1 | 15 | 0.99598 | 0.98827 |

Las dos capturas únicas de 2.5–25 Hz son especialmente consistentes alrededor de la frecuencia natural nominal `f0 = 10.2046 Hz`:

| Captura | CH3/CH1 (dB) | Fase (grados) | Coherencia local |
|---|---:|---:|---:|
| `XD_ALL0005` | -31.466 | 178.80 | 0.8936 |
| `XD_ALL0007` | -31.048 | -176.39 | 0.9405 |

La diferencia entre ambas es sólo 0.42 dB. Los dos barridos 10–100 Hz nuevos también concuerdan: alrededor de 12 Hz dan -31.28 y -31.40 dB.

## Comparación con el circuito

- El modelo PSoC High completo predice `CH3/CH1 = -57.582 dB` en 10.2046 Hz. La tanda nueva mide aproximadamente -31.26 dB: la muesca es reproducible, pero queda 26.33 dB menos profunda que el objetivo.
- El LP sí funciona aproximadamente como se espera. En 10.2046 Hz las dos capturas dan 13.192 y 13.202 dB, frente a 13.978 dB del modelo. En toda la banda de ajuste 10.6–984 Hz, la medición queda a 0.435 dB RMS del modelo PSoC High.
- BP es muy coherente localmente, pero las dos repeticiones nuevas difieren 0.75 dB en ganancia absoluta en 10.2046 Hz (0.732 y -0.022 dB, frente a 0.772 dB nominal). Una diferencia pequeña en BP es importante porque el compensador depende de una cancelación casi exacta.
- Al fusionar todas las campañas históricas de BP, `tfest` ajusta la nube con 6.62 dB RMS. Esto no significa baja coherencia dentro de cada barrido: significa que las campañas no coinciden bien entre sí en ganancia de BP, especialmente a alta frecuencia. LP, en cambio, permanece consistente al fusionar campañas (`tfest`: 0.205 dB RMS).
- Para la tanda principal, `tfest` describe bien la curva realmente medida del compensador (1.55 dB RMS). El desacuerdo de 11.58 dB RMS es contra el modelo objetivo, no un fracaso de `tfest`.

## Potenciómetro

Con los componentes nominales:

- cursor objetivo para `zeta0 = 0.25`: 634.5388 ohm;
- cancelación exacta: 632.5560 ohm;
- separación entre ambos ajustes: sólo 1.9828 ohm.

Por eso el ajuste es extremadamente sensible. Tomando únicamente la profundidad medida de la muesca, la posición efectiva sería del orden de 674 ohm (aproximación), unos 39 ohm por encima del objetivo. La estimación compleja que combina BP y CH3 no supera el criterio de confiabilidad en ninguna captura, porque errores sub-dB en CH2 dominan el residuo cerca de la cancelación. El programa ahora informa explícitamente que esa estimación no es confiable y no presenta el mínimo numérico como una resistencia física válida.

## Conclusión práctica

Las nuevas grabaciones son coherentes y suficientes para concluir que el circuito es repetible. LP está bien; el problema dominante sigue siendo la calibración extremadamente fina de la cancelación en el compensador. No conviene continuar todavía con más barridos anchos: primero hay que recalibrar alrededor de 10.2046 Hz con mayor sensibilidad vertical en CH3 y luego repetir un barrido estrecho.
