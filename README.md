# 🎯 macSpaces — Gestor de Espacios para macOS

![Versión](https://img.shields.io/badge/versión-v1.3.0-6366f1?style=flat-square)
![Licencia](https://img.shields.io/badge/licencia-GPLv3-a855f7?style=flat-square)
![Plataforma](https://img.shields.io/badge/plataforma-macOS-222?style=flat-square&logo=apple&logoColor=white)

Organiza tu Mac con un clic. Crea espacios de trabajo con las apps que necesitas, y ciérralos cuando termines.

---

## ¿Qué es?

Una herramienta gratuita para macOS que te permite crear espacios virtuales (Mission Control) con perfiles predefinidos. Cada perfil abre automáticamente las apps que necesitas en un espacio dedicado, y al cerrar el perfil, todo se limpia solo.

Funciona desde la barra de menú de macOS, sin ventanas extra ni configuraciones complicadas.

## ¿Qué puedo hacer?

- Crear un espacio de trabajo con un clic desde la barra de menú
- Abrir automáticamente las apps asociadas a cada perfil
- Cerrar un perfil y que se cierren sus apps y se elimine el espacio
- Ver qué perfiles están activos directamente en el menú
- Cambiar el navegador predeterminado del sistema desde el menú, sin abrir Preferencias del Sistema
- Consultar el registro de actividad para depuración
- Personalizar perfiles y apps editando un solo archivo

## Perfiles incluidos

| Perfil | Apps |
|--------|------|
| Personal | Safari |
| Work | Outlook, Teams, Chrome |

Puedes agregar los tuyos editando `init.lua`.

## ¿Para quién es?

- Personas que trabajan con múltiples contextos en su Mac (trabajo, personal, estudio)
- Usuarios que quieren organizar sus espacios sin apps de pago
- Cualquiera que busque automatizar su flujo de trabajo en macOS

## Requisitos

- macOS con Mission Control habilitado
- [Hammerspoon](https://www.hammerspoon.org) instalado
- Permisos de Accesibilidad y Automatización para Hammerspoon

## Instalación rápida

```bash
curl -sL https://raw.githubusercontent.com/diegoiprg/dilware-tool-macSpaces/main/install.sh | bash
```

Después, abre Hammerspoon y presiona ⌘R para recargar.

---

## Sobre este proyecto

Esta herramienta es parte de **Dilware**, una colección de proyectos de software libre creados con ayuda de inteligencia artificial bajo mi supervisión y dirección técnica. El objetivo es que sean útiles para la mayor cantidad de personas posible.

Conoce todos mis proyectos en el [Portafolio Dilware](https://diegoiprg.github.io/diegoiprg-portafolio/).

## Autor

**Diego Iparraguirre** — Ingeniero de Sistemas

[![LinkedIn](https://img.shields.io/badge/LinkedIn-diegoiprg-0A66C2?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/diegoiprg/)
[![GitHub](https://img.shields.io/badge/GitHub-diegoiprg-222?style=flat-square&logo=github&logoColor=white)](https://github.com/diegoiprg)

---

Software libre bajo licencia [GPLv3](./LICENSE).
