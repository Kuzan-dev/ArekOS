"""
GUI for Vitrum Window Patcher using GTK4 and Libadwaita.
"""

from typing import Optional

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')

from gi.repository import Gtk, Adw, Gdk

from .traffic_lights import VitrumTrafficLights
from .patchers import zen, steam, chrome, vscode, kwin_rules


CUSTOM_CSS = """
.badge-active {
    background-color: rgba(48, 209, 88, 0.18);
    color: #30d158;
    font-weight: bold;
    font-size: 11px;
    border-radius: 12px;
    padding: 3px 10px;
}

.badge-inactive {
    background-color: rgba(255, 159, 10, 0.18);
    color: #ff9f0a;
    font-weight: bold;
    font-size: 11px;
    border-radius: 12px;
    padding: 3px 10px;
}

.banner-box {
    background: linear-gradient(135deg, rgba(35, 38, 55, 0.7), rgba(20, 22, 34, 0.85));
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 18px;
    padding: 18px 22px;
    margin-bottom: 8px;
}

.patch-btn-accent {
    background: linear-gradient(135deg, #0a84ff, #0056cc);
    color: #ffffff;
    font-weight: bold;
    border-radius: 10px;
    padding: 6px 14px;
}
.patch-btn-accent:hover {
    background: linear-gradient(135deg, #2b95ff, #0066ee);
}
"""


class VitrumWindowPatcherWindow(Adw.ApplicationWindow):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.set_title("Vitrum Window Patcher")
        self.set_default_size(900, 680)

        # Force Dark theme
        Adw.StyleManager.get_default().set_color_scheme(Adw.ColorScheme.PREFER_DARK)

        # CSS
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(CUSTOM_CSS.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self._build_ui()
        self.refresh_all()

    def _build_ui(self):
        self.toast_overlay = Adw.ToastOverlay.new()
        self.set_content(self.toast_overlay)

        main_box = Gtk.Box.new(Gtk.Orientation.VERTICAL, 0)
        self.toast_overlay.set_child(main_box)

        # HeaderBar with Vitrum Native Traffic Lights
        header = Adw.HeaderBar.new()
        header.set_show_start_title_buttons(False)
        header.set_show_end_title_buttons(False)
        main_box.append(header)

        # Semáforos nativos de Vitrum en la esquina izquierda
        self.traffic_lights = VitrumTrafficLights(self)
        header.pack_start(self.traffic_lights)

        title_box = Gtk.Box.new(Gtk.Orientation.VERTICAL, 0)
        title_lbl = Gtk.Label.new("Vitrum Window Patcher")
        title_lbl.add_css_class("title")
        subtitle_lbl = Gtk.Label.new("Gestor de Semáforos y Decoraciones de Ventana")
        subtitle_lbl.add_css_class("subtitle")
        title_box.append(title_lbl)
        title_box.append(subtitle_lbl)
        header.set_title_widget(title_box)

        # Header buttons
        btn_reload = Gtk.Button.new_from_icon_name("view-refresh-symbolic")
        btn_reload.set_tooltip_text("Recargar estado de aplicaciones")
        btn_reload.connect("clicked", lambda b: self.refresh_all())
        header.pack_start(btn_reload)

        btn_batch = Gtk.Button.new()
        btn_batch.set_label("⚡ Parchar Todo")
        btn_batch.set_tooltip_text("Parchar automáticamente todas las aplicaciones detectadas")
        btn_batch.connect("clicked", self._on_batch_patch)
        header.pack_end(btn_batch)

        # Scrollable Preferences Page
        scroll = Gtk.ScrolledWindow.new()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        main_box.append(scroll)

        pref_page = Adw.PreferencesPage.new()
        scroll.set_child(pref_page)

        # Banner Info Card
        banner_group = Adw.PreferencesGroup.new()
        pref_page.add(banner_group)

        banner = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 16)
        banner.add_css_class("banner-box")
        
        banner_icon = Gtk.Image.new_from_icon_name("window-maximize-symbolic")
        banner_icon.set_pixel_size(38)
        banner_icon.add_css_class("accent")
        banner.append(banner_icon)

        banner_text_box = Gtk.Box.new(Gtk.Orientation.VERTICAL, 2)
        banner_title = Gtk.Label.new("Semáforos Nativos de Vitrum (macOS Monterey / Sequoia)")
        banner_title.add_css_class("heading")
        banner_title.set_halign(Gtk.Align.START)
        banner_desc = Gtk.Label.new("Aplica semáforos a la izquierda (12 px con borde de 1 px y pitch de 20 px), esquinas de 10 px y desenfoque KWin en navegadores, Steam y apps Electron.")
        banner_desc.add_css_class("dim-label")
        banner_desc.set_wrap(True)
        banner_desc.set_halign(Gtk.Align.START)
        banner_text_box.append(banner_title)
        banner_text_box.append(banner_desc)
        banner.append(banner_text_box)
        banner_group.add(banner)

        # ================= SECCIÓN 1: APPS ESPECIALIZADAS =================
        self.group_special = Adw.PreferencesGroup.new()
        self.group_special.set_title("Navegadores y Aplicaciones Especializadas")
        self.group_special.set_description("Aplicaciones con marcos internos o CSD que requieren inyección de CSS o temas dedicados.")
        pref_page.add(self.group_special)

        # --- Zen Browser Row ---
        self.row_zen = Adw.ActionRow.new()
        self.row_zen.set_title("Zen Browser")
        self.row_zen.set_subtitle("Inyecta zen-userChrome.css con semáforos macOS en todos los perfiles")
        img_zen = Gtk.Image.new_from_icon_name("app.zen_browser.zen")
        img_zen.set_pixel_size(32)
        self.row_zen.add_prefix(img_zen)
        
        self.badge_zen = Gtk.Label.new("")
        self.row_zen.add_suffix(self.badge_zen)
        
        zen_btns = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 6)
        self.btn_zen_patch = Gtk.Button.new_with_label("Parchar")
        self.btn_zen_patch.add_css_class("patch-btn-accent")
        self.btn_zen_patch.connect("clicked", self._on_patch_zen)
        self.btn_zen_revert = Gtk.Button.new_with_label("Revertir")
        self.btn_zen_revert.connect("clicked", self._on_revert_zen)
        zen_btns.append(self.btn_zen_patch)
        zen_btns.append(self.btn_zen_revert)
        self.row_zen.add_suffix(zen_btns)
        self.group_special.add(self.row_zen)

        # --- Steam Row ---
        self.row_steam = Adw.ActionRow.new()
        self.row_steam.set_title("Steam")
        self.row_steam.set_subtitle("Configura Adwaita-for-Steam con controles macOS y regla KWin de 10px")
        img_steam = Gtk.Image.new_from_icon_name("steam")
        img_steam.set_pixel_size(32)
        self.row_steam.add_prefix(img_steam)
        
        self.badge_steam = Gtk.Label.new("")
        self.row_steam.add_suffix(self.badge_steam)

        steam_btns = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 6)
        self.btn_steam_patch = Gtk.Button.new_with_label("Parchar")
        self.btn_steam_patch.add_css_class("patch-btn-accent")
        self.btn_steam_patch.connect("clicked", self._on_patch_steam)
        self.btn_steam_revert = Gtk.Button.new_with_label("Revertir")
        self.btn_steam_revert.connect("clicked", self._on_revert_steam)
        steam_btns.append(self.btn_steam_patch)
        steam_btns.append(self.btn_steam_revert)
        self.row_steam.add_suffix(steam_btns)
        self.group_special.add(self.row_steam)

        # --- Google Chrome Row ---
        self.row_chrome = Adw.ActionRow.new()
        self.row_chrome.set_title("Google Chrome")
        self.row_chrome.set_subtitle("Usa el marco y barra del sistema para mostrar la decoración y semáforos de Vitrum")
        img_chrome = Gtk.Image.new_from_icon_name("com.google.Chrome")
        img_chrome.set_pixel_size(32)
        self.row_chrome.add_prefix(img_chrome)
        
        self.badge_chrome = Gtk.Label.new("")
        self.row_chrome.add_suffix(self.badge_chrome)

        chrome_btns = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 6)
        self.btn_chrome_patch = Gtk.Button.new_with_label("Parchar")
        self.btn_chrome_patch.add_css_class("patch-btn-accent")
        self.btn_chrome_patch.connect("clicked", self._on_patch_chrome)
        self.btn_chrome_revert = Gtk.Button.new_with_label("Revertir")
        self.btn_chrome_revert.connect("clicked", self._on_revert_chrome)
        chrome_btns.append(self.btn_chrome_patch)
        chrome_btns.append(self.btn_chrome_revert)
        self.row_chrome.add_suffix(chrome_btns)
        self.group_special.add(self.row_chrome)

        # --- VS Code Row ---
        self.row_vscode = Adw.ActionRow.new()
        self.row_vscode.set_title("Visual Studio Code / VSCodium")
        self.row_vscode.set_subtitle("Fuerza barra de título nativa ('window.titleBarStyle': 'native') con semáforos")
        img_vscode = Gtk.Image.new_from_icon_name("com.visualstudio.code")
        img_vscode.set_pixel_size(32)
        self.row_vscode.add_prefix(img_vscode)
        
        self.badge_vscode = Gtk.Label.new("")
        self.row_vscode.add_suffix(self.badge_vscode)

        vscode_btns = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 6)
        self.btn_vscode_patch = Gtk.Button.new_with_label("Parchar")
        self.btn_vscode_patch.add_css_class("patch-btn-accent")
        self.btn_vscode_patch.connect("clicked", self._on_patch_vscode)
        self.btn_vscode_revert = Gtk.Button.new_with_label("Revertir")
        self.btn_vscode_revert.connect("clicked", self._on_revert_vscode)
        vscode_btns.append(self.btn_vscode_patch)
        vscode_btns.append(self.btn_vscode_revert)
        self.row_vscode.add_suffix(vscode_btns)
        self.group_special.add(self.row_vscode)

        # ================= SECCIÓN 2: REGLAS KWIN (ELECTRON Y JUEGOS) =================
        self.group_kwin = Adw.PreferencesGroup.new()
        self.group_kwin.set_title("Reglas KWin (Electron, Juegos y Apps sin marco)")
        self.group_kwin.set_description("Fuerza la barra y semáforos de Vitrum en aplicaciones que omiten el marco predeterminado.")
        pref_page.add(self.group_kwin)

        self.kwin_switches = {}
        for app in kwin_rules.COMMON_APPS:
            row = Adw.ActionRow.new()
            row.set_title(app["name"])
            row.set_subtitle(f"{app['description']} (wmclass={app['wmclass']})")
            
            icon_name = app["id"] if Gtk.IconTheme.get_for_display(Gdk.Display.get_default()).has_icon(app["id"]) else "application-x-executable"
            img = Gtk.Image.new_from_icon_name(icon_name)
            img.set_pixel_size(28)
            row.add_prefix(img)

            switch = Gtk.Switch.new()
            switch.set_valign(Gtk.Align.CENTER)
            switch.app_id = app["id"]
            switch.app_name = app["name"]
            switch.wmclass = app["wmclass"]
            switch.connect("notify::active", self._on_kwin_switch_toggled)
            row.add_suffix(switch)

            self.kwin_switches[app["id"]] = switch
            self.group_kwin.add(row)

        # ================= SECCIÓN 3: REGLA MANUAL =================
        group_custom = Adw.PreferencesGroup.new()
        group_custom.set_title("Forzar Semáforos en Cualquier Otra Aplicación")
        group_custom.set_description("Introduce la clase de ventana (WM_CLASS) para obligar a KWin a decorarla con Vitrum.")
        pref_page.add(group_custom)

        custom_row = Adw.ActionRow.new()
        custom_row.set_title("Nueva Regla Personalizada")
        
        custom_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 8)
        self.entry_name = Gtk.Entry.new()
        self.entry_name.set_placeholder_text("Nombre de app (ej: Obsidian)")
        self.entry_wmclass = Gtk.Entry.new()
        self.entry_wmclass.set_placeholder_text("wmclass (ej: obsidian)")

        btn_add_custom = Gtk.Button.new_with_label("+ Añadir Regla")
        btn_add_custom.add_css_class("patch-btn-accent")
        btn_add_custom.connect("clicked", self._on_add_custom_rule)

        custom_box.append(self.entry_name)
        custom_box.append(self.entry_wmclass)
        custom_box.append(btn_add_custom)
        custom_row.add_suffix(custom_box)
        group_custom.add(custom_row)

    def refresh_all(self):
        """Checks the live patch status of every application."""
        # 1. Zen Browser
        zen_ok = zen.is_patched()
        self.badge_zen.set_text("✨ Semáforos Activos" if zen_ok else "⚠️ Predeterminado")
        self.badge_zen.set_css_classes(["badge-active" if zen_ok else "badge-inactive"])
        self.btn_zen_patch.set_sensitive(not zen_ok)
        self.btn_zen_revert.set_sensitive(zen_ok)

        # 2. Steam
        steam_ok = steam.is_patched()
        self.badge_steam.set_text("✨ Semáforos Activos" if steam_ok else "⚠️ Predeterminado")
        self.badge_steam.set_css_classes(["badge-active" if steam_ok else "badge-inactive"])
        self.btn_steam_patch.set_sensitive(not steam_ok)
        self.btn_steam_revert.set_sensitive(steam_ok)

        # 3. Google Chrome
        chrome_ok = chrome.is_patched()
        self.badge_chrome.set_text("✨ Semáforos Activos" if chrome_ok else "⚠️ Predeterminado")
        self.badge_chrome.set_css_classes(["badge-active" if chrome_ok else "badge-inactive"])
        self.btn_chrome_patch.set_sensitive(not chrome_ok)
        self.btn_chrome_revert.set_sensitive(chrome_ok)

        # 4. VS Code
        vscode_ok = vscode.is_patched()
        self.badge_vscode.set_text("✨ Semáforos Activos" if vscode_ok else "⚠️ Predeterminado")
        self.badge_vscode.set_css_classes(["badge-active" if vscode_ok else "badge-inactive"])
        self.btn_vscode_patch.set_sensitive(not vscode_ok)
        self.btn_vscode_revert.set_sensitive(vscode_ok)

        # 5. KWin Switches
        for app_id, switch in self.kwin_switches.items():
            active = kwin_rules.is_rule_active(app_id)
            # Prevent triggering notify::active
            switch.handler_block_by_func(self._on_kwin_switch_toggled)
            switch.set_active(active)
            switch.handler_unblock_by_func(self._on_kwin_switch_toggled)

    def _on_patch_zen(self, button):
        ok, msg = zen.patch()
        self.show_toast(msg)
        self.refresh_all()

    def _on_revert_zen(self, button):
        ok, msg = zen.revert()
        self.show_toast(msg)
        self.refresh_all()

    def _on_patch_steam(self, button):
        ok, msg = steam.patch()
        self.show_toast(msg)
        self.refresh_all()

    def _on_revert_steam(self, button):
        ok, msg = steam.revert()
        self.show_toast(msg)
        self.refresh_all()

    def _on_patch_chrome(self, button):
        ok, msg = chrome.patch()
        self.show_toast(msg)
        self.refresh_all()

    def _on_revert_chrome(self, button):
        ok, msg = chrome.revert()
        self.show_toast(msg)
        self.refresh_all()

    def _on_patch_vscode(self, button):
        ok, msg = vscode.patch()
        self.show_toast(msg)
        self.refresh_all()

    def _on_revert_vscode(self, button):
        ok, msg = vscode.revert()
        self.show_toast(msg)
        self.refresh_all()

    def _on_kwin_switch_toggled(self, switch, param):
        if switch.get_active():
            ok, msg = kwin_rules.add_kwin_decoration_rule(switch.app_id, switch.app_name, switch.wmclass)
        else:
            ok, msg = kwin_rules.remove_kwin_decoration_rule(switch.app_id)
        self.show_toast(msg)

    def _on_add_custom_rule(self, button):
        name = self.entry_name.get_text().strip()
        wmclass = self.entry_wmclass.get_text().strip().lower()
        if not name or not wmclass:
            self.show_toast("Por favor escribe el nombre y el wmclass.")
            return

        rule_id = name.lower().replace(" ", "-")
        ok, msg = kwin_rules.add_kwin_decoration_rule(rule_id, name, wmclass)
        self.show_toast(msg)
        self.entry_name.set_text("")
        self.entry_wmclass.set_text("")
        self.refresh_all()

    def _on_batch_patch(self, button):
        """Applies semáforos to all detected apps."""
        count = 0
        if not zen.is_patched():
            ok, _ = zen.patch()
            if ok: count += 1

        if not steam.is_patched():
            ok, _ = steam.patch()
            if ok: count += 1

        if not chrome.is_patched() and chrome.is_installed():
            ok, _ = chrome.patch()
            if ok: count += 1

        if not vscode.is_patched() and vscode.is_installed():
            ok, _ = vscode.patch()
            if ok: count += 1

        self.show_toast(f"¡Se han parchado {count} aplicaciones con semáforos de Vitrum!")
        self.refresh_all()

    def show_toast(self, message: str):
        toast = Adw.Toast.new(message)
        toast.set_timeout(3)
        self.toast_overlay.add_toast(toast)
