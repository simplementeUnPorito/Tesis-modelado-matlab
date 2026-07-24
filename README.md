# Modelado MATLAB/Simulink de Tesis

Modelos del geófono SM-24, cadena analógica, controladores, interfaces y pruebas teóricas del sistema MASW. Este repositorio conserva el historial que antes vivía en `src/matlab`.

## Inicio rápido

```matlab
cd('C:/ruta/Tesis-calculos-matlab')
init_project
```

`init_project` agrega este repositorio y `third-party/MASW-Matlab-code` al path. Clone con `--recurse-submodules` para disponer de esa dependencia.

Los cachés de Simulink (`slprj/`, `*.slxc` y `*_cache.mat`) son regenerables y no se versionan. En el superproyecto `Tesis` este repositorio se monta en `modelado/matlab`.

Los archivos MATLAB `.mat` versionados se guardan mediante Git LFS en `Github-LFS/repositories/Tesis-calculos-matlab`. Después de clonar con `GIT_LFS_SKIP_SMUDGE=1`, configure e hidrate estos objetos con:

```powershell
$env:GITHUB_LFS_ROOT = 'C:\Users\elias\OneDrive\Github-LFS'
.\scripts\configure-lfs-folderstore.ps1
.\scripts\hydrate-lfs.ps1 -All
```
