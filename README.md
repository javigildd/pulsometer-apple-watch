# PulseMeter — Apple Watch

App para Apple Watch que monitoriza el ritmo cardiaco en tiempo real y vibra cuando sales de un rango BPM definido. Pensada para correr en paralelo con Strava.

## Comportamiento

- Defines un rango mín–máx (por defecto 150–170 BPM).
- HR **por encima del máx** → **2 vibraciones** (toca aflojar).
- HR **bajando al mínimo** desde el rango/encima → **1 vibración** (vuelve a empezar a correr).
- Compatible con Strava: PulseMeter abre su propia `HKWorkoutSession` de tipo `.other` en paralelo, sin interferir.

## Estructura

```
project.yml                       # spec de xcodegen
PulseMeter.xcodeproj/             # proyecto Xcode (generado, ya commiteado)
PulseMeter Watch App/
  PulseMeterApp.swift             # entrada
  ContentView.swift               # UI principal + ajustes
  HeartRateMonitor.swift          # HealthKit + zonas + hápticos
  Info.plist                      # generado por xcodegen
  PulseMeter.entitlements         # HealthKit
  Assets.xcassets/
  Preview Content/
```

## Cómo pasarla al reloj

1. **Abre el proyecto**: doble click en `PulseMeter.xcodeproj`.
2. **Firma**: navegador → proyecto **PulseMeter** → target **PulseMeter Watch App** → pestaña **Signing & Capabilities**:
   - Marca **Automatically manage signing**.
   - **Team**: tu Apple ID (vale el Personal Team gratis). Si no tienes, en Xcode menú **Settings → Accounts → +** y añades tu Apple ID.
   - Si Xcode se queja del bundle id, cámbialo a uno único tuyo (p. ej. `com.tunombre.PulseMeter`).
3. **Activa Modo desarrollador** una sola vez:
   - iPhone: **Ajustes → Privacidad y seguridad → Modo desarrollador → ON** (reinicia el iPhone).
   - Apple Watch: **Ajustes → Privacidad y seguridad → Modo desarrollador → ON**.
4. **Conecta el iPhone por USB** al Mac. El Watch tiene que estar emparejado y desbloqueado.
5. En la barra superior de Xcode elige tu **Apple Watch** como destino (no el simulador).
6. **Cmd+R** (o pulsa ▶). La primera vez tarda unos minutos en firmar e instalar.
7. Si en el iPhone aparece "Untrusted Developer": **Ajustes → General → VPN y gestión de dispositivos** → abre tu perfil → **Confiar**.
8. La primera vez que pulses **Empezar** en la app, te pedirá permisos de Salud → acepta.

> Con Apple ID gratuito la firma caduca cada **7 días**: tendrás que reabrir Xcode y darle a ▶ otra vez para reinstalar. Con Developer Program de pago (99 €/año) dura un año.

## Uso con Strava

1. Abre Strava en el reloj y empieza la actividad.
2. Vuelve al menú del reloj y abre **PulseMeter**.
3. Ajusta el rango si hace falta y pulsa **Empezar**.
4. Las dos apps reciben el HR del sensor a la vez.
5. Al terminar, **Parar** en PulseMeter y **Finalizar** en Strava.

## Regenerar el proyecto

Si cambias `project.yml`, regenera el `.xcodeproj` con:

```bash
xcodegen generate
```

(Si no tienes xcodegen: `brew install xcodegen`.)

## Notas técnicas

- `HKLiveWorkoutBuilder` para recibir muestras de HR en streaming (~1 Hz).
- Las alertas solo disparan en transiciones de zona, con un **cooldown de 10 s** para no spamear cuando el HR oscila justo en el borde.
- Activity type: `.other` → no contamina tus métricas de "carrera" en Salud (de eso ya se encarga Strava).
- Deployment target: watchOS 10.
