# Uso de herramientas de IA en el desarrollo

Documento del requisito "documentar cómo se utilizaron herramientas de IA y cuál fue su impacto en productividad, calidad, documentación y pruebas". Lo marcado con **[completar]** son datos medidos que solo el autor puede aportar; no se estiman aquí para no presentar cifras inventadas.

**En una frase:** la arquitectura, el alcance y las prioridades las definió y dirigió el autor; la IA implementó la mayor parte del código bajo esa arquitectura y apoyó con revisión, instrucciones y borradores de documentación; el autor orquestó varios agentes en paralelo, ejecutó cada verificación y realizó cada commit.

## 1. Qué se construyó

Plataforma financiera digital en Flutter, organizada como monorepo (Pub Workspaces y Melos) con arquitectura limpia por features, Trunk Based Development y CI en GitHub Actions.

- **Onboarding y autenticación:** registro en tres pasos, login y sesión con Supabase; el segmento (joven o adulto) lo calcula el backend según la edad.
- **Cuentas, saldos y movimientos** reales, con paginación y dinero siempre en centavos enteros; registrar un movimiento como función de demostración.
- **Personalización dinámica:** el home cambia por segmento con un JSON de Remote Config, en vivo y sin reinstalar.
- **Servicio externo:** conversor de remesas EUR→USD con una API pública, con reintentos, caché y fecha de la tasa.
- **Notificaciones push** al crearse un movimiento, con permiso, registro del token y borrado del token al cerrar sesión.
- **Monitoreo** con Firebase (Analytics, Crashlytics, Performance), con eventos finos (embudo del registro, estados degradados, notificaciones) y un filtro de privacidad que descarta correos, nombres e importes.
- **Resiliencia:** reintentos con backoff, caché cifrada, modo sin conexión con datos guardados y su fecha, recuperación automática e indisponibilidad parcial (cada servicio se apaga por separado desde un panel de depuración).

## 2. Herramientas y roles

| Quién | Rol |
|---|---|
| **El autor** | Propuso la arquitectura y el stack (monorepo con Pub Workspaces y Melos, arquitectura limpia por features, Trunk Based Development, Supabase y Firebase) y aportó el enunciado y el documento de arquitectura inicial; fijó el alcance, las prioridades y los recortes; orquestó los agentes; ejecutó los comandos; verificó cada pieza en un dispositivo Android físico; y realizó cada commit y merge. **[confirmar]** Cuánto de la redacción del documento inicial se apoyó en IA |
| **Claude Code, varios agentes** | Implementó la **mayor parte del código**, por paquete y con propiedad exclusiva de carpetas, siguiendo la arquitectura del autor: backend de apoyo, red y caché, sistema de diseño, onboarding, cuentas, shell, telemetría y personalización, notificaciones, tasas, registrar movimiento, integración y E2E |
| **Claude, en conversación** | Apoyo al autor, no autoría de la arquitectura: revisó el diseño contra el enunciado, propuso correcciones y contratos entre paquetes, redactó las instrucciones por pieza y borradores de documentación y diagramas, que el autor revisó |
| **OpenCode** | Tarea de comandos: crear y configurar el proyecto de Firebase con FlutterFire |
| **Orca** | Orquestación de varias ventanas de agentes trabajando casi en paralelo |

**[completar]** Si se usó alguna otra herramienta, añadirla aquí.

## 3. Método de trabajo

1. **La arquitectura vino primero y es del autor.** Se revisó contra el enunciado antes de programar, y esa revisión corrigió inconsistencias.
2. **Instrucciones por pieza, escritas y conservadas** (`docs/ia/prompts/`, carpeta local que se publicará con el repositorio): contexto, reglas de arquitectura, alcance, pruebas exigidas y criterios de aceptación. Funcionaron como especificaciones ejecutables: ver [`../sdd.md`](../sdd.md).
3. **Agentes en paralelo con contratos.** Con Orca se trabajó en varias ventanas a la vez sobre paquetes distintos, con propiedad exclusiva de carpetas y comunicándose solo por APIs públicas acordadas. Si un agente necesitaba algo ajeno, se detenía y lo pedía, como haría un equipo real.
4. **El autor ejecutaba y verificaba, no la IA.** Los agentes de Flutter escribían archivos; el autor corría `melos run analyze`, `melos run test` y la aplicación, y devolvía la salida real. Una regla prohibía afirmar que algo pasa sin haberla visto. Solo el backend y la tarea de FlutterFire ejecutaron comandos propios, con una lista cerrada y sin acceso a nada remoto. Una excepción real: al inicio de una sesión, un agente de Flutter ejecutó unas lecturas de comandos (`find`, `grep`, `ls`); el autor lo corrigió de inmediato y la regla quedó guardada en la memoria del agente.
5. **Trunk Based Development, con un matiz honesto.** Desde el principio, commits pequeños y frecuentes a `main`. Las piezas iniciales (red, cuentas, shell y el primer frente de Firebase y personalización) se subieron directamente a `main`. A partir del frente de notificaciones se formalizó una **rama corta por pieza**, uno o dos commits, `merge --no-ff` el mismo día, ramas borradas y CI en verde antes de abrir la siguiente. Se ve en el historial: `git log --oneline --graph`.
6. **Todo se probó en un Android físico** contra el backend real, incluido el E2E, el QA de la push (con la app abierta, en segundo plano y cerrada), el cambio de usuario y el recorrido completo del guion de demostración.

## 4. Quién hizo qué

| La IA | El autor |
|---|---|
| Escribió la mayor parte del código y de las pruebas de cada pieza | Propuso la arquitectura, el stack y las reglas de trabajo (incluido Trunk Based Development) |
| Redactó borradores de documentación, decisiones y diagramas | Definió el alcance, las prioridades y qué se recorta |
| Revisó el diseño contra el enunciado y propuso correcciones | Orquestó los agentes y decidió qué se pedía a cada uno |
| | Ejecutó análisis, pruebas y aplicación, y verificó en el dispositivo |
| | Decidió qué entra a `main` y realizó cada commit y merge |

**Nota sobre las especificaciones.** Las instrucciones y los contratos que guiaron a los agentes (`docs/ia/prompts/`) funcionaron como especificaciones, y su **redacción también fue asistida por IA**; la dirección, las decisiones y la validación fueron del autor, que probaba y verificaba cada pieza antes de integrarla. Fue un enfoque spec-first informal, no SDD estricto: ante cualquier discrepancia, el código real mandaba sobre el texto (ver [`../sdd.md`](../sdd.md)).

## 5. Revisión crítica: errores que se detectaron

La IA acelera, pero también produjo o heredó errores plausibles. Estos se detectaron antes de la entrega, en la revisión del autor y en una segunda pasada de IA:

| Hallazgo | Corrección |
|---|---|
| Un interceptor de Dio no cubre las peticiones de `supabase_flutter`, que usa `package:http` | Cliente HTTP con reintentos para Supabase y para las tasas |
| Filtro de CI por diferencia que, comparado contra `main` estando en `main`, deja un diff vacío y un verde falso | Comparar contra el commit previo y comprobar en el log que las pruebas corren |
| Parámetro `anonKey` deprecado, detectado por el analizador del CI | `publishableKey`, y una búsqueda automática en la verificación final |
| Montos con signo frente a monto positivo más tipo, y dinero en `double` | Dominio con tipo explícito y centavos enteros con un único parser |
| Instrucciones desactualizadas que habrían hecho a un agente rehacer trabajo ya integrado | Precondiciones verificables al inicio de cada instrucción |
| Conflicto entre exportar solo la API pública y una prueba que usaba clases internas | Excepción acotada: el cambio de la API y de su consumidor en el mismo merge |
| Contrato de backend redactado sin verificar contra la base real | Aviso explícito y prueba de integración contra el backend |
| Cobertura de `core_network` con una rama sin probar (reintento por tiempo agotado) | Prueba adicional |
| Un trigger de push ya existente que habría duplicado las notificaciones | Auditoría del backend antes de construir, en lugar de duplicar |
| **Un cambio no pedido:** un agente mapeó `AuthRetryableFetchException` en `map_failure.dart` para arreglar un mensaje de login, sin que se le pidiera | El autor lo rechazó y se revirtió; la causa real era que el teléfono no alcanzaba `127.0.0.1` (faltaba `adb reverse`), comprobado con los registros del backend |
| **Alcance excedido:** un agente implementó transacciones antes de que se pidiera | Se revirtió y se implementó después, cuando tocaba |
| **Hueco del CI:** el CI analiza y prueba, pero no compila el APK; `flutter_local_notifications` exigía *core library desugaring* y solo apareció al compilar en el dispositivo | Se añadió el desugaring en `build.gradle.kts`; el E2E en el dispositivo cubre lo que el CI no ve |
| **Falso verde del RPC:** las pruebas con falsos no pueden saber si `add_demo_movement` acepta el monto como cadena decimal para su parámetro `numeric` | Prueba de integración contra el backend local, que lo confirmó |
| **Diagnóstico de la push:** el primer envío no llegó; la causa estaba en la configuración del backend (clave y modo de prueba de FCM), no en la app | Se recorrió la cadena eslabón por eslabón (token, trigger, función, FCM) antes de tocar código |

## 6. Impacto

**Productividad.** Instrucciones acotadas con criterios de aceptación y varios agentes en paralelo, orquestados con Orca, permitieron avanzar en varios paquetes a la vez. El costo observado fue que cada pieza exigía ejecutar, verificar y hacer merge: el cuello de botella pasó de escribir código a la atención del autor.
**[completar]** Horas totales aproximadas y piezas integradas:

```bash
git rev-list --count main
git log --merges --oneline | wc -l
```

No se compara con un trabajo sin IA que no se haya medido.

**Calidad.** Capas y reglas de dependencia comprobables con búsquedas automáticas (los features no importan Supabase ni otros features); errores de diseño detectados antes de implementarse (sección 5); datos sensibles protegidos con un filtro de privacidad probado. El riesgo propio de la IA, código plausible pero incorrecto, se mitigó con análisis estático, pruebas y la comprobación en el dispositivo.

**Documentación.** La IA produjo borradores del documento de arquitectura (con alternativas y trade-offs), de los diagramas, de la estrategia de despliegue y de este documento, que el autor revisó. Riesgo observado: los documentos se quedan atrás del código, así que se reconciliaron con el estado real al final. Cada paquete tiene un README con su API, sus decisiones, sus recortes y los eventos de telemetría que emite.

**Pruebas.** Cada instrucción exigía pruebas junto con la pieza, con falsos escritos a mano y sin red en el CI, priorizando lo crítico (dinero, errores, reintentos, caché, privacidad). Hay un E2E contra el backend real que pasó en un dispositivo físico (login, home, cuenta, modo sin conexión, recuperación y cierre de sesión). Límite: las pruebas con falsos no detectan un nombre de columna equivocado ni el tipo de un parámetro, por eso existen las pruebas de integración.
**[completar]** Número total de pruebas: la salida de `melos exec -- flutter test` muestra `+N` por paquete; súmalos. Cobertura donde la hayas medido. Dato de ejemplo ya medido: `core_network` tiene 40 pruebas pasando.

## 7. Límites y riesgos del uso de IA

- **Confianza indebida:** una afirmación de la IA sobre el estado del código puede ser falsa. Solo cuenta lo que muestra una ejecución real.
- **Contexto obsoleto:** los agentes parten del texto de la instrucción; si está viejo, rehacen o contradicen trabajo previo.
- **Cambios no pedidos:** un agente tiende a "arreglar de más"; por eso cada instrucción define qué carpetas son suyas y el autor revisa qué entra a cada commit.
- **Deriva entre agentes:** se mitigó con contratos, propiedad de carpetas y el código de `main` como fuente de verdad.
- **Secretos:** a los agentes se les prohibió leer, imprimir o escribir claves, tokens y credenciales; los valores reales los colocó el autor a mano.
- **Comprensión:** el autor debe poder explicar y modificar cualquier parte del repositorio. Lo que no se entiende no se integra.

## 8. Evidencia

- **Historial de git:** ramas por pieza y merges sin fast-forward (desde el frente de notificaciones), y commits directos a `main` en las piezas iniciales (`git log --oneline --graph`).
- **READMEs de cada paquete** (`packages/**/README.md`) y `packages/app/README.md`, que incluye el guion de demostración.
- **Las instrucciones por pieza** (`docs/ia/prompts/`) y **`docs/documento-maestro-arquitectura.md`** (decisiones, alternativas y trade-offs) viven en `docs/`, una carpeta local fuera del control de versiones que se publicará junto con el repositorio.
