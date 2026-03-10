# RetroCam

RetroCam — iOS-приложение на SwiftUI, которое эмулирует камеру старого мобильного телефона.

## Возможности
- Фото 640x480
- Видео 640x480
- Retro-фильтр
- Штамп даты
- Переключение фронтальной/основной камеры

## Структура
- `RetroCamS40App.swift` — точка входа приложения
- `ContentView.swift` — главный экран
- `CameraService.swift` — логика камеры
- `CameraPreview.swift` — превью камеры через `UIViewRepresentable`
- `RetroFilter.swift` — обработка фото и видео
- `VideoExporter.swift` — экспорт видео
- `UIImage+Retro.swift` — утилиты для обработки изображений

## Требования
- iOS 16+
- Swift 5.9+

## Разрешения
- Camera
- Microphone
- Photo Library Add