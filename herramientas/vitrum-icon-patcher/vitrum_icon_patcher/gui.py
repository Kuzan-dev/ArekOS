"""
GUI for Vitrum Icon Patcher using GTK4 and Libadwaita.
"""

import os
from pathlib import Path
from typing import Optional, List

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('GdkPixbuf', '2.0')
gi.require_version('Gdk', '4.0')

from gi.repository import Gtk, Adw, GdkPixbuf, Gdk, GLib, Pango

from .constants import PRESET_PALETTES, WHITESUR_SCALABLE_DIR, VITRUM_ICONOS_DIR
from .traffic_lights import VitrumTrafficLights
from .scanner import AppInfo, scan_all_apps, patch_app_icon, revert_app_icon, load_history
from .engine import (
    find_icon_path,
    generate_squircle_svg,
    render_svg_to_pixbuf,
    extract_dominant_colors,
    load_image_as_base64_png,
    rgb_to_hex
)

CUSTOM_CSS = """
.launchpad-card {
    background: linear-gradient(135deg, rgba(30, 32, 45, 0.75), rgba(18, 20, 30, 0.85));
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 20px;
    padding: 24px;
    box-shadow: 0 12px 30px rgba(0, 0, 0, 0.4);
}

.tile-box {
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 16px;
    padding: 16px 20px;
}

.badge-unpatched {
    background-color: rgba(255, 159, 10, 0.18);
    color: #ff9f0a;
    font-weight: bold;
    font-size: 11px;
    border-radius: 12px;
    padding: 3px 8px;
}

.badge-patched {
    background-color: rgba(48, 209, 88, 0.18);
    color: #30d158;
    font-weight: bold;
    font-size: 11px;
    border-radius: 12px;
    padding: 3px 8px;
}

.patch-button {
    background: linear-gradient(135deg, #0a84ff, #0056cc);
    color: #ffffff;
    font-weight: bold;
    border-radius: 12px;
    padding: 10px 20px;
}
.patch-button:hover {
    background: linear-gradient(135deg, #2b95ff, #0066ee);
}

.app-row {
    padding: 10px 14px;
    border-radius: 10px;
    margin: 2px 4px;
}
.app-row:hover {
    background: rgba(255, 255, 255, 0.05);
}
.app-row:selected {
    background: rgba(10, 132, 255, 0.25);
}
"""


class VitrumIconPatcherWindow(Adw.ApplicationWindow):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.set_title("Vitrum Icon Patcher")
        self.set_default_size(1020, 720)

        # Prefer Dark theme
        Adw.StyleManager.get_default().set_color_scheme(Adw.ColorScheme.PREFER_DARK)

        # Apply CSS
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(CUSTOM_CSS.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.apps: List[AppInfo] = []
        self.filtered_apps: List[AppInfo] = []
        self.current_app: Optional[AppInfo] = None
        self.active_filter = "all"  # all, unpatched, patched, games, pwa
        self.search_text = ""

        # Current editor state
        self.current_source_image: Optional[str] = None
        self.current_mode = "emblem"
        self.current_top_color = "auto"
        self.current_bottom_color = "auto"
        self.current_scale = 0.65
        self.current_shadow = True
        self.generated_svg: Optional[str] = None

        self._build_ui()
        self.reload_apps()

    def _build_ui(self):
        # Toast Overlay
        self.toast_overlay = Adw.ToastOverlay.new()
        self.set_content(self.toast_overlay)

        # Main Box
        main_box = Gtk.Box.new(Gtk.Orientation.VERTICAL, 0)
        self.toast_overlay.set_child(main_box)

        # HeaderBar
        header = Adw.HeaderBar.new()
        header.set_show_start_title_buttons(False)
        header.set_show_end_title_buttons(False)
        main_box.append(header)

        # Vitrum Native Traffic Lights (Semáforos Monterey/Sequoia)
        self.traffic_lights = VitrumTrafficLights(self)
        header.pack_start(self.traffic_lights)

        title_box = Gtk.Box.new(Gtk.Orientation.VERTICAL, 0)
        title_lbl = Gtk.Label.new("Vitrum Icon Patcher")
        title_lbl.add_css_class("title")
        subtitle_lbl = Gtk.Label.new("Launchpad & WhiteSur Squircle Studio")
        subtitle_lbl.add_css_class("subtitle")
        title_box.append(title_lbl)
        title_box.append(subtitle_lbl)
        header.set_title_widget(title_box)

        # Header buttons
        btn_reload = Gtk.Button.new_from_icon_name("view-refresh-symbolic")
        btn_reload.set_tooltip_text("Recargar aplicaciones")
        btn_reload.connect("clicked", lambda b: self.reload_apps())
        header.pack_start(btn_reload)

        btn_batch = Gtk.Button.new()
        btn_batch.set_label("⚡ Parchar Todo")
        btn_batch.set_tooltip_text("Parchar automáticamente todas las aplicaciones sin squircle")
        btn_batch.connect("clicked", self._on_batch_patch_clicked)
        header.pack_end(btn_batch)

        # Paned (Split view: Left list, Right studio)
        self.paned = Gtk.Paned.new(Gtk.Orientation.HORIZONTAL)
        self.paned.set_position(360)
        self.paned.set_shrink_start_child(False)
        self.paned.set_shrink_end_child(False)
        main_box.append(self.paned)

        # ----------------- LEFT PANE -----------------
        left_box = Gtk.Box.new(Gtk.Orientation.VERTICAL, 8)
        left_box.set_size_request(340, -1)
        left_box.set_margin_start(10)
        left_box.set_margin_end(6)
        left_box.set_margin_top(10)
        left_box.set_margin_bottom(10)

        # Search entry
        self.search_entry = Gtk.SearchEntry.new()
        self.search_entry.set_placeholder_text("Buscar aplicación...")
        self.search_entry.connect("search-changed", self._on_search_changed)
        left_box.append(self.search_entry)

        # Filter Pills (Horizontal Box)
        filters_scroll = Gtk.ScrolledWindow.new()
        filters_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.NEVER)
        filter_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 6)
        filter_box.set_margin_top(2)
        filter_box.set_margin_bottom(4)

        filters = [
            ("all", "Todas"),
            ("unpatched", "⚠️ Sin parchar"),
            ("patched", "✨ Parchadas"),
            ("games", "🎮 Juegos"),
            ("pwa", "🌐 Web/PWA"),
        ]

        self.filter_buttons = {}
        first_btn = None
        for key, label in filters:
            btn = Gtk.ToggleButton.new_with_label(label)
            if first_btn is None:
                first_btn = btn
                btn.set_active(True)
            else:
                btn.set_group(first_btn)
            btn.connect("toggled", self._on_filter_toggled, key)
            filter_box.append(btn)
            self.filter_buttons[key] = btn

        filters_scroll.set_child(filter_box)
        left_box.append(filters_scroll)

        # App List
        self.list_scroll = Gtk.ScrolledWindow.new()
        self.list_scroll.set_vexpand(True)
        self.app_listbox = Gtk.ListBox.new()
        self.app_listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.app_listbox.connect("row-selected", self._on_app_selected)
        self.list_scroll.set_child(self.app_listbox)
        left_box.append(self.list_scroll)

        self.lbl_count = Gtk.Label.new("")
        self.lbl_count.add_css_class("dim-label")
        self.lbl_count.set_halign(Gtk.Align.START)
        left_box.append(self.lbl_count)

        self.paned.set_start_child(left_box)

        # ----------------- RIGHT PANE (STUDIO) -----------------
        self.right_stack = Gtk.Stack.new()
        self.right_stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)

        # Empty State
        empty_page = Adw.StatusPage.new()
        empty_page.set_title("Selecciona una aplicación")
        empty_page.set_description("Elige cualquier app instalada de la lista para previsualizar y convertir su icono al formato Squircle de Launchpad.")
        empty_page.set_icon_name("applications-graphics-symbolic")
        self.right_stack.add_named(empty_page, "empty")

        # Studio Content
        studio_scroll = Gtk.ScrolledWindow.new()
        studio_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        studio_box = Gtk.Box.new(Gtk.Orientation.VERTICAL, 16)
        studio_box.set_margin_start(20)
        studio_box.set_margin_end(20)
        studio_box.set_margin_top(14)
        studio_box.set_margin_bottom(20)
        studio_scroll.set_child(studio_box)
        self.right_stack.add_named(studio_scroll, "studio")

        self.paned.set_end_child(self.right_stack)

        # --- Studio Header Info ---
        header_card = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 12)
        header_card.set_valign(Gtk.Align.CENTER)
        
        info_vbox = Gtk.Box.new(Gtk.Orientation.VERTICAL, 2)
        self.lbl_app_name = Gtk.Label.new("")
        self.lbl_app_name.add_css_class("title-2")
        self.lbl_app_name.set_halign(Gtk.Align.START)
        self.lbl_app_id = Gtk.Label.new("")
        self.lbl_app_id.add_css_class("dim-label")
        self.lbl_app_id.set_halign(Gtk.Align.START)
        info_vbox.append(self.lbl_app_name)
        info_vbox.append(self.lbl_app_id)
        header_card.append(info_vbox)

        self.lbl_app_status = Gtk.Label.new("")
        self.lbl_app_status.set_hexpand(True)
        self.lbl_app_status.set_halign(Gtk.Align.END)
        header_card.append(self.lbl_app_status)
        studio_box.append(header_card)

        # --- Dual Preview Deck ---
        preview_deck = Gtk.Box.new(Gtk.Orientation.VERTICAL, 10)
        preview_deck.add_css_class("launchpad-card")

        deck_title = Gtk.Label.new("VISTA PREVIA EN LAUNCHPAD")
        deck_title.add_css_class("caption")
        deck_title.add_css_class("dim-label")
        deck_title.set_halign(Gtk.Align.START)
        preview_deck.append(deck_title)

        tiles_hbox = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 24)
        tiles_hbox.set_halign(Gtk.Align.CENTER)
        tiles_hbox.set_valign(Gtk.Align.CENTER)

        # Original Tile
        orig_tile = Gtk.Box.new(Gtk.Orientation.VERTICAL, 8)
        orig_tile.add_css_class("tile-box")
        orig_tile.set_size_request(130, 130)
        orig_tile.set_halign(Gtk.Align.CENTER)
        self.img_original = Gtk.Image.new()
        self.img_original.set_pixel_size(72)
        orig_lbl = Gtk.Label.new("Original")
        orig_lbl.add_css_class("dim-label")
        orig_tile.append(self.img_original)
        orig_tile.append(orig_lbl)
        tiles_hbox.append(orig_tile)

        # Arrow
        arrow_lbl = Gtk.Label.new("➔")
        arrow_lbl.add_css_class("title-1")
        arrow_lbl.add_css_class("accent")
        tiles_hbox.append(arrow_lbl)

        # Squircle Tile
        squircle_tile = Gtk.Box.new(Gtk.Orientation.VERTICAL, 8)
        squircle_tile.add_css_class("tile-box")
        squircle_tile.set_size_request(140, 140)
        squircle_tile.set_halign(Gtk.Align.CENTER)
        self.img_squircle = Gtk.Image.new()
        self.img_squircle.set_pixel_size(92)
        squircle_lbl = Gtk.Label.new("✨ Squircle (WhiteSur)")
        squircle_lbl.add_css_class("accent")
        squircle_lbl.add_css_class("heading")
        squircle_tile.append(self.img_squircle)
        squircle_tile.append(squircle_lbl)
        tiles_hbox.append(squircle_tile)

        preview_deck.append(tiles_hbox)
        studio_box.append(preview_deck)

        # --- Configuration Options ---
        pref_group = Adw.PreferencesGroup.new()
        pref_group.set_title("Configuración de Estilo")
        studio_box.append(pref_group)

        # Mode row
        row_mode = Adw.ActionRow.new()
        row_mode.set_title("Modo de Composición")
        row_mode.set_subtitle("Elige cómo adaptar el icono dentro de la silueta squircle")
        
        mode_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 4)
        btn_mode_emblem = Gtk.ToggleButton.new_with_label("Emblema con Fondo")
        btn_mode_emblem.set_active(True)
        btn_mode_mask = Gtk.ToggleButton.new_with_label("Máscara Completa")
        btn_mode_mask.set_group(btn_mode_emblem)
        btn_mode_emblem.connect("toggled", self._on_mode_toggled, "emblem")
        btn_mode_mask.connect("toggled", self._on_mode_toggled, "mask")
        mode_box.append(btn_mode_emblem)
        mode_box.append(btn_mode_mask)
        row_mode.add_suffix(mode_box)
        pref_group.add(row_mode)

        # Color Preset row
        self.row_palette = Adw.ActionRow.new()
        self.row_palette.set_title("Paleta de Color de Fondo")
        self.row_palette.set_subtitle("Colores del degradado squircle (como Disney+, HBO, etc.)")
        
        self.combo_palette = Gtk.DropDown.new_from_strings([p[2] for p in PRESET_PALETTES])
        self.combo_palette.connect("notify::selected", self._on_palette_changed)
        self.row_palette.add_suffix(self.combo_palette)
        pref_group.add(self.row_palette)

        # Custom Colors Row (Visible when Custom is picked or to fine-tune)
        self.row_custom_colors = Adw.ActionRow.new()
        self.row_custom_colors.set_title("Ajuste Manual de Colores")
        self.row_custom_colors.set_subtitle("Color Superior e Inferior del Degradado")
        
        colors_box = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 8)
        self.color_dialog = Gtk.ColorDialog.new()
        self.btn_color_top = Gtk.ColorDialogButton.new(self.color_dialog)
        self.btn_color_top.connect("notify::rgba", self._on_custom_color_changed)
        
        self.btn_color_bottom = Gtk.ColorDialogButton.new(self.color_dialog)
        self.btn_color_bottom.connect("notify::rgba", self._on_custom_color_changed)
        
        lbl_top = Gtk.Label.new("Superior:")
        lbl_top.add_css_class("dim-label")
        lbl_bot = Gtk.Label.new("Inferior:")
        lbl_bot.add_css_class("dim-label")

        colors_box.append(lbl_top)
        colors_box.append(self.btn_color_top)
        colors_box.append(lbl_bot)
        colors_box.append(self.btn_color_bottom)
        self.row_custom_colors.add_suffix(colors_box)
        pref_group.add(self.row_custom_colors)

        # Scale slider row
        self.row_scale = Adw.ActionRow.new()
        self.row_scale.set_title("Tamaño del Logo (Escala)")
        self.row_scale.set_subtitle("Margen y proporción del emblema dentro del squircle")
        
        self.scale_slider = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0.40, 0.85, 0.05)
        self.scale_slider.set_value(0.65)
        self.scale_slider.set_size_request(160, -1)
        self.scale_slider.set_draw_value(True)
        self.scale_slider.connect("value-changed", self._on_scale_changed)
        self.row_scale.add_suffix(self.scale_slider)
        pref_group.add(self.row_scale)

        # Shadow switch row
        self.row_shadow = Adw.ActionRow.new()
        self.row_shadow.set_title("Sombra Suave del Logo")
        self.row_shadow.set_subtitle("Añade profundidad debajo del logo interior")
        self.switch_shadow = Gtk.Switch.new()
        self.switch_shadow.set_active(True)
        self.switch_shadow.connect("notify::active", self._on_shadow_toggled)
        self.row_shadow.add_suffix(self.switch_shadow)
        pref_group.add(self.row_shadow)

        # Custom Source Image Row
        row_custom_img = Adw.ActionRow.new()
        row_custom_img.set_title("Usar Imagen Externa")
        row_custom_img.set_subtitle("Sustituir el logo por un archivo PNG o SVG personalizado")
        btn_choose_img = Gtk.Button.new_with_label("Seleccionar Archivo...")
        btn_choose_img.connect("clicked", self._on_choose_custom_image)
        row_custom_img.add_suffix(btn_choose_img)
        pref_group.add(row_custom_img)

        # --- Action Buttons ---
        action_card = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 12)
        action_card.set_margin_top(8)

        self.btn_patch = Gtk.Button.new_with_label("✨ Parchar para Launchpad")
        self.btn_patch.add_css_class("patch-button")
        self.btn_patch.set_hexpand(True)
        self.btn_patch.connect("clicked", self._on_patch_clicked)
        action_card.append(self.btn_patch)

        self.btn_revert = Gtk.Button.new_with_label("↩️ Revertir a Original")
        self.btn_revert.connect("clicked", self._on_revert_clicked)
        action_card.append(self.btn_revert)

        studio_box.append(action_card)

    def reload_apps(self):
        """Scans installed apps and updates the list."""
        self.apps = scan_all_apps()
        self._apply_filter()

    def _on_filter_toggled(self, button, filter_key):
        if button.get_active():
            self.active_filter = filter_key
            self._apply_filter()

    def _on_search_changed(self, entry):
        self.search_text = entry.get_text().strip().lower()
        self._apply_filter()

    def _apply_filter(self):
        # Clear listbox
        while True:
            row = self.app_listbox.get_row_at_index(0)
            if row is None:
                break
            self.app_listbox.remove(row)

        self.filtered_apps = []
        for app in self.apps:
            # Search filter
            if self.search_text:
                if self.search_text not in app.name.lower() and self.search_text not in app.id.lower():
                    continue

            # Category / Status filter
            if self.active_filter == "unpatched" and app.is_patched:
                continue
            elif self.active_filter == "patched" and not app.is_patched:
                continue
            elif self.active_filter == "games" and not app.is_game:
                continue
            elif self.active_filter == "pwa" and not app.is_pwa:
                continue

            self.filtered_apps.append(app)
            self._create_app_row(app)

        unpatched_count = sum(1 for a in self.apps if not a in self.apps or not a.is_patched)
        self.lbl_count.set_text(f"Mostrando {len(self.filtered_apps)} de {len(self.apps)} apps ({unpatched_count} sin parchar)")

        if not self.filtered_apps:
            self.right_stack.set_visible_child_name("empty")
        elif self.current_app is None or self.current_app not in self.filtered_apps:
            # Select first row
            row0 = self.app_listbox.get_row_at_index(0)
            if row0:
                self.app_listbox.select_row(row0)

    def _create_app_row(self, app: AppInfo):
        row = Gtk.ListBoxRow.new()
        row.add_css_class("app-row")
        row.app_data = app

        hbox = Gtk.Box.new(Gtk.Orientation.HORIZONTAL, 12)
        
        # Icon
        img = Gtk.Image.new()
        img.set_pixel_size(36)
        if app.icon_path:
            try:
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(app.icon_path, 36, 36, True)
                img.set_from_pixbuf(pb)
            except Exception:
                img.set_from_icon_name("application-x-executable")
        else:
            img.set_from_icon_name(app.icon_name or "application-x-executable")
        hbox.append(img)

        # Labels
        vbox = Gtk.Box.new(Gtk.Orientation.VERTICAL, 2)
        vbox.set_hexpand(True)
        name_lbl = Gtk.Label.new(app.name)
        name_lbl.set_halign(Gtk.Align.START)
        name_lbl.add_css_class("heading")
        name_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        name_lbl.set_max_width_chars(20)

        sub_lbl = Gtk.Label.new(f"{app.category} • {app.id}")
        sub_lbl.set_halign(Gtk.Align.START)
        sub_lbl.add_css_class("dim-label")
        sub_lbl.add_css_class("caption")
        sub_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        sub_lbl.set_max_width_chars(25)

        vbox.append(name_lbl)
        vbox.append(sub_lbl)
        hbox.append(vbox)

        # Badge
        badge = Gtk.Label.new("Squircle" if app.is_patched else "Sin parchar")
        badge.add_css_class("badge-patched" if app.is_patched else "badge-unpatched")
        badge.set_valign(Gtk.Align.CENTER)
        hbox.append(badge)

        row.set_child(hbox)
        self.app_listbox.append(row)

    def _on_app_selected(self, listbox, row):
        if not row or not hasattr(row, "app_data"):
            return
        app = row.app_data
        self.current_app = app
        self.current_source_image = app.icon_path
        self.combo_palette.set_selected(0)  # Auto
        self.current_top_color = "auto"
        self.current_bottom_color = "auto"

        self.lbl_app_name.set_text(app.name)
        self.lbl_app_id.set_text(f"Archivo: {app.id} • Categoría: {app.category}")
        
        if app.is_patched:
            self.lbl_app_status.set_text("✨ Ya tiene Squircle WhiteSur")
            self.lbl_app_status.remove_css_class("badge-unpatched")
            self.lbl_app_status.add_css_class("badge-patched")
            self.btn_revert.set_sensitive(True)
        else:
            self.lbl_app_status.set_text("⚠️ Icono estándar / cuadrado")
            self.lbl_app_status.remove_css_class("badge-patched")
            self.lbl_app_status.add_css_class("badge-unpatched")
            self.btn_revert.set_sensitive(app.id in load_history())

        # Set Original Preview
        if app.icon_path:
            try:
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(app.icon_path, 72, 72, True)
                self.img_original.set_from_pixbuf(pb)
            except Exception:
                self.img_original.set_from_icon_name("application-x-executable")
        else:
            self.img_original.set_from_icon_name(app.icon_name or "application-x-executable")

        self.right_stack.set_visible_child_name("studio")
        self._update_preview()

    def _update_preview(self):
        """Regenerates the SVG in memory and renders it live on the squircle preview tile."""
        if not self.current_app or not self.current_source_image:
            return

        try:
            svg = generate_squircle_svg(
                source_image_path=self.current_source_image,
                mode=self.current_mode,
                top_color=self.current_top_color,
                bottom_color=self.current_bottom_color,
                scale=self.current_scale,
                enable_shadow=self.current_shadow
            )
            self.generated_svg = svg

            # Render live to preview image (92x92)
            pixbuf = render_svg_to_pixbuf(svg, 92)
            if pixbuf:
                self.img_squircle.set_from_pixbuf(pixbuf)
        except Exception as e:
            print(f"Error updating preview: {e}")

    def _on_mode_toggled(self, button, mode):
        if button.get_active():
            self.current_mode = mode
            is_emblem = (mode == "emblem")
            self.row_palette.set_visible(is_emblem)
            self.row_custom_colors.set_visible(is_emblem)
            self.row_scale.set_visible(is_emblem)
            self.row_shadow.set_visible(is_emblem)
            self._update_preview()

    def _on_palette_changed(self, dropdown, param):
        idx = dropdown.get_selected()
        if idx >= 0 and idx < len(PRESET_PALETTES):
            top_col, bot_col, _ = PRESET_PALETTES[idx]
            self.current_top_color = top_col
            self.current_bottom_color = bot_col
            self._update_preview()

    def _on_custom_color_changed(self, button, param):
        rgba_top = self.btn_color_top.get_rgba()
        rgba_bot = self.btn_color_bottom.get_rgba()
        if rgba_top and rgba_bot:
            self.current_top_color = rgb_to_hex(rgba_top.red * 255, rgba_top.green * 255, rgba_top.blue * 255)
            self.current_bottom_color = rgb_to_hex(rgba_bot.red * 255, rgba_bot.green * 255, rgba_bot.blue * 255)
            self._update_preview()

    def _on_scale_changed(self, scale):
        self.current_scale = scale.get_value()
        self._update_preview()

    def _on_shadow_toggled(self, switch, param):
        self.current_shadow = switch.get_active()
        self._update_preview()

    def _on_choose_custom_image(self, button):
        dialog = Gtk.FileDialog.new()
        dialog.set_title("Seleccionar imagen o logo")
        
        filter_img = Gtk.FileFilter.new()
        filter_img.set_name("Imágenes (PNG, SVG, JPG, WebP)")
        filter_img.add_mime_type("image/png")
        filter_img.add_mime_type("image/svg+xml")
        filter_img.add_mime_type("image/jpeg")
        filter_img.add_mime_type("image/webp")
        filters = Gio_filters = Gtk.FilterListModel.new()
        
        dialog.open(self, None, self._on_custom_image_selected)

    def _on_custom_image_selected(self, dialog, result):
        try:
            file = dialog.open_finish(result)
            if file:
                path = file.get_path()
                self.current_source_image = path
                self._update_preview()
                self.show_toast(f"Logo cargado desde: {os.path.basename(path)}")
        except Exception as e:
            print(f"File selection error: {e}")

    def _on_patch_clicked(self, button):
        if not self.current_app or not self.generated_svg:
            return

        ok, msg = patch_app_icon(self.current_app, self.generated_svg)
        if ok:
            self.show_toast(f"¡{self.current_app.name} parchada con éxito para Launchpad!")
            self.current_app.is_patched = True
            self.reload_apps()
        else:
            self.show_toast(f"Error al parchar: {msg}")

    def _on_revert_clicked(self, button):
        if not self.current_app:
            return

        ok, msg = revert_app_icon(self.current_app)
        if ok:
            self.show_toast(f"¡Icono de {self.current_app.name} restaurado al original!")
            self.current_app.is_patched = False
            self.reload_apps()
        else:
            self.show_toast(f"No se pudo revertir: {msg}")

    def _on_batch_patch_clicked(self, button):
        unpatched = [a for a in self.apps if not a.is_patched and a.icon_path]
        if not unpatched:
            self.show_toast("No hay aplicaciones pendientes por parchar.")
            return

        count = 0
        for app in unpatched:
            try:
                svg = generate_squircle_svg(
                    source_image_path=app.icon_path,
                    mode="emblem",
                    top_color="auto",
                    bottom_color="auto",
                    scale=0.65,
                    enable_shadow=True
                )
                ok, _ = patch_app_icon(app, svg)
                if ok:
                    count += 1
            except Exception as e:
                print(f"Error batch patching {app.name}: {e}")

        self.show_toast(f"¡Se han parchado {count} aplicaciones para Launchpad con éxito!")
        self.reload_apps()

    def show_toast(self, message: str):
        toast = Adw.Toast.new(message)
        toast.set_timeout(3)
        self.toast_overlay.add_toast(toast)
