# Changelog

Registro de cambios del proyecto `dilware-tool-macSpaces`.

## [1.3.0] - 2025-03-16

### Corregido
- Orden no determinístico del menú al iterar `pairs()` — reemplazado por `profile_order` (array)
- Estado inconsistente de `space_id` tras fallo de `removeSpace` — ahora siempre se limpia
- Badge de versión en README desactualizado
- Feedback prematuro al cambiar navegador — el menú ya no se actualiza antes de la confirmación del sistema
- `install.sh`: supresión silenciosa de errores de git reemplazada por verificación de conectividad
- `install.sh`: detección de repo inválido mejorada (verifica `.git/` en vez de solo el directorio)
- Bundle ID duplicado de Arc (`com.arc.app` era incorrecto) — eliminado, se mantiene `company.thebrowser.Browser`
- `require("hs.urlevent")` faltante — ahora se importa explícitamente como `local urlevent`
- Notificación ruidosa al iniciar/recargar — eliminada, solo se registra en log
- `open -a TextEdit` reemplazado por `open` genérico para respetar la app predeterminada del usuario para `.log`

### Cambiado
- `deactivate_profile` ahora espera `delay.medium * 2` antes de operar el espacio, dando tiempo a que las apps cierren
- Declaración adelantada de `build_menu` para eliminar dependencias circulares entre módulos
- Código reorganizado en secciones con separadores visuales para mejor legibilidad
- Nombres de variables internos estandarizados (`app_name`, `new_space`, `target_space`, `win_app`)
- Submenú de navegadores ordenado: activo primero, luego alfabético
- `install.sh` agrega respaldo automático del `init.lua` existente antes de sobreescribir
- `install.sh` verifica que `git` esté instalado antes de continuar

## [1.2.0] - 2025-06-16

### Agregado
- Submenú "Navegador predeterminado" en la barra de menú
- Detección automática de todos los navegadores instalados capaces de manejar `http://`
- Indicador visual del navegador activo (◉) en el submenú
- Cambio de navegador predeterminado con un clic (muestra el prompt de confirmación del sistema)
- Mapeo de bundle IDs a nombres legibles: Safari, Chrome, Edge, Firefox, Brave, Opera, Vivaldi, Arc

## [1.1.0] - 2025-06-16

### Corregido
- `clearLog()` podía crashear si el archivo de log no existía (handle nulo)
- `activate_profile` borraba el log completo al activar cualquier perfil
- Variable `currentSpace` asignada pero nunca usada
- `app:kill9()` reemplazado por `app:kill()` (cierre limpio)
- `os.exit()` en opción "Salir" causaba cierre abrupto de Hammerspoon
- Error de `pcall` no se mostraba en log al fallar creación de espacio
- Posible crash al acceder a `win:application()` sin validar nil

### Agregado
- Protección contra doble activación de un mismo perfil
- Estado visual de perfiles activos en el menú (◉ activo / ○ inactivo)
- Lanzamiento secuencial de apps con delay configurable
- Validación de espacios disponibles antes de operar
- Referencia al portafolio del autor en README

### Cambiado
- Funciones refactorizadas a `local function`
- Menú simplificado: una sola acción por perfil según su estado
- Título del menú cambiado a símbolo tipográfico (◇)
- Opción "Salir" removida
- README reescrito en formato funcional/negocio
- `install.sh` actualizado con URLs correctas y soporte para actualización
- `.gitignore` actualizado para el stack del proyecto

## [1.0.0] - 2025-06-09

### Agregado
- Primera versión estable del gestor de espacios virtuales
- Perfiles: Personal (Safari) y Work (Outlook, Teams, Chrome)
- Menú en barra superior con controles
- Notificaciones del sistema y registro en archivo
- Script de instalación automática
- Licencia GPLv3
