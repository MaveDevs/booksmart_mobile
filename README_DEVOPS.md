# BookSmart — Flujo de CI/CD

Este documento explica cómo funciona el pipeline de integración y entrega continua (CI/CD) del proyecto BookSmart Mobile.

---

## Resumen del Flujo

```
develop (push) ──► flutter analyze ──► APK Debug ──► Artefacto descargable (14 días)
main    (push) ──► flutter analyze ──► APK Release ──► Artefacto descargable (30 días)
```

| Rama | Qué hace | APK generado | Retención |
|------|----------|-------------|-----------|
| `develop` | Análisis estático + build de prueba | Debug | 14 días |
| `main` | Análisis estático + build de producción | Release | 30 días |

---

## ¿Qué significan los estados de las Actions?

En la pestaña **Actions** del repositorio en GitHub verás un indicador de color junto a cada ejecución:

| Estado | Significado |
|--------|-------------|
| 🟢 Verde (passed) | Todo salió bien: el análisis no encontró errores y el APK se generó correctamente. |
| 🔴 Rojo (failed) | Algo falló: puede ser un error de análisis en el código, un error de compilación o un problema con las dependencias. Haz clic en el job para ver los logs detallados. |
| 🟡 Amarillo (in progress) | El pipeline está ejecutándose. Espera unos minutos. |
| ⚪ Gris (cancelled) | La ejecución fue cancelada (por ejemplo, por un push más reciente que la reemplazó). |

---

## ¿Cómo descargar el APK generado?

1. Ve al repositorio en GitHub: `github.com/MaveDevs/booksmart_mobile`
2. Haz clic en la pestaña **Actions** (en la barra superior).
3. Selecciona la ejecución más reciente con estado 🟢 verde.
4. En la parte inferior de la página, en la sección **Artifacts**, verás el APK:
   - `booksmart-debug-<hash>` → APK de pruebas (rama develop)
   - `booksmart-release-<hash>` → APK de producción (rama main)
5. Haz clic en el nombre del artefacto para descargarlo (se descarga como `.zip`).
6. Descomprime el `.zip` y obtendrás el archivo `.apk` listo para instalar.

---

## Configuración de Secrets (API URL)

El pipeline inyecta la URL de la API de forma segura usando **GitHub Secrets**. Esto evita que la URL de producción quede expuesta en el código fuente.

### Paso a paso para configurar el secret:

1. Ve al repositorio en GitHub.
2. Haz clic en **Settings** (Configuración) → pestaña superior del repo.
3. En el menú lateral izquierdo, busca **Secrets and variables** → **Actions**.
4. Haz clic en el botón verde **New repository secret**.
5. Configura:
   - **Name:** `API_BASE_URL`
   - **Secret:** `https://booksmartutt.duckdns.org` (o la URL que corresponda)
6. Haz clic en **Add secret**.

> **¿Cómo funciona internamente?** Durante el build, el workflow reemplaza la línea `baseUrl` en `lib/config/api_config.dart` con el valor del secret. Este cambio ocurre SOLO en el runner de GitHub Actions y nunca se sube al repositorio.

---

## Estructura del Pipeline

El archivo de configuración se encuentra en:

```
.github/workflows/ci_cd.yml
```

### Job `develop` (rama develop)
1. Checkout del código
2. Configura Java 17 y Flutter (última versión estable)
3. Inyecta la API URL desde el secret `API_BASE_URL`
4. Ejecuta `flutter pub get`
5. Ejecuta `flutter analyze` (detecta errores y warnings)
6. Genera el APK en modo Debug
7. Sube el APK como artefacto descargable

### Job `release` (rama main)
1. Mismos pasos de configuración
2. Genera el APK en modo **Release** (optimizado, sin debug info)
3. Sube el APK como artefacto descargable

---

## Flujo de trabajo recomendado

```
1. Trabajas en tu rama feature/xxx
2. Haces merge a develop → se ejecuta CI (analyze + debug APK)
3. Si todo está verde ✅, haces merge de develop a main
4. Se genera el APK de Release → listo para distribuir
```

---

## Tecnologías del Pipeline

- **GitHub Actions** — Plataforma de CI/CD
- **Flutter (stable)** — Última versión estable
- **Java 17 (Temurin)** — Requerido por el build de Android
- **upload-artifact v4** — Para subir los APKs como artefactos descargables
