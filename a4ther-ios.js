// ============================================================
//  A4ther Systems v3.3.0 | LS Aluguel
//  iOS Free Fire Anti-Cheat Scanner (Scriptable)
//  Roda em iPhone SEM jailbreak via app Scriptable (gratuito App Store).
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

const VERSION = "3.3.0";

// ============================================================
//  DATA — bundles, domínios, IPs, TLDs, ASNs (109+ entries)
// ============================================================

// CHEAT_APPS — bundle ID → descrição (categorizado)
const CHEAT_APPS = {
    // v4.4.52: KhoinDVN family — DNS proxy profiles VN (sequester FF iOS)
    "com.khoindvn":                           "KhoinDVN DNS Proxy — perfil MDM com DNS sequester FF",
    "com.khoindvn.apple-dns":                 "KhoinDVN DNS Profile — payload com.apple.dnsSettings.managed",
    "com.khoindvn.dns":                       "KhoinDVN DNS — variante DNS proxy",
    "com.khoindvn.vpn":                       "KhoinDVN VPN — variante VPN profile",
    "com.khoindvn.proxy":                     "KhoinDVN Proxy — profile proxy generic",
    "com.khoind.app":                         "KhoinD App — parent KhoinDVN",

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

    // === Proxy / VPN / MITM ===
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
    // === NextDNS / DNS profiles (sequester DNS = redirect FF login) ===
    "com.ascent.nextdns.profile":             "NextDNS profile (Ascent) - DNS sequester",
    "io.nextdns.profile":                     "NextDNS profile direto - DNS sequester",
    "com.controld.config-profile":            "Control-D DNS profile - DNS sequester",
    "com.adguard.dns.config-profile":         "AdGuard DNS profile",
    "com.cloudflare.warp.profile":            "Cloudflare WARP profile",
    "com.opendns.config-profile":             "OpenDNS profile",
    "com.quad9.config-profile":               "Quad9 DNS profile",
    "com.nextdns.ios.profile":                "NextDNS iOS profile",
    "com.nextdns.nextdns.profile":            "NextDNS profile alt",
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

// APPLE_MDM_DOMAINS — endpoints reais Apple MDM/Activation/Push
// Device aparecer hitando esses = enrollado em MDM (profile remoto ativo)
const APPLE_MDM_DOMAINS = [
    "mdmenrollment.apple.com",
    "iprofiles.apple.com",
    "albert.apple.com",
    "gs.apple.com",
    "deviceenrollment.apple.com",
    "deviceservices-external.apple.com",
    "identity.apple.com",
    "init-p01st.push.apple.com",
    "setup.icloud.com",
    "gsa.apple.com",
    "humb.apple.com",
];

// DNS_OVER_HTTPS_DOMAINS — endpoints DoH (profile com custom DNS aparece aqui)
const DNS_OVER_HTTPS_DOMAINS = [
    "cloudflare-dns.com", "one.one.one.one", "1.1.1.1",
    "dns.google", "8.8.8.8", "8.8.4.4",
    "dns.quad9.net", "9.9.9.9",
    "dns.adguard.com", "dns-family.adguard.com",
    "doh.opendns.com", "doh.cleanbrowsing.org",
    "mozilla.cloudflare-dns.com",
    "dns.nextdns.io",
    "dns.controld.com",
];

// CERT_VALIDATION_DOMAINS — OCSP/CRL Apple oficiais (suspeito se OUTRA CA aparecer)
const APPLE_CERT_DOMAINS = [
    "ocsp.apple.com", "ocsp2.apple.com", "ocsp.digicert.com",
    "crl.apple.com", "crl3.digicert.com", "crl4.digicert.com",
    "valid.apple.com", "certs.apple.com",
];

// SCREEN_TIME_DOMAINS — Apple Screen Time / Family backend (presença = restrictions ativas)
const SCREEN_TIME_DOMAINS = [
    "familycircle.apple.com",
    "p38-fmip.icloud.com",
    "p38-fmf.icloud.com",
    "screentime.apple.com",
];

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
    // v4.4.54: Holograma cheat (BR) — arquivos modificados em pasta do FF
    "holograma", "hologram", "holohack", "holomod", "holoff",
    "appcake", "buildstore", "ifunbox", "panda.tool",
];

// SCRIPTABLE bundle (usado pra detectar abuse)
const SCRIPTABLE_BUNDLE = "dk.simonbs.Scriptable";

// ============================================================
//  iOS PROFILE PAYLOAD TYPES (analisador de .mobileconfig)
// ============================================================
// PayloadType → categoria + severidade
const PROFILE_PAYLOADS = {
    // ── CRÍTICOS (MITM / sequestro de rede) ──
    "com.apple.vpn.managed":                       { sev: "CRITICAL", cat: "VPN",        desc: "VPN configurada via profile - roteia TODO tráfego" },
    "com.apple.vpn.managed.applayer":              { sev: "CRITICAL", cat: "VPN",        desc: "Per-app VPN - rote app específico (FF?)" },
    "com.apple.proxy.http.global":                 { sev: "CRITICAL", cat: "PROXY",      desc: "HTTP Proxy global - MITM clássico" },
    "com.apple.security.root":                     { sev: "CRITICAL", cat: "CA",         desc: "CA Root cert - permite decrypt TLS (MITM completo)" },
    "com.apple.security.pkcs1":                    { sev: "CRITICAL", cat: "CA",         desc: "PKCS#1 cert - permite MITM" },
    "com.apple.security.pkcs12":                   { sev: "CRITICAL", cat: "CA",         desc: "PKCS#12 cert - permite MITM" },
    "com.apple.security.scep":                     { sev: "CRITICAL", cat: "CA",         desc: "SCEP cert enrollment - MDM" },
    "com.apple.webcontent-filter":                 { sev: "CRITICAL", cat: "FILTER",     desc: "Web Content Filter - proxy alternativo" },
    "com.apple.dnsSettings.managed":               { sev: "CRITICAL", cat: "DNS",        desc: "DNS custom - sequester domínios FF" },
    "com.apple.dnsProxy.managed":                  { sev: "CRITICAL", cat: "DNS",        desc: "DNS Proxy - interceptação de DNS" },
    "com.apple.relay.managed":                     { sev: "HIGH",     cat: "RELAY",      desc: "iCloud Private Relay disable/managed" },

    // ── RESTRICTIONS / POLICIES ──
    "com.apple.applicationaccess":                 { sev: "CRITICAL", cat: "RESTRICT",   desc: "App restrictions - controla quais apps rodam" },
    "com.apple.applicationaccess.new":             { sev: "CRITICAL", cat: "RESTRICT",   desc: "App restrictions (iOS 13+)" },
    "com.apple.screentimepolicy":                  { sev: "CRITICAL", cat: "RESTRICT",   desc: "Screen Time policy" },
    "com.apple.passwordpolicy":                    { sev: "HIGH",     cat: "RESTRICT",   desc: "Password policy enforced" },
    "com.apple.systempolicy.kernel-extension-policy": { sev: "HIGH",  cat: "RESTRICT",   desc: "Kext allow/deny policy" },
    "com.apple.systempolicy.system-extension-policy": { sev: "HIGH",  cat: "RESTRICT",   desc: "System extension policy" },
    "com.apple.familyControls":                    { sev: "HIGH",     cat: "RESTRICT",   desc: "Family Controls / Screen Time" },

    // ── MDM ──
    "com.apple.mdm":                               { sev: "HIGH",     cat: "MDM",        desc: "MDM - device sob controle remoto" },

    // ── ACCOUNTS / ACTIVATION ──
    "com.apple.iTunesStoreAccount":                { sev: "MEDIUM",   cat: "ACCOUNT",    desc: "iTunes Store Account managed" },
    "com.apple.activation":                        { sev: "MEDIUM",   cat: "ACTIVATION", desc: "Device activation managed" },

    // ── NETWORK ──
    "com.apple.wifi.managed":                      { sev: "MEDIUM",   cat: "WIFI",       desc: "Wi-Fi forçado via profile" },
    "com.apple.airplay.security":                  { sev: "LOW",      cat: "AIRPLAY",    desc: "AirPlay policy" },

    // ── EMAIL / CALENDAR / CONTACTS (geralmente legítimo MDM corporativo) ──
    "com.apple.mail.managed":                      { sev: "LOW",      cat: "EMAIL",      desc: "Email managed (corporativo)" },
    "com.apple.eas.account":                       { sev: "LOW",      cat: "EMAIL",      desc: "Exchange Account" },
    "com.apple.caldav.account":                    { sev: "LOW",      cat: "CALENDAR",   desc: "CalDAV managed" },
    "com.apple.carddav.account":                   { sev: "LOW",      cat: "CONTACTS",   desc: "CardDAV managed" },
};

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

    // === 0. OPAQUE-ID PROFILE PATTERNS (NextDNS, MDM, etc.) ===
    // Profiles dinâmicos com UUID no identifier indicam MDM/DNS reseller
    // Padrão: <reverse_domain>.<name>-<UUID 36 chars com hífens>
    const opaqueProfileRegex = /^[a-zA-Z][a-zA-Z0-9.-]*\.profile-[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;
    const dnsResellerRegex = /(nextdns|controld|control-d|cloudflare.*warp|adguard.*dns|opendns|quad9|cleanbrowsing|mullvad.*dns)/i;
    for (const b of bundlesSeen) {
        if (opaqueProfileRegex.test(b)) {
            alert(`[CRITICAL] Profile com ID OPACO (UUID dinâmico = MDM/reseller): ${b}`);
        }
        if (dnsResellerRegex.test(b) && !FF_OFFICIAL.has(b)) {
            // Já pode estar em CHEAT_APPS, mas reforça
            if (!CHEAT_APPS[b]) {
                alert(`[HIGH] DNS reseller bundle: ${b} (DNS sequester possível)`);
            }
        }
    }

    // === 1. CHEAT_APPS (115+ bundles catalogados) ===
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

    // ════════════════════════════════════════════════════════════════
    // PROFILE EFFECTS (DETECÇÃO INDIRETA dos profile payloads que JS
    // sem JB não consegue ler direto do filesystem)
    // ════════════════════════════════════════════════════════════════

    // === 7b. VPN ATIVA - sintoma: muitos apps usando o mesmo IP gateway ===
    const ipUsage = {};
    for (const [bundle, data] of Object.entries(networkByBundle)) {
        for (const ip of data.ips || []) {
            if (!ipUsage[ip]) ipUsage[ip] = new Set();
            ipUsage[ip].add(bundle);
        }
    }
    for (const [ip, bundles] of Object.entries(ipUsage)) {
        if (bundles.size >= 8) {
            // 8+ apps no mesmo IP = sinal forte de VPN tunnel
            alert(`[HIGH] VPN/PROXY indicador: ${bundles.size} apps roteando via ${ip}`);
        }
    }

    // === 7c. APPLE MDM endpoints - device enrollado em MDM remoto ===
    for (const d of APPLE_MDM_DOMAINS) {
        for (const seen of domainsSeen) {
            if (seen.toLowerCase() === d.toLowerCase() ||
                seen.toLowerCase().endsWith("." + d.toLowerCase())) {
                warn(`[MEDIUM] Apple MDM endpoint ativo: ${seen} (device MDM-enrollado)`);
                break;
            }
        }
    }

    // === 7d. CUSTOM DNS / DNS-over-HTTPS - sinal de profile com DNS Settings ===
    let dohHits = 0;
    for (const d of DNS_OVER_HTTPS_DOMAINS) {
        for (const seen of domainsSeen) {
            if (seen.toLowerCase() === d.toLowerCase() ||
                seen.toLowerCase().endsWith("." + d.toLowerCase())) {
                warn(`[MEDIUM] DNS-over-HTTPS endpoint: ${seen} (profile DNS custom?)`);
                dohHits++;
                break;
            }
        }
    }
    if (dohHits >= 2) {
        alert(`[HIGH] ${dohHits} DoH endpoints diferentes - DNS Settings profile provável`);
    }

    // === 7e. CA / CERT validation - non-Apple CA = profile com CA root ===
    // Lista de domínios cert-related que NÃO são Apple
    const certKeywords = ['ocsp.', 'crl.', '.crl.', 'pki.', 'certs.', '.cert.'];
    const nonAppleCertDomains = [];
    for (const seen of domainsSeen) {
        const sl = seen.toLowerCase();
        // Se domain tem padrão de cert validation
        let hasCertPattern = certKeywords.some(k => sl.includes(k));
        if (!hasCertPattern) continue;
        // Se NÃO é endpoint Apple oficial
        let isApple = APPLE_CERT_DOMAINS.some(a =>
            sl === a.toLowerCase() || sl.endsWith("." + a.toLowerCase())
        );
        if (!isApple && !sl.includes("apple.com") && !sl.includes("digicert.com") &&
            !sl.includes("godaddy.com") && !sl.includes("letsencrypt.org") &&
            !sl.includes("comodoca.com") && !sl.includes("sectigo.com")) {
            nonAppleCertDomains.push(seen);
        }
    }
    if (nonAppleCertDomains.length > 0) {
        alert(`[HIGH] CA root custom indicador: ${nonAppleCertDomains.length} cert endpoints não-Apple/legítimos:`);
        for (const d of nonAppleCertDomains.slice(0, 5)) {
            alert(`   → ${d}`);
        }
    }

    // === 7f. SCREEN TIME / FAMILY backend - Restrictions ativas? ===
    for (const d of SCREEN_TIME_DOMAINS) {
        for (const seen of domainsSeen) {
            if (seen.toLowerCase().endsWith(d.toLowerCase())) {
                ok(`Screen Time / Family Sharing ativo (${seen}) - pode ter Restrictions`);
                break;
            }
        }
    }

    // === 7g. PROXY HTTP/HTTPS indicador - patterns em domínios ===
    // Apps que NÃO deveriam usar proxy mas têm tráfego pra "proxy.*" ou IPs em ASNs cheat
    const proxyDomainPatterns = ['proxy.', '.proxy.', 'tunnel.', '.tunnel.', 'mitm.', '.relay.'];
    for (const [bundle, data] of Object.entries(networkByBundle)) {
        if (bundle.startsWith("com.apple.")) continue;
        for (const d of data.domains) {
            for (const pat of proxyDomainPatterns) {
                if (d.includes(pat)) {
                    warn(`[MEDIUM] ${bundle} → ${d} (padrão proxy/tunnel)`);
                    break;
                }
            }
        }
    }

    // === 7h. WebContentFilter indicador - apps de filter/adblock ativos ===
    const wcfHints = ["adguard", "1blocker", "adblock", "wipr", "blockada", "snowhaze"];
    for (const b of bundlesSeen) {
        const bl = b.toLowerCase();
        for (const k of wcfHints) {
            if (bl.includes(k)) {
                warn(`[LOW] App content filter (pode mascarar tráfego): ${b}`);
                break;
            }
        }
    }

    // === 7i. PROVISIONING profile indicador (dev cert) - sem Apple endpoints ===
    // App com telemetria mas sem domínio Apple OFICIAL = sideload provável
    // (já parcialmente coberto em SIDELOAD_DOMAINS check, mas reforço aqui)
    let suspectSideloadCount = 0;
    for (const [bundle, data] of Object.entries(networkByBundle)) {
        if (bundle.startsWith("com.apple.") || FF_OFFICIAL.has(bundle)) continue;
        if (CHEAT_APPS[bundle]) continue; // já catalogado
        const domains = [...data.domains];
        const hasApple = domains.some(d => [...APP_STORE_OFFICIAL].some(o => d.endsWith(o)));
        const hasTelemetry = TELEMETRY_DOMAINS.some(t =>
            domains.some(d => d === t || d.endsWith("." + t))
        );
        if (hasTelemetry && !hasApple && data.hits > 5) {
            suspectSideloadCount++;
            if (suspectSideloadCount <= 5) {
                warn(`[MEDIUM] Provisioning profile suspeito: ${bundle} (telemetria sem Apple endpoints, ${data.hits} hits)`);
            }
        }
    }
    if (suspectSideloadCount > 5) {
        warn(`[MEDIUM] ...e mais ${suspectSideloadCount - 5} apps com padrão de sideload`);
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

// ============================================================
//  PROFILE FILE ANALYZER (.mobileconfig)
// ============================================================

async function loadProfileFile() {
    const dp = DocumentPicker;
    let path;
    try {
        path = await dp.openFile();
    } catch (e) {
        path = await dp.open(["com.apple.mobileconfig", "public.data", "public.xml", "public.text"]);
    }
    if (!path) throw new Error("Nenhum arquivo selecionado");
    const fileFM = path.startsWith("/private/") ? FileManager.local() : FileManager.iCloud();
    let raw = fileFM.readString(path);
    if (!raw) {
        // Tenta como binary - extrai strings ASCII printáveis
        const data = fileFM.read(path);
        try {
            raw = data.toRawString();
        } catch (e) {
            // Fallback: força ler bytes e extrair só ASCII
            raw = "";
            for (let i = 0; i < data.getLength(); i++) {
                const b = data.bytes[i];
                raw += (b >= 32 && b < 127) ? String.fromCharCode(b) : " ";
            }
        }
    }
    if (!raw) throw new Error("Não consegui ler conteúdo: " + path);
    return { raw, path };
}

function analyzeProfile(raw, opts) {
    opts = opts || {};
    // Reset só se não estiver em modo batch (sysdiagnose chama várias vezes)
    if (!opts.noReset) {
        alerts = []; warnings = []; okItems = [];
    }
    const prefix = opts.filePrefix ? `[${opts.filePrefix}] ` : "";

    // 1) Extrair todos os PayloadType
    const payloadTypes = [];
    const ptRegex = /<key>\s*PayloadType\s*<\/key>\s*<string>([^<]+)<\/string>/gi;
    let m;
    while ((m = ptRegex.exec(raw)) !== null) {
        payloadTypes.push(m[1].trim());
    }
    // Fallback: scan ASCII pra binary plists
    if (payloadTypes.length === 0) {
        for (const pt of Object.keys(PROFILE_PAYLOADS)) {
            if (raw.includes(pt)) payloadTypes.push(pt);
        }
    }

    // 2) Extrair metadata
    function extractMeta(key) {
        const r = new RegExp(`<key>\\s*${key}\\s*<\\/key>\\s*<string>([^<]+)<\\/string>`, "i");
        const mm = raw.match(r);
        return mm ? mm[1].trim() : null;
    }
    function extractMetaBinary(key) {
        // Pra binary plist, procura a string seguinte ao key
        const idx = raw.indexOf(key);
        if (idx === -1) return null;
        // Procura próxima string ASCII printable
        let s = "", started = false, count = 0;
        for (let i = idx + key.length; i < raw.length && count < 200; i++) {
            const c = raw.charCodeAt(i);
            if (c >= 32 && c < 127 && c !== 60 && c !== 62) {
                s += String.fromCharCode(c);
                started = true;
            } else if (started) {
                if (s.length >= 3) break;
                s = ""; started = false;
            }
            count++;
        }
        return s.length >= 3 ? s : null;
    }

    const displayName  = extractMeta("PayloadDisplayName")  || extractMetaBinary("PayloadDisplayName");
    const identifier   = extractMeta("PayloadIdentifier")   || extractMetaBinary("PayloadIdentifier");
    const organization = extractMeta("PayloadOrganization") || extractMetaBinary("PayloadOrganization");
    const uuid         = extractMeta("PayloadUUID")         || extractMetaBinary("PayloadUUID");

    // Hosts / proxies / URLs no profile
    const hostNames = [];
    const hnRegex = /<key>\s*HostName\s*<\/key>\s*<string>([^<]+)<\/string>/gi;
    while ((m = hnRegex.exec(raw)) !== null) hostNames.push(m[1].trim());

    const proxyServers = [];
    const psRegex = /<key>\s*ProxyServer\s*<\/key>\s*<string>([^<]+)<\/string>/gi;
    while ((m = psRegex.exec(raw)) !== null) proxyServers.push(m[1].trim());

    const proxyPACs = [];
    const pacRegex = /<key>\s*ProxyAutoConfigURLString\s*<\/key>\s*<string>([^<]+)<\/string>/gi;
    while ((m = pacRegex.exec(raw)) !== null) proxyPACs.push(m[1].trim());

    // 3) Mostrar metadata
    if (displayName)  okItems.push(`Display Name: ${displayName}`);
    if (identifier)   okItems.push(`Identifier:   ${identifier}`);
    if (organization) okItems.push(`Organization: ${organization}`);
    if (uuid)         okItems.push(`UUID:         ${uuid}`);

    // 4) Verificar cada PayloadType contra a lista crítica
    const unique = [...new Set(payloadTypes)];
    if (unique.length === 0) {
        warn("Nenhum PayloadType detectado - arquivo pode não ser .mobileconfig válido");
    }
    for (const pt of unique) {
        const info = PROFILE_PAYLOADS[pt];
        if (info) {
            const tag = `[${info.sev}]`;
            const msg = `${tag} ${info.cat} - ${pt}\n   → ${info.desc}`;
            if (info.sev === "CRITICAL") alerts.push(msg);
            else if (info.sev === "HIGH") alerts.push(msg);
            else if (info.sev === "MEDIUM") warnings.push(msg);
            else warnings.push(msg);
        } else {
            okItems.push(`PayloadType desconhecido: ${pt}`);
        }
    }

    // 5) Mostrar HostNames / ProxyServers / PAC URLs encontrados
    for (const h of hostNames)    alerts.push(`HostName configurado: ${h}`);
    for (const p of proxyServers) alerts.push(`ProxyServer: ${p}`);
    for (const u of proxyPACs)    alerts.push(`PAC URL: ${u}`);

    // 6) Identifier com UUID opaco = profile dinâmico (MDM, NextDNS, etc.)
    if (identifier) {
        const opaqueRegex = /[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/;
        if (opaqueRegex.test(identifier)) {
            alerts.push(`[CRITICAL] Profile com UUID OPACO no identifier: ${identifier}`);
            alerts.push(`   → Profile dinâmico (gerado por MDM/reseller como NextDNS/ControlD)`);
        }
        // DNS reseller patterns no identifier
        const dnsResellerProf = /(nextdns|controld|control-d|adguard|cloudflare.*warp|opendns|quad9)/i;
        if (dnsResellerProf.test(identifier)) {
            alerts.push(`[CRITICAL] DNS reseller profile: ${identifier} (SEQUESTRA DNS - pode redirecionar FF)`);
        }
    }

    // 7) Heurística de cheat strings em Organization/DisplayName
    const cheatRegex = /(esign|feather|ksign|gbox|scarlet|sideload|trollstore|cheat|hack|aimbot|wallhack|ffh4x|mod\.menu|injector|cracked|mitmproxy|holograma|hologram)/i;
    if (organization && cheatRegex.test(organization)) {
        alerts.push(`Organization contém keyword de cheat: ${organization}`);
    }
    if (displayName && cheatRegex.test(displayName)) {
        alerts.push(`Display Name contém keyword de cheat: ${displayName}`);
    }
    if (identifier && cheatRegex.test(identifier)) {
        alerts.push(`Identifier contém keyword de cheat: ${identifier}`);
    }

    // 7) URLs no profile - greppa todas
    const urls = raw.match(/https?:\/\/[a-zA-Z0-9.\-\/]+/g) || [];
    const uniqueUrls = [...new Set(urls)].slice(0, 10);
    for (const u of uniqueUrls) {
        const ul = u.toLowerCase();
        // FF login domains via profile = MITM clássico
        for (const ffd of FF_PROXY_LOGIN_DOMAINS) {
            if (ul.includes(ffd)) {
                alerts.push(`Profile contém URL de domínio FF (MITM!): ${u}`);
            }
        }
        // Cheat infra domains
        for (const [cd] of Object.entries(KNOWN_CHEAT_INFRA)) {
            if (ul.includes(cd.toLowerCase())) {
                alerts.push(`Profile contém URL de cheat infra: ${u}`);
            }
        }
        // Suspect TLDs
        for (const tld of SUSPICIOUS_TLDS) {
            if (ul.endsWith(tld) || ul.includes(tld + "/") || ul.includes(tld + ":")) {
                warnings.push(`URL com TLD suspeito (${tld}): ${u}`);
                break;
            }
        }
    }

    return {
        payloadTypes: unique,
        metadata: { displayName, identifier, organization, uuid },
        hostNames, proxyServers, proxyPACs,
        urls: uniqueUrls,
    };
}

function buildProfileTable(profileInfo) {
    const t = new UITable();
    t.showSeparators = true;

    const hdr = new UITableRow();
    hdr.height = 80;
    hdr.isHeader = true;
    const c = hdr.addText("A4THER SYSTEMS", `v${VERSION} ▪ LS Aluguel ▪ Profile Analyzer`);
    c.titleFont = Font.boldSystemFont(22);
    c.titleColor = Color.cyan();
    c.subtitleFont = Font.systemFont(12);
    c.subtitleColor = Color.gray();
    t.addRow(hdr);

    const verdict = new UITableRow();
    verdict.height = 70;
    let txt, color;
    if (alerts.length > 0) { txt = `✗ PROFILE PERIGOSO — ${alerts.length} alertas`; color = Color.red(); }
    else if (warnings.length > 0) { txt = `⚠ REVISAR — ${warnings.length} avisos`; color = Color.orange(); }
    else { txt = "✓ Profile parece OK"; color = Color.green(); }
    const vc = verdict.addText(txt,
        `Payloads: ${profileInfo.payloadTypes.length}  •  Hosts: ${profileInfo.hostNames.length}  •  Proxies: ${profileInfo.proxyServers.length}`);
    vc.titleFont = Font.boldSystemFont(20);
    vc.titleColor = color;
    vc.subtitleFont = Font.systemFont(12);
    t.addRow(verdict);

    function section(title, items, color) {
        if (items.length === 0) return;
        const sh = new UITableRow();
        const shc = sh.addText(`◆ ${title}`, `${items.length} item${items.length !== 1 ? "s" : ""}`);
        shc.titleFont = Font.boldSystemFont(16);
        shc.titleColor = color;
        t.addRow(sh);
        for (const item of items) {
            const r = new UITableRow();
            r.height = 60;
            const x = r.addText("●  " + item);
            x.titleFont = Font.systemFont(12);
            x.titleColor = color;
            t.addRow(r);
        }
    }

    section("ALERTAS",  alerts,   Color.red());
    section("AVISOS",   warnings, Color.orange());
    section("METADATA", okItems,  Color.green());

    return t;
}

// ============================================================
//  MAIN
// ============================================================

async function main() {
    // Menu inicial: escolha o modo
    const menu = new Alert();
    menu.title = `A4ther Systems v${VERSION}`;
    menu.message = "Free Fire iOS Anti-Cheat Scanner\nLS Aluguel\n\nEscolha o que analisar:";
    menu.addAction("Sysdiagnose (TUDO - recomendado)");
    menu.addAction("Privacy Report (.ndjson)");
    menu.addAction("Profile File (.mobileconfig)");
    menu.addAction("Privacy Report + Profile");
    menu.addCancelAction("Cancelar");
    const choice = await menu.present();
    if (choice === -1) return;

    // ── Modo 0: Sysdiagnose (mais completo)
    if (choice === 0) {
        await runSysdiagnoseAnalyzer();
        return;
    }
    // ── Modo 1: Privacy Report
    if (choice === 1 || choice === 3) {
        await runPrivacyReport();
    }
    // ── Modo 2: Profile File
    if (choice === 2 || choice === 3) {
        await runProfileAnalyzer();
    }
}

async function runPrivacyReport() {
    const info = new Alert();
    info.title = "App Privacy Report";
    info.message = "Vai abrir o picker pra você selecionar o arquivo .ndjson.\n\nSe ainda não tem:\n1. Settings → Privacy → App Privacy Report → ON\n2. Joga FF por uns minutos\n3. Em App Privacy Report → 'Save App Privacy Report'";
    info.addAction("Selecionar arquivo");
    info.addCancelAction("Pular");
    if ((await info.present()) === -1) return;

    // Reset counters pra esta run
    alerts = []; warnings = []; okItems = [];

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

// ============================================================
//  SYSDIAGNOSE ANALYZER
//  Aponta para uma pasta sysdiagnose_*.tar.gz JÁ EXTRAÍDA pelo iOS.
//  Lê todos os arquivos forenses relevantes: apps instalados, profiles,
//  install history, network state, processos, crashes.
// ============================================================

async function runSysdiagnoseAnalyzer() {
    const info = new Alert();
    info.title = "Sysdiagnose Analyzer";
    info.message = "Como gerar:\n\n1. iPhone: aperta Vol+ + Vol- + Side por 1 seg (sente vibrar leve)\n2. Aguarda ~5min (continua usando o iPhone)\n3. Settings → Privacy & Security → Analytics & Improvements → Analytics Data\n4. Acha sysdiagnose_*.tar.gz, toca → Share → Save to Files\n5. No Files app: toca no .tar.gz → iOS extrai automaticamente (vira pasta)\n6. Volta aqui → seleciona a PASTA extraída";
    info.addAction("Selecionar pasta");
    info.addCancelAction("Cancelar");
    if ((await info.present()) === -1) return;

    let folderPath;
    try {
        folderPath = await DocumentPicker.openFolder();
    } catch (e) {
        const a = new Alert();
        a.title = "Erro";
        a.message = "Folder picker falhou: " + String(e);
        a.addAction("OK");
        await a.present();
        return;
    }
    if (!folderPath) return;

    alerts = []; warnings = []; okItems = [];
    okItems.push(`Pasta selecionada: ${folderPath}`);

    // Try iCloud first, fall back to local FM
    let fm = FileManager.iCloud();
    try {
        if (!fm.fileExists(folderPath)) fm = FileManager.local();
    } catch (e) {
        fm = FileManager.local();
    }

    // ─── AUTO-DETECT: a pasta selecionada é realmente sysdiagnose? ───
    // Verifica se tem os arquivos/dirs característicos
    function isSysdiagnoseFolder(p) {
        const indicators = [
            "logs/MobileInstallation",
            "logs",
            "summaries",
            "ps.txt",
            "taskinfo.txt",
            "remotectl_dumpstate.txt",
            "swcutil_show.txt",
            "crashes_and_spins",
        ];
        let score = 0;
        for (const ind of indicators) {
            try {
                if (fm.fileExists(fm.joinPath(p, ind))) score++;
            } catch (e) {}
        }
        return score >= 2; // pelo menos 2 indicadores = é sysdiagnose
    }

    if (!isSysdiagnoseFolder(folderPath)) {
        // Tenta descer um nível: lista subpastas e procura uma que pareça sysdiagnose
        let foundChild = null;
        try {
            const contents = fm.listContents(folderPath);
            okItems.push(`Pasta tem ${contents.length} itens: ${contents.slice(0, 8).join(", ")}${contents.length > 8 ? "..." : ""}`);
            for (const item of contents) {
                const subPath = fm.joinPath(folderPath, item);
                let isDir = false;
                try { isDir = fm.isDirectory(subPath); } catch (e) {}
                if (!isDir) continue;
                // Match sysdiagnose_AAAA.MM.DD_*
                if (item.match(/^sysdiagnose_/i) || isSysdiagnoseFolder(subPath)) {
                    foundChild = subPath;
                    break;
                }
            }
        } catch (e) {
            warnings.push("Erro listando pasta: " + String(e));
        }

        if (foundChild) {
            okItems.push(`Descendendo para sysdiagnose: ${foundChild.split("/").slice(-1)[0]}`);
            folderPath = foundChild;
        } else {
            // ABORTA com mensagem clara
            alerts.push("PASTA SELECIONADA NAO EH UM SYSDIAGNOSE");
            alerts.push("Esperado: pasta contendo logs/, summaries/, ps.txt, etc.");
            alerts.push("Confirme que:");
            alerts.push("  1. O .tar.gz foi EXTRAIDO no Files app");
            alerts.push("     (toca-segura no .tar.gz → Uncompress)");
            alerts.push("  2. Selecionou a pasta extraida (nome: sysdiagnose_*)");
            alerts.push("     NAO a pasta-pai do Files");
            alerts.push("  3. Dentro da pasta tem logs/, summaries/, ps.txt etc.");
            const stats = { events: 0, bundles: 0, domains: 0, ips: 0 };
            await buildResultTable(stats).present(true);
            return;
        }
    }
    okItems.push(`✓ Confirmado como sysdiagnose folder`);

    // 1. Apps instalados + install history (via mobile_installation.log)
    await scanSysdiagnoseApplications(folderPath, fm);
    // 2. Configuration profiles (logs/MCState/Shared/profile-*.stub)
    await scanSysdiagnoseProfiles(folderPath, fm);
    // 3. Network state (NetworkExtension + Prefs + WiFi)
    await scanSysdiagnoseNetwork(folderPath, fm);
    // 4. Lockdown + MobileActivation (jailbreak indicators)
    await scanSysdiagnoseLockdownAndActivation(folderPath, fm);
    // 5. System info (iOS version + swcutil + remotectl)
    await scanSysdiagnoseSystemInfo(folderPath, fm);
    // 6. Process listing (ps.txt + taskinfo.txt)
    await scanSysdiagnoseProcesses(folderPath, fm);
    // 7. Crash logs
    await scanSysdiagnoseCrashes(folderPath, fm);

    // Build UI
    const stats = {
        events: 0, bundles: 0, domains: 0, ips: 0,
    };
    await buildResultTable(stats).present(true);

    // Save option
    const s = new Alert();
    s.title = "Salvar análise sysdiagnose?";
    s.message = "Salvar relatório TXT?";
    s.addAction("Sim");
    s.addCancelAction("Não");
    if ((await s.present()) === 0) {
        const sfm = FileManager.iCloud();
        const ts = new Date().toISOString().replace(/[:\.]/g, "-").substring(0, 19);
        const path = sfm.joinPath(sfm.documentsDirectory(), `a4ther_sysdiag_${ts}.txt`);
        sfm.writeString(path, buildTextReport(stats));
        const d = new Alert();
        d.title = "Salvo";
        d.message = path;
        d.addAction("OK");
        await d.present();
    }
}

function joinFolderPath(folder, sub, fm) {
    return fm.joinPath(folder, sub);
}

function tryReadFile(folder, candidates, fm) {
    for (const c of candidates) {
        const p = joinFolderPath(folder, c, fm);
        try {
            if (fm.fileExists(p)) {
                const raw = fm.readString(p);
                if (raw && raw.length > 0) return { path: p, raw };
            }
        } catch (e) { /* ignore */ }
    }
    return null;
}

function tryListDir(folder, sub, fm) {
    const p = joinFolderPath(folder, sub, fm);
    try {
        if (fm.fileExists(p) && fm.isDirectory(p)) {
            return { path: p, files: fm.listContents(p) };
        }
    } catch (e) { /* ignore */ }
    return null;
}

async function scanSysdiagnoseApplications(folder, fm) {
    okItems.push("── Apps instalados (mobile_installation.log) ──");
    // PATH CORRETO confirmado: logs/MobileInstallation/mobile_installation.log[.0|.1|...]
    // (não tem "summaries/Applications.txt" canônico em sysdiagnose puro)
    let combinedRaw = "";
    const logCandidates = [
        "logs/MobileInstallation/mobile_installation.log",
        "logs/MobileInstallation/mobile_installation.log.0",
        "logs/MobileInstallation/mobile_installation.log.1",
        "logs/MobileInstallation/mobile_installation.log.2",
        "logs/MobileInstallation/mobile_installation.log.3",
    ];
    let logsFound = [];
    for (const c of logCandidates) {
        const p = joinFolderPath(folder, c, fm);
        try {
            if (fm.fileExists(p)) {
                const raw = fm.readString(p);
                if (raw) {
                    combinedRaw += raw + "\n";
                    logsFound.push(c.split("/").pop());
                }
            }
        } catch (e) {}
    }
    // Fallback: tenta nomes de pasta variantes
    if (!combinedRaw) {
        for (const subdir of ["logs/MobileInstallation", "MobileInstallation", "mobile_installation"]) {
            const lr = tryListDir(folder, subdir, fm);
            if (lr) {
                for (const f of lr.files) {
                    if (!f.match(/^mobile_installation\.log/)) continue;
                    const p = fm.joinPath(lr.path, f);
                    try {
                        const raw = fm.readString(p);
                        if (raw) { combinedRaw += raw + "\n"; logsFound.push(f); }
                    } catch (e) {}
                }
                if (combinedRaw) break;
            }
        }
    }
    if (!combinedRaw) {
        warnings.push("logs/MobileInstallation/mobile_installation.log não encontrado");
        return;
    }
    okItems.push(`Logs lidos: ${logsFound.join(", ")}`);

    // Extrai bundle IDs de eventos "Install succeeded for <bundle>" ou "Uninstall succeeded for <bundle>"
    const installEvents = [];
    const uninstallEvents = [];
    const bundles = new Set();
    const lines = combinedRaw.split("\n");
    for (const line of lines) {
        // Padrão típico: "Install succeeded for com.dts.freefireth at ..."
        let m = line.match(/Install succeeded for ([a-zA-Z0-9._-]+)/i);
        if (m) {
            bundles.add(m[1]);
            installEvents.push(line);
            continue;
        }
        m = line.match(/Uninstall succeeded for ([a-zA-Z0-9._-]+)/i);
        if (m) {
            bundles.add(m[1]);
            uninstallEvents.push(line);
            continue;
        }
        // Fallback: qualquer bundle ID na linha
        const bm = line.match(/\b([a-z][a-z0-9_-]+(?:\.[a-zA-Z0-9_-]+){2,})\b/i);
        if (bm) {
            const b = bm[1];
            if (!b.includes("/") && !/^\d/.test(b)) bundles.add(b);
        }
    }
    okItems.push(`${bundles.size} bundle IDs distintos no log`);
    okItems.push(`${installEvents.length} eventos install, ${uninstallEvents.length} eventos uninstall`);

    // CHEAT_APPS check
    let cheatHits = 0;
    for (const b of bundles) {
        if (CHEAT_APPS[b]) {
            const sev = CHEAT_SEVERITY[b] || "MEDIUM";
            const desc = CHEAT_APPS[b];
            const msg = `[${sev}] ${b} — ${desc}`;
            if (sev === "CRITICAL" || sev === "HIGH") alerts.push("[sysdiag/apps] " + msg);
            else warnings.push("[sysdiag/apps] " + msg);
            cheatHits++;
        }
    }
    if (cheatHits === 0) okItems.push("Nenhum cheat app instalado");

    // FF official
    let ffFound = 0;
    for (const ff of FF_OFFICIAL) {
        if (bundles.has(ff)) {
            okItems.push(`Free Fire oficial: ${ff}`);
            ffFound++;
        }
    }
    // FF non-official re-sign
    for (const b of bundles) {
        if (b.toLowerCase().includes("freefire") && !FF_OFFICIAL.has(b) && !CHEAT_APPS[b]) {
            alerts.push(`[sysdiag/apps] Bundle FF NÃO oficial (re-sign): ${b}`);
        }
    }
    // Keyword heuristic
    for (const b of bundles) {
        if (CHEAT_APPS[b]) continue;
        if (b.startsWith("com.apple.") || b.startsWith("com.google.") ||
            b.startsWith("com.facebook.") || b.startsWith("com.microsoft.") ||
            FF_OFFICIAL.has(b)) continue;
        const bl = b.toLowerCase();
        for (const kw of SUSPECT_KEYWORDS) {
            if (bl.includes(kw)) {
                warnings.push(`[sysdiag/apps] Bundle por padrão de nome [${kw}]: ${b}`);
                break;
            }
        }
    }
}

async function scanSysdiagnoseProfiles(folder, fm) {
    okItems.push("── Configuration Profiles (MCState) ──");
    // PATH CORRETO confirmado: logs/MCState/Shared/profile-*.stub (binary plists)
    // + logs/MCState/Shared/MCSettingsEvents.plist (eventos)
    const candidates = [
        "logs/MCState/Shared",
        "logs/MCState",
        "MCState/Shared",
        // fallbacks legados (caso o sysdiagnose seja extraído de FFS)
        "Managed_Configuration_Profiles",
        "managed_configuration_profiles",
    ];
    let dirInfo = null;
    for (const c of candidates) {
        const r = tryListDir(folder, c, fm);
        if (r) { dirInfo = r; break; }
    }
    if (!dirInfo) {
        okItems.push("logs/MCState/Shared não encontrado (device sem profiles)");
        return;
    }
    okItems.push(`Pasta: ${dirInfo.path.split("/").slice(-2).join("/")}`);

    let profileCount = 0;
    let stubsFound = 0;
    for (const f of dirInfo.files) {
        // profile-*.stub são os profiles instalados (binary plists)
        if (!f.match(/\.(mobileconfig|plist|stub)$/i)) continue;
        const full = fm.joinPath(dirInfo.path, f);
        let raw = "";
        try { raw = fm.readString(full); } catch (e) {}
        if (!raw) {
            try {
                const data = fm.read(full);
                raw = data.toRawString();
            } catch (e) {}
        }
        if (!raw || raw.length < 30) continue;
        profileCount++;
        if (f.endsWith(".stub")) stubsFound++;
        // Use analyzeProfile com noReset + prefix
        analyzeProfile(raw, { noReset: true, filePrefix: `MCState/${f}` });
    }
    okItems.push(`${profileCount} profiles analisados (${stubsFound} stubs)`);

    // MCSettingsEvents.plist tem o histórico de install/remove de profiles
    const eventsCandidates = [
        "logs/MCState/Shared/MCSettingsEvents.plist",
        "MCState/Shared/MCSettingsEvents.plist",
    ];
    const er = tryReadFile(folder, eventsCandidates, fm);
    if (er) {
        okItems.push(`MCSettingsEvents.plist presente (${er.raw.length} bytes)`);

        // Extrai profile identifiers no conteúdo (XML ou binary com strings ASCII)
        const profileIdRegex = /(com\.[a-zA-Z][a-zA-Z0-9._-]+(?:profile)?(?:-[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})?)/gi;
        const profileIds = new Set();
        let m;
        while ((m = profileIdRegex.exec(er.raw)) !== null) {
            const pid = m[1];
            // Filtra entries Apple legítimas
            if (pid.startsWith("com.apple.") &&
                !pid.includes("profile") &&
                !pid.includes("mdm")) continue;
            profileIds.add(pid);
        }

        // Timestamps no plist (formato ISO ou epoch)
        const timestamps = er.raw.match(/\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}/g) || [];

        // Cada profile encontrado
        for (const pid of profileIds) {
            // Pattern: profile com UUID opaco = NextDNS / DNS reseller / MDM
            const hasUUID = /[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/.test(pid);
            const isDNS = /nextdns|controld|control-d|adguard.*dns|cloudflare.*warp/i.test(pid);

            if (hasUUID && isDNS) {
                alerts.push(`[CRITICAL] DNS profile com UUID opaco: ${pid}`);
                alerts.push(`   → NextDNS/ControlD/AdGuard-tipo, redireciona DNS = MITM em FF login`);
            } else if (hasUUID) {
                alerts.push(`[HIGH] Profile com UUID opaco (MDM/reseller): ${pid}`);
            } else if (isDNS) {
                alerts.push(`[HIGH] DNS reseller profile: ${pid}`);
            } else if (CHEAT_APPS[pid]) {
                alerts.push(`[CRITICAL] Profile catalogado: ${pid}`);
            } else if (/(esign|feather|ksign|gbox|scarlet|sideload|trollstore)/i.test(pid)) {
                alerts.push(`[CRITICAL] Profile de cert sideloader: ${pid}`);
            } else if (!pid.startsWith("com.apple.")) {
                warnings.push(`[MEDIUM] Profile não-Apple: ${pid}`);
            }
        }

        // Contagem geral
        const installCount = (er.raw.match(/InstallProfile|installProfile|Install Profile/gi) || []).length;
        const removeCount = (er.raw.match(/RemoveProfile|removeProfile|Remove Profile/gi) || []).length;
        if (installCount > 0) okItems.push(`MCSettingsEvents: ${installCount} install events`);
        if (removeCount > 0) {
            warnings.push(`MCSettingsEvents: ${removeCount} REMOVE events (profile foi removido - limpeza?)`);
            // Indica histórico de profile removido (sinal forte que houve atividade)
            if (profileIds.size > 0) {
                warnings.push(`   → ${profileIds.size} profile(s) identifier(s) presentes nos eventos`);
            }
        }
        if (timestamps.length > 0) okItems.push(`Timestamps no plist: ${timestamps[0]} ... ${timestamps[timestamps.length - 1]}`);

        // Cheat keywords genéricas
        const cheatHit = er.raw.match(/esign|feather|ksign|gbox|scarlet|sideload|trollstore|cheat|hack/i);
        if (cheatHit) alerts.push(`[sysdiag/MCState] MCSettingsEvents tem keyword cheat: ${cheatHit[0]}`);
    }
}

async function scanSysdiagnoseInstallLogs(folder, fm) {
    okItems.push("── Install / Uninstall history ──");
    const candidates = [
        "mobile_installation_logs/mobile_installation.log.0",
        "mobile_installation_logs/mobile_installation.log",
        "mobile_installation/mobile_installation.log.0",
        "logs/MobileInstallation/mobile_installation.log.0",
    ];
    const r = tryReadFile(folder, candidates, fm);
    if (!r) {
        // Tenta listar a pasta e pegar o primeiro .log
        const lr = tryListDir(folder, "mobile_installation_logs", fm) ||
                   tryListDir(folder, "logs/MobileInstallation", fm);
        if (lr) {
            okItems.push(`Logs dir: ${lr.path.split("/").pop()}, ${lr.files.length} arquivos`);
            // Pega o primeiro .log e lê
            for (const f of lr.files) {
                if (f.endsWith(".log") || f.endsWith(".log.0")) {
                    const p = fm.joinPath(lr.path, f);
                    let raw = "";
                    try { raw = fm.readString(p); } catch (e) {}
                    if (raw) {
                        parseInstallLog(raw);
                        return;
                    }
                }
            }
        }
        warnings.push("Logs de instalação não encontrados");
        return;
    }
    okItems.push(`Arquivo: ${r.path.split("/").pop()}`);
    parseInstallLog(r.raw);
}

function parseInstallLog(raw) {
    // Grep linhas relevantes
    const lines = raw.split("\n");
    const installEvents = [];
    const removeEvents = [];
    for (const line of lines) {
        const ll = line.toLowerCase();
        // Bundle FF ou cheat na linha?
        const isFFOrCheat = ll.includes("freefire") || ll.includes("dts.freefire") ||
                            ll.includes("garena") || ll.includes("cheat") ||
                            ll.includes("trollstore") || ll.includes("esign") ||
                            ll.includes("feather") || ll.includes("ksign");
        if (!isFFOrCheat) continue;
        if (ll.includes("install")) installEvents.push(line);
        else if (ll.includes("uninstall") || ll.includes("remove") || ll.includes("delete")) {
            removeEvents.push(line);
        }
    }
    if (installEvents.length > 0) {
        okItems.push(`${installEvents.length} eventos de install relevantes`);
        for (const e of installEvents.slice(-5)) {
            warnings.push(`[install] ${e.substring(0, 200)}`);
        }
    }
    if (removeEvents.length > 0) {
        alerts.push(`[sysdiag/install] ${removeEvents.length} eventos de UNINSTALL relevantes (recente?):`);
        for (const e of removeEvents.slice(-5)) {
            alerts.push(`  ${e.substring(0, 200)}`);
        }
    }
}

async function scanSysdiagnoseNetwork(folder, fm) {
    okItems.push("── Network state (NetworkExtension + Prefs + WiFi) ──");

    // 1. logs/Networking/com.apple.networkextension.plist — VPN/NE clients ativos
    const neCandidates = [
        "logs/Networking/com.apple.networkextension.plist",
        "logs/Networking/com.apple.networkextension.cache.plist",
        "Networking/com.apple.networkextension.plist",
    ];
    const ne = tryReadFile(folder, neCandidates, fm);
    if (ne) {
        okItems.push(`NetworkExtension: ${ne.path.split("/").pop()}`);
        // Extrai bundle IDs de NE clients
        const neBundleRegex = /\b[a-zA-Z][a-zA-Z0-9_-]+(?:\.[a-zA-Z0-9_-]+){2,}\b/g;
        const neBundles = new Set();
        let m;
        while ((m = neBundleRegex.exec(ne.raw)) !== null) {
            const b = m[0];
            if (b.includes("/") || /^\d/.test(b)) continue;
            // Filtra Apple frameworks
            if (b.startsWith("com.apple.") && !b.includes("vpn")) continue;
            neBundles.add(b);
        }
        if (neBundles.size > 0) {
            okItems.push(`NE clients detectados: ${neBundles.size}`);
            for (const b of neBundles) {
                if (CHEAT_APPS[b]) {
                    const sev = CHEAT_SEVERITY[b] || "MEDIUM";
                    alerts.push(`[sysdiag/NE] CHEAT VPN ATIVA: ${b} — ${CHEAT_APPS[b]}`);
                } else if (b.toLowerCase().includes("vpn") || b.toLowerCase().includes("proxy")) {
                    warnings.push(`[sysdiag/NE] VPN/Proxy: ${b}`);
                }
            }
        }
    } else {
        okItems.push("Nenhum NetworkExtension ativo (sem VPN/proxy)");
    }

    // 2. Preferences/SystemConfiguration/preferences.plist — DNS, proxy global
    const prefsCandidates = [
        "Preferences/SystemConfiguration/preferences.plist",
        "preferences/SystemConfiguration/preferences.plist",
        "logs/preferences/SystemConfiguration/preferences.plist",
    ];
    const prefs = tryReadFile(folder, prefsCandidates, fm);
    if (prefs) {
        okItems.push(`SystemConfiguration prefs: ${prefs.path.split("/").pop()}`);
        const proxyMatch = prefs.raw.match(/HTTPProxy[^a-zA-Z]+([0-9.]+)/i);
        if (proxyMatch) alerts.push(`[sysdiag/prefs] HTTPProxy global: ${proxyMatch[1]}`);
        const httpsMatch = prefs.raw.match(/HTTPSProxy[^a-zA-Z]+([0-9.]+)/i);
        if (httpsMatch) alerts.push(`[sysdiag/prefs] HTTPSProxy global: ${httpsMatch[1]}`);
        const pacMatch = prefs.raw.match(/ProxyAutoConfigURLString[^<]*<string>([^<]+)/i);
        if (pacMatch) alerts.push(`[sysdiag/prefs] PAC URL: ${pacMatch[1]}`);
        // DNS servers
        const dnsServers = prefs.raw.match(/ServerAddresses[\s\S]{0,400}/g) || [];
        for (const ds of dnsServers.slice(0, 3)) {
            const ips = ds.match(/(\d+\.\d+\.\d+\.\d+)/g);
            if (ips) {
                for (const ip of ips) {
                    // Whitelist DNS Apple/Google/Cloudflare comuns
                    if (["8.8.8.8", "8.8.4.4", "1.1.1.1", "1.0.0.1"].includes(ip)) {
                        okItems.push(`DNS: ${ip} (público comum)`);
                    } else {
                        warnings.push(`[sysdiag/dns] DNS custom: ${ip}`);
                    }
                }
            }
        }
    }

    // 3. WiFi info
    const wifiCandidates = [
        "WiFi/com.apple.wifi.plist",
        "WiFi/com.apple.wifi.known-networks.plist",
    ];
    for (const wc of wifiCandidates) {
        const wf = tryReadFile(folder, [wc], fm);
        if (wf) {
            okItems.push(`WiFi: ${wc.split("/").pop()} (${wf.raw.length} bytes)`);
            // Procura ProxyHost/ProxyPort/PacFileUrl em config Wi-Fi
            if (/Proxy(Host|Port|Server)/.test(wf.raw)) {
                alerts.push(`[sysdiag/wifi] Wi-Fi com proxy POR SSID em ${wc.split("/").pop()}`);
            }
        }
    }

    // 4. Procura cheat infra em todos os arquivos network coletados
    const allNetRaw = (ne && ne.raw ? ne.raw : "") + (prefs && prefs.raw ? prefs.raw : "");
    for (const [indicator, desc] of Object.entries(KNOWN_CHEAT_INFRA)) {
        if (allNetRaw.toLowerCase().includes(indicator.toLowerCase())) {
            alerts.push(`[sysdiag/net] CHEAT INFRA em network config: ${indicator} — ${desc}`);
        }
    }
}

async function scanSysdiagnoseLockdownAndActivation(folder, fm) {
    okItems.push("── Lockdown / MobileActivation (JB detect) ──");

    // lockdownd.log — anomalias indicam JB
    const ld = tryReadFile(folder, [
        "logs/MobileLockdown/lockdownd.log",
        "logs/lockdownd.log",
    ], fm);
    if (ld) {
        okItems.push(`lockdownd.log: ${ld.raw.length} bytes`);
        // Procura entradas suspeitas
        const susp = ld.raw.split("\n").filter(l =>
            /jailbreak|jb\.|tweakloader|substitute|substrate|trollstore|dopamine|amfid|bypass/i.test(l)
        ).slice(0, 5);
        for (const l of susp) {
            alerts.push(`[sysdiag/lockdownd] ${l.substring(0, 180)}`);
        }
    }

    // mobileactivationd.log — activation
    const ma = tryReadFile(folder, [
        "logs/MobileActivation/mobileactivationd.log",
        "logs/MobileActivation/mobileactivationd.log.0",
    ], fm);
    if (ma) {
        okItems.push(`mobileactivationd.log: ${ma.raw.length} bytes`);
        // Procura por activation com server não-Apple ou bypass
        const bypass = ma.raw.split("\n").filter(l =>
            /bypass|patched|spoofed|cracked|fake/i.test(l)
        ).slice(0, 5);
        for (const l of bypass) {
            alerts.push(`[sysdiag/activation] ${l.substring(0, 180)}`);
        }
    }
}

async function scanSysdiagnoseSystemInfo(folder, fm) {
    okItems.push("── System Info ──");

    // iOS version
    const sv = tryReadFile(folder, [
        "logs/SystemVersion/SystemVersion.plist",
        "System/Library/CoreServices/SystemVersion.plist",
    ], fm);
    if (sv) {
        const verMatch = sv.raw.match(/ProductVersion[\s\S]{0,100}<string>([^<]+)/);
        const buildMatch = sv.raw.match(/ProductBuildVersion[\s\S]{0,100}<string>([^<]+)/);
        if (verMatch) okItems.push(`iOS: ${verMatch[1]} (build ${buildMatch ? buildMatch[1] : "?"})`);
    }

    // swcutil_show.txt — apps com associated domains (Universal Links)
    const swc = tryReadFile(folder, ["swcutil_show.txt"], fm);
    if (swc) {
        okItems.push(`swcutil_show.txt: ${swc.raw.length} bytes`);
        // Extrai bundle IDs e domínios associados
        const swcBundles = new Set();
        const swcBundleRegex = /App ID:\s*[A-Z0-9]+\.([a-zA-Z][a-zA-Z0-9._-]+)/g;
        let m;
        while ((m = swcBundleRegex.exec(swc.raw)) !== null) {
            swcBundles.add(m[1]);
        }
        if (swcBundles.size > 0) {
            okItems.push(`Apps com Universal Links: ${swcBundles.size}`);
            for (const b of swcBundles) {
                if (CHEAT_APPS[b]) {
                    alerts.push(`[sysdiag/swcutil] CHEAT app com Universal Links: ${b}`);
                }
            }
        }
    }

    // remotectl_dumpstate.txt — system info detalhado
    const rd = tryReadFile(folder, ["remotectl_dumpstate.txt"], fm);
    if (rd) {
        // Procura JB indicators
        const jbHints = rd.raw.split("\n").filter(l =>
            /jailbroken|trollstore|sileo|cydia|frida|substrate|dopamine|palera1n/i.test(l)
        ).slice(0, 3);
        for (const l of jbHints) {
            alerts.push(`[sysdiag/remotectl] ${l.substring(0, 180)}`);
        }
    }
}

async function scanSysdiagnoseProcesses(folder, fm) {
    okItems.push("── Processos ──");
    const candidates = [
        "taskinfo.txt",
        "summaries/taskinfo.txt",
        "ps.txt",
        "summaries/ps.txt",
        "ps_thread.txt",
    ];
    const r = tryReadFile(folder, candidates, fm);
    if (!r) {
        warnings.push("taskinfo/ps.txt não encontrado");
        return;
    }
    okItems.push(`Arquivo: ${r.path.split("/").pop()}`);

    // Greppa processos suspeitos
    const patterns = [
        "frida", "frida-server", "frida-gadget", "cycript", "gdb", "lldb", "debugserver",
        "substrated", "Substrate", "MobileSubstrate",
        "cheat", "hack", "aimbot", "injector",
        "trollstore", "TrollStore", "iSH",
        "Cydia", "Sileo", "Zebra",
    ];
    const lines = r.raw.split("\n");
    for (const p of patterns) {
        const found = lines.filter(l => l.toLowerCase().includes(p.toLowerCase())).slice(0, 3);
        for (const l of found) {
            alerts.push(`[sysdiag/proc] Processo (${p}): ${l.substring(0, 180)}`);
        }
    }
}

async function scanSysdiagnoseCrashes(folder, fm) {
    okItems.push("── Crashes / Spins ──");
    const candidates = [
        "crashes_and_spins",
        "Crashes_and_spins",
        "Library/Logs/CrashReporter",
        "logs/Crashes",
    ];
    let dirInfo = null;
    for (const c of candidates) {
        const r = tryListDir(folder, c, fm);
        if (r) { dirInfo = r; break; }
    }
    if (!dirInfo) {
        warnings.push("Pasta de crashes não encontrada");
        return;
    }
    okItems.push(`Pasta: ${dirInfo.path.split("/").pop()}`);
    okItems.push(`${dirInfo.files.length} arquivos de crash`);

    // Procura crashes do FF ou de Frida/cheat
    let suspectCount = 0;
    for (const f of dirInfo.files) {
        const fl = f.toLowerCase();
        if (fl.includes("freefire") || fl.includes("frida") ||
            fl.includes("cheat") || fl.includes("dts.freefire") ||
            fl.includes("dopamine") || fl.includes("trollstore")) {
            alerts.push(`[sysdiag/crash] Crash relevante: ${f}`);
            suspectCount++;
        }
    }
    if (suspectCount === 0) okItems.push("Nenhum crash relevante");

    // Lê os 3 mais recentes pra ver se conteúdo tem traços
    const sorted = dirInfo.files.slice(0, 5);
    for (const f of sorted) {
        if (!f.match(/\.(ips|crash|panic|json)$/i)) continue;
        const p = fm.joinPath(dirInfo.path, f);
        let raw = "";
        try { raw = fm.readString(p); } catch (e) {}
        if (!raw || raw.length < 100) continue;
        // Procura strings de cheat
        const hits = ["frida-server", "frida-gadget", "libsubstrate", "substitute",
                      "DYLD_INSERT", "Cycript", "cheat", "trolldecrypt"];
        for (const h of hits) {
            if (raw.toLowerCase().includes(h.toLowerCase())) {
                alerts.push(`[sysdiag/crash] ${f} contém: ${h}`);
                break;
            }
        }
    }
}

async function runProfileAnalyzer() {
    const info = new Alert();
    info.title = "Profile File (.mobileconfig)";
    info.message = "Vai abrir o picker pra você selecionar o arquivo .mobileconfig.\n\nDe onde tirar:\n• Profile baixado de algum site (verificar ANTES de instalar)\n• Profile exportado via Apple Configurator 2 no Mac\n• Profile salvo em Files / iCloud Drive\n\nO scanner extrai todos PayloadTypes + metadata e cruza com lista de cheat services.";
    info.addAction("Selecionar arquivo");
    info.addCancelAction("Pular");
    if ((await info.present()) === -1) return;

    let profile;
    try { profile = await loadProfileFile(); }
    catch (e) {
        const a = new Alert();
        a.title = "Erro";
        a.message = String(e);
        a.addAction("OK");
        await a.present();
        return;
    }

    const result = analyzeProfile(profile.raw);
    await buildProfileTable(result).present(true);

    // Opcional: salvar relatório
    const s = new Alert();
    s.title = "Salvar análise?";
    s.message = "Salvar relatório TXT?";
    s.addAction("Sim");
    s.addCancelAction("Não");
    if ((await s.present()) === 0) {
        const fm = FileManager.iCloud();
        const ts = new Date().toISOString().replace(/[:\.]/g, "-").substring(0, 19);
        const path = fm.joinPath(fm.documentsDirectory(), `a4ther_profile_${ts}.txt`);
        const lines = [];
        lines.push("=========================================");
        lines.push(`  A4ther Systems v${VERSION} | LS Aluguel`);
        lines.push("  iOS Profile Analyzer");
        lines.push(`  ${new Date().toISOString()}`);
        lines.push(`  Source: ${profile.path}`);
        lines.push("=========================================");
        lines.push("");
        lines.push("--- METADATA ---");
        if (result.metadata.displayName)  lines.push(`  DisplayName:  ${result.metadata.displayName}`);
        if (result.metadata.identifier)   lines.push(`  Identifier:   ${result.metadata.identifier}`);
        if (result.metadata.organization) lines.push(`  Organization: ${result.metadata.organization}`);
        if (result.metadata.uuid)         lines.push(`  UUID:         ${result.metadata.uuid}`);
        lines.push("");
        lines.push(`--- PAYLOAD TYPES (${result.payloadTypes.length}) ---`);
        for (const pt of result.payloadTypes) {
            const info = PROFILE_PAYLOADS[pt];
            if (info) lines.push(`  [${info.sev}] ${pt} → ${info.desc}`);
            else lines.push(`  [?] ${pt}`);
        }
        if (result.hostNames.length > 0) {
            lines.push("");
            lines.push("--- HOSTNAMES ---");
            for (const h of result.hostNames) lines.push(`  ${h}`);
        }
        if (result.proxyServers.length > 0) {
            lines.push("");
            lines.push("--- PROXY SERVERS ---");
            for (const p of result.proxyServers) lines.push(`  ${p}`);
        }
        if (result.proxyPACs.length > 0) {
            lines.push("");
            lines.push("--- PAC URLs ---");
            for (const u of result.proxyPACs) lines.push(`  ${u}`);
        }
        if (alerts.length > 0) {
            lines.push("");
            lines.push("--- ALERTAS ---");
            for (const a of alerts) lines.push("  [!] " + a);
        }
        if (warnings.length > 0) {
            lines.push("");
            lines.push("--- AVISOS ---");
            for (const w of warnings) lines.push("  [?] " + w);
        }
        fm.writeString(path, lines.join("\n"));
        const d = new Alert();
        d.title = "Salvo";
        d.message = path;
        d.addAction("OK");
        await d.present();
    }
}

await main();
Script.complete();
