# Rutina

Aplicación móvil desarrollada con Flutter para organizar actividades diarias,
registrar hábitos y dar seguimiento a objetivos personales desde un solo lugar.
La información se guarda localmente en el dispositivo para que la aplicación
funcione sin depender de un servidor.

## Funcionalidades

- Gestión de tareas y rutinas diarias.
- Diario personal para registrar notas y reflexiones.
- Seguimiento del peso y del progreso semanal.
- Configuración y revisión del objetivo de calorías.
- Contador de pasos y registro de actividad diaria.
- Lista de compras, productos e inventario.
- Recordatorios mediante notificaciones locales.
- Tema claro y oscuro según la configuración del dispositivo.
- Interfaz en español y almacenamiento local de los datos.

## Tecnologías

- [Flutter](https://flutter.dev/)
- [Dart](https://dart.dev/)
- `shared_preferences` para la persistencia local.
- `flutter_local_notifications` para los recordatorios.
- `intl` y `timezone` para fechas, horarios y localización.

## Requisitos

- Flutter instalado y configurado.
- Dart SDK compatible con la versión indicada en `pubspec.yaml`.
- Un dispositivo físico o emulador para ejecutar la aplicación.

## Ejecución local

```bash
flutter pub get
flutter run
```

Para validar el proyecto:

```bash
flutter analyze
flutter test
```
