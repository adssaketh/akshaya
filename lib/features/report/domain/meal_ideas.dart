import '../../../core/design/tokens/status_kind.dart';
import '../../pantry/domain/stock_logic.dart';
import 'nutrition_table.dart';
import 'report_builder.dart';
import 'report_models.dart';

/// One ingredient a dish needs: any [count] items whose name has one of the
/// [keywords].
final class Need {
  const Need(this.label, this.keywords, {this.count = 1});

  /// What to call it when the pantry has none ("rice", "a vegetable").
  final String label;
  final List<String> keywords;
  final int count;
}

/// Where a dish comes from. South Indian dishes are listed first when the
/// pantry can make several.
enum Cuisine { south, north, any }

/// A simple home dish and what it needs. Salt, oil or ghee, tamarind, curry
/// leaves and the basic spices are assumed to be at home.
final class Dish {
  const Dish(
    this.name,
    this.minutes,
    this.needs,
    this.how, {
    this.vegetarian = true,
    this.cuisine = Cuisine.south,
  });

  final String name;
  final int minutes;
  final List<Need> needs;

  /// One or two plain sentences on how to make it.
  final String how;

  /// False for dishes with egg or meat.
  final bool vegetarian;
  final Cuisine cuisine;
}

// Words that find the same food under its English, Telugu, Tamil, Kannada,
// Malayalam or Hindi name.
const List<String> _toorWords = <String>[
  'toor',
  'tur',
  'arhar',
  'tuvar',
  'pappu',
  'paruppu',
  'thuvaram',
  'togari',
  'kandi pappu',
];
const List<String> _dalWords = <String>[
  ..._toorWords,
  'dal',
  'dhal',
  'moong',
  'mung',
  'masoor',
  'urad',
  'chana dal',
  'pesara',
];
const List<String> _riceWords = <String>[
  'rice',
  'basmati',
  'sona masoori',
  'idli rice',
  'ponni',
  'matta',
  'biyyam',
  'arisi',
];
const List<String> _moongWords = <String>[
  'moong',
  'mung',
  'green gram',
  'pesalu',
  'pasi paruppu',
];
const List<String> _tomatoWords = <String>['tomato', 'tamata', 'tamatar'];
const List<String> _onionWords = <String>[
  'onion',
  'ullipaya',
  'vengayam',
  'pyaz',
  'kanda',
];
const List<String> _gravyBase = <String>[..._onionWords, ..._tomatoWords];
const List<String> _curdWords = <String>[
  'curd',
  'yogurt',
  'yoghurt',
  'dahi',
  'perugu',
  'thayir',
];
const List<String> _coconutWords = <String>[
  'coconut',
  'kobbari',
  'thengai',
  'nariyal',
];
const List<String> _tamarindWords = <String>[
  'tamarind',
  'imli',
  'chintapandu',
  'puli',
];
const List<String> _greens = <String>[
  'spinach',
  'palak',
  'methi',
  'fenugreek leaves',
  'amaranth leaves',
  'thotakura',
  'keerai',
  'gongura',
  'mustard greens',
  'sarson',
];
const List<String> _veg = <String>[
  'carrot',
  'beans',
  'peas',
  'matar',
  'potato',
  'aloo',
  'bangaladumpa',
  'cauliflower',
  'gobi',
  'cabbage',
  'capsicum',
  'brinjal',
  'eggplant',
  'baingan',
  'vankaya',
  'okra',
  'bhindi',
  'ladies finger',
  'bendakaya',
  'vendakkai',
  'pumpkin',
  'gummadikaya',
  'bottle gourd',
  'lauki',
  'sorakaya',
  'ridge gourd',
  'beerakaya',
  'bitter gourd',
  'kakarakaya',
  'ivy gourd',
  'dondakaya',
  'tindora',
  'kovakkai',
  'raw banana',
  'aratikaya',
  'vazhaikkai',
  'drumstick',
  'murungakkai',
  'cluster beans',
  'gavar',
  'beetroot',
  'radish',
  'turnip',
  'zucchini',
  'broccoli',
  'mushroom',
  'sweet corn',
  'cucumber',
  'dosakaya',
  'spinach',
  'palak',
  'methi',
  'tomato',
  'onion',
];
const List<String> _vegNoBase = <String>[
  'carrot',
  'beans',
  'peas',
  'potato',
  'cauliflower',
  'cabbage',
  'capsicum',
  'brinjal',
  'okra',
  'pumpkin',
  'bottle gourd',
  'ridge gourd',
  'bitter gourd',
  'ivy gourd',
  'raw banana',
  'drumstick',
  'cluster beans',
  'beetroot',
  'radish',
  'turnip',
  'cucumber',
];
const List<String> _fruits = <String>[
  'banana',
  'apple',
  'mango',
  'papaya',
  'orange',
  'mosambi',
  'grape',
  'pomegranate',
  'guava',
  'pineapple',
  'watermelon',
  'muskmelon',
  'pear',
  'kiwi',
  'chikoo',
  'sapota',
  'strawberry',
  'jamun',
  'amla',
];
const List<String> _saladVeg = <String>[
  'onion',
  'tomato',
  'cucumber',
  'carrot',
  'lemon',
];

const Need _anyDal = Need('any dal', _dalWords);
const Need _toor = Need('toor dal', _toorWords);
const Need _moong = Need('moong dal', _moongWords);
const Need _rice = Need('rice', _riceWords);
const Need _tomato = Need('tomato', _tomatoWords);
const Need _onion = Need('onion', _onionWords);
const Need _onionOrTomato = Need('onion or tomato', _gravyBase);
const Need _coconut = Need('coconut', _coconutWords);
const Need _tamarind = Need('tamarind', _tamarindWords);
const Need _curd = Need('curd', _curdWords);
const Need _egg = Need('eggs', <String>['egg', 'muttai', 'guddu', 'anda']);
const Need _batter = Need('idli or dosa batter', <String>[
  'idli batter',
  'dosa batter',
  'batter',
]);
const Need _aVeg = Need('a vegetable', _veg);
const Need _twoVeg = Need('two vegetables', _veg, count: 2);

/// The dishes the offline suggestions choose from: mostly South Indian
/// (Andhra, Telangana, Tamil, Karnataka, Kerala), with a few from elsewhere.
const List<Dish> kDishes = <Dish>[
  // ---- Dals, soups and stews (South)
  Dish(
    'Mudda pappu (plain toor dal)',
    20,
    <Need>[_toor],
    'Pressure-cook toor dal with turmeric and a drop of oil until very soft, '
        'mash it and serve hot with rice and ghee.',
  ),
  Dish(
    'Tomato pappu',
    25,
    <Need>[_toor, _tomato],
    'Cook toor dal with chopped tomato, green chilli and turmeric until '
        'soft, mash, and finish with a tempering of mustard, cumin and '
        'curry leaves.',
  ),
  Dish(
    'Palakura pappu (spinach dal)',
    25,
    <Need>[_toor, Need('spinach or leafy greens', _greens)],
    'Boil dal with turmeric, add chopped greens for the last few minutes, '
        'mash and temper with garlic, mustard and red chilli.',
  ),
  Dish(
    'Gongura pappu',
    30,
    <Need>[
      _toor,
      Need('gongura', <String>['gongura', 'sorrel', 'ambadi', 'roselle']),
    ],
    'Boil dal until soft. Saute gongura leaves until they melt, mix into '
        'the dal and temper with garlic and red chilli.',
  ),
  Dish(
    'Dosakaya pappu (cucumber dal)',
    30,
    <Need>[
      _toor,
      Need('yellow cucumber', <String>['cucumber', 'dosakaya']),
    ],
    'Cook dal with diced yellow cucumber and tamarind until soft, then '
        'temper with mustard, cumin and curry leaves.',
  ),
  Dish(
    'Sorakaya pappu (bottle gourd dal)',
    30,
    <Need>[
      _toor,
      Need('bottle gourd', <String>['bottle gourd', 'lauki', 'sorakaya']),
    ],
    'Pressure-cook dal with diced bottle gourd and turmeric, mash lightly '
        'and temper with cumin and curry leaves.',
  ),
  Dish(
    'Mamidikaya pappu (raw mango dal)',
    30,
    <Need>[
      _toor,
      Need('raw mango', <String>['raw mango', 'kairi', 'mamidikaya']),
    ],
    'Cook dal with chunks of raw mango and green chilli until soft, mash and '
        'finish with a mustard and garlic tempering.',
  ),
  Dish(
    'Pappu charu (dal rasam)',
    30,
    <Need>[_toor, _tomato],
    'Simmer tamarind water with tomato, rasam spices and a ladle of '
        'cooked dal, and finish with a tempering of mustard, garlic and '
        'curry leaves.',
  ),
  Dish(
    'Sambar',
    40,
    <Need>[_toor, Need('two vegetables', _vegNoBase, count: 2)],
    'Boil toor dal soft. Cook the vegetables in tamarind water with sambar '
        'powder, add the dal, simmer and temper with mustard and curry '
        'leaves.',
  ),
  Dish(
    'Murungakkai sambar (drumstick sambar)',
    40,
    <Need>[
      _toor,
      Need('drumstick', <String>[
        'drumstick',
        'murungakkai',
        'munakkaya',
        'moringa',
      ]),
    ],
    'Cook drumstick pieces in tamarind water with sambar powder, add soft '
        'toor dal, simmer and temper with mustard and curry leaves.',
  ),
  Dish(
    'Vengaya sambar (onion sambar)',
    35,
    <Need>[_toor, _onion],
    'Fry small onions until soft, add tamarind water and sambar powder, '
        'then the cooked dal, and simmer before the tempering.',
  ),
  Dish(
    'Tomato rasam',
    25,
    <Need>[_tomato, _anyDal],
    'Simmer tomato with tamarind, pepper and cumin, add some cooked dal '
        'water, and temper with mustard and curry leaves.',
  ),
  Dish(
    'Lemon rasam',
    20,
    <Need>[
      Need('lemon', <String>['lemon', 'lime', 'nimbu', 'nimmakaya']),
      _anyDal,
    ],
    'Make a thin rasam with cooked dal water, pepper, cumin and ginger; '
        'add lemon juice after switching off the heat.',
  ),
  Dish(
    'Keerai masiyal (mashed greens)',
    20,
    <Need>[Need('leafy greens', _greens), _anyDal],
    'Boil greens with a spoon of moong dal, mash coarsely and temper with '
        'mustard, cumin and red chilli.',
  ),
  Dish(
    'Poosanikai (pumpkin) kootu',
    30,
    <Need>[
      Need('pumpkin', <String>['pumpkin', 'kaddu', 'gummadikaya']),
      Need('moong or chana dal', <String>[..._moongWords, 'chana dal']),
    ],
    'Cook pumpkin and dal together until soft, add ground coconut and '
        'cumin, and finish with a mustard tempering.',
  ),
  Dish(
    'Vegetable kootu',
    30,
    <Need>[
      Need('a vegetable', _vegNoBase),
      Need('moong or chana dal', <String>[..._moongWords, 'chana dal']),
    ],
    'Boil the vegetable with dal and turmeric, stir in a coconut and cumin '
        'paste, and temper with mustard and curry leaves.',
  ),
  Dish(
    'Majjiga pulusu (buttermilk curry)',
    30,
    <Need>[
      Need('curd or buttermilk', <String>[
        ..._curdWords,
        'buttermilk',
        'majjiga',
      ]),
      Need('a vegetable', _vegNoBase),
    ],
    'Cook okra, pumpkin or cucumber lightly, then stir in whisked curd with '
        'besan, ginger and green chilli and warm gently without boiling.',
  ),
  Dish(
    'Vatha kuzhambu (tamarind curry)',
    35,
    <Need>[_tamarind, Need('a vegetable', _vegNoBase)],
    'Fry the vegetable with mustard and fenugreek, add tamarind water with '
        'sambar powder and simmer until thick.',
  ),

  // ---- Tiffin and breakfast (South)
  Dish(
    'Idli or dosa with chutney',
    10,
    <Need>[_batter],
    'Steam idlis or spread dosas on a hot tawa. Serve with a quick coconut '
        'or tomato chutney.',
  ),
  Dish(
    'Uttapam',
    15,
    <Need>[_batter, _onionOrTomato],
    'Pour thick batter on a tawa, top with chopped onion, tomato and green '
        'chilli, and cook both sides.',
  ),
  Dish(
    'Pesarattu (green moong dosa)',
    25,
    <Need>[
      Need('whole green moong', _moongWords),
      Need('ginger, onion or chilli', <String>[
        'ginger',
        'allam',
        'onion',
        'green chilli',
      ]),
    ],
    'Soak moong overnight, grind with ginger and green chilli, and spread '
        'thin dosas; sprinkle chopped onion on top.',
  ),
  Dish(
    'Adai (mixed dal dosa)',
    30,
    <Need>[Need('two dals', _dalWords, count: 2), _rice],
    'Soak rice and dals, grind coarsely with red chilli and cumin, and cook '
        'thick dosas with a little oil.',
  ),
  Dish(
    'Rava dosa',
    20,
    <Need>[
      Need('rava', <String>['rava', 'sooji', 'suji', 'semolina']),
      _curd,
    ],
    'Mix rava, rice flour and curd into a thin batter with cumin and '
        'pepper, rest 15 minutes and cook lacy dosas.',
  ),
  Dish(
    'Upma',
    20,
    <Need>[
      Need('rava', <String>['rava', 'sooji', 'suji', 'semolina']),
      _onion,
    ],
    'Roast the rava. Temper mustard, curry leaves, onion and chilli, add hot '
        'water and the rava, and stir until it thickens.',
  ),
  Dish(
    'Semiya upma (vermicelli upma)',
    20,
    <Need>[
      Need('vermicelli', <String>['vermicelli', 'semiya']),
      _aVeg,
    ],
    'Roast the vermicelli, temper mustard and vegetables, add water and '
        'cook until the strands are soft and dry.',
  ),
  Dish(
    'Ragi mudde (finger-millet balls)',
    25,
    <Need>[
      Need('ragi flour', <String>['ragi', 'finger millet', 'nachni']),
    ],
    'Stir ragi flour into boiling salted water until it forms a smooth '
        'dough, shape into balls and serve with sambar or pappu.',
  ),
  Dish(
    'Ragi dosa',
    20,
    <Need>[
      Need('ragi flour', <String>['ragi', 'finger millet', 'nachni']),
      _onion,
    ],
    'Mix ragi flour with water, chopped onion, cumin and curry leaves into '
        'a thin batter and cook crisp dosas.',
  ),
  Dish(
    'Ragi ambali (buttermilk porridge)',
    15,
    <Need>[
      Need('ragi flour', <String>['ragi', 'finger millet', 'nachni']),
      Need('curd or buttermilk', <String>[
        ..._curdWords,
        'buttermilk',
        'majjiga',
      ]),
    ],
    'Cook ragi flour in water into a smooth porridge, cool, and stir in '
        'buttermilk with a pinch of salt and cumin.',
  ),
  Dish(
    'Ven pongal',
    30,
    <Need>[_rice, _moong],
    'Roast moong dal, cook with rice until very soft and creamy, then add '
        'a ghee tempering of pepper, cumin, ginger and cashew.',
  ),
  Dish(
    'Sakkarai pongal (sweet pongal)',
    30,
    <Need>[
      _rice,
      _moong,
      Need('jaggery', <String>['jaggery', 'bellam', 'vellam', 'gur', 'sugar']),
    ],
    'Cook rice and roasted moong dal until soft, stir in melted jaggery, '
        'cardamom and ghee-roasted cashew.',
  ),
  Dish(
    'Bisi bele bath',
    45,
    <Need>[_rice, _toor, Need('two vegetables', _vegNoBase, count: 2)],
    'Cook rice, toor dal and vegetables together until soft, add tamarind '
        'and bisi bele bath powder, and finish with ghee.',
  ),
  Dish(
    'Medu vada',
    40,
    <Need>[
      Need('urad dal', <String>['urad', 'minapa', 'minappappu', 'black gram']),
    ],
    'Soak and grind urad dal into a fluffy batter with pepper and curry '
        'leaves, shape rings and deep-fry until golden.',
  ),
  Dish(
    'Pesara punugulu (moong fritters)',
    30,
    <Need>[
      Need('moong dal', _moongWords),
      Need('ginger, onion or chilli', <String>[
        'ginger',
        'onion',
        'green chilli',
      ]),
    ],
    'Grind soaked moong dal coarsely with chilli and ginger, drop small '
        'spoonfuls into hot oil and fry until crisp.',
  ),
  Dish(
    'Neer dosa',
    20,
    <Need>[_rice, _coconut],
    'Grind soaked rice with grated coconut into a thin batter and cook '
        'lacy, soft dosas without turning.',
  ),
  Dish(
    'Idiyappam (string hoppers)',
    25,
    <Need>[
      Need('rice flour', <String>['rice flour']),
    ],
    'Knead rice flour with hot water and salt, press into strings through '
        'a mould and steam for ten minutes.',
  ),

  // ---- Rice dishes (South)
  Dish(
    'Tomato bath (tomato rice)',
    20,
    <Need>[_rice, _tomato],
    'Cook tomato with onion and spice powder until soft, then mix in cooked '
        'rice and a squeeze of lemon.',
  ),
  Dish(
    'Chitranna (lemon rice)',
    15,
    <Need>[
      _rice,
      Need('lemon', <String>['lemon', 'lime', 'nimbu', 'nimmakaya']),
    ],
    'Temper mustard, peanuts, curry leaves and turmeric, mix into cooked '
        'rice with lemon juice and salt.',
  ),
  Dish(
    'Pulihora (tamarind rice)',
    30,
    <Need>[_rice, _tamarind],
    'Cook thick tamarind paste with mustard, chilli and peanuts, then mix '
        'into cooked rice with a spoon of sesame oil.',
  ),
  Dish(
    'Perugu annam (curd rice)',
    15,
    <Need>[_rice, _curd],
    'Mash soft cooked rice with curd and salt, then top with a tempering '
        'of mustard, curry leaves and green chilli.',
  ),
  Dish(
    'Coconut rice',
    20,
    <Need>[_rice, _coconut],
    'Temper mustard, chana dal, peanuts and curry leaves, add grated '
        'coconut and mix into cooked rice.',
  ),
  Dish(
    'Vangi bath (brinjal rice)',
    35,
    <Need>[
      _rice,
      Need('brinjal', <String>['brinjal', 'eggplant', 'baingan', 'vankaya']),
    ],
    'Cook brinjal with vangi bath powder and tamarind, then fold into '
        'cooked rice with a ghee tempering.',
  ),

  // ---- Vegetable curries and fries (South)
  Dish(
    'Cabbage poriyal',
    20,
    <Need>[
      Need('cabbage', <String>['cabbage']),
      Need('dal or coconut', <String>[
        ..._moongWords,
        'chana dal',
        ..._coconutWords,
      ]),
    ],
    'Temper mustard and curry leaves, add shredded cabbage and a spoon of '
        'soaked dal, cook dry and finish with coconut.',
  ),
  Dish(
    'Beans poriyal',
    20,
    <Need>[
      Need('beans', <String>['beans', 'green beans', 'french beans']),
      Need('dal or coconut', <String>[
        ..._moongWords,
        'chana dal',
        ..._coconutWords,
      ]),
    ],
    'Temper mustard and dal, add finely chopped beans and cook covered '
        'until tender; finish with grated coconut.',
  ),
  Dish(
    'Carrot poriyal',
    20,
    <Need>[
      Need('carrot', <String>['carrot', 'gajar']),
      Need('dal or coconut', <String>[
        ..._moongWords,
        'chana dal',
        ..._coconutWords,
      ]),
    ],
    'Saute grated or diced carrot with mustard and curry leaves, cook '
        'briefly and finish with coconut.',
  ),
  Dish(
    'Beetroot poriyal',
    25,
    <Need>[
      Need('beetroot', <String>['beetroot']),
      _coconut,
    ],
    'Cook diced beetroot with mustard, curry leaves and chilli until soft, '
        'then add grated coconut.',
  ),
  Dish(
    'Bendakaya fry (okra fry)',
    20,
    <Need>[
      Need('okra', <String>[
        'okra',
        'bhindi',
        'ladies finger',
        'bendakaya',
        'vendakkai',
      ]),
    ],
    'Dry the okra well, slice and fry on medium heat with mustard, '
        'turmeric and chilli until crisp at the edges.',
  ),
  Dish(
    'Aratikaya fry (raw banana fry)',
    25,
    <Need>[
      Need('raw banana', <String>[
        'raw banana',
        'plantain',
        'aratikaya',
        'vazhaikkai',
      ]),
    ],
    'Slice raw banana, toss with turmeric, chilli and salt, and shallow-fry '
        'until golden and crisp.',
  ),
  Dish(
    'Dondakaya fry (ivy gourd fry)',
    20,
    <Need>[
      Need('ivy gourd', <String>[
        'ivy gourd',
        'tindora',
        'dondakaya',
        'kovakkai',
        'tendli',
      ]),
    ],
    'Slice ivy gourd lengthwise and fry with mustard, cumin and chilli '
        'powder until browned.',
  ),
  Dish(
    'Bangaladumpa vepudu (potato fry)',
    25,
    <Need>[
      Need('potato', <String>['potato', 'aloo', 'bangaladumpa']),
    ],
    'Cube potatoes and fry with mustard, curry leaves, turmeric and chilli '
        'powder until crisp outside and soft inside.',
  ),
  Dish(
    'Gutti vankaya (stuffed brinjal curry)',
    40,
    <Need>[
      Need('small brinjal', <String>['brinjal', 'eggplant', 'vankaya']),
      Need('peanut, sesame or coconut', <String>[
        'peanut',
        'groundnut',
        'sesame',
        'til',
        ..._coconutWords,
      ]),
    ],
    'Stuff slit brinjals with a ground peanut, sesame and spice mix and '
        'cook gently in a covered pan until soft.',
  ),
  Dish(
    'Vankaya tomato curry',
    30,
    <Need>[
      Need('brinjal', <String>['brinjal', 'eggplant', 'vankaya']),
      _tomato,
    ],
    'Cook brinjal pieces with tomato, turmeric and chilli powder until '
        'soft and the tomato breaks down.',
  ),
  Dish(
    'Beerakaya curry (ridge gourd curry)',
    25,
    <Need>[
      Need('ridge gourd', <String>['ridge gourd', 'beerakaya', 'turai']),
      _onionOrTomato,
    ],
    'Peel and chop ridge gourd, cook with onion or tomato and a little '
        'moong dal until soft and dry.',
  ),
  Dish(
    'Kothavarangai poriyal (cluster beans)',
    25,
    <Need>[
      Need('cluster beans', <String>[
        'cluster beans',
        'gavar',
        'kothavarangai',
      ]),
      _coconut,
    ],
    'Cook chopped cluster beans with mustard, dal and chilli, and finish '
        'with grated coconut.',
  ),
  Dish(
    'Sundal (chickpea tempering)',
    25,
    <Need>[
      Need('chickpeas', <String>['chana', 'chickpea', 'kabuli', 'chole']),
      Need('coconut, onion or lemon', <String>[
        ..._coconutWords,
        'onion',
        'lemon',
      ]),
    ],
    'Boil soaked chickpeas, then toss with a mustard, chilli and curry leaf '
        'tempering and fresh coconut.',
  ),
  Dish(
    'Kadala curry (Kerala black chana curry)',
    40,
    <Need>[
      Need('black chana', <String>[
        'chana',
        'kala chana',
        'black chana',
        'chickpea',
      ]),
      Need('coconut or onion', <String>[..._coconutWords, 'onion']),
    ],
    'Pressure-cook soaked chana, simmer in a roasted coconut and spice '
        'masala, and temper with mustard and curry leaves.',
  ),
  Dish(
    'Avial (mixed vegetables in coconut)',
    35,
    <Need>[Need('three vegetables', _vegNoBase, count: 3), _coconut],
    'Steam mixed vegetables until just tender, stir in a coarse coconut, '
        'green chilli and cumin paste with a little curd, and finish with '
        'coconut oil.',
  ),

  // ---- Chutneys and sides (South)
  Dish(
    'Coconut chutney',
    10,
    <Need>[_coconut],
    'Grind coconut with green chilli, roasted chana dal, salt and a little '
        'water; add a mustard tempering.',
  ),
  Dish(
    'Tomato pachadi (tomato chutney)',
    20,
    <Need>[_tomato],
    'Cook tomato with garlic and red chilli until soft, grind coarsely and '
        'temper with mustard and curry leaves.',
  ),
  Dish(
    'Palli chutney (peanut chutney)',
    10,
    <Need>[
      Need('peanuts', <String>['peanut', 'groundnut', 'palli']),
    ],
    'Roast peanuts, grind with green chilli, tamarind and salt, and temper '
        'with mustard.',
  ),
  Dish(
    'Perugu pachadi (curd raita)',
    5,
    <Need>[
      _curd,
      Need('cucumber, onion or tomato', <String>[
        'cucumber',
        'onion',
        'tomato',
        'carrot',
      ]),
    ],
    'Whisk curd with salt and roasted cumin, stir in finely chopped '
        'vegetables and a mustard tempering.',
  ),
  Dish(
    'Majjiga (buttermilk)',
    5,
    <Need>[_curd],
    'Whisk curd with cold water, salt, a pinch of hing and a few curry '
        'leaves or mint.',
  ),

  // ---- Egg dishes (South); shown when eggs are included
  Dish(
    'Kodi guddu kura (Andhra egg curry)',
    30,
    <Need>[_egg, _onion, _tomato],
    'Boil the eggs. Cook onion, tomato, ginger-garlic and chilli masala, '
        'add the eggs and simmer until the gravy clings.',
    vegetarian: false,
  ),
  Dish(
    'Egg pulusu (tamarind egg curry)',
    30,
    <Need>[_egg, _tamarind, _onionOrTomato],
    'Simmer boiled eggs in an onion and tamarind gravy with chilli and '
        'jaggery until tangy and thick.',
    vegetarian: false,
  ),
  Dish(
    'Muttai podimas (egg bhurji)',
    15,
    <Need>[_egg, _onion],
    'Saute onion, green chilli, curry leaves and turmeric, add beaten eggs '
        'and scramble until just set.',
    vegetarian: false,
  ),
  Dish(
    'Muttai milagu varuval (pepper egg fry)',
    20,
    <Need>[_egg, _onion],
    'Fry sliced onion with plenty of crushed pepper, add halved boiled '
        'eggs and toss until coated.',
    vegetarian: false,
  ),
  Dish(
    'Egg dosa',
    15,
    <Need>[_batter, _egg],
    'Spread dosa batter on a hot tawa, break an egg over it, spread, '
        'sprinkle pepper and flip.',
    vegetarian: false,
  ),
  Dish(
    'Masala omelette',
    10,
    <Need>[
      _egg,
      Need('onion, tomato or chilli', <String>[..._gravyBase, 'green chilli']),
    ],
    'Beat eggs with chopped onion, tomato, green chilli and coriander, and '
        'cook on a greased pan.',
    vegetarian: false,
  ),
  Dish(
    'Egg fried rice',
    20,
    <Need>[_rice, _egg],
    'Scramble eggs in a hot pan, add chopped onion and vegetables, then '
        'cooked rice, pepper and soy sauce or salt.',
    vegetarian: false,
  ),
  Dish(
    'Egg biryani',
    45,
    <Need>[_rice, _egg, _onion],
    'Fry onion and biryani masala, layer with boiled eggs and par-cooked '
        'rice, and steam on low heat.',
    vegetarian: false,
  ),
  Dish(
    'Boiled egg salad',
    10,
    <Need>[_egg, Need('salad vegetable', _saladVeg)],
    'Boil and slice the eggs, toss with onion, tomato, cucumber, lemon, '
        'pepper and salt.',
    vegetarian: false,
    cuisine: Cuisine.any,
  ),

  // ---- Elsewhere in India and everyday meals
  Dish(
    'Dal tadka',
    25,
    <Need>[_anyDal],
    'Boil the dal with turmeric until soft. Temper cumin, garlic and chilli '
        'in ghee or oil, pour it over and add salt.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Moong dal khichdi',
    30,
    <Need>[_rice, _moong],
    'Pressure-cook rice and dal in equal parts with turmeric and salt until '
        'soft. Finish with a spoon of ghee.',
    cuisine: Cuisine.any,
  ),
  Dish(
    'Vegetable pulao',
    30,
    <Need>[_rice, _twoVeg],
    'Fry whole spices and the vegetables, add washed rice and water, and '
        'cook covered until the rice is done.',
    cuisine: Cuisine.any,
  ),
  Dish(
    'Chole masala',
    40,
    <Need>[
      Need('chickpeas', <String>['chana', 'chickpea', 'kabuli', 'chole']),
      _onionOrTomato,
    ],
    'Pressure-cook soaked chickpeas. Simmer them in an onion and tomato '
        'masala until thick.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Rajma masala',
    40,
    <Need>[
      Need('rajma', <String>['rajma', 'kidney bean']),
      _onionOrTomato,
    ],
    'Pressure-cook soaked rajma, then simmer in an onion and tomato masala '
        'until the gravy thickens.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Palak paneer',
    30,
    <Need>[
      Need('spinach', <String>['spinach', 'palak']),
      Need('paneer', <String>['paneer']),
    ],
    'Blanch and blend the spinach. Cook it with onion and spices, then add '
        'paneer cubes and simmer briefly.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Matar paneer',
    30,
    <Need>[
      Need('peas', <String>['peas', 'matar']),
      Need('paneer', <String>['paneer']),
      _tomato,
    ],
    'Cook a tomato and spice gravy, add peas and paneer, and simmer until '
        'the peas are tender.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Paneer bhurji',
    15,
    <Need>[
      Need('paneer', <String>['paneer']),
      _onionOrTomato,
    ],
    'Saute onion and tomato with turmeric and chilli, crumble in the paneer '
        'and cook for a few minutes.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Aloo gobi',
    25,
    <Need>[
      Need('potato', <String>['potato', 'aloo']),
      Need('cauliflower', <String>['cauliflower', 'gobi']),
    ],
    'Saute cumin, then add potato and cauliflower with turmeric and chilli '
        'powder. Cover and cook until soft.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Roti with a seasonal sabzi',
    30,
    <Need>[
      Need('atta', <String>['atta', 'wheat flour', 'whole wheat']),
      _aVeg,
    ],
    'Make rotis from atta. Cook any vegetable with onion, spices and a '
        'little water to go with it.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Aloo paratha',
    25,
    <Need>[
      Need('atta', <String>['atta', 'wheat flour', 'whole wheat']),
      Need('potato', <String>['potato', 'aloo']),
    ],
    'Mash boiled potato with salt and spices, stuff it into atta dough and '
        'cook the parathas with a little ghee.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Besan chilla',
    15,
    <Need>[
      Need('besan', <String>['besan', 'gram flour', 'chickpea flour']),
      _aVeg,
    ],
    'Whisk besan with water, salt and chopped vegetables into a batter and '
        'cook thin pancakes on a hot pan.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Kadhi',
    30,
    <Need>[
      Need('curd or buttermilk', <String>[
        ..._curdWords,
        'buttermilk',
        'chaas',
      ]),
      Need('besan', <String>['besan', 'gram flour']),
    ],
    'Whisk curd with besan and water, simmer with turmeric, and finish with '
        'a cumin and curry leaf tempering.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Poha with peanuts',
    15,
    <Need>[
      Need('poha', <String>['poha', 'aval', 'flattened rice', 'beaten rice']),
      Need('onion or potato', <String>['onion', 'potato', 'peanut']),
    ],
    'Rinse the poha. Temper mustard, curry leaves, onion and turmeric, fold '
        'in the poha with salt and finish with lemon.',
    cuisine: Cuisine.any,
  ),
  Dish(
    'Sabudana khichdi',
    20,
    <Need>[
      Need('sabudana', <String>['sabudana', 'sago']),
      Need('peanuts', <String>['peanut', 'groundnut']),
      Need('potato', <String>['potato', 'aloo']),
    ],
    'Soak sabudana, roast peanuts, saute cumin and diced potato, then fold '
        'in the sabudana until translucent.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Vegetable dalia',
    25,
    <Need>[
      Need('dalia', <String>['dalia', 'daliya', 'broken wheat']),
      _twoVeg,
    ],
    'Saute vegetables, add dalia and water, and pressure-cook until soft.',
    cuisine: Cuisine.any,
  ),
  Dish(
    'Oats porridge',
    10,
    <Need>[
      Need('oats', <String>['oats']),
      Need('milk', <String>['milk']),
    ],
    'Simmer oats in milk for a few minutes and top with chopped fruit or '
        'nuts if you have them.',
    cuisine: Cuisine.any,
  ),
  Dish(
    'Mixed vegetable curry',
    30,
    <Need>[Need('three vegetables', _veg, count: 3)],
    'Cook onion, tomato and spices, add the chopped vegetables with a little '
        'water and simmer until tender.',
    cuisine: Cuisine.any,
  ),
  Dish(
    'Vegetable soup',
    20,
    <Need>[_twoVeg],
    'Simmer chopped vegetables with garlic, pepper and salt, blend if you '
        'like, and serve hot.',
    cuisine: Cuisine.any,
  ),
  Dish(
    'Baingan bharta',
    30,
    <Need>[
      Need('brinjal', <String>['brinjal', 'eggplant', 'baingan', 'vankaya']),
      _onionOrTomato,
    ],
    'Roast the brinjal, peel and mash it, and cook with onion, tomato and '
        'spices.',
    cuisine: Cuisine.north,
  ),
  Dish(
    'Sprouts salad',
    10,
    <Need>[
      Need('sprouts', <String>['sprouts', 'sprouted']),
      Need('salad vegetable', _saladVeg),
    ],
    'Mix the sprouts with chopped vegetables, lemon juice, salt and a pinch '
        'of chaat masala.',
    cuisine: Cuisine.any,
  ),
  Dish(
    'Chana salad',
    10,
    <Need>[
      Need('chickpeas', <String>['chana', 'chickpea', 'kabuli', 'chole']),
      Need('salad vegetable', _saladVeg),
    ],
    'Boil soaked chickpeas, cool them and toss with chopped onion, tomato, '
        'lemon and chaat masala.',
    cuisine: Cuisine.any,
  ),
  Dish(
    'Banana milkshake',
    5,
    <Need>[
      Need('banana', <String>['banana']),
      Need('milk', <String>['milk']),
    ],
    'Blend ripe banana with cold milk, and a few nuts or dates if you have '
        'them.',
    cuisine: Cuisine.any,
  ),
  Dish(
    'Fruit and curd bowl',
    5,
    <Need>[Need('a fruit', _fruits), _curd],
    'Chop the fruit over a bowl of curd. A little honey or jaggery is '
        'optional.',
    cuisine: Cuisine.any,
  ),
  Dish(
    'Fruit salad',
    10,
    <Need>[Need('two fruits', _fruits, count: 2)],
    'Chop the fruit, add a squeeze of lemon and a pinch of chaat masala or '
        'black salt.',
    cuisine: Cuisine.any,
  ),
];

/// A dish the pantry can make, or nearly.
final class MealIdea {
  const MealIdea({
    required this.dish,
    required this.uses,
    required this.fills,
    required this.usesExpiring,
    required this.missing,
  });

  final Dish dish;

  /// Pantry items it would use.
  final List<String> uses;

  /// Plate groups those items cover.
  final Set<PlateGroup> fills;

  /// Items among [uses] that expire soon.
  final List<String> usesExpiring;

  /// What is missing, empty when the pantry can make it now.
  final List<String> missing;

  bool get canMakeNow => missing.isEmpty;
}

/// Dishes to cook from what is in stock: foods that fill the [missing] plate
/// groups and use items that expire soon come first. Dishes missing one thing
/// are included last (at most one), with what to buy. Expired items are never
/// used. When [vegetarian] is true, dishes with egg or meat are left out.
List<MealIdea> suggestMealIdeas({
  required List<ItemStock> stocks,
  List<PlateGroup> missing = const <PlateGroup>[],
  bool vegetarian = true,
  int limit = 6,
}) {
  final List<ItemStock> usable =
      stocks
          .where(
            (ItemStock s) =>
                s.totalRemaining > 0 &&
                s.status != StatusKind.expired &&
                s.status != StatusKind.outOfStock,
          )
          .toList()
        ..sort((ItemStock a, ItemStock b) {
          final int byUrgency =
              (a.status == StatusKind.expiring ? 0 : 1) -
              (b.status == StatusKind.expiring ? 0 : 1);
          return byUrgency != 0
              ? byUrgency
              : a.item.name.compareTo(b.item.name);
        });

  // Each name is prepared once, not once per dish and keyword.
  final Map<ItemStock, String> padded = <ItemStock, String>{
    for (final ItemStock s in usable)
      s: paddedName(s.item.name, s.item.aliases),
  };
  final List<(MealIdea, int)> scored = <(MealIdea, int)>[];
  for (final Dish dish in kDishes) {
    if (vegetarian && !dish.vegetarian) {
      continue;
    }
    final List<ItemStock> chosen = <ItemStock>[];
    final List<String> lacking = <String>[];
    for (final Need need in dish.needs) {
      final List<ItemStock> hits = usable
          .where(
            (ItemStock s) =>
                need.keywords.any((String k) => paddedHasWord(padded[s]!, k)),
          )
          .where((ItemStock s) => !chosen.contains(s))
          .take(need.count)
          .toList();
      if (hits.length >= need.count) {
        chosen.addAll(hits);
      } else {
        lacking.add(need.label);
      }
    }
    // A dish is offered only when the pantry has most of what it needs: never
    // a suggestion built from nothing.
    if (lacking.length > 1 || chosen.isEmpty) {
      continue;
    }
    final Set<PlateGroup> fills = <PlateGroup>{
      for (final ItemStock s in chosen)
        if (plateGroupOf(groupOfItem(s.item)) != null)
          plateGroupOf(groupOfItem(s.item))!,
    };
    final List<String> expiring = <String>[
      for (final ItemStock s in chosen)
        if (s.status == StatusKind.expiring) s.item.name,
    ];
    // Gaps and soon-to-expire items matter most; South Indian dishes get a
    // nudge so they come first when several would do.
    final int score =
        3 * fills.where(missing.contains).length +
        2 * expiring.length +
        fills.length +
        (dish.cuisine == Cuisine.south ? 3 : 0) -
        (lacking.isEmpty ? 0 : 6);
    scored.add((
      MealIdea(
        dish: dish,
        uses: <String>[for (final ItemStock s in chosen) s.item.name],
        fills: fills,
        usesExpiring: expiring,
        missing: lacking,
      ),
      score,
    ));
  }
  scored.sort(((MealIdea, int) a, (MealIdea, int) b) {
    final int byScore = b.$2.compareTo(a.$2);
    return byScore != 0 ? byScore : a.$1.dish.name.compareTo(b.$1.dish.name);
  });

  final List<MealIdea> ready = <MealIdea>[
    for (final (MealIdea, int) e in scored)
      if (e.$1.canMakeNow) e.$1,
  ];
  final List<MealIdea> near = <MealIdea>[
    for (final (MealIdea, int) e in scored)
      if (!e.$1.canMakeNow) e.$1,
  ];
  final List<MealIdea> result = ready.take(limit).toList();
  if (result.length < limit && near.isNotEmpty) {
    result.add(near.first);
  }
  return result;
}
