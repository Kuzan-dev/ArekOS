"""
Main entry point for Vitrum Icon Patcher.
Supports GUI and CLI batch operations.
"""

import sys
import argparse

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Adw, Gio

from .scanner import scan_all_apps, patch_app_icon, revert_app_icon
from .engine import generate_squircle_svg
from .gui import VitrumIconPatcherWindow


class VitrumIconPatcherApp(Adw.Application):
    def __init__(self):
        super().__init__(
            application_id="org.vitrum.iconpatcher",
            flags=Gio.ApplicationFlags.DEFAULT_FLAGS
        )

    def do_activate(self):
        win = self.props.active_window
        if not win:
            win = VitrumIconPatcherWindow(application=self)
        win.present()


def run_cli_batch():
    print("🔍 Escaneando aplicaciones del sistema...")
    apps = scan_all_apps()
    unpatched = [a for a in apps if not a.is_patched and a.icon_path]
    print(f"📊 Total de aplicaciones: {len(apps)} | Sin parchar: {len(unpatched)}")

    if not unpatched:
        print("✨ ¡Todas las aplicaciones ya tienen el formato Squircle de Launchpad!")
        return 0

    count = 0
    for app in unpatched:
        try:
            print(f"  ⚡ Parchando: {app.name} ({app.id})...")
            svg = generate_squircle_svg(
                source_image_path=app.icon_path,
                mode="emblem",
                top_color="auto",
                bottom_color="auto",
                scale=0.65,
                enable_shadow=True
            )
            ok, msg = patch_app_icon(app, svg)
            if ok:
                count += 1
            else:
                print(f"     ⚠️ Error: {msg}")
        except Exception as e:
            print(f"     ❌ Falló {app.name}: {e}")

    print(f"\n🎉 ¡Operación completada! Se parcharon {count} aplicaciones con éxito.")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Vitrum Icon Patcher - Launchpad Squircle Studio")
    parser.add_argument("--batch", "-b", action="store_true", help="Parchar todas las aplicaciones pendientes sin abrir interfaz")
    parser.add_argument("--list", "-l", action="store_true", help="Listar aplicaciones pendientes de parchar")
    args, unknown = parser.parse_known_args()

    if args.list:
        apps = scan_all_apps()
        unpatched = [a for a in apps if not a.is_patched]
        print(f"Aplicaciones sin parchar ({len(unpatched)}):")
        for a in unpatched:
            print(f" - {a.name} [{a.category}] (Icon={a.icon_name})")
        return 0

    if args.batch:
        return run_cli_batch()

    # Otherwise run GUI
    app = VitrumIconPatcherApp()
    return app.run([sys.argv[0]] + unknown)


if __name__ == "__main__":
    sys.exit(main())
