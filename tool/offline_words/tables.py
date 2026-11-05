# Word tables shared by the Python prototype and the generated Dart file.
# Forms are written naturally here; gen_dart.py / proto.py normalise them.
import regex

NUKTA_MAP = {
    'क़': 'क', 'ख़': 'ख', 'ग़': 'ग', 'ज़': 'ज',
    'ड़': 'ड', 'ढ़': 'ढ', 'फ़': 'फ', 'य़': 'य',
}
DIGIT_MAP = {}
for i in range(10):
    DIGIT_MAP[chr(0x0966 + i)] = str(i)
    DIGIT_MAP[chr(0x0C66 + i)] = str(i)
REMOVE = {'‌', '‍', '़'}


def normalize_text(s: str) -> str:
    s = s.lower()
    out = []
    for ch in s:
        if ch in REMOVE:
            continue
        ch = NUKTA_MAP.get(ch, ch)
        ch = DIGIT_MAP.get(ch, ch)
        if ch == 'ँ':
            ch = 'ं'
        elif ch == 'ఁ':
            ch = 'ం'
        out.append(ch)
    return ''.join(out)


TOKEN_RE = regex.compile(r'[\p{L}\p{M}]+|\d+(?:[.,/]\d+)?|[½¼¾]|[,;.।|\n&+]')


def tokenize(s: str):
    return TOKEN_RE.findall(normalize_text(s))


def words(text):
    return [normalize_text(w.strip()) for w in text.split(',') if w.strip()]


def table(mapping):
    out = {}
    for value, text in mapping:
        for w in words(text):
            assert w not in out or out[w] == value, (w, out[w], value)
            out[w] = value
    return out


NUMBER_WORDS = table([
    (0.5, 'half, ara, అర, aadha, adha, aadhi, adhi, आधा, आधी, आधे'),
    (0.25, 'quarter, pavu, paav, pav, pao, పావు, पाव'),
    (1.25, 'sawa, सवा'),
    (1.5, 'dedh, डेढ़, onnara, okkatinnara, ఒకటిన్నర'),
    (2.5, 'dhai, adhai, ढाई, rendunnara, రెండున్నర'),
    (1, 'one, ek, एक, okati, okkati, oka, okka, ఒకటి, ఒక'),
    (2, 'two, do, दो, rendu, remdu, రెండు'),
    (3, 'three, teen, तीन, moodu, mudu, మూడు'),
    (4, 'four, char, chaar, चार, nalugu, nalgu, నాలుగు'),
    (5, 'five, panch, paanch, पांच, aidu, ayidu, ఐదు'),
    (6, 'six, chhe, chhah, chah, छह, छः, aaru, aru, ఆరు'),
    (7, 'seven, saat, सात, edu, ఏడు'),
    (8, 'eight, aath, आठ, enimidi, ఎనిమిది'),
    (9, 'nine, nau, नौ, tommidi, తొమ్మిది'),
    (10, 'ten, das, दस, padi, పది'),
    (12, 'twelve, barah, baarah, बारह'),
])

UNIT_WORDS = table([
    ('kg', 'kg, kgs, kilo, kilos, kilogram, kilograms, kilolu, కిలో, కిలోలు, కేజీ, కేజీలు, కిలోగ్రాము, किलो, किलोग्राम, केजी'),
    ('g', 'g, gm, gms, gram, grams, gramme, gramulu, గ్రాము, గ్రాములు, గ్రా, ग्राम, ग्रा'),
    ('l', 'l, lt, ltr, ltrs, liter, liters, litre, litres, litrelu, litru, లీటర్, లీటరు, లీటర్లు, లీటరులు, లీ, लीटर, लिटर'),
    ('ml', 'ml, mls, millilitre, milliliter, ఎంఎల్, మిల్లీలీటర్, मिली, मिलीलीटर'),
    ('packet', 'packet, packets, pkt, pkts, pack, packs, packetlu, పాకెట్, ప్యాకెట్, ప్యాకెట్లు, పాకెట్లు, पैकेट, पैकेट्स'),
    ('dozen', 'dozen, dozens, dzn, darjan, డజను, డజన్, డజనులు, दर्जन, दरजन'),
    ('pcs', 'piece, pieces, pc, pcs, nos, mukka, mukkalu, ముక్క, ముక్కలు, tukda, tukde, टुकड़ा, टुकड़े, नग, nag'),
    ('bunch', 'bunch, bunches, katta, kattalu, కట్ట, కట్టలు, గుత్తి, guchha, गुच्छा, गुच्छे, gaddi, गड्डी, जुड़ी'),
])

INTENT_WORDS = table([
    ('add', 'add, adding, put, insert, veyyi, veyi, veyyandi, cherchu, cherchandi, jodinchu, jodo, jodna, jod, daalo, dalo, daal, daalna, dalna, యాడ్, ఆడ్, వేయి, వెయ్యి, చేర్చు, చేర్చండి, जोड़ो, जोड़ें, जोड़ना, ऐड, डालो, डाल, डालें, डालना'),
    ('need', 'need, needs, needed, want, wants, buy, get, bring, order, kavali, kaavali, kavalsi, kavalani, konali, konaali, konalsi, chahiye, chahie, chahiyen, lena, lana, kharidna, kharidni, కావాలి, కావాలని, కొనాలి, चाहिए, चाहिये, लेना, खरीदना, खरीदनी'),
    ('bought', 'bought, purchased, got, brought, picked, konnanu, konnaanu, kontini, konnamu, tecchanu, techanu, tecchaanu, techaanu, kharida, kharidi, kharide, laya, laaya, laye, lai, కొన్నాను, తెచ్చాను, కొన్నా, खरीदा, खरीदी, खरीदे, लाया, लाई, लाए'),
    ('use', 'use, used, using, consumed, took, cooked, vaadesanu, vadesanu, vaadesaanu, vaadanu, vadanu, vaadaanu, vaadina, vadina, vaadukunnanu, vadukunnanu, vaadesaam, istemal, istemaal, istamal, kharch, kharcha, vaadam, వాడేశాను, వాడాను, వాడిన, వాడుకున్నాను, ఉపయోగించాను, इस्तेमाल, खर्च, खर्चा'),
    ('finished', 'finished, finish, over, empty, ended, gone, out, khatam, khatm, khatham, khalas, samapt, ayipoyindi, ayipoyindhi, ayipoyayi, ayipoyaayi, ayipoindi, aipoyindi, aipoyayi, aipoindi, ayipoyina, aipoyina, ledu, ledhu, లేదు, అయిపోయింది, అయిపోయాయి, అయిపోయినవి, అయిపోయిన, ఐపోయింది, ఖతం, खत्म, खतम, खलास, समाप्त'),
    ('remove', 'remove, delete, cancel, hatao, hata, hatado, nikalo, nikaal, teeseyyi, teeseyandi, teesey, teeseyyandi, teesiveyyi, teesiveyandi, tiseyyi, తీసేయి, తీసెయ్యి, తీసివేయి, తీసేయండి, తీసివేయండి, हटाओ, हटा, हटाइए, निकालो, निकाल'),
    ('queryExpiring', 'expiring, expire, expires, expiry, expired, expiries, spoil, spoiling, spoilt, spoiled, gaduvu, గడువు'),
    ('queryStock', 'stock, left, remaining, how, much, many, kitna, kitni, kitne, entha, enta, enni, ఎంత, ఎన్ని, कितना, कितनी, कितने, baki, baaki, bacha, bachi, migilindi, migilina, మిగిలింది, మిగిలిన, बाकी, बचा, बची'),
    ('list', 'list, lists, shopping, cart, లిస్ట్, లిస్టు, लिस्ट, सूची'),
    ('setStock', 'set, update, adjust, correct, recount'),
])

# Words that say how much is there right now ("rice inka 3 kilo undi"). A
# clause with an amount and one of these, and no other intent word, sets the
# stock. Every word here is also a stop word.
PRESENCE_WORDS = set(words(
    'have, has, is, are, '
    'undi, vundi, unnayi, unnai, vunnayi, '
    'hai, hain, '
    'ఉంది, ఉన్నాయి, వుంది, '
    'है, हैं'
))

SEPARATOR_WORDS = set(words('and, aur, mariyu, plus, then, tatha, और, మరియు'))

STOP_WORDS = set(words(
    # English
    'a, an, the, of, to, in, on, at, for, from, my, me, i, we, our, is, are, was, were, be, it, its, that, this, these, those, '
    'some, please, pls, kindly, now, also, as, with, by, into, there, have, has, had, all, more, again, today, just, '
    'what, which, will, going, about, tell, show, '
    # Telugu romanised
    'cheyyi, cheyyandi, cheyyu, chey, cheyali, cheyyaali, cheshanu, chesaanu, ani, kuda, kooda, lo, loki, lopala, ki, ni, nu, ku, '
    'tho, nunchi, nundi, naaku, naku, nenu, mana, maa, ippudu, inka, inkaa, konchem, undi, unnayi, unnai, vundi, vunnayi, '
    # Hindi romanised
    'mein, me, mei, men, ko, ka, ke, se, hai, hain, tha, thi, the, ho, gaya, gayi, gaye, hua, hui, hue, karo, kar, kare, kijiye, '
    'kijie, dijiye, diya, diye, dena, de, mujhe, mera, meri, mere, hum, humko, hamare, abhi, bhi, wala, wali, wale, jo, yeh, ye, '
    'woh, vo, par, pe, tak, sirf, bas, thoda, zara, kripya, '
    # Telugu script
    'చేయి, చేయండి, చెయ్యి, చేయడి, చేశాను, చేసాను, లో, కి, ను, ని, కు, తో, నుంచి, నుండి, కూడా, ఉంది, ఉన్నాయి, వుంది, ఇంకా, '
    'ఇప్పుడు, నాకు, నేను, ఈ, ఆ, కొంచెం, అని, మా, మన, దయచేసి, '
    # Hindi script
    'में, मे, को, की, का, के, से, है, हैं, था, थी, थे, हो, गया, गयी, गई, गए, हुआ, हुई, हुए, करो, कर, करें, कीजिए, दीजिए, दिया, '
    'मुझे, मेरा, मेरी, मेरे, हम, अभी, भी, वाला, वाली, वाले, जो, यह, ये, वह, वो, पर, पे, तक, सिर्फ, बस, थोड़ा, कृपया'
))

# Latin plural endings tried when a word is not found as written.
