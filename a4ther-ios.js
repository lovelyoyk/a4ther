// ============================================================
//  A4ther Systems v1.0.0 | LS Aluguel
//  iOS Free Fire Anti-Cheat Scanner (Scriptable)
//  Roda em iPhone SEM jailbreak via app Scriptable (gratuito App Store).
//
//  Como usar:
//    1. iPhone: Settings → Privacy & Security → App Privacy Report → ON
//    2. Joga Free Fire por alguns minutos pra popular o log
//    3. Em App Privacy Report, toca "Save App Privacy Report" → salva .ndjson
//    4. Abre o app Scriptable, "Add Script", cola este código (ou importa via URL)
//    5. Roda o script, seleciona o arquivo .ndjson exportado
//    6. Lê o relatório
// ============================================================

const VERSION = "1.0.0";

// ============================================================
//  LISTAS DE DETECÇÃO (sincronizadas com a4ther.sh)
// ============================================================

// Bundle IDs de cheat FF iOS CONFIRMADOS via source code
const CHEAT_BUNDLES_FF = [
    "com.34306.espff",
    "com.dts.freefireth.externalesp",
    "com.quyhoang.fxy",
    "com.phuc.aimlock",
    "com.checkboxcus.hhn",
    "com.hhnios.pubgvngatena",
    "com.dts.freefirethack",
    "com.dts.freefireth2",
    "com.nextor.app",
];

// Bundle IDs de jailbreak / package managers
const CHEAT_BUNDLES_JB = [
    "com.opa334.dopamine",
    "xyz.palera1n.palera1n",
    "com.electrateam.unc0ver",
    "com.tihmstar.checkra1n",
    "org.taurine.jailbreak",
    "org.coolstar.odyssey",
    "org.coolstar.sileo",
    "xyz.willy.Zebra",
    "com.cydia.Cydia",
    "com.opa334.TrollStore",
    "com.opa334.TrollStoreHelper",
    "com.opa334.trolldecrypt",
    "com.opa334.trollfools",
    "com.rileytestut.AltStore",
    "com.altstore.altstoreclassic",
    "com.sideloadly.sideloadly",
    "com.iosgods.iosgods",
    "com.gbox.pubg",
    "live.cclerc.geranium",
    "com.tigisoftware.Filza",
    "com.tigisoftware.FilzaFree",
    "com.ifunbox.ifunbox",
    "app.ish.iSH",
    "com.septudio.SSHClientLite",
    "com.shpion.cleaner",
];

// Certificate-based sideloaders (Esign / Feather / Ksign / Gbox / Scarlet / etc.)
// Esses serviços assinam IPAs com cert de Apple Developer (free ou enterprise) e
// instalam apps modificados sem jailbreak. Apple revoga periodicamente.
const CHEAT_BUNDLES_CERT_SIDELOAD = [
    // Esign
    "com.esign.ios",
    "com.esign.esign",
    "app.esign.esign",
    "com.esignapp.esign",
    "io.esign.esign",
    // Feather (developer khcrysalis)
    "kh.crysalis.feather",
    "xn.crysalis.feather",
    "com.crysalis.feather",
    "io.feather.feather",
    "app.feather.feather",
    // Ksign
    "com.ksign.app",
    "io.ksign.ksign",
    "app.ksign.ksign",
    "com.ksign.ksign",
    "pkr.appwhitelist.ksign",
    // Gbox (installer iOS, diferente do com.gbox.pubg que é cheat)
    "com.gbox.gbox",
    "com.gboxapp.gbox",
    "io.gbox.gbox",
    "app.gbox.io",
    "com.itools.gbox",
    // Scarlet
    "com.usescarlet.scarlet",
    "com.scarletapp.scarlet",
    "com.scarletios.scarlet",
    // Outros sideloaders cert-based
    "com.appdb.appdb",
    "com.tutuapp.tutuapp",
    "com.appcake.appcake",
    "com.appvalley.appvalley",
    "com.buildstore.buildstore",
    "com.appsync.appsync",
    "com.ignition.ignition",
    "com.signtools.signtools",
    "com.relink.relink",
    "io.itrustteam.itrust",
    "io.appdb.appdb",
];

// Bundle IDs de proxy / VPN / sniffer (cheats remotos)
const CHEAT_BUNDLES_PROXY = [
    "com.touchingapp.potatso",
    "com.touchingapp.potatsolite",
    "com.monite.proxyff",
    "com.nssurge.inc.surge-ios",
    "com.luo.quantumultx",
    "group.com.luo.quantumult",
    "com.shadowrocket.Shadowrocket",
    "com.liguangming.Shadowrocket",
    "com.github.shadowsocks",
    "com.netease.trojan",
    "com.hiddify.app",
    "com.karing.app",
    "com.metacubex.ClashX",
    "com.ssrss.Ssrss",
    "com.adguard.ios.AdguardPro",
    "com.cloudflare.1dot1dot1dot1",
    "com.nordvpn.NordVPN",
    "com.expressvpn.ExpressVPN",
    "com.surfshark.vpnclient.ios",
    "com.protonvpn.ios",
    "com.windscribe.vpn",
    "com.getlantern.lantern",
    "com.psiphon3.PsiphonForIOS",
    "com.v2box.ios",
    "com.streisand.Streisand",
];

// Bundle IDs Free Fire LEGÍTIMOS
const FF_OFFICIAL = [
    "com.dts.freefireth",
    "com.dts.freefiremax",
    "com.garena.global.freefire",
    "com.garena.global.ffmax",
    "com.garena.freefire.br",
    "com.garena.freefire.kr",
];

// Domínios de cheat conhecidos
const CHEAT_DOMAINS = [
    "fatalitycheats.xyz",
    "anubisw.online",
    "api.baontq.xyz",
    "purplevioleto.com",
    "ggwhitehawk.com",
    "ggpolarbear.com",
    "ggblueshark.com",
    "ipasign.cc",
    "ipa.aspy.dev",
];

// Domínios de cert-based sideloaders (Esign / Feather / Ksign / Gbox / etc.)
const CERT_SIDELOAD_DOMAINS = [
    // Esign
    "esign.yyyue.xyz",
    "esign.kichik.com",
    "esign.app",
    "api.esign.app",
    // Feather
    "feathertweak.com",
    "feather.appsmash.com",
    "khcrysalis.com",
    "feather.app",
    // Ksign
    "ksign.app",
    "ksign.click",
    "api.ksign.app",
    // Gbox
    "gbox.global",
    "gboxapp.io",
    "api.gbox.io",
    // Scarlet
    "scarlet.usescarlet.com",
    "api.scarletapp.com",
    // Outros
    "appdb.to",
    "appdb.win",
    "tutuapp.com",
    "panda.tools",
    "ignition.fun",
    "appvalley.vip",
    "buildstore.us",
    "itrustteam.com",
    "iosgods.com",
];

// TLDs suspeitos (free hosting usado por cheat panels)
const TLD_SUSPECT = [
    ".netlify.app", ".workers.dev", ".vercel.app",
    ".xyz", ".pw", ".top", ".click", ".icu",
    ".gq", ".cf", ".ml", ".ga", ".tk",
    ".monster", ".fun", ".rest", ".bar", ".lol",
];

// Keywords em bundle/domain (heurística)
const SUSPECT_KEYWORDS = [
    "cheat", "hack", "aimbot", "wallhack", "esp",
    "modmenu", "injector", "tweak", "substrate", "frida",
    "filza", "esign", "feather", "ksign", "gbox", "scarlet",
    "dopamine", "sileo", "trollstore", "trolldecrypt", "spoofer",
    "cleaner", "unc0ver", "checkra1n", "jailbreak", "cydia",
    "zebra", "altstore", "iosgods", "geranium", "potatso",
    "shadowrocket", "surge", "quantumult", "hiddify", "shadowsocks",
    "trojan", "karing", "proxyff", "bypass", "inject", "libhooker",
    "sideload", "appdb", "tutuapp", "appvalley", "ignition",
];

// ============================================================
//  DETECÇÃO
// ============================================================

let alerts = [];
let warnings = [];
let okItems = [];

function alert(msg) { alerts.push(msg); }
function warn(msg) { warnings.push(msg); }
function ok(msg) { okItems.push(msg); }

// ============================================================
//  CARREGAR APP PRIVACY REPORT (.ndjson)
// ============================================================

async function loadReport() {
    // Pede pro usuário escolher o arquivo .ndjson
    const fm = FileManager.iCloud();
    const dp = DocumentPicker;
    let path;
    try {
        path = await dp.openFile();
    } catch (e) {
        // Fallback: tenta picker padrão
        path = await dp.open(["public.data", "public.text", "public.json"]);
    }
    if (!path) {
        throw new Error("Nenhum arquivo selecionado");
    }
    const fileFM = path.startsWith("/private/") ? FileManager.local() : fm;
    const raw = fileFM.readString(path);
    if (!raw) throw new Error("Arquivo vazio ou ilegível: " + path);
    return { raw, path };
}

function parseNDJSON(raw) {
    const lines = raw.split("\n").filter(l => l.trim().length > 0);
    const events = [];
    for (const line of lines) {
        try {
            const e = JSON.parse(line);
            events.push(e);
        } catch (err) {
            // ignora linhas malformadas
        }
    }
    return events;
}

// ============================================================
//  ANÁLISE
// ============================================================

function analyze(events) {
    const bundlesSeen = new Set();
    const domainsSeen = new Set();
    const networkByBundle = {};

    for (const ev of events) {
        // network activity
        if (ev.type === "networkActivity" || ev.networkActivity) {
            const bundle = ev.bundleID || ev.bundle || (ev.networkActivity && ev.networkActivity.bundleID);
            const domain = ev.domain || ev.domainName || (ev.networkActivity && ev.networkActivity.domain);
            if (bundle) bundlesSeen.add(bundle);
            if (domain) {
                domainsSeen.add(domain);
                if (bundle) {
                    if (!networkByBundle[bundle]) networkByBundle[bundle] = new Set();
                    networkByBundle[bundle].add(domain);
                }
            }
        }
        // access activity (mic, camera, location, etc.)
        if (ev.accessor || ev.access) {
            const bundle = ev.accessor || (ev.access && ev.access.identifier);
            if (bundle) bundlesSeen.add(bundle);
        }
        // generic bundleID field
        if (ev.bundleID) bundlesSeen.add(ev.bundleID);
        if (ev.bundle) bundlesSeen.add(ev.bundle);
    }

    return { bundlesSeen, domainsSeen, networkByBundle };
}

function detect(analysis) {
    const { bundlesSeen, domainsSeen, networkByBundle } = analysis;

    // 1) Bundles de cheat FF
    for (const b of CHEAT_BUNDLES_FF) {
        if (bundlesSeen.has(b)) {
            alert(`Bundle de CHEAT FF detectado: ${b}`);
        }
    }

    // 2) Jailbreak / sideloader bundles
    for (const b of CHEAT_BUNDLES_JB) {
        if (bundlesSeen.has(b)) {
            alert(`Jailbreak / sideloader: ${b}`);
        }
    }

    // 3) Proxy / VPN bundles
    for (const b of CHEAT_BUNDLES_PROXY) {
        if (bundlesSeen.has(b)) {
            alert(`Proxy / VPN bundle ativo: ${b}`);
        }
    }

    // 3b) Cert-based sideloaders (Esign / Feather / Ksign / Gbox / Scarlet)
    for (const b of CHEAT_BUNDLES_CERT_SIDELOAD) {
        if (bundlesSeen.has(b)) {
            alert(`Cert sideloader (assina IPA modded): ${b}`);
        }
    }

    // 3c) Domínios de sideload services (apps re-assinam via esses servers)
    for (const d of CERT_SIDELOAD_DOMAINS) {
        for (const seen of domainsSeen) {
            if (seen.toLowerCase().includes(d.toLowerCase())) {
                alert(`Domínio de sideload service: ${seen}`);
            }
        }
    }

    // 4) Heurística por nome do bundle
    for (const b of bundlesSeen) {
        // ignora bundles oficiais Apple/Free Fire/grandes
        if (b.startsWith("com.apple.") || b.startsWith("com.garena.") ||
            b.startsWith("com.google.") || b.startsWith("com.facebook.") ||
            b.startsWith("com.whatsapp") || b.startsWith("com.instagram.")) continue;
        for (const kw of SUSPECT_KEYWORDS) {
            if (b.toLowerCase().includes(kw)) {
                alert(`Bundle suspeito por padrão de nome [${kw}]: ${b}`);
                break;
            }
        }
    }

    // 5) FF oficial: presente?
    let ffFound = false;
    for (const b of FF_OFFICIAL) {
        if (bundlesSeen.has(b)) {
            ok(`Free Fire oficial detectado: ${b}`);
            ffFound = true;
        }
    }
    if (!ffFound) {
        warn("Free Fire OFICIAL não apareceu no App Privacy Report — pode não ter jogado durante o período do log");
    }

    // 6) Bundles com "freefire" no nome mas NÃO oficial
    for (const b of bundlesSeen) {
        if (b.toLowerCase().includes("freefire") && !FF_OFFICIAL.includes(b)) {
            alert(`Bundle FF NÃO oficial: ${b}`);
        }
    }

    // 7) Domínios de cheat
    for (const d of CHEAT_DOMAINS) {
        for (const seen of domainsSeen) {
            if (seen.toLowerCase().includes(d.toLowerCase())) {
                alert(`Domínio de CHEAT acessado: ${seen}`);
            }
        }
    }

    // 8) TLDs suspeitos (com filtro pra não dar falso positivo em domínios curtos)
    for (const seen of domainsSeen) {
        for (const tld of TLD_SUSPECT) {
            if (seen.toLowerCase().endsWith(tld)) {
                // ignora se for relacionado a app oficial conhecido
                const bundle = Object.entries(networkByBundle).find(([b, doms]) =>
                    doms.has(seen) && (b.startsWith("com.apple.") || b.startsWith("com.google."))
                );
                if (!bundle) {
                    warn(`Domínio com TLD suspeito [${tld}]: ${seen}`);
                }
            }
        }
    }

    // 9) FF conectando em domínios estranhos (não-Garena)
    for (const ffBundle of FF_OFFICIAL) {
        const doms = networkByBundle[ffBundle];
        if (!doms) continue;
        for (const d of doms) {
            // domínios Garena/Akamai/CDN oficiais OK
            if (d.includes("garena") || d.includes("dts.com") ||
                d.includes("akamai") || d.includes("cloudfront") ||
                d.includes("apple.com") || d.includes("googleapis") ||
                d.includes("crashlytics") || d.includes("appsflyer") ||
                d.includes("facebook") || d.includes("fbcdn")) {
                continue;
            }
            // outros domínios = revisar
            warn(`Free Fire conectou em domínio não-padrão: ${d}`);
        }
    }
}

// ============================================================
//  UI
// ============================================================

function buildResultTable() {
    const t = new UITable();
    t.showSeparators = true;

    // Banner / Header
    const hdr = new UITableRow();
    hdr.height = 80;
    hdr.isHeader = true;
    const c = hdr.addText("A4THER SYSTEMS", `v${VERSION} ▪ LS Aluguel ▪ FF iOS Scanner`);
    c.titleFont = Font.boldSystemFont(22);
    c.titleColor = Color.cyan();
    c.subtitleFont = Font.systemFont(12);
    c.subtitleColor = Color.gray();
    t.addRow(hdr);

    // Verdict row
    const verdictRow = new UITableRow();
    verdictRow.height = 70;
    let verdictText, verdictColor;
    if (alerts.length > 0) {
        verdictText = `✗  SUSPEITO  —  ${alerts.length} alertas`;
        verdictColor = Color.red();
    } else if (warnings.length > 0) {
        verdictText = `⚠  REVISAR  —  ${warnings.length} avisos`;
        verdictColor = Color.orange();
    } else {
        verdictText = `✓  LIMPO  —  device aprovado`;
        verdictColor = Color.green();
    }
    const vc = verdictRow.addText(verdictText, `Alertas: ${alerts.length}  •  Avisos: ${warnings.length}  •  OKs: ${okItems.length}`);
    vc.titleFont = Font.boldSystemFont(20);
    vc.titleColor = verdictColor;
    vc.subtitleFont = Font.systemFont(12);
    t.addRow(verdictRow);

    // Section: ALERTAS
    if (alerts.length > 0) {
        const sh = new UITableRow();
        const shc = sh.addText("◆  ALERTAS", `${alerts.length} item${alerts.length !== 1 ? "s" : ""}`);
        shc.titleFont = Font.boldSystemFont(16);
        shc.titleColor = Color.red();
        t.addRow(sh);
        for (const a of alerts) {
            const r = new UITableRow();
            r.height = 50;
            const x = r.addText("●  " + a);
            x.titleFont = Font.systemFont(13);
            x.titleColor = Color.red();
            t.addRow(r);
        }
    }

    // Section: AVISOS
    if (warnings.length > 0) {
        const sh = new UITableRow();
        const shc = sh.addText("◆  AVISOS", `${warnings.length} item${warnings.length !== 1 ? "s" : ""}`);
        shc.titleFont = Font.boldSystemFont(16);
        shc.titleColor = Color.orange();
        t.addRow(sh);
        for (const w of warnings) {
            const r = new UITableRow();
            r.height = 50;
            const x = r.addText("●  " + w);
            x.titleFont = Font.systemFont(13);
            x.titleColor = Color.orange();
            t.addRow(r);
        }
    }

    // Section: OKs
    if (okItems.length > 0) {
        const sh = new UITableRow();
        const shc = sh.addText("◆  OK", `${okItems.length} item${okItems.length !== 1 ? "s" : ""}`);
        shc.titleFont = Font.boldSystemFont(16);
        shc.titleColor = Color.green();
        t.addRow(sh);
        for (const o of okItems) {
            const r = new UITableRow();
            r.height = 45;
            const x = r.addText("●  " + o);
            x.titleFont = Font.systemFont(13);
            x.titleColor = Color.green();
            t.addRow(r);
        }
    }

    return t;
}

function buildTextReport() {
    const lines = [];
    lines.push("=========================================");
    lines.push(`  A4ther Systems v${VERSION} | LS Aluguel`);
    lines.push("  Free Fire iOS Anti-Cheat Scanner");
    lines.push(`  Data: ${new Date().toISOString()}`);
    lines.push("=========================================");
    lines.push("");
    if (alerts.length > 0) {
        lines.push(`*** SUSPEITO - ${alerts.length} alertas ***`);
    } else if (warnings.length > 0) {
        lines.push(`*** REVISAR - ${warnings.length} avisos ***`);
    } else {
        lines.push(`*** LIMPO - device aprovado ***`);
    }
    lines.push("");
    lines.push(`Alertas: ${alerts.length}`);
    lines.push(`Avisos:  ${warnings.length}`);
    lines.push(`OKs:     ${okItems.length}`);
    lines.push("");
    if (alerts.length > 0) {
        lines.push("--- ALERTAS ---");
        for (const a of alerts) lines.push("  [!] " + a);
        lines.push("");
    }
    if (warnings.length > 0) {
        lines.push("--- AVISOS ---");
        for (const w of warnings) lines.push("  [?] " + w);
        lines.push("");
    }
    if (okItems.length > 0) {
        lines.push("--- OKs ---");
        for (const o of okItems) lines.push("  [+] " + o);
    }
    return lines.join("\n");
}

// ============================================================
//  MAIN
// ============================================================

async function main() {
    // Boas vindas
    const welcome = new Alert();
    welcome.title = "A4ther Systems v" + VERSION;
    welcome.message = "Free Fire iOS Anti-Cheat Scanner\nLS Aluguel\n\nVai abrir o picker pra você selecionar o arquivo .ndjson exportado do App Privacy Report.\n\nSe você ainda não tem:\n1. Settings → Privacy → App Privacy Report → ON\n2. Joga FF por alguns minutos\n3. Em App Privacy Report, toca em Save Report";
    welcome.addAction("Continuar");
    welcome.addCancelAction("Cancelar");
    const idx = await welcome.present();
    if (idx === -1) return;

    let report;
    try {
        report = await loadReport();
    } catch (e) {
        const err = new Alert();
        err.title = "Erro";
        err.message = String(e);
        err.addAction("OK");
        await err.present();
        return;
    }

    const events = parseNDJSON(report.raw);

    if (events.length === 0) {
        const err = new Alert();
        err.title = "Arquivo vazio";
        err.message = "Nenhum evento parseado de " + report.path + "\n\nVerifique se é um App Privacy Report válido (.ndjson).";
        err.addAction("OK");
        await err.present();
        return;
    }

    const analysis = analyze(events);
    detect(analysis);

    ok(`${events.length} eventos analisados`);
    ok(`${analysis.bundlesSeen.size} bundles únicos`);
    ok(`${analysis.domainsSeen.size} domínios únicos`);

    // Mostrar table na UI
    const table = buildResultTable();
    await table.present(true);

    // Salvar relatório em texto?
    const saveAlert = new Alert();
    saveAlert.title = "Salvar relatório?";
    saveAlert.message = "Quer salvar o relatório em texto na pasta Scriptable?";
    saveAlert.addAction("Sim, salvar");
    saveAlert.addCancelAction("Não");
    const saveIdx = await saveAlert.present();
    if (saveIdx === 0) {
        const fm = FileManager.iCloud();
        const ts = new Date().toISOString().replace(/[:\.]/g, "-").substring(0, 19);
        const fn = `a4ther_scan_${ts}.txt`;
        const dir = fm.documentsDirectory();
        const path = fm.joinPath(dir, fn);
        fm.writeString(path, buildTextReport());
        const done = new Alert();
        done.title = "Salvo";
        done.message = "Relatório salvo em:\n" + path;
        done.addAction("OK");
        await done.present();
    }
}

await main();
Script.complete();
