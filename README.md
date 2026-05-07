# PulseMeter — Apple Watch

App para Apple Watch que monitoriza el ritmo cardiaco en tiempo real y vibra cuando sales de un rango BPM definido. Pensada para correr en paralelo con Strava (o cualquier otra app de entrenamiento).

## Comportamiento

- Defines un rango mín–máx (por defecto 150–170 BPM).
- Si las pulsaciones **suben por encima del máx** → **2 vibraciones** (toca aflojar).
- Si las pulsaciones **bajan al mínimo** desde el rango/encima → **1 vibración** (vuelve a empezar a correr).
- Compatible con Strava: PulseMeter abre su propia `HKWorkoutSession` en paralelo, sin interferir.

## Estructura

```
PulseMeterApp.swift      // entrada de la app
ContentView.swift        // UI principal + ajustes (Stepper mín/máx)
HeartRateMonitor.swift   // HealthKit + lógica de zonas + hápticos
Info-additions.plist     // claves de privacidad que hay que pegar en Info.plist
```

## Cómo crear el proyecto en Xcode

1. Abre Xcode → **File → New → Project…**
2. Plataforma **watchOS** → **App** → siguiente.
   - Product Name: `PulseMeter`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Bundle Identifier: el tuyo (p. ej. `com.javiergil.PulseMeter`).
3. Guarda el proyecto donde quieras (puedes incluso guardarlo aquí mismo).
4. En el navegador de Xcode, dentro del target **PulseMeter Watch App**, **borra** los archivos generados `ContentView.swift` y `PulseMeterApp.swift` (mover a la papelera).
5. Arrastra a esa misma carpeta del proyecto los tres archivos del repo:
   - `PulseMeterApp.swift`
   - `ContentView.swift`
   - `HeartRateMonitor.swift`

   Marca **"Copy items if needed"** y añade al target **PulseMeter Watch App**.
6. Selecciona el proyecto en el navegador → target **PulseMeter Watch App** → pestaña **Signing & Capabilities**:
   - Elige tu **Team** (vale el Personal Team gratis).
   - Pulsa **+ Capability** y añade **HealthKit**.
7. En la pestaña **Info** del mismo target, añade las dos claves de `Info-additions.plist`:
   - `Privacy - Health Share Usage Description`
   - `Privacy - Health Update Usage Description`

## Cómo pasarla al reloj

1. Conecta el iPhone por USB al Mac. El Apple Watch tiene que estar emparejado y desbloqueado.
2. En el iPhone: **Ajustes → Privacidad y seguridad → Modo desarrollador → ON** y reinicia.
3. En el Apple Watch: **Ajustes → Privacidad y seguridad → Modo desarrollador → ON**.
4. En Xcode, en la barra superior elige como destino tu **Apple Watch** (no el simulador).
5. Pulsa **▶ Run** (Cmd+R). La primera vez Xcode firma con tu Apple ID y tarda un par de minutos en instalar.
6. Si sale "Untrusted Developer" en el reloj/iPhone: en iPhone ve a **Ajustes → General → VPN y gestión de dispositivos**, abre tu perfil de desarrollador y pulsa **Confiar**.
7. Acepta los permisos de HealthKit la primera vez que pulses **Empezar**.

> Con Apple ID gratuito la firma caduca cada **7 días** y tendrás que reinstalar desde Xcode. Con cuenta de desarrollador de pago (99 €/año) dura un año.

## Uso típico con Strava

1. Abre Strava en el reloj y empieza la actividad.
2. Vuelve al menú del reloj y abre **PulseMeter**.
3. Ajusta el rango si hace falta y pulsa **Empezar**.
4. Las dos apps recibirán las pulsaciones del sensor a la vez.
5. Al terminar, **Parar** en PulseMeter y **Finalizar** en Strava.

## Notas técnicas

- Usa `HKLiveWorkoutBuilder` para recibir muestras de HR en streaming (~1 Hz).
- El alerta solo dispara en transiciones de zona, con un **cooldown de 10 s** para evitar spam si las pulsaciones oscilan justo en el borde.
- Activity type: `.other` (no contamina tus métricas de "carrera" en Salud — Strava ya las registra).
