// ============================================================
//  A4ther Systems v2.0.0 | LS Aluguel
//  iOS Free Fire Anti-Cheat Scanner (Scriptable)
//  Roda em iPhone SEM jailbreak via app Scriptable (gratuito App Store).
//
//  Data sources mescladas:
//   - kellerzz/KellerSS-iOS (2779 linhas, ~50 bundles)
//   - ynwkxshii/PantherSS-IOS (2702 linhas, +5 modules extras)
//   - VLIZVIP/-loz-IOZ-ANTI-CHEAT (idêntico ao Keller)
//   - 34 cert sideloaders (Esign, Feather, Ksign, Gbox, Scarlet)
//   - 9 FF iOS cheats confirmados (espff, externalesp, aimlock, etc.)
//
//  Como usar:
//    1. Settings → Privacy & Security → App Privacy Report → ON
//    2. Joga FF por alguns minutos pra popular o log
//    3. Em App Privacy Report, "Save App Privacy Report" → salva .ndjson
//    4. Abre o Scriptable, importa este script (URL):
//       scriptable:///add?url=https://raw.githubusercontent.com/lovelyoyk/a4ther/main/a4ther-ios.js
//    5. Roda, seleciona o arquivo .ndjson
//    6. Vê o resultado
// ============================================================

const VERSION = "2.0.0";

// ============================================================
//  DATA — bundles, domínios, IPs, TLDs, ASNs (109+ entries)
// ============================================================

// CHEAT_APPS — bundle ID → descrição (categorizado)
const CHEAT_APPS = {
    // === FF cheats específicos iOS (Substrate tweaks + IPAs modded) ===
    "com.34306.espff":                        "ESP Free Fire — tweak iOS (filtra com.dts.freefireth)",
    "com.dts.freefireth.externalesp":         "External ESP Free Fire — tweak iOS",
    "com.quyhoang.fxy":                       "Elite Luxury / Nextor mod menu — FF/FFMax",
    "com.phuc.aimlock":                       "Aim Lock tweak — FF (aim speed boost)",
    "com.checkboxcus.hhn":                    "Checkbox Custom HHN — FF mod menu",
    "com.hhnios.pubgvngatena":                "iGG by HHNiOS — FF/PUBG menu mixto",
    "com.dts.freefirethack":                  "Free Fire IPA re-pack (bundle modificado)",
    "com.dts.freefireth2":                    "Free Fire IPA re-sign variant",
    "com.nextor.app":                         "Nextor menu carrier app",

    // === Proxy / VPN / MITM (KellerSS + Panther) ===
    "com.touchingapp.potatsolite":            "PotatsoLite — proxy iOS (mitmproxy cheat)",
    "com.touchingapp.potatso":                "Potatso — proxy iOS",
    "com.monite.proxyff":                     "ProxyFF — proxy iOS (cheat confirmado)",
    "com.nssurge.inc.surge-ios":              "Surge — proxy/MITM iOS",
    "com.luo.quantumultx":                    "Quantumult X — proxy iOS",
    "group.com.luo.quantumult":               "Quantumult — proxy iOS",
    "com.shadowrocket.Shadowrocket":          "Shadowrocket — proxy iOS",
    "com.liguangming.Shadowrocket":           "Shadowrocket (alt) — proxy iOS",
    "com.github.shadowsocks":                 "Shadowsocks",
    "com.netease.trojan":                     "Trojan proxy",
    "com.hiddify.app":                        "Hiddify — proxy",
    "com.karing.app":                         "Karing — proxy",
    "com.metacubex.ClashX":                   "ClashX — proxy",
    "com.ssrss.Ssrss":                        "SSR iOS proxy",
    "com.adguard.ios.AdguardPro":             "AdGuard Pro (proxy MITM)",
    "com.privateinternetaccess.ios":          "PIA VPN",
    "com.anonymousiphone.detoxme":            "Detox — proxy iOS",
    "com.futureland.vpnmaster":               "VPN Master",
    "com.cloudflare.1dot1dot1dot1":           "Cloudflare 1.1.1.1 (WARP proxy)",
    "com.Nord.VPN":                           "NordVPN",
    "com.expressvpn.ExpressVPN":              "ExpressVPN",
    "com.protonvpn.ios":                      "ProtonVPN",
    "com.surfshark.vpnclient.ios":            "Surfshark VPN",
    "com.windscribe.vpn":                     "Windscribe VPN",
    "com.celeritasdesign.GoodVPN":            "GoodVPN",
    "com.getlantern.lantern":                 "Lantern VPN/proxy",
    "com.psiphon3.PsiphonForIOS":             "Psiphon proxy",
    "com.v2box.ios":                          "V2Box (V2Ray client)",
    "com.streisand.Streisand":                "Streisand proxy",
    "com.limeVPN.LimeVPN":                    "LimeVPN",
    "com.openVPN.OpenVPN-Connect":            "OpenVPN Connect",
    "io.nextdns.NextDNS":                     "NextDNS (DNS filter — pode mascarar)",

    // === Jailbreak / package managers ===
    "com.opa334.dopamine":                    "Dopamine — Jailbreak iOS 15-16",
    "xyz.palera1n.palera1n":                  "palera1n — Jailbreak rootless",
    "com.electrateam.unc0ver":                "unc0ver — Jailbreak iOS 14",
    "com.tihmstar.checkra1n":                 "checkra1n — Jailbreak hardware A11-",
    "org.taurine.jailbreak":                  "Taurine — Jailbreak",
    "org.coolstar.odyssey":                   "Odyssey — Jailbreak",
    "org.coolstar.sileo":                     "Sileo — package manager JB",
    "xyz.willy.Zebra":                        "Zebra — package manager JB",
    "com.cydia.Cydia":                        "Cydia — package manager JB",

    // === Sideload sem JB (TrollStore family + AltStore) ===
    "com.opa334.TrollStore":                  "TrollStore — sideload sem JB",
    "com.opa334.TrollStoreHelper":            "TrollStoreHelper",
    "com.opa334.trolldecrypt":                "TrollDecrypt — decifrar IPAs",
    "com.opa334.trollfools":                  "TrollFools — injetor de tweaks",
    "com.rileytestut.AltStore":               "AltStore — sideload via dev cert",
    "com.altstore.altstoreclassic":           "AltStore Classic",
    "com.sideloadly.sideloadly":              "Sideloadly — sideload",

    // === Cert-based sideloaders (Esign / Feather / Ksign / Gbox / Scarlet) ===
    "com.esign.ios":                          "ESign — sideload/IPA installer",
    "com.esign.esign":                        "ESign (alt)",
    "app.esign.esign":                        "ESign (app prefix)",
    "com.esignapp.esign":                     "ESign (alt 2)",
    "io.esign.esign":                         "ESign (io prefix)",
    "kh.crysalis.feather":                    "Feather — sideloader khcrysalis",
    "xn.crysalis.feather":                    "Feather (alt)",
    "com.crysalis.feather":                   "Feather (com)",
    "io.feather.feather":                     "Feather (io)",
    "app.feather.feather":                    "Feather (app)",
    "com.ksign.app":                          "Ksign — sideloader cert-based",
    "io.ksign.ksign":                         "Ksign (io)",
    "app.ksign.ksign":                        "Ksign (app)",
    "com.ksign.ksign":                        "Ksign (com)",
    "pkr.appwhitelist.ksign":                 "Ksign (whitelist variant)",
    "com.gbox.gbox":                          "GBox — sideloader iOS",
    "com.gboxapp.gbox":                       "GBox (alt)",
    "io.gbox.gbox":                           "GBox (io)",
    "app.gbox.io":                            "GBox (io 2)",
    "com.itools.gbox":                        "GBox (itools)",
    "com.usescarlet.scarlet":                 "Scarlet — sideloader",
    "com.scarletapp.scarlet":                 "Scarlet (alt)",
    "com.scarletios.scarlet":                 "Scarlet (ios)",
    "com.appdb.appdb":                        "AppDB — sideload store",
    "io.appdb.appdb":                         "AppDB (io)",
    "com.tutuapp.tutuapp":                    "TutuApp",
    "com.appcake.appcake":                    "AppCake",
    "com.appvalley.appvalley":                "AppValley",
    "com.buildstore.buildstore":              "BuildStore",
    "com.ignition.ignition":                  "Ignition",
    "com.signtools.signtools":                "SignTools",
    "io.itrustteam.itrust":                   "iTrust",

    // === Cheat stores / IPA marketplaces ===
    "com.iosgods.iosgods":                    "iOSGods — cheat app store",
    "com.gbox.pubg":                          "GBox PUBG/FF cheat mod",

    // === File managers / shells (acesso root) ===
    "com.tigisoftware.Filza":                 "Filza — file manager root",
    "com.tigisoftware.FilzaFree":             "Filza Free",
    "com.ifunbox.ifunbox":                    "iFunBox — gerenciador iOS",
    "app.ish.iSH":                            "iSH — shell Linux x86 emulado",
    "com.septudio.SSHClientLite":             "SSH Client Lite — shell remoto",

    // === Tweak managers / utilities ===
    "live.cclerc.geranium":                   "Geranium — tweak manager JB",

    // === Developer / dev profile (suspeito em contexto de jogo) ===
    "com.apple.dt.Xcode":                     "Xcode — IDE Apple",
    "com.apple.Preferences.Developer":        "Preferências de Desenvolvedor",
    "com.apple.developer":                    "Perfil Apple Developer",
    "com.apple.TestFlight":                   "TestFlight (testing IPAs)",
    "developer.apple.wwdc-Release":           "WWDC build (dev cert)",

    // === Anti-detect / cleanup ===
    "com.shpion.cleaner":                     "Spion Cleaner — limpeza de rastros",
    "com.limneos.adprivacy":                  "AdPrivacy — manipulação rede",
    "com.jjcm.nomoread":                      "NoMoreAd — bloqueio rede",
};

// CHEAT_SEVERITY — severidade por bundle (criticality)
const CHEAT_SEVERITY = {
    "com.34306.espff":                        "CRITICAL",
    "com.dts.freefireth.externalesp":         "CRITICAL",
    "com.quyhoang.fxy":                       "CRITICAL",
    "com.phuc.aimlock":                       "CRITICAL",
    "com.checkboxcus.hhn":                    "CRITICAL",
    "com.hhnios.pubgvngatena":                "CRITICAL",
    "com.dts.freefirethack":                  "CRITICAL",
    "com.dts.freefireth2":                    "CRITICAL",
    "com.opa334.dopamine":                    "CRITICAL",
    "xyz.palera1n.palera1n":                  "CRITICAL",
    "com.opa334.TrollStore":                  "CRITICAL",
    "com.opa334.TrollStoreHelper":            "CRITICAL",
    "com.opa334.trolldecrypt":                "CRITICAL",
    "com.opa334.trollfools":                  "CRITICAL",
    "com.iosgods.iosgods":                    "CRITICAL",
    "com.gbox.pubg":                          "CRITICAL",
    "com.tigisoftware.Filza":                 "CRITICAL",
    "com.tigisoftware.FilzaFree":             "CRITICAL",
    "com.monite.proxyff":                     "CRITICAL",
    "com.touchingapp.potatso":                "HIGH",
    "com.touchingapp.potatsolite":            "HIGH",
    "com.shadowrocket.Shadowrocket":          "HIGH",
    "com.liguangming.Shadowrocket":           "HIGH",
    "com.esign.ios":                          "HIGH",
    "com.esign.esign":                        "HIGH",
    "kh.crysalis.feather":                    "HIGH",
    "com.ksign.app":                          "HIGH",
    "com.gbox.gbox":                          "HIGH",
    "com.usescarlet.scarlet":                 "HIGH",
    "com.rileytestut.AltStore":               "HIGH",
    "com.altstore.altstoreclassic":           "HIGH",
    "com.sideloadly.sideloadly":              "HIGH",
};

// FF_OFFICIAL — bundles oficiais Free Fire (qualquer outro com "freefire" = mod)
const FF_OFFICIAL = new Set([
    "com.dts.freefireth",
    "com.dts.freefiremax",
    "com.garena.global.freefire",
    "com.garena.global.ffmax",
    "com.garena.freefire.br",
    "com.garena.freefire.kr",
]);

// FF_PROXY_LOGIN_DOMAINS — domínios LOGIN do FF (cheat se acessados por bundle != FF)
const FF_PROXY_LOGIN_DOMAINS = new Set([
    "version.ffmax.purplevioleto.com",
    "version.ggwhitehawk.com",
    "loginbp.ggpolarbear.com",
    "gin.freefiremobile.com",
    "100067.connect.garena.com",
    "100067.msdk.garena.com",
    "client.us.freefiremobile.com",
    "client.sea.freefiremobile.com",
    "sacnetwork.ggblueshark.com",
    "sacevent.ggblueshark.com",
]);

// KNOWN_CHEAT_INFRA — IPs + domínios confirmados de cheat servers
const KNOWN_CHEAT_INFRA = {
    "46.202.145.85":                          "Fatality Cheats — servidor",
    "fatalitycheats.xyz":                     "Fatality Cheats — domínio",
    "anubisw.online":                         "Anubis cheat server — Free Fire",
    "api.baontq.xyz":                         "Baontq cheat API — Free Fire",
    "version.ffmax.purplevioleto.com":        "Purple Violeto — FF MAX modded",
    "version.ggwhitehawk.com":                "White Hawk cheat",
    "loginbp.ggpolarbear.com":                "Polar Bear cheat",
    "ggwhitehawk.com":                        "White Hawk parent domain",
    "ggpolarbear.com":                        "Polar Bear parent domain",
    "ggblueshark.com":                        "Blue Shark parent domain",
    "ipasign.cc":                             "IPA Sign service",
    "ipa.aspy.dev":                           "IPA hosting (TrollStore)",
};

// FALSE_POSITIVE_IPS — IPs Garena legítimos (não confundir com cheat)
const FALSE_POSITIVE_IPS = new Set([
    "104.29.135.227", "104.29.137.112", "104.29.137.125", "104.29.137.146",
    "104.29.137.16",  "104.29.137.203", "104.29.137.53",  "104.29.152.107",
    "104.29.152.157", "104.29.152.164", "104.29.152.189", "104.29.152.27",
    "104.29.152.79",  "104.29.152.95",  "104.29.153.53",  "104.29.154.91",
    "104.29.155.129", "104.29.155.27",  "104.29.155.56",  "104.29.156.120",
    "104.29.156.174", "104.29.156.24",  "104.29.157.107", "104.29.157.123",
    "104.29.158.139", "104.29.158.97",  "104.29.159.185",
    "23.192.36.217",  "23.221.214.168", "54.69.69.125",   "92.223.118.254",
    "1.1.1.1",
]);

// TELEMETRY_DOMAINS — analytics/crash reporting (HIGH se app não-AppStore usa)
const TELEMETRY_DOMAINS = [
    "sentry.io", "ingest.sentry.io",
    "appsflyer.com", "t.appsflyer.com", "api2.appsflyer.com",
    "amplitude.com", "api.amplitude.com",
    "mixpanel.com", "api.mixpanel.com",
    "segment.io", "api.segment.io",
    "firebase.io", "firebaseio.com",
    "bugsnag.com", "notify.bugsnag.com",
    "crashlytics.com",
    "adjust.com", "app.adjust.com",
    "branch.io", "api2.branch.io",
];

// SIDELOAD_DOMAINS — domínios usados por sideloaders / IPA stores
const SIDELOAD_DOMAINS = [
    // Genéricos
    "ppsspp.org", "altstore.io", "api.altstore.io", "sideloadly.io",
    "ipa.store", "signulous.com", "udid.io", "diawi.com",
    "testflight.apple.com",
    // Cert sideload services
    "esign.yyyue.xyz", "esign.kichik.com", "esign.app", "api.esign.app",
    "feathertweak.com", "feather.appsmash.com", "khcrysalis.com", "feather.app",
    "ksign.app", "ksign.click", "api.ksign.app",
    "gbox.global", "gboxapp.io", "api.gbox.io",
    "scarlet.usescarlet.com", "api.scarletapp.com",
    "appdb.to", "appdb.win", "tutuapp.com", "panda.tools",
    "ignition.fun", "appvalley.vip", "buildstore.us", "itrustteam.com",
    "iosgods.com",
];

// APP_STORE_OFFICIAL — domínios oficiais Apple (App Store legítimo)
const APP_STORE_OFFICIAL = new Set([
    "apple.com", "icloud.com", "mzstatic.com", "phobos.apple.com",
    "apps.apple.com", "itunes.apple.com",
]);

// SCRIPT_URL_PATTERNS — domínios que servem código executável (Scriptable abuse)
const SCRIPT_URL_PATTERNS = [
    { regex: /raw\.githubusercontent\.com/i,    label: "GitHub Raw" },
    { regex: /gist\.github(usercontent)?\.com/i, label: "GitHub Gist" },
    { regex: /pastebin\.com/i,                  label: "Pastebin" },
    { regex: /pastecode\.io/i,                  label: "PasteCode" },
    { regex: /hastebin\.com/i,                  label: "Hastebin" },
    { regex: /cdn\.jsdelivr\.net/i,             label: "jsDelivr CDN" },
    { regex: /unpkg\.com/i,                     label: "UNPKG CDN" },
    { regex: /cdnjs\.cloudflare\.com/i,         label: "CDNJS/Cloudflare" },
    { regex: /rawgit\.com/i,                    label: "RawGit deprecated" },
    { regex: /script\.google\.com/i,            label: "Google Apps Script" },
    { regex: /glitch\.me/i,                     label: "Glitch.me hosting" },
    { regex: /replit\.com/i,                    label: "Replit" },
    { regex: /\.workers\.dev/i,                 label: "Cloudflare Workers" },
    { regex: /\.vercel\.app/i,                  label: "Vercel" },
    { regex: /\.netlify\.app/i,                 label: "Netlify" },
];

// SUSPICIOUS_TLDS — free hosting comum em cheat panels
const SUSPICIOUS_TLDS = [
    ".site", ".store", ".netlify.app", ".netlify", ".xyz", ".pw",
    ".top", ".click", ".bid", ".win", ".stream", ".download",
    ".icu", ".gq", ".cf", ".ml", ".ga", ".tk",
    ".monster", ".fun", ".rest", ".bar", ".lol",
];

// VPS_HOSTING_KEYWORDS — substrings em rDNS de hosts de cheat
const VPS_HOSTING_KEYWORDS = [
    "vps.", ".vps", "server", "hosting", "cloud", "node",
    ".vultr.com", ".linode.com", ".hetzner.com", ".contabo.net",
    ".digitalocean.com", ".umbler.net", ".kinghost.net",
];

// CHEAT_PROXY_ASN — Autonomous Systems comuns em cheat proxy
const CHEAT_PROXY_ASN = {
    "AS35916":  "Multacom Corporation (LA)",
    "AS47583":  "Hostinger International (BR)",
    "AS60781":  "LeaseWeb",
    "AS28753":  "LeaseWeb (alt)",
    "AS395954": "LeaseWeb (alt 2)",
    "AS16276":  "OVH",
    "AS14061":  "DigitalOcean",
    "AS20473":  "Vultr/Choopa",
    "AS8100":   "QuadraNet",
    "AS40065":  "FDC",
    "AS53667":  "FranTech",
    "AS13335":  "Cloudflare (CDN/Proxy)",
    "AS209":    "Lumen",
    "AS7203":   "Sharktech",
};

// SUSPECT_KEYWORDS — heurística por padrão de nome
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
    "appcake", "buildstore", "ifunbox", "panda.tool",
];

// SCRIPTABLE bundle (usado pra detectar abuse)
const SCRIPTABLE_BUNDLE = "dk.simonbs.Scriptable";

// ============================================================
//  DETECTION ENGINE
// ============================================================

let alerts = [];
let warnings = [];
let okItems = [];

function alert(msg) { alerts.push(msg); }
function warn(msg) { warnings.push(msg); }
function ok(msg) { okItems.push(msg); }

async function loadReport() {
    const dp = DocumentPicker;
    let path;
    try {
        path = await dp.openFile();
    } catch (e) {
        path = await dp.open(["public.data", "public.text", "public.json"]);
    }
    if (!path) throw new Error("Nenhum arquivo selecionado");
    const fileFM = path.startsWith("/private/") ? FileManager.local() : FileManager.iCloud();
    const raw = fileFM.readString(path);
    if (!raw) throw new Error("Arquivo vazio: " + path);
    return { raw, path };
}

function parseNDJSON(raw) {
    const lines = raw.split("\n").filter(l => l.trim().length > 0);
    const events = [];
    for (const line of lines) {
        try { events.push(JSON.parse(line)); }
        catch (err) {}
    }
    return events;
}

function analyze(events) {
    const bundlesSeen = new Set();
    const domainsSeen = new Set();
    const ipsSeen = new Set();
    const networkByBundle = {};

    for (const ev of events) {
        const bundle = ev.bundleID || ev.bundle ||
                       (ev.networkActivity && ev.networkActivity.bundleID) ||
                       ev.accessor || (ev.access && ev.access.identifier);
        const domain = ev.domain || ev.domainName ||
                       (ev.networkActivity && ev.networkActivity.domain);
        const ip = ev.firstHop || ev.ipAddress;

        if (bundle) bundlesSeen.add(bundle);
        if (domain) {
            domainsSeen.add(domain);
            if (bundle) {
                if (!networkByBundle[bundle]) networkByBundle[bundle] = { domains: new Set(), ips: new Set(), hits: 0 };
                networkByBundle[bundle].domains.add(domain.toLowerCase());
                networkByBundle[bundle].hits += (ev.hits || 1);
            }
        }
        if (ip) {
            ipsSeen.add(ip);
            if (bundle && networkByBundle[bundle]) networkByBundle[bundle].ips.add(ip);
        }
    }
    return { bundlesSeen, domainsSeen, ipsSeen, networkByBundle };
}

function detect(analysis) {
    const { bundlesSeen, domainsSeen, ipsSeen, networkByBundle } = analysis;

    // === 1. CHEAT_APPS (109 bundles catalogados) ===
    for (const b of bundlesSeen) {
        if (CHEAT_APPS[b]) {
            const sev = CHEAT_SEVERITY[b] || "MEDIUM";
            const desc = CHEAT_APPS[b];
            if (sev === "CRITICAL") {
                alert(`[CRITICAL] ${b} — ${desc}`);
            } else if (sev === "HIGH") {
                alert(`[HIGH] ${b} — ${desc}`);
            } else {
                warn(`[${sev}] ${b} — ${desc}`);
            }
        }
    }

    // === 2. FF oficial: presente? ===
    let ffFound = false;
    for (const b of FF_OFFICIAL) {
        if (bundlesSeen.has(b)) {
            ok(`Free Fire oficial: ${b}`);
            ffFound = true;
        }
    }
    if (!ffFound) {
        warn("Free Fire oficial NÃO apareceu no log — pode não ter jogado no período capturado");
    }

    // === 3. Bundle com "freefire" no nome mas NÃO oficial ===
    for (const b of bundlesSeen) {
        if (b.toLowerCase().includes("freefire") && !FF_OFFICIAL.has(b)) {
            alert(`[CRITICAL] Bundle FF NÃO oficial (re-sign/IPA mod): ${b}`);
        }
    }

    // === 4. KNOWN_CHEAT_INFRA (domínios + IPs confirmados) ===
    for (const [indicator, desc] of Object.entries(KNOWN_CHEAT_INFRA)) {
        const isIP = /^\d+\.\d+\.\d+\.\d+$/.test(indicator);
        if (isIP) {
            if (ipsSeen.has(indicator)) {
                alert(`[CRITICAL] CHEAT IP: ${indicator} — ${desc}`);
            }
        } else {
            for (const seen of domainsSeen) {
                if (seen.toLowerCase() === indicator.toLowerCase() ||
                    seen.toLowerCase().endsWith("." + indicator.toLowerCase())) {
                    // FF login domains chamados pelo próprio FF = OK
                    if (FF_PROXY_LOGIN_DOMAINS.has(indicator.toLowerCase())) {
                        const callers = Object.entries(networkByBundle)
                            .filter(([b, d]) => d.domains.has(seen.toLowerCase()))
                            .map(([b]) => b);
                        const onlyFF = callers.every(b => FF_OFFICIAL.has(b));
                        if (onlyFF) {
                            ok(`FF login domain ${seen} acessado só pelo próprio FF`);
                            continue;
                        }
                    }
                    alert(`[CRITICAL] CHEAT DOMAIN: ${seen} — ${desc}`);
                }
            }
        }
    }

    // === 5. FF_PROXY_LOGIN_DOMAINS chamado por bundle não-FF (proxy bypass clássico) ===
    for (const [bundle, info] of Object.entries(networkByBundle)) {
        if (FF_OFFICIAL.has(bundle)) continue;
        for (const d of info.domains) {
            if (FF_PROXY_LOGIN_DOMAINS.has(d)) {
                alert(`[CRITICAL] PROXY BYPASS LOGIN: ${bundle} acessou ${d} (domínio só do FF — MITM)`);
            }
        }
    }

    // === 6. TELEMETRY + SIDELOAD domains por app (sideload sem App Store) ===
    for (const [bundle, info] of Object.entries(networkByBundle)) {
        if (bundle.startsWith("com.apple.") || FF_OFFICIAL.has(bundle)) continue;

        const domains = [...info.domains];
        const hasOfficial = domains.some(d =>
            [...APP_STORE_OFFICIAL].some(o => d === o || d.endsWith("." + o))
        );
        const telHits = TELEMETRY_DOMAINS.filter(td =>
            domains.some(d => d === td || d.endsWith("." + td))
        );
        const sideloadHits = SIDELOAD_DOMAINS.filter(sd =>
            domains.some(d => d === sd || d.endsWith("." + sd))
        );

        if (sideloadHits.length > 0) {
            alert(`[HIGH] Sideload indicator: ${bundle} → ${sideloadHits.slice(0, 3).join(", ")}`);
        } else if (telHits.length > 0 && !hasOfficial) {
            warn(`[MEDIUM] App não-AppStore com telemetria: ${bundle} → ${telHits.slice(0, 2).join(", ")}`);
        }
    }

    // === 7. SCRIPT_URL_PATTERNS via Scriptable (abuse de execução remota) ===
    const scriptableData = networkByBundle[SCRIPTABLE_BUNDLE];
    if (scriptableData) {
        for (const d of scriptableData.domains) {
            for (const p of SCRIPT_URL_PATTERNS) {
                if (p.regex.test(d)) {
                    warn(`[MEDIUM] Scriptable acessou ${d} (${p.label})`);
                }
            }
        }
    }

    // === 8. SUSPICIOUS_TLDS em domínios ===
    for (const seen of domainsSeen) {
        for (const tld of SUSPICIOUS_TLDS) {
            if (seen.toLowerCase().endsWith(tld)) {
                // Se foi acessado só por apps Apple/Google legítimos, ignora
                const callers = Object.entries(networkByBundle)
                    .filter(([b, d]) => d.domains.has(seen.toLowerCase()));
                const onlyLegit = callers.every(([b]) =>
                    b.startsWith("com.apple.") || b.startsWith("com.google.")
                );
                if (onlyLegit) continue;
                warn(`[MEDIUM] TLD suspeito '${tld}': ${seen}`);
                break;
            }
        }
    }

    // === 9. Heurística por keyword no bundle ===
    for (const b of bundlesSeen) {
        if (CHEAT_APPS[b]) continue; // já catalogado
        if (b.startsWith("com.apple.") || b.startsWith("com.google.") ||
            b.startsWith("com.facebook.") || b.startsWith("com.whatsapp") ||
            b.startsWith("com.instagram.") || b.startsWith("com.burbn.") ||
            FF_OFFICIAL.has(b)) continue;
        const bl = b.toLowerCase();
        for (const kw of SUSPECT_KEYWORDS) {
            if (bl.includes(kw)) {
                warn(`[LOW] Bundle suspeito por padrão de nome [${kw}]: ${b}`);
                break;
            }
        }
    }

    // === 10. FF conectando em domínio não-Garena ===
    for (const ffBundle of FF_OFFICIAL) {
        const data = networkByBundle[ffBundle];
        if (!data) continue;
        for (const d of data.domains) {
            const isOfficial = d.includes("garena") || d.includes("dts.com") ||
                d.includes("akamai") || d.includes("cloudfront") ||
                d.includes("apple.com") || d.includes("googleapis") ||
                d.includes("crashlytics") || d.includes("appsflyer") ||
                d.includes("facebook") || d.includes("fbcdn") ||
                d.includes("freefiremobile") || d.includes("ggblueshark");
            if (!isOfficial) warn(`[LOW] FF conectou em domínio não-padrão: ${d}`);
        }
    }
}

// ============================================================
//  UI
// ============================================================

function buildResultTable(stats) {
    const t = new UITable();
    t.showSeparators = true;

    const hdr = new UITableRow();
    hdr.height = 80;
    hdr.isHeader = true;
    const c = hdr.addText("A4THER SYSTEMS", `v${VERSION} ▪ LS Aluguel ▪ FF iOS Scanner`);
    c.titleFont = Font.boldSystemFont(22);
    c.titleColor = Color.cyan();
    c.subtitleFont = Font.systemFont(12);
    c.subtitleColor = Color.gray();
    t.addRow(hdr);

    const verdict = new UITableRow();
    verdict.height = 70;
    let txt, color;
    if (alerts.length > 0) { txt = `✗ SUSPEITO — ${alerts.length} alertas`; color = Color.red(); }
    else if (warnings.length > 0) { txt = `⚠ REVISAR — ${warnings.length} avisos`; color = Color.orange(); }
    else { txt = "✓ LIMPO — device aprovado"; color = Color.green(); }
    const vc = verdict.addText(txt,
        `Alertas: ${alerts.length}  •  Avisos: ${warnings.length}  •  OKs: ${okItems.length}`);
    vc.titleFont = Font.boldSystemFont(20);
    vc.titleColor = color;
    vc.subtitleFont = Font.systemFont(12);
    t.addRow(verdict);

    const meta = new UITableRow();
    meta.height = 50;
    const mc = meta.addText("Análise", `${stats.events} eventos, ${stats.bundles} bundles, ${stats.domains} domínios, ${stats.ips} IPs`);
    mc.titleFont = Font.boldSystemFont(13);
    mc.subtitleFont = Font.systemFont(11);
    mc.subtitleColor = Color.gray();
    t.addRow(meta);

    function section(title, items, color) {
        if (items.length === 0) return;
        const sh = new UITableRow();
        const shc = sh.addText(`◆ ${title}`, `${items.length} item${items.length !== 1 ? "s" : ""}`);
        shc.titleFont = Font.boldSystemFont(16);
        shc.titleColor = color;
        t.addRow(sh);
        for (const item of items) {
            const r = new UITableRow();
            r.height = 50;
            const x = r.addText("●  " + item);
            x.titleFont = Font.systemFont(12);
            x.titleColor = color;
            t.addRow(r);
        }
    }

    section("ALERTAS", alerts, Color.red());
    section("AVISOS",  warnings, Color.orange());
    section("OK",      okItems, Color.green());

    return t;
}

function buildTextReport(stats) {
    const lines = [];
    lines.push("=========================================");
    lines.push(`  A4ther Systems v${VERSION} | LS Aluguel`);
    lines.push("  Free Fire iOS Anti-Cheat Scanner");
    lines.push(`  ${new Date().toISOString()}`);
    lines.push("=========================================");
    lines.push("");
    if (alerts.length > 0) lines.push(`*** SUSPEITO - ${alerts.length} alertas ***`);
    else if (warnings.length > 0) lines.push(`*** REVISAR - ${warnings.length} avisos ***`);
    else lines.push(`*** LIMPO ***`);
    lines.push("");
    lines.push(`Eventos:  ${stats.events}`);
    lines.push(`Bundles:  ${stats.bundles}`);
    lines.push(`Domínios: ${stats.domains}`);
    lines.push(`IPs:      ${stats.ips}`);
    lines.push(`Alertas:  ${alerts.length}`);
    lines.push(`Avisos:   ${warnings.length}`);
    lines.push(`OKs:      ${okItems.length}`);
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
        lines.push("--- OK ---");
        for (const o of okItems) lines.push("  [+] " + o);
    }
    return lines.join("\n");
}

// ============================================================
//  MAIN
// ============================================================

async function main() {
    const w = new Alert();
    w.title = `A4ther Systems v${VERSION}`;
    w.message = "Free Fire iOS Anti-Cheat Scanner\nLS Aluguel\n\n109+ bundle IDs catalogados, 12 cheat servers, 22 telemetry, 22 TLDs, 15 script patterns.\n\nVai abrir o picker pra você selecionar o arquivo .ndjson do App Privacy Report.\n\nSe ainda não tem:\n1. Settings → Privacy → App Privacy Report → ON\n2. Joga FF por uns minutos\n3. Em App Privacy Report, 'Save App Privacy Report'";
    w.addAction("Continuar");
    w.addCancelAction("Cancelar");
    const idx = await w.present();
    if (idx === -1) return;

    let report;
    try { report = await loadReport(); }
    catch (e) {
        const a = new Alert();
        a.title = "Erro";
        a.message = String(e);
        a.addAction("OK");
        await a.present();
        return;
    }

    const events = parseNDJSON(report.raw);
    if (events.length === 0) {
        const a = new Alert();
        a.title = "Arquivo vazio";
        a.message = "Nenhum evento parseado.\n\nVerifique se é um App Privacy Report válido (.ndjson).";
        a.addAction("OK");
        await a.present();
        return;
    }

    const analysis = analyze(events);
    detect(analysis);

    const stats = {
        events: events.length,
        bundles: analysis.bundlesSeen.size,
        domains: analysis.domainsSeen.size,
        ips: analysis.ipsSeen.size,
    };

    await buildResultTable(stats).present(true);

    const s = new Alert();
    s.title = "Salvar relatório?";
    s.message = "Salvar relatório TXT no Scriptable?";
    s.addAction("Sim");
    s.addCancelAction("Não");
    if ((await s.present()) === 0) {
        const fm = FileManager.iCloud();
        const ts = new Date().toISOString().replace(/[:\.]/g, "-").substring(0, 19);
        const path = fm.joinPath(fm.documentsDirectory(), `a4ther_scan_${ts}.txt`);
        fm.writeString(path, buildTextReport(stats));
        const d = new Alert();
        d.title = "Salvo";
        d.message = path;
        d.addAction("OK");
        await d.present();
    }
}

await main();
Script.complete();
