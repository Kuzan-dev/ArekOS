// Esquina activa «Minimizar todo». A diferencia de «Escritorio» de KWin (que aparta las ventanas y las
// devuelve todas en cuanto se activa cualquiera), minimiza de verdad: al abrir una app desde el Dock solo
// vuelve esa. Si se vuelve a la esquina sin que quede ninguna ventana a la vista, se restauran las que
// minimizó. Las esquinas salen de [Script-vitrumminimizar] Esquinas en kwinrc (índices de KWin: 1 arriba-dcha,
// 3 abajo-dcha, 5 abajo-izda, 7 arriba-izda), que escribe Ajustes → Esquinas activas.

let ocultas = [];
let activa = null;    // la que estaba activa al minimizar: vuelve a tener el foco al restaurar
let esquinas = [];

function visibles() {
    return workspace.windowList().filter(w =>
        w.normalWindow && !w.skipTaskbar && w.minimizable && !w.minimized &&
        (w.onAllDesktops || w.desktops.indexOf(workspace.currentDesktop) >= 0));
}

function alternar() {
    const v = visibles();
    if (v.length > 0) {
        ocultas = v;
        activa = workspace.activeWindow;
        v.forEach(w => w.minimized = true);
    } else {
        ocultas.forEach(w => { if (w.minimized) w.minimized = false; });
        if (activa && ocultas.indexOf(activa) >= 0) workspace.activeWindow = activa;
        ocultas = [];
        activa = null;
    }
    return true;
}

function cargar() {
    esquinas.forEach(e => unregisterScreenEdge(e));
    esquinas = String(readConfig("Esquinas", "")).split(",").filter(x => x.trim() !== "").map(Number)
        .filter(e => e === 1 || e === 3 || e === 5 || e === 7);
    esquinas.forEach(e => registerScreenEdge(e, alternar));
}

workspace.windowRemoved.connect(w => {
    ocultas = ocultas.filter(o => o !== w);
    if (activa === w) activa = null;
});
options.configChanged.connect(cargar);
// también como atajo (sin tecla por defecto: se asigna en Preferencias → Atajos → KWin)
registerShortcut("VitrumMinimizarTodo", "Vitrum: minimizar todo", "", alternar);
cargar();
