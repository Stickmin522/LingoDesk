# LingoDesk

[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Français](README.fr.md) · [العربية](README.ar.md) · **Español** · [Deutsch](README.de.md)

LingoDesk convierte la voz y el audio que se reproduce en tu dispositivo Android en subtítulos bilingües y notas de reuniones en tiempo real. Puedes usarlo en clases, cursos en línea, reuniones y conversaciones, y leer los subtítulos flotantes mientras utilizas otras aplicaciones.

<p align="center"><img src="docs/images/lingodesk-logo-rounded.png" width="240" height="240" alt="LingoDesk" /></p>

## Capturas de pantalla

<p><img src="docs/images/captions.png" width="240" alt="LingoDesk" /> <img src="docs/images/overlay.png" width="240" alt="LingoDesk" /></p>

[Descargar APK](https://github.com/Stickmin522/LingoDesk/releases/latest)

## Funciones

- Graba el micrófono, el audio del dispositivo o ambos a la vez.
- Elige dos idiomas distintos entre los 60 compatibles. La traducción funciona automáticamente en ambos sentidos.
- Alterna entre los subtítulos bilingües y las notas en directo con un botón.
- La grabación y la traducción continúan en segundo plano al consultar el historial o usar otras aplicaciones. La grabación se detiene desde la app.
- Los subtítulos flotantes solo aparecen durante una sesión activa, al salir de la app. Puedes moverlos y cambiar su tamaño; la barra de herramientas se oculta automáticamente. Cerrar la ventana no detiene la grabación.
- Recuerda la activación, la posición y el tamaño de la ventana flotante.
- Elige entre 60 idiomas de interfaz o usa el idioma del sistema. Si el dispositivo no admite el idioma seleccionado, se muestra en inglés. Utiliza las fuentes del sistema.
- Reproduce las grabaciones guardadas y exporta en WAV, TXT, SRT o JSON.
- Se adapta a teléfonos, tabletas, pantallas plegables, orientación horizontal y pantalla dividida, con temas claro y oscuro.

## Primeros pasos

Necesitas un dispositivo ARM64 con Android 10 o posterior.

1. Instala el APK y configura el servicio indicado abajo.
2. Selecciona dos idiomas distintos y una fuente de audio, concede los permisos solicitados e inicia la grabación.
3. Activa los subtítulos flotantes y el permiso para mostrarlos sobre otras aplicaciones. Durante la grabación podrás verlos al volver a la pantalla de inicio.
4. Regresa a la app para detener y guardar la grabación. Abre el historial para reproducirla o exportarla.

## LecSync

El reconocimiento de voz, la traducción y las notas utilizan la API de LecSync y requieren conexión a Internet. Crea tu propia clave API en la [consola de LecSync](https://www.lecsync.com/dashboard/api) e introdúcela en los ajustes de la app. El consumo se factura a la cuenta asociada a esa clave. La app se conecta directamente a la API, por lo que no depende de una web de traducción creada por separado. Las grabaciones y el historial se guardan en el dispositivo y no se sincronizan con la cuenta de la web. Consulta la [documentación de la API](https://www.lecsync.com/developers) para obtener más información.

## Compilar desde el código fuente

Consulta la [guía de compilación](docs/BUILD.md).

## Palabras clave

Android, Flutter, Rust, Kotlin, traducción en tiempo real, reconocimiento de voz, subtítulos bilingües, subtítulos flotantes, grabación en segundo plano, audio del sistema, ARM64, Android 17, traducción multilingüe, notas de reuniones.
