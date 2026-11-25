#!/usr/bin/env python3
"""Generates the Let Talk keyword/guide pages into website/<slug>/index.html.
Run from repo root: python3 website/_build_guides.py
Facts used (from the app + support page): iPhone app; both people need Let Talk; free to download; 44 languages in the in-app list; messages show the original one tap away with read
receipts; calls: speech -> text -> translation -> subtitles + spoken translation; 8 male + 8 female voices;
calls encrypted in transit; QR add; voice cloning is *coming in 2.0* (not available).
"""
import json, os, html

ROOT = os.path.dirname(os.path.abspath(__file__))
SITE = "https://lettalkapp.com"
APP = "https://apps.apple.com/us/app/let-talk-translate-calls/id6835005338"
TODAY = "2026-11-23"

LANGS = ["English","Spanish","French","German","Italian","Portuguese","Russian","Japanese","Korean","Chinese","Arabic",
 "Hindi","Dutch","Swedish","Norwegian","Danish","Finnish","Polish","Turkish","Thai","Vietnamese","Indonesian","Malay",
 "Filipino","Hebrew","Ukrainian","Czech","Hungarian","Romanian","Bulgarian","Croatian","Slovak","Slovenian","Estonian",
 "Latvian","Lithuanian","Greek","Icelandic","Irish","Welsh","Maltese","Basque","Catalan","Galician"]
assert len(LANGS) == 44

HEAD_COMMON = """    <meta name="apple-itunes-app" content="app-id=6835005338">
    <meta name="robots" content="index, follow">
    <meta name="theme-color" content="#ffb300">
    <link rel="icon" href="/favicon.ico" sizes="any">
    <link rel="icon" type="image/png" sizes="32x32" href="/assets/favicon-32.png">
    <link rel="icon" type="image/png" sizes="96x96" href="/assets/favicon-96.png">
    <link rel="apple-touch-icon" href="/assets/apple-touch-icon.png">
    <link rel="manifest" href="/site.webmanifest">
    <link rel="stylesheet" href="/guides.css">
    <script>
    (function(){var q=new URLSearchParams(location.search),k='lt_src',v=(q.get('src')||q.get('utm_source')||'').toLowerCase().replace(/[^a-z0-9_-]/g,'').slice(0,40);
    try{if(v){sessionStorage.setItem(k,v)}else{v=sessionStorage.getItem(k)||''}}catch(e){}
    if(!v){var r=document.referrer;v=/instagram/.test(r)?'instagram':/facebook|fb\\./.test(r)?'facebook':/tiktok/.test(r)?'tiktok':/google\\./.test(r)?'google':/lettalkapp\\.com/.test(r)?'site':r?'referral':'direct'}
    window.LT_SRC=v;var ct='web-'+v;
    function tag(){document.querySelectorAll('a[href*="apps.apple.com"]').forEach(function(a){var u=new URL(a.href);u.searchParams.set('pt','125247212');u.searchParams.set('ct',ct);u.searchParams.set('mt','8');a.href=u.toString()})}
    if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',tag)}else{tag()}})();
    </script>
    <script>
    !function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?n.callMethod.apply(n,arguments):n.queue.push(arguments)};if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';n.queue=[];t=b.createElement(e);t.async=!0;t.src=v;s=b.getElementsByTagName(e)[0];s.parentNode.insertBefore(t,s)}(window,document,'script','https://connect.facebook.net/en_US/fbevents.js');
    fbq('init','1687391939764616');fbq('track','PageView');
    document.addEventListener('click',function(ev){var a=ev.target.closest&&ev.target.closest('a[href*="apps.apple.com"]');if(a&&window.fbq){fbq('trackCustom','AppStoreClick',{placement:'guide:'+location.pathname.slice(0,40),source:window.LT_SRC||'direct'});fbq('track','Lead',{content_name:'App Store click',content_category:window.LT_SRC||'direct'});}},true);
    </script>
    <noscript><img height="1" width="1" style="display:none" src="https://www.facebook.com/tr?id=1687391939764616&ev=PageView&noscript=1" alt=""/></noscript>"""

NAV = [("/translate-phone-calls/","Phone calls"),("/video-call-translator/","Video calls"),
       ("/translate-text-messages/","Messages"),("/languages/","Languages"),("/support/","Support")]

def header(path):
    links = "".join(f'<a href="{h}"{" aria-current=\"page\"" if h==path else ""}>{t}</a>' for h,t in NAV)
    return f"""<a class="skip" href="#main">Skip to content</a>
<header class="gh"><div class="wrap">
<a class="logo" href="/" aria-label="Let Talk home"><span aria-hidden="true">🍌</span><span>Let Talk</span></a>
<nav class="gnav" aria-label="Main">{links}</nav>
<a class="btn btn-primary btn-small" href="{APP}">Get the app</a>
</div></header>"""

FOOTER = f"""<footer class="gf"><div class="wrap">
<span>© 2026 Lets Talk APP LLC · Let Talk is an iPhone app for translated calls and messages.</span>
<nav aria-label="Footer"><a href="/">Home</a><a href="/translate-phone-calls/">Translate phone calls</a><a href="/video-call-translator/">Video call translator</a><a href="/translate-text-messages/">Translate messages</a><a href="/languages/">Languages</a><a href="/privacy/">Privacy</a><a href="/terms/">Terms</a><a href="/support/">Support</a></nav>
</div></footer>"""

def band(title="Talk to anyone in their language", sub="Let Talk is free to download on the App Store for iPhone."):
    return f"""<div class="wrap"><div class="band">
<h2>{title}</h2><p>{sub}</p>
<a class="btn btn-primary" href="{APP}">Download Let Talk for iPhone →</a>
</div></div>"""

def faq_html(faqs):
    return "\n".join(f"<details><summary>{html.escape(q)}</summary><p>{a}</p></details>" for q,a in faqs)

def strip_tags(s):
    import re
    return re.sub(r"<[^>]+>","",s)

def page(path, title, desc, h1, eyebrow, lede, body, faqs, crumb):
    url = SITE + path
    graph = [
      {"@type":"WebPage","@id":url,"url":url,"name":title,"description":desc,"inLanguage":"en",
       "isPartOf":{"@type":"WebSite","name":"Let Talk","alternateName":["LetTalk","Let Talk app","lettalkapp"],"url":SITE+"/"},
       "about":{"@id":SITE+"/#app"}},
      {"@type":"MobileApplication","@id":SITE+"/#app","name":"Let Talk","alternateName":"LetTalk","operatingSystem":"iOS",
       "applicationCategory":"UtilitiesApplication","url":SITE+"/","downloadUrl":APP,
       "offers":{"@type":"Offer","price":"0","priceCurrency":"USD"}},
      {"@type":"BreadcrumbList","itemListElement":[
        {"@type":"ListItem","position":1,"name":"Let Talk","item":SITE+"/"},
        {"@type":"ListItem","position":2,"name":crumb,"item":url}]},
    ]
    if faqs:
        graph.append({"@type":"FAQPage","mainEntity":[{"@type":"Question","name":q,
            "acceptedAnswer":{"@type":"Answer","text":strip_tags(a)}} for q,a in faqs]})
    ld = json.dumps({"@context":"https://schema.org","@graph":graph}, ensure_ascii=False, indent=1)
    faq_sec = f"""<section class="s" id="faq"><div class="wrap narrow"><h2>Questions</h2>{faq_html(faqs)}</div></section>""" if faqs else ""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{html.escape(title)}</title>
    <meta name="description" content="{html.escape(desc)}">
    <link rel="canonical" href="{url}">
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="Let Talk">
    <meta property="og:url" content="{url}">
    <meta property="og:title" content="{html.escape(title)}">
    <meta property="og:description" content="{html.escape(desc)}">
    <meta property="og:image" content="{SITE}/assets/icon-512.png">
    <meta name="twitter:card" content="summary">
{HEAD_COMMON}
    <script type="application/ld+json">
{ld}
    </script>
</head>
<body>
{header(path)}
<main id="main">
<section class="ghero"><div class="wrap">
<p class="crumbs"><a href="/">Let Talk</a> › {html.escape(crumb)}</p>
<p class="eyebrow">{eyebrow}</p>
<h1>{h1}</h1>
<p class="lede">{lede}</p>
<div class="cta-row"><a class="btn btn-primary" href="{APP}">Get Let Talk on the App Store →</a><span class="cta-note">iPhone · free download</span></div>
</div></section>
{body}
{faq_sec}
{band()}
</main>
{FOOTER}
</body>
</html>
"""

def related(exclude):
    items = [("/translate-phone-calls/","Translate phone calls","Hear each other in your own languages"),
             ("/video-call-translator/","Video call translator","Live translated subtitles on video"),
             ("/translate-text-messages/","Translate text messages","Chat in two languages at once"),
             ("/languages/","All 44 languages","See every language Let Talk supports")]
    a = "".join(f'<a href="{h}">{t}<small>{s}</small></a>' for h,t,s in items if h!=exclude)
    return f'<section class="s"><div class="wrap"><h2>Keep exploring</h2><div class="related">{a}</div></div></section>'

COMMON_FAQ = [
 ("Does the other person need Let Talk?","Yes. Translated calls and messages work between two Let Talk accounts, so the person you're talking to installs Let Talk too. You can add each other by phone number or by scanning a QR code."),
 ("How much does Let Talk cost?","Let Talk is free to download on the App Store."),
 ("Is Let Talk available on Android?","Let Talk is available for iPhone today."),
]

pages = []

# 1. Translate phone calls
pages.append(dict(path="/translate-phone-calls/",
 title="Translate Phone Calls in Real Time on iPhone | Let Talk",
 desc="Let Talk translates phone calls in real time on iPhone. Speak your language, and the other person hears you in theirs, with live subtitles on both sides. 44 languages.",
 crumb="Translate phone calls", eyebrow="Real-time call translator",
 h1='Translate phone calls <span class="grad">as you talk.</span>',
 lede="Let Talk is an iPhone app that translates voice calls live. You speak your language. The other person hears your words in theirs, and you hear their reply in yours.",
 body=f"""
<section class="s"><div class="wrap">
<h2>How real-time call translation works</h2>
<div class="grid g3">
<div class="card"><span class="num">1</span><h3>You speak normally</h3><p>No push-to-talk and no handing your phone back and forth. Just talk the way you would on any call.</p></div>
<div class="card"><span class="num">2</span><h3>Let Talk translates it</h3><p>Your speech is turned into text, translated into the other person's language and shown as subtitles.</p></div>
<div class="card"><span class="num">3</span><h3>They hear it in their language</h3><p>The translation is read aloud in the voice you picked. Their reply comes back to you the same way.</p></div>
</div></div></section>
<section class="s alt"><div class="wrap g2 grid" style="align-items:center">
<div class="prose"><h2>A real conversation, not a phrasebook</h2>
<p>Most translator apps make you take turns holding the phone up to someone. Let Talk works inside the call itself, so it feels like a normal phone call with someone who happens to understand you.</p>
<p>You choose how your translated voice sounds, from 8 male and 8 female voices, and you can preview each one in Settings.</p>
<p>Calls are encrypted in transit.</p></div>
<div class="convo" aria-label="Example translated call">
<p class="who">Mamá says (Spanish)</p><div class="bub in" lang="es">¿Ya comiste, mi amor?<small lang="en">Did you eat yet, my love?</small></div>
<p class="who r">You say (English)</p><div class="bub out">Yes! I made your soup recipe.<small lang="es">¡Sí! Hice tu receta de sopa.</small></div>
</div></div></section>
<section class="s"><div class="wrap narrow prose">
<h2>Who uses a phone call translator</h2>
<ul>
<li><strong>Families split by language.</strong> Grandparents, in-laws and cousins who speak another language.</li>
<li><strong>Travelers.</strong> Call a host, driver or new friend abroad without a phrasebook.</li>
<li><strong>Small businesses.</strong> Talk with suppliers, clients and crews in their own language.</li>
<li><strong>Couples.</strong> Date across a language gap and still say exactly what you mean.</li>
</ul>
<h2 style="margin-top:28px">Let Talk vs. a regular translator app</h2>
<div class="tw"><table>
<tr><th></th><th>Let Talk</th><th>Typical translator app</th></tr>
<tr><td>Works during a live call</td><td>Yes, built into the call</td><td>Usually no. You pass the phone back and forth.</td></tr>
<tr><td>Both sides hear their own language</td><td>Yes</td><td>One side at a time</td></tr>
<tr><td>Subtitles on screen</td><td>Yes</td><td>Varies</td></tr>
<tr><td>Video calls and messages too</td><td>Yes, in the same app</td><td>Usually separate apps</td></tr>
<tr><td>Price</td><td>Free to download</td><td>Often a paid subscription</td></tr>
</table></div>
</div></section>
{related("/translate-phone-calls/")}""",
 faqs=[("Can an app translate a phone call in real time?","Yes. Let Talk translates voice calls live on iPhone. Each person speaks their own language and hears the other person in theirs, with subtitles on screen."),
       *COMMON_FAQ,
       ("How many languages can Let Talk translate?","Let Talk's language list has 44 languages, including Spanish, French, Chinese, Arabic, Japanese, Korean, Portuguese, Hindi and Russian. See the <a href=\"/languages/\">full list</a>."),
       ("Can I choose the voice the other person hears?","Yes. Go to Settings → Voice Settings to preview and pick from 8 male and 8 female voices.")]))

# 2. Video call translator
pages.append(dict(path="/video-call-translator/",
 title="Video Call Translator with Live Subtitles | Let Talk for iPhone",
 desc="Translate video calls live with Let Talk. See each other face to face with translated subtitles and translated speech in 44 languages. iPhone, free download.",
 crumb="Video call translator", eyebrow="Live translated video calls",
 h1='Video calls with <span class="grad">live translated subtitles.</span>',
 lede="See the person you're talking to and understand every word. Let Talk adds translated subtitles and spoken translation to one-on-one video calls on iPhone.",
 body=f"""
<section class="s"><div class="wrap grid g2" style="align-items:center">
<div class="prose"><h2>Face to face, in two languages</h2>
<p>On a Let Talk video call, what the other person says appears as subtitles in your language, and the translation is read aloud. Your words reach them the same way, in theirs.</p>
<p>It's built for conversations where seeing each other matters: meeting a partner's family, checking in with a client, or catching up with a friend overseas.</p></div>
<div class="convo" aria-label="Example translated video call">
<p class="who">Yuki says (Japanese)</p><div class="bub in" lang="ja">会議は三時からです。<small lang="en">The meeting starts at three.</small></div>
<p class="who r">You say (English)</p><div class="bub out">Perfect, I'll send the slides before then.<small lang="ja">了解です。それまでにスライドを送ります。</small></div>
</div></div></section>
<section class="s alt"><div class="wrap">
<h2>What you get on a translated video call</h2>
<div class="grid g3">
<div class="card"><h3>Live subtitles</h3><p>Translated captions show up on screen as the other person speaks.</p></div>
<div class="card"><h3>Spoken translation</h3><p>Hear the translation out loud in a voice you choose.</p></div>
<div class="card"><h3>One app for everything</h3><p>Video calls, voice calls and translated messages all live in Let Talk.</p></div>
</div></div></section>
<section class="s"><div class="wrap narrow prose">
<h2>Good fits for a video call translator</h2>
<ul><li><strong>Business meetings</strong> with suppliers and clients abroad</li>
<li><strong>Meeting the in-laws</strong> when you don't share a language yet</li>
<li><strong>Long-distance relationships</strong> across languages</li>
<li><strong>Language exchange</strong>: see the original next to the translation</li></ul>
</div></section>
{related("/video-call-translator/")}""",
 faqs=[("Is there an app that translates video calls live?","Yes. Let Talk translates one-on-one video calls on iPhone with live subtitles and spoken translation in each person's language."),
       ("Does Let Talk work with Zoom, FaceTime or WhatsApp calls?","No. Let Talk translates calls made inside the Let Talk app. Both people use Let Talk to call each other."),
       *COMMON_FAQ]))

# 3. Translate text messages
pages.append(dict(path="/translate-text-messages/",
 title="Translate Text Messages Automatically | Let Talk Chat Translator",
 desc="Chat with anyone in their language. Let Talk translates messages automatically, so you write in yours and they read it in theirs. The original is one tap away.",
 crumb="Translate text messages", eyebrow="Translated messaging",
 h1='Text in your language. <span class="grad">They read it in theirs.</span>',
 lede="Let Talk is a messaging app with translation built in. Every message arrives already translated into the reader's language, with the original one tap away.",
 body=f"""
<section class="s"><div class="wrap grid g2" style="align-items:center">
<div class="convo" aria-label="Example translated chat">
<p class="who">Camille writes (French)</p><div class="bub in" lang="fr">Tu arrives quand à Paris ?<small lang="en">When do you get to Paris?</small></div>
<p class="who r">You write (English)</p><div class="bub out">Friday morning. Can't wait!<small lang="fr">Vendredi matin. J'ai hâte !</small></div>
<p class="who">Camille</p><div class="bub in" lang="fr">Je viens te chercher 🚗<small lang="en">I'll come pick you up 🚗</small></div>
</div>
<div class="prose"><h2>No copy and paste</h2>
<p>With most translators you copy a message, paste it into another app, then copy the result back. Let Talk does the translating inside the chat, so the conversation just flows.</p>
<p>Read receipts show when a message has been seen. You can also send photos, voice messages, files, contacts and your location.</p></div>
</div></section>
<section class="s alt"><div class="wrap">
<h2>Built for real conversations</h2>
<div class="grid g3">
<div class="card"><h3>Automatic translation</h3><p>Messages show up in the reader's language without any extra steps.</p></div>
<div class="card"><h3>Original one tap away</h3><p>See exactly what was written, which helps when you're learning the language.</p></div>
<div class="card"><h3>Add people by QR code</h3><p>Meet someone, scan their code, and you're connected.</p></div>
</div></div></section>
{related("/translate-text-messages/")}""",
 faqs=[("Is there a messaging app that translates automatically?","Yes. Let Talk translates every message into the reader's language as it arrives, and the original text is one tap away."),
       ("Can I see the original message?","Yes. Tap a translated message to see the original text."),
       *COMMON_FAQ]))

# 4. Pair pages
PAIRS = [
 dict(slug="spanish", name="Spanish", native="Español", code="es",
  lines=[("them","¿Ya comiste, mi amor?","Did you eat yet, my love?"),("you","Not yet. Calling you first!","Todavía no. ¡Primero te llamo a ti!"),("them","Te extraño. ¿Cuándo vienes?","I miss you. When are you coming?")],
  who="Spanish is spoken by around 500 million people across Mexico, Central and South America, Spain and the United States. Let Talk is for the calls that matter: a grandmother in Guadalajara, a coworker on the crew, or a host family in Madrid.",
  uses=["Calling Spanish-speaking family members","Talking with employees, crews and customers","Travel in Mexico, Spain and Latin America","Dating and relationships across English and Spanish"]),
 dict(slug="french", name="French", native="Français", code="fr",
  lines=[("them","Tu arrives à quelle heure à la gare ?","What time do you get to the station?"),("you","Around six. I'll text you when I'm close.","Vers dix-huit heures. Je t'écris quand j'arrive."),("them","Parfait, je t'attends devant.","Perfect, I'll wait for you out front.")],
  who="French is spoken in France, Canada, Belgium, Switzerland and across West and Central Africa. Whether it's relatives in Quebec, friends in Dakar or a trip to Paris, Let Talk translates the conversation both ways.",
  uses=["Family in Haiti, Senegal, Côte d'Ivoire or Quebec","Trips to France, Belgium and Switzerland","Business calls with French-speaking partners","Practicing French with the original text on screen"]),
 dict(slug="japanese", name="Japanese", native="日本語", code="ja",
  lines=[("them","会議は三時からです。","The meeting starts at three."),("you","Got it. I'll send the files before then.","了解です。それまでにファイルを送ります。"),("them","ありがとうございます。よろしくお願いします。","Thank you. I appreciate your help.")],
  who="Japanese is one of the hardest languages for English speakers to pick up quickly. Let Talk lets you hold real conversations with partners, host families and friends in Japan from day one.",
  uses=["Meetings with Japanese clients and suppliers","Host families and exchange programs","Friends and partners in Japan","Trips to Tokyo, Osaka and Kyoto"]),
 dict(slug="chinese", name="Chinese", native="中文", code="zh",
  lines=[("them","你吃饭了吗？","Have you eaten?"),("you","Yes! Let's video chat this weekend.","吃了！周末我们视频聊天吧。"),("them","好啊，周六晚上可以吗？","Sure, does Saturday evening work?")],
  who="Mandarin Chinese has more native speakers than any other language. Let Talk helps with supplier calls, grandparents and in-laws, and students far from home.",
  uses=["Calls with suppliers and manufacturers","Grandparents and in-laws who speak Mandarin","International students staying in touch","Travel in China, Taiwan and Singapore"]),
 dict(slug="arabic", name="Arabic", native="العربية", code="ar", rtl=True,
  lines=[("them","كيف حالك؟ اشتقت إليك.","How are you? I missed you."),("you","I'm good! I'll call you tomorrow evening.","أنا بخير! سأتصل بك غدًا في المساء."),("them","إن شاء الله، أنتظرك.","God willing, I'll be waiting.")],
  who="Arabic connects more than 20 countries, from Morocco to the Gulf. Let Talk translates the conversation between Arabic and English, with right-to-left text shown correctly.",
  uses=["Family in Egypt, Morocco, Iraq, Yemen and the Gulf","Business with partners in the Middle East","Travel across the Arab world","Newcomers and the people helping them settle in"]),
 dict(slug="portuguese", name="Portuguese", native="Português", code="pt",
  lines=[("them","Que saudade! Quando você vem?","I miss you so much! When are you coming?"),("you","I land Saturday morning!","Chego no sábado de manhã!"),("them","Vou te buscar no aeroporto.","I'll pick you up at the airport.")],
  who="Portuguese is spoken in Brazil, Portugal, Angola, Mozambique and beyond. Let Talk keeps the conversation going with family, friends and partners in either direction.",
  uses=["Family and friends in Brazil and Portugal","Business with Brazilian partners","Travel in Brazil, Portugal and Cape Verde","Relationships across Portuguese and English"]),
 dict(slug="korean", name="Korean", native="한국어", code="ko",
  lines=[("them","밥 먹었어?","Did you eat?"),("you","Just did. Let's video call this weekend!","방금 먹었어. 주말에 영상통화 하자!"),("them","좋아! 토요일 어때?","Sounds good! How about Saturday?")],
  who="Korean speakers are a phone call away, whether it's in-laws in Seoul, friends you met online or a business partner in Busan. Let Talk translates the conversation live.",
  uses=["In-laws and family in Korea","Friends you met online","Business calls with Korean companies","Trips to Seoul and Busan"]),
]

for p in PAIRS:
    L = p["name"]; c = p["code"]
    d = ' dir="rtl"' if p.get("rtl") else ""
    bubbles = ""
    for who, said, tr in p["lines"]:
        if who == "them":
            bubbles += f'<p class="who">They say ({L})</p><div class="bub in"><span lang="{c}"{d}>{said}</span><small lang="en">{tr}</small></div>'
        else:
            bubbles += f'<p class="who r">You say (English)</p><div class="bub out">{said}<small lang="{c}"{d}>{tr}</small></div>'
    uses = "".join(f"<li>{u}</li>" for u in p["uses"])
    others = "".join(f'<a href="/{q["slug"]}-english-call-translator/">{q["name"]} ↔ English</a>' for q in PAIRS if q is not p)
    path = f"/{p['slug']}-english-call-translator/"
    pages.append(dict(path=path,
     title=f"{L} to English Call Translator: Live Voice & Video | Let Talk",
     desc=f"Translate calls between {L} and English in real time. Let Talk translates voice calls, video calls and messages both ways on iPhone, with live subtitles.",
     crumb=f"{L} ↔ English", eyebrow=f"{L} ↔ English · {p['native']}",
     h1=f'{L} to English, <span class="grad">live on every call.</span>',
     lede=f"Talk with {L} speakers in real time. You speak English and they hear {L}. They speak {L} and you hear English. Voice calls, video calls and messages all work this way.",
     body=f"""
<section class="s"><div class="wrap grid g2" style="align-items:center">
<div class="prose"><h2>{L} ↔ English, both directions</h2><p>{p['who']}</p>
<p>Each person sets their own language in Settings. Let Talk handles the translation both ways, so neither of you has to switch languages.</p></div>
<div class="convo" aria-label="Example {L} and English conversation">{bubbles}</div>
</div></section>
<section class="s alt"><div class="wrap narrow prose">
<h2>Popular reasons people translate {L} calls</h2><ul>{uses}</ul>
<h2 style="margin-top:28px">Other language pairs</h2><div class="langs">{others}<a href="/languages/">All 44 languages</a></div>
</div></section>
{related("")}""",
     faqs=[(f"Can I translate a phone call from {L} to English?", f"Yes. Let Talk translates live voice and video calls between {L} and English on iPhone. You hear English, they hear {L}, and subtitles show on screen."),
           (f"Does it work from English to {L} too?", f"Yes. Translation works both ways. Each person sets their own language, and Let Talk translates in both directions."),
           *COMMON_FAQ]))

# 5. Languages hub
_pair = {q["name"]: q["slug"] for q in PAIRS}
chips = "".join(f'<a href="/{_pair[l]}-english-call-translator/">{l}</a>' if l in _pair else f"<span>{l}</span>" for l in LANGS)
pages.append(dict(path="/languages/",
 title="Let Talk Supported Languages: 44 Languages for Calls & Messages",
 desc="Let Talk translates calls and messages in 44 languages, including Spanish, French, Chinese, Arabic, Japanese, Korean, Portuguese, Hindi, Russian and more.",
 crumb="Languages", eyebrow="Supported languages",
 h1='44 languages. <span class="grad">One app.</span>',
 lede="Pick your language, they pick theirs, and Let Talk translates calls and messages between the two.",
 body=f"""
<section class="s"><div class="wrap narrow prose">
<h2>Every language in Let Talk</h2>
<p>Highlighted languages have their own guide pages.</p>
<div class="langs">{chips}</div>
<h2 style="margin-top:32px">How language settings work</h2>
<p>Set your language once in Settings. When you call or message someone, Let Talk translates from your language into theirs and back again. The app also remembers the languages you use most, so they stay at the top of the list.</p>
</div></section>
{related("/languages/")}""",
 faqs=[("How many languages does Let Talk support?","Let Talk's language list has 44 languages: " + ", ".join(LANGS) + "."),
       ("Can two people use different languages on the same call?","Yes. That's the point of Let Talk. Each person speaks and hears their own language."),
       *COMMON_FAQ[:2]]))

for p in pages:
    out = os.path.join(ROOT, p["path"].strip("/"), "index.html")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write(page(p["path"], p["title"], p["desc"], p["h1"], p["eyebrow"], p["lede"], p["body"], p["faqs"], p["crumb"]))
    print("wrote", p["path"])

# sitemap
urls = [("/", TODAY), ("/privacy/", "2026-11-13"), ("/terms/", "2026-11-13"), ("/support/", "2026-11-14")] + [(p["path"], TODAY) for p in pages]
sm = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + \
     "".join(f"  <url>\n    <loc>{SITE}{u}</loc>\n    <lastmod>{d}</lastmod>\n  </url>\n" for u,d in urls) + "</urlset>\n"
open(os.path.join(ROOT, "sitemap.xml"), "w").write(sm)
print("sitemap:", len(urls), "urls")
