# Modelado MATLAB/Simulink de Tesis

Modelos del geófono SM-24, cadena analógica, controladores, interfaces y pruebas teóricas del sistema MASW. Este repositorio conserva el historial que antes vivía en `src/matlab`.

## Inicio rápido

```matlab
cd('C:/ruta/Tesis-modelado-matlab')
init_project
```

`init_project` agrega este repositorio y `third-party/MASW-Matlab-code` al path. Clone con `--recurse-submodules` para disponer de esa dependencia.

Los cachés de Simulink (`slprj/`, `*.slxc` y `*_cache.mat`) son regenerables y no se versionan. En el superproyecto `Tesis` este repositorio se monta en `modelado/matlab`.
