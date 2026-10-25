"""
Main entry point for Vitrum Window Patcher.
"""

import sys
import argparse

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Adw, Gio

from .gui import VitrumWindowPatcherWindow
from .patchers import zen, steam, chrome, vscode, kwin_rules


class VitrumWindowPatcherApp(Adw.Application):
    def __init__(self):
        super().__init__(
            application_id="org.vitrum.windowpatcher",
            flags=Gio.ApplicationFlags.DEFAULT_FLAGS
        )

    def do_activate(self):
        win = self.props.active_window
        if not win:
            win = VitrumWindowPatcherWindow(application=self)
        win.present()


def print_status():
    print("🚦 Estado de Semáforos en Aplicaciones:")
    print(f" - Zen Browser:       {'✨ Activo (userChrome.css)' if zen.is_patched() else '⚠️ Sin parchar'}")
    print(f" - Steam:             {'✨ Activo (Adwaita + KWin)' if steam.is_patched() else '⚠️ Sin parchar'}")
    print(f" - Google Chrome:     {'✨ Activo (Marco del sistema)' if chrome.is_patched() else '⚠️ Sin parchar'}")
    print(f" - VS Code / Codium:  {'✨ Activo (Barra nativa)' if vscode.is_patched() else '⚠️ Sin parchar'}")
    print("\nReglas KWin activas para apps:")
    for app in kwin_rules.COMMON_APPS:
        active = kwin_rules.is_rule_active(app["id"])
        print(f" - {app['name']}: {'[ACTIVADA]' if active else '[INACTIVA]'}")


def main():
    parser = argparse.ArgumentParser(description="Vitrum Window Patcher - Gestor de Semáforos macOS")
    parser.add_argument("--status", "-s", action="store_true", help="Mostrar estado de semáforos en las aplicaciones")
    parser.add_argument("--batch", "-b", action="store_true", help="Parchar automáticamente todas las aplicaciones detectadas")
    args, unknown = parser.parse_known_args()

    if args.status:
        print_status()
        return 0

    if args.batch:
        print("⚡ Aplicando semáforos en aplicaciones...")
        if not zen.is_patched():
            ok, msg = zen.patch()
            print(f" - Zen: {msg}")
        if not steam.is_patched():
            ok, msg = steam.patch()
            print(f" - Steam: {msg}")
        if not chrome.is_patched() and chrome.is_installed():
            ok, msg = chrome.patch()
            print(f" - Chrome: {msg}")
        if not vscode.is_patched() and vscode.is_installed():
            ok, msg = vscode.patch()
            print(f" - VS Code: {msg}")
        print("🎉 Proceso finalizado.")
        return 0

    app = VitrumWindowPatcherApp()
    return app.run([sys.argv[0]] + unknown)


if __name__ == "__main__":
    sys.exit(main())
