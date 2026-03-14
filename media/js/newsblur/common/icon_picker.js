// Reusable icon picker component for folder and feed icons
// Used by reader_feed_exception.js for both folder and feed icon selection

NEWSBLUR.IconPicker = {
    // Search terms for icons: icon name -> array of searchable synonyms/keywords
    // Keys use the icon filename (without extension). Values include the icon name itself,
    // its category, and semantic synonyms so "bike" matches bicycle, cycling, etc.
    ICON_SEARCH_TERMS: {
        // === Lucide outline icons ===
        // Files
        'folder': ['folder', 'directory', 'files', 'organize'],
        'folder-open': ['folder', 'open', 'directory', 'files'],
        'folder-archive': ['folder', 'archive', 'backup', 'storage', 'zip'],
        'folder-check': ['folder', 'check', 'done', 'complete', 'verified'],
        'folder-cog': ['folder', 'settings', 'config', 'gear', 'cog'],
        'folder-heart': ['folder', 'heart', 'favorite', 'love', 'liked'],
        'folder-minus': ['folder', 'minus', 'remove', 'delete'],
        'folder-plus': ['folder', 'plus', 'add', 'new', 'create'],
        'folders': ['folders', 'multiple', 'directory', 'collection'],
        'file': ['file', 'document', 'page', 'paper'],
        'file-text': ['file', 'text', 'document', 'article', 'page', 'paper', 'writing'],
        'file-badge': ['file', 'badge', 'certificate', 'award', 'document'],
        'file-check': ['file', 'check', 'done', 'approved', 'verified', 'document'],
        'file-cog': ['file', 'settings', 'config', 'gear', 'document'],
        'file-lock': ['file', 'lock', 'secure', 'private', 'encrypted', 'document'],
        'files': ['files', 'documents', 'multiple', 'pages', 'papers'],
        'archive': ['archive', 'box', 'storage', 'backup', 'old'],
        'clipboard': ['clipboard', 'paste', 'copy', 'notes', 'checklist'],
        'inbox': ['inbox', 'mail', 'email', 'messages', 'received'],
        'layers': ['layers', 'stack', 'overlap', 'design', 'depth'],
        // Places
        'home': ['home', 'house', 'residence', 'dwelling', 'main'],
        'house': ['house', 'home', 'residence', 'dwelling', 'building'],
        'building': ['building', 'office', 'workplace', 'business', 'skyscraper', 'tower'],
        'building-2': ['building', 'office', 'workplace', 'business', 'corporate'],
        'store': ['store', 'shop', 'retail', 'market', 'business', 'shopping'],
        'landmark': ['landmark', 'monument', 'government', 'bank', 'museum', 'institution'],
        'factory': ['factory', 'industry', 'manufacturing', 'production', 'warehouse'],
        'warehouse': ['warehouse', 'storage', 'logistics', 'factory', 'depot'],
        'castle': ['castle', 'palace', 'fortress', 'medieval', 'kingdom', 'royal'],
        'church': ['church', 'religion', 'chapel', 'worship', 'cathedral', 'faith'],
        'hospital': ['hospital', 'medical', 'health', 'clinic', 'emergency', 'doctor'],
        'tent': ['tent', 'camping', 'outdoor', 'adventure', 'shelter'],
        'mountain': ['mountain', 'peak', 'summit', 'hiking', 'nature', 'hill', 'climb'],
        'fence': ['fence', 'yard', 'boundary', 'garden', 'property', 'barrier'],
        'school': ['school', 'education', 'classroom', 'learning', 'academy', 'university'],
        // Favorites
        'star': ['star', 'favorite', 'rating', 'bookmark', 'important', 'featured'],
        'heart': ['heart', 'love', 'like', 'favorite', 'health', 'romance', 'valentine'],
        'heart-handshake': ['heart', 'handshake', 'charity', 'donate', 'care', 'partnership'],
        'bookmark': ['bookmark', 'save', 'favorite', 'read later', 'mark'],
        'flag': ['flag', 'report', 'mark', 'country', 'nation', 'important'],
        'tag': ['tag', 'label', 'category', 'price', 'metadata'],
        'tags': ['tags', 'labels', 'categories', 'metadata', 'multiple'],
        'award': ['award', 'prize', 'achievement', 'ribbon', 'recognition'],
        'crown': ['crown', 'king', 'queen', 'royal', 'premium', 'vip', 'best'],
        'gem': ['gem', 'diamond', 'jewel', 'precious', 'ruby', 'valuable'],
        'diamond': ['diamond', 'gem', 'jewel', 'precious', 'luxury', 'valuable'],
        'sparkles': ['sparkles', 'magic', 'special', 'new', 'glitter', 'shine', 'ai'],
        'trophy': ['trophy', 'winner', 'champion', 'prize', 'award', 'cup', 'achievement'],
        'medal': ['medal', 'award', 'achievement', 'prize', 'winner', 'olympics'],
        // Reading
        'book': ['book', 'read', 'reading', 'literature', 'library', 'novel', 'study'],
        'book-open': ['book', 'open', 'read', 'reading', 'study', 'literature'],
        'book-marked': ['book', 'bookmark', 'read', 'saved', 'marked', 'reading'],
        'library': ['library', 'books', 'reading', 'study', 'collection', 'archive'],
        'newspaper': ['newspaper', 'news', 'press', 'media', 'article', 'journal', 'daily'],
        'scroll': ['scroll', 'ancient', 'document', 'parchment', 'history', 'torah'],
        'notebook': ['notebook', 'journal', 'diary', 'notes', 'writing', 'pad'],
        'graduation-cap': ['graduation', 'cap', 'education', 'university', 'college', 'degree', 'school', 'academic'],
        'brain': ['brain', 'mind', 'think', 'intelligence', 'smart', 'neuroscience', 'idea'],
        'kanban': ['kanban', 'board', 'project', 'agile', 'tasks', 'workflow', 'trello'],
        'sticker': ['sticker', 'label', 'badge', 'tag', 'note'],
        // Audio
        'music': ['music', 'song', 'audio', 'melody', 'note', 'tune', 'sound', 'musical'],
        'headphones': ['headphones', 'audio', 'music', 'listen', 'earbuds', 'sound'],
        'headset': ['headset', 'audio', 'gaming', 'call center', 'microphone', 'support'],
        'mic': ['mic', 'microphone', 'record', 'voice', 'audio', 'speak', 'podcast', 'sing'],
        'radio': ['radio', 'broadcast', 'fm', 'am', 'station', 'music', 'antenna'],
        'podcast': ['podcast', 'audio', 'show', 'episode', 'listen', 'broadcast', 'radio'],
        'disc': ['disc', 'cd', 'dvd', 'record', 'vinyl', 'album', 'music'],
        'album': ['album', 'music', 'record', 'vinyl', 'collection', 'cd'],
        'boom-box': ['boombox', 'stereo', 'music', 'speaker', 'radio', 'ghettoblaster'],
        'cassette-tape': ['cassette', 'tape', 'retro', 'music', 'vintage', 'recording', 'mixtape'],
        'speaker': ['speaker', 'audio', 'sound', 'volume', 'music', 'loudspeaker'],
        'drum': ['drum', 'percussion', 'music', 'beat', 'rhythm', 'instrument'],
        'bluetooth': ['bluetooth', 'wireless', 'connection', 'pair', 'audio'],
        'signal': ['signal', 'reception', 'wireless', 'antenna', 'connection', 'network', 'cellular'],
        // Visual
        'video': ['video', 'movie', 'film', 'camera', 'record', 'clip', 'cinema'],
        'video-off': ['video', 'off', 'camera', 'disabled', 'mute'],
        'film': ['film', 'movie', 'cinema', 'video', 'reel', 'hollywood'],
        'tv': ['tv', 'television', 'screen', 'monitor', 'watch', 'show', 'display'],
        'monitor': ['monitor', 'screen', 'display', 'computer', 'desktop'],
        'camera': ['camera', 'photo', 'picture', 'photography', 'snapshot', 'image'],
        'image': ['image', 'photo', 'picture', 'gallery', 'graphic'],
        'images': ['images', 'photos', 'pictures', 'gallery', 'collection'],
        'eye': ['eye', 'view', 'see', 'watch', 'visible', 'look', 'visibility'],
        'eye-off': ['eye', 'off', 'hidden', 'invisible', 'hide', 'private'],
        'picture-in-picture': ['picture', 'pip', 'window', 'video', 'overlay', 'float'],
        'youtube': ['youtube', 'video', 'streaming', 'google', 'watch', 'channel'],
        // Games
        'gamepad-2': ['gamepad', 'controller', 'gaming', 'console', 'play', 'xbox', 'playstation', 'nintendo'],
        'joystick': ['joystick', 'gaming', 'arcade', 'controller', 'play', 'retro'],
        'dice-5': ['dice', 'game', 'random', 'chance', 'board game', 'gambling', 'casino'],
        'puzzle': ['puzzle', 'jigsaw', 'game', 'solve', 'brain', 'pieces'],
        'drama': ['drama', 'theater', 'theatre', 'masks', 'acting', 'performance', 'comedy', 'tragedy'],
        'wand': ['wand', 'magic', 'wizard', 'spell', 'fantasy', 'harry potter'],
        'wand-2': ['wand', 'magic', 'wizard', 'spell', 'fantasy'],
        'origami': ['origami', 'paper', 'craft', 'fold', 'art', 'japanese', 'crane'],
        // Sports
        'volleyball': ['volleyball', 'sport', 'ball', 'beach', 'team', 'game', 'athletics'],
        'dumbbell': ['dumbbell', 'gym', 'fitness', 'exercise', 'workout', 'weight', 'strength', 'training', 'lifting'],
        'target': ['target', 'aim', 'goal', 'bullseye', 'archery', 'focus', 'objective'],
        'bike': ['bike', 'bicycle', 'cycling', 'ride', 'pedal', 'cyclist', 'biking', 'motorcycle', 'transport', 'exercise', 'sport'],
        'thumbs-up': ['thumbs up', 'like', 'approve', 'good', 'yes', 'agree', 'positive'],
        // Travel
        'plane': ['plane', 'airplane', 'flight', 'travel', 'airport', 'fly', 'jet', 'aviation'],
        'ship': ['ship', 'boat', 'cruise', 'ocean', 'sea', 'vessel', 'maritime', 'navy'],
        'sailboat': ['sailboat', 'sail', 'boat', 'ocean', 'sea', 'yacht', 'wind', 'sailing', 'nautical'],
        'rocket': ['rocket', 'space', 'launch', 'startup', 'fast', 'nasa', 'spaceship', 'spacecraft'],
        'train': ['train', 'railway', 'railroad', 'transit', 'metro', 'subway', 'locomotive', 'transport'],
        'bus': ['bus', 'transit', 'transport', 'public', 'commute', 'school bus', 'coach'],
        'car': ['car', 'auto', 'automobile', 'vehicle', 'drive', 'driving', 'sedan', 'transport'],
        'tractor': ['tractor', 'farm', 'agriculture', 'field', 'rural', 'farming'],
        'cable-car': ['cable car', 'gondola', 'ski', 'mountain', 'lift', 'aerial', 'tramway'],
        'backpack': ['backpack', 'bag', 'school', 'hiking', 'travel', 'adventure', 'camping', 'rucksack'],
        'compass': ['compass', 'navigation', 'direction', 'explore', 'travel', 'north', 'orient'],
        'navigation': ['navigation', 'direction', 'gps', 'navigate', 'arrow', 'compass', 'location'],
        'map': ['map', 'geography', 'location', 'directions', 'atlas', 'navigation', 'world'],
        'map-pin': ['map', 'pin', 'location', 'place', 'marker', 'gps', 'address', 'destination'],
        // Tech
        'code': ['code', 'programming', 'developer', 'software', 'html', 'css', 'javascript', 'coding', 'brackets'],
        'terminal': ['terminal', 'command line', 'shell', 'console', 'cli', 'bash', 'prompt'],
        'database': ['database', 'data', 'storage', 'sql', 'server', 'table', 'backend'],
        'server': ['server', 'hosting', 'backend', 'api', 'cloud', 'rack', 'datacenter'],
        'cpu': ['cpu', 'processor', 'chip', 'computing', 'hardware', 'silicon'],
        'hard-drive': ['hard drive', 'storage', 'disk', 'hdd', 'ssd', 'memory', 'data'],
        'laptop': ['laptop', 'computer', 'notebook', 'portable', 'macbook', 'device'],
        'computer': ['computer', 'desktop', 'pc', 'mac', 'workstation', 'device'],
        'keyboard': ['keyboard', 'typing', 'keys', 'input', 'hardware'],
        'mouse': ['mouse', 'cursor', 'click', 'pointer', 'input', 'hardware'],
        'printer': ['printer', 'print', 'output', 'paper', 'document', 'office'],
        'usb': ['usb', 'drive', 'flash', 'port', 'cable', 'connection', 'thumb drive'],
        'wifi': ['wifi', 'wireless', 'internet', 'connection', 'network', 'signal'],
        'globe': ['globe', 'world', 'earth', 'internet', 'web', 'international', 'global', 'planet'],
        'rss': ['rss', 'feed', 'subscribe', 'syndication', 'news', 'atom', 'xml'],
        'git-merge': ['git', 'merge', 'branch', 'version control', 'code', 'pull request'],
        'git-branch': ['git', 'branch', 'version control', 'code', 'fork'],
        'webhook': ['webhook', 'api', 'callback', 'integration', 'automation', 'hook'],
        'scan': ['scan', 'qr', 'barcode', 'read', 'detect', 'camera'],
        'settings': ['settings', 'gear', 'config', 'preferences', 'options', 'cog', 'configure'],
        // Nature
        'sun': ['sun', 'sunny', 'day', 'weather', 'bright', 'light', 'summer', 'solar'],
        'sun-dim': ['sun', 'dim', 'sunset', 'dusk', 'twilight', 'low light'],
        'sun-snow': ['sun', 'snow', 'winter', 'cold', 'weather', 'mixed'],
        'sunrise': ['sunrise', 'morning', 'dawn', 'sun', 'day', 'early'],
        'sunset': ['sunset', 'evening', 'dusk', 'sun', 'twilight', 'golden hour'],
        'moon': ['moon', 'night', 'lunar', 'crescent', 'dark', 'sleep'],
        'cloud': ['cloud', 'weather', 'sky', 'overcast', 'hosting', 'storage'],
        'umbrella': ['umbrella', 'rain', 'weather', 'protection', 'shelter', 'wet'],
        'tree-pine': ['tree', 'pine', 'evergreen', 'forest', 'nature', 'christmas', 'conifer'],
        'tree-deciduous': ['tree', 'deciduous', 'oak', 'nature', 'forest', 'park', 'shade'],
        'flower-2': ['flower', 'bloom', 'garden', 'nature', 'plant', 'floral', 'petal', 'rose'],
        'leaf': ['leaf', 'nature', 'plant', 'green', 'eco', 'organic', 'environment'],
        'clover': ['clover', 'luck', 'lucky', 'irish', 'shamrock', 'nature', 'four leaf'],
        'droplets': ['droplets', 'water', 'rain', 'liquid', 'wet', 'splash'],
        'snowflake': ['snowflake', 'snow', 'winter', 'cold', 'ice', 'frozen', 'christmas'],
        'wind': ['wind', 'breeze', 'air', 'weather', 'blow', 'gust'],
        'haze': ['haze', 'fog', 'mist', 'smog', 'weather', 'visibility'],
        'orbit': ['orbit', 'space', 'planet', 'satellite', 'rotation', 'astronomy'],
        'earth': ['earth', 'globe', 'world', 'planet', 'global', 'geography'],
        // Animals
        'bird': ['bird', 'sparrow', 'robin', 'flying', 'wing', 'avian', 'tweet'],
        'cat': ['cat', 'kitten', 'feline', 'pet', 'meow', 'kitty'],
        'dog': ['dog', 'puppy', 'canine', 'pet', 'hound', 'woof', 'bark'],
        'fish': ['fish', 'aquarium', 'ocean', 'sea', 'swim', 'aquatic', 'marine'],
        'rabbit': ['rabbit', 'bunny', 'hare', 'pet', 'animal', 'easter'],
        'turtle': ['turtle', 'tortoise', 'slow', 'shell', 'reptile', 'sea turtle'],
        'bug': ['bug', 'insect', 'beetle', 'pest', 'debug', 'software bug'],
        'feather': ['feather', 'bird', 'quill', 'light', 'writing', 'pen'],
        'egg': ['egg', 'breakfast', 'chicken', 'easter', 'hatch', 'food'],
        'baby': ['baby', 'child', 'infant', 'newborn', 'kid', 'toddler'],
        'shrimp': ['shrimp', 'prawn', 'seafood', 'ocean', 'crustacean'],
        // Food
        'coffee': ['coffee', 'cafe', 'espresso', 'latte', 'cappuccino', 'drink', 'caffeine', 'cup', 'morning'],
        'utensils': ['utensils', 'fork', 'knife', 'eating', 'dining', 'restaurant', 'food', 'cutlery'],
        'chef-hat': ['chef', 'hat', 'cooking', 'kitchen', 'restaurant', 'food', 'baker'],
        'pizza': ['pizza', 'food', 'italian', 'slice', 'pepperoni', 'cheese', 'pie'],
        'sandwich': ['sandwich', 'food', 'lunch', 'bread', 'sub', 'deli'],
        'croissant': ['croissant', 'pastry', 'bread', 'french', 'bakery', 'breakfast'],
        'apple': ['apple', 'fruit', 'food', 'healthy', 'teacher', 'red'],
        'banana': ['banana', 'fruit', 'food', 'yellow', 'tropical'],
        'cherry': ['cherry', 'fruit', 'food', 'red', 'berry'],
        'citrus': ['citrus', 'orange', 'lemon', 'lime', 'fruit', 'vitamin c'],
        'grape': ['grape', 'fruit', 'wine', 'vineyard', 'purple'],
        'carrot': ['carrot', 'vegetable', 'food', 'orange', 'healthy', 'garden'],
        'beef': ['beef', 'meat', 'steak', 'food', 'cow', 'protein', 'bbq', 'grill'],
        'drumstick': ['drumstick', 'chicken', 'food', 'meat', 'poultry', 'leg'],
        'soup': ['soup', 'stew', 'broth', 'food', 'hot', 'bowl', 'warm'],
        'popcorn': ['popcorn', 'snack', 'movie', 'cinema', 'theater', 'corn'],
        'cake': ['cake', 'birthday', 'dessert', 'sweet', 'bakery', 'celebration', 'party'],
        'cookie': ['cookie', 'biscuit', 'sweet', 'dessert', 'snack', 'baking'],
        'lollipop': ['lollipop', 'candy', 'sweet', 'sugar', 'treat', 'dessert'],
        'popsicle': ['popsicle', 'ice pop', 'frozen', 'cold', 'summer', 'treat'],
        'ice-cream-cone': ['ice cream', 'cone', 'dessert', 'frozen', 'sweet', 'summer', 'gelato'],
        'flame': ['flame', 'fire', 'hot', 'burn', 'heat', 'trending', 'popular', 'spicy'],
        'wine': ['wine', 'drink', 'alcohol', 'glass', 'vineyard', 'red', 'white', 'beverage'],
        'martini': ['martini', 'cocktail', 'drink', 'alcohol', 'bar', 'party', 'beverage'],
        'bottle-wine': ['bottle', 'wine', 'drink', 'alcohol', 'beverage'],
        'cup-soda': ['cup', 'soda', 'drink', 'cola', 'pop', 'beverage', 'soft drink'],
        'milk': ['milk', 'dairy', 'drink', 'beverage', 'calcium', 'bottle'],
        // Shopping
        'shopping-cart': ['shopping', 'cart', 'buy', 'store', 'ecommerce', 'purchase', 'retail'],
        'shopping-bag': ['shopping', 'bag', 'buy', 'store', 'retail', 'purchase'],
        'shopping-basket': ['shopping', 'basket', 'buy', 'store', 'grocery', 'market'],
        'gift': ['gift', 'present', 'birthday', 'christmas', 'surprise', 'celebration', 'wrap'],
        'package': ['package', 'box', 'delivery', 'shipping', 'parcel', 'mail'],
        'wallet': ['wallet', 'money', 'payment', 'finance', 'cash', 'purse'],
        'credit-card': ['credit card', 'payment', 'money', 'finance', 'debit', 'bank', 'visa'],
        'coins': ['coins', 'money', 'currency', 'cash', 'finance', 'change'],
        'piggy-bank': ['piggy bank', 'savings', 'money', 'finance', 'save', 'investment'],
        'box': ['box', 'package', 'container', 'storage', 'shipping', 'cardboard'],
        'briefcase': ['briefcase', 'business', 'work', 'office', 'professional', 'job', 'career'],
        'ticket': ['ticket', 'event', 'concert', 'movie', 'admission', 'pass', 'coupon'],
        'barcode': ['barcode', 'scan', 'product', 'price', 'upc', 'inventory'],
        // Home
        'bed': ['bed', 'sleep', 'bedroom', 'rest', 'furniture', 'hotel', 'night'],
        'bath': ['bath', 'bathroom', 'shower', 'tub', 'wash', 'clean', 'hygiene'],
        'lamp': ['lamp', 'light', 'desk', 'reading', 'illuminate', 'glow'],
        'lamp-ceiling': ['lamp', 'ceiling', 'light', 'chandelier', 'illuminate', 'overhead'],
        'lamp-desk': ['lamp', 'desk', 'light', 'office', 'reading', 'study'],
        'lamp-floor': ['lamp', 'floor', 'light', 'standing', 'living room'],
        'refrigerator': ['refrigerator', 'fridge', 'kitchen', 'cold', 'food', 'appliance'],
        'washing-machine': ['washing machine', 'laundry', 'clean', 'clothes', 'appliance'],
        // Health
        'stethoscope': ['stethoscope', 'doctor', 'medical', 'health', 'hospital', 'nurse', 'checkup'],
        'syringe': ['syringe', 'needle', 'injection', 'vaccine', 'medical', 'shot', 'health'],
        'thermometer': ['thermometer', 'temperature', 'fever', 'medical', 'health', 'weather'],
        'thermometer-sun': ['thermometer', 'sun', 'hot', 'temperature', 'heat', 'weather'],
        'test-tube': ['test tube', 'science', 'lab', 'chemistry', 'experiment', 'research'],
        'microscope': ['microscope', 'science', 'lab', 'research', 'biology', 'zoom', 'magnify'],
        // Fashion
        'shirt': ['shirt', 'clothing', 'fashion', 'apparel', 'tshirt', 'clothes', 'wear', 'outfit'],
        'glasses': ['glasses', 'eyewear', 'spectacles', 'vision', 'reading', 'sunglasses', 'fashion'],
        'watch': ['watch', 'time', 'clock', 'wrist', 'accessory', 'fashion', 'smartwatch'],
        // Tools
        'hammer': ['hammer', 'tool', 'build', 'construction', 'nail', 'fix', 'repair'],
        'wrench': ['wrench', 'tool', 'fix', 'repair', 'mechanic', 'plumbing', 'spanner'],
        'scissors': ['scissors', 'cut', 'trim', 'craft', 'tool', 'snip'],
        'ruler': ['ruler', 'measure', 'length', 'tool', 'design', 'straight'],
        'highlighter': ['highlighter', 'marker', 'highlight', 'color', 'emphasize', 'pen'],
        'paintbrush': ['paintbrush', 'paint', 'art', 'draw', 'creative', 'design', 'color'],
        'palette': ['palette', 'art', 'paint', 'color', 'creative', 'design', 'artist'],
        'brush': ['brush', 'paint', 'art', 'clean', 'stroke', 'draw'],
        'pen': ['pen', 'write', 'sign', 'ink', 'fountain pen', 'writing'],
        'pencil-line': ['pencil', 'write', 'draw', 'sketch', 'edit', 'line'],
        'stamp': ['stamp', 'mail', 'postage', 'seal', 'approve', 'rubber stamp'],
        'key': ['key', 'lock', 'access', 'security', 'password', 'unlock'],
        'lock': ['lock', 'security', 'locked', 'password', 'private', 'safe', 'protect'],
        'link': ['link', 'chain', 'url', 'connection', 'hyperlink', 'web'],
        'magnet': ['magnet', 'attract', 'magnetic', 'pull', 'physics'],
        'plug': ['plug', 'electric', 'power', 'socket', 'connect', 'outlet', 'charge'],
        'battery': ['battery', 'power', 'charge', 'energy', 'electric'],
        'flashlight': ['flashlight', 'torch', 'light', 'dark', 'illuminate', 'beam'],
        'hourglass': ['hourglass', 'time', 'timer', 'wait', 'sand', 'patience', 'loading'],
        'timer': ['timer', 'countdown', 'clock', 'time', 'stopwatch', 'alarm'],
        'clock': ['clock', 'time', 'hour', 'schedule', 'watch', 'alarm'],
        'calendar': ['calendar', 'date', 'schedule', 'event', 'planner', 'day', 'month', 'appointment'],
        // Social
        'mail': ['mail', 'email', 'envelope', 'message', 'letter', 'inbox', 'send'],
        'mailbox': ['mailbox', 'mail', 'postal', 'letter', 'delivery'],
        'message-square': ['message', 'chat', 'comment', 'text', 'bubble', 'conversation', 'talk'],
        'message-circle': ['message', 'chat', 'comment', 'text', 'bubble', 'conversation'],
        'phone': ['phone', 'call', 'telephone', 'mobile', 'contact', 'cell'],
        'at-sign': ['at', 'email', 'mention', 'address', 'contact', 'handle'],
        'send': ['send', 'share', 'submit', 'deliver', 'arrow', 'paper plane'],
        'users': ['users', 'people', 'group', 'team', 'community', 'members'],
        'user': ['user', 'person', 'profile', 'account', 'avatar', 'member'],
        'contact': ['contact', 'person', 'address book', 'card', 'info'],
        'hand': ['hand', 'stop', 'wave', 'gesture', 'palm', 'halt'],
        'handshake': ['handshake', 'deal', 'agreement', 'partner', 'meet', 'business'],
        'megaphone': ['megaphone', 'announce', 'broadcast', 'loud', 'marketing', 'promotion', 'speaker'],
        'share-2': ['share', 'social', 'distribute', 'spread', 'forward', 'repost'],
        // Status
        'circle-check': ['check', 'done', 'complete', 'success', 'verified', 'approve', 'circle'],
        'circle-x': ['x', 'close', 'cancel', 'error', 'delete', 'remove', 'circle'],
        'repeat': ['repeat', 'loop', 'refresh', 'cycle', 'reload', 'sync', 'rotate'],
        'undo': ['undo', 'back', 'revert', 'reverse', 'return', 'history'],
        'upload': ['upload', 'send', 'share', 'cloud', 'export', 'file'],
        'search': ['search', 'find', 'magnifying glass', 'look', 'discover', 'explore', 'query'],
        'trash': ['trash', 'delete', 'remove', 'garbage', 'bin', 'waste', 'discard'],
        'x': ['x', 'close', 'cancel', 'delete', 'remove', 'cross'],
        'recycle': ['recycle', 'green', 'environment', 'eco', 'reuse', 'sustainable'],
        // Misc
        'anchor': ['anchor', 'ship', 'marine', 'nautical', 'dock', 'port', 'harbor'],
        'axe': ['axe', 'chop', 'wood', 'lumberjack', 'tool', 'cut', 'hatchet'],
        'barrel': ['barrel', 'container', 'keg', 'storage', 'oil', 'wine', 'beer'],
        'bell': ['bell', 'notification', 'alert', 'alarm', 'ring', 'remind', 'chime'],
        'binoculars': ['binoculars', 'look', 'spy', 'view', 'observe', 'bird watching', 'zoom'],
        'bone': ['bone', 'skeleton', 'dog', 'pet', 'anatomy', 'fossil'],
        'candy': ['candy', 'sweet', 'sugar', 'treat', 'confection', 'halloween'],
        'cone': ['cone', 'shape', 'geometry', 'traffic', 'ice cream'],
        'construction': ['construction', 'building', 'hard hat', 'work', 'site', 'caution'],
        'fan': ['fan', 'cool', 'air', 'ventilation', 'breeze', 'spin'],
        'fuel': ['fuel', 'gas', 'petrol', 'energy', 'gasoline', 'diesel', 'pump'],
        'hash': ['hash', 'hashtag', 'number', 'pound', 'tag', 'social'],
        'hop': ['hop', 'beer', 'brew', 'plant', 'ingredient', 'craft beer'],
        'logs': ['logs', 'wood', 'timber', 'campfire', 'lumber', 'firewood'],
        'milestone': ['milestone', 'goal', 'achievement', 'progress', 'marker', 'signpost'],
        'pin': ['pin', 'location', 'tack', 'pushpin', 'mark', 'attach'],
        'satellite': ['satellite', 'space', 'communication', 'gps', 'orbit', 'signal'],
        'skull': ['skull', 'death', 'danger', 'pirate', 'halloween', 'skeleton', 'toxic'],
        'slice': ['slice', 'cut', 'piece', 'portion', 'pizza'],
        'sword': ['sword', 'weapon', 'knight', 'battle', 'medieval', 'blade', 'fight'],
        'table': ['table', 'furniture', 'desk', 'spreadsheet', 'data', 'grid'],
        'telescope': ['telescope', 'space', 'astronomy', 'stars', 'observe', 'sky', 'science'],
        'traffic-cone': ['traffic cone', 'construction', 'warning', 'road', 'safety', 'caution'],
        'vegan': ['vegan', 'plant', 'vegetarian', 'organic', 'healthy', 'green', 'diet'],
        'weight': ['weight', 'heavy', 'gym', 'fitness', 'measure', 'scale', 'mass'],
        'wheat': ['wheat', 'grain', 'bread', 'farm', 'agriculture', 'cereal', 'harvest'],
        'zap': ['zap', 'lightning', 'electric', 'power', 'energy', 'flash', 'bolt', 'thunder'],
        'atom': ['atom', 'science', 'physics', 'nuclear', 'molecule', 'chemistry', 'electron'],
        'dna': ['dna', 'genetics', 'biology', 'science', 'helix', 'genome', 'medical'],
        'hexagon': ['hexagon', 'shape', 'geometry', 'hex', 'honeycomb', 'polygon'],
        'triangle': ['triangle', 'shape', 'geometry', 'warning', 'delta', 'polygon'],
        'circle': ['circle', 'shape', 'round', 'dot', 'ring', 'geometry'],
        'square': ['square', 'shape', 'box', 'rectangle', 'geometry'],
        'octagon': ['octagon', 'shape', 'stop', 'geometry', 'polygon'],
        'lightbulb': ['lightbulb', 'idea', 'light', 'bright', 'innovation', 'creative', 'think', 'lamp'],

        // === Heroicons solid icons ===
        // (prefix with heroicons- to disambiguate from lucide icons with same name)
        // Files
        'heroicons-folder': ['folder', 'directory', 'files', 'organize'],
        'heroicons-folder-open': ['folder', 'open', 'directory', 'files'],
        'heroicons-folder-plus': ['folder', 'plus', 'add', 'new', 'create'],
        'heroicons-folder-minus': ['folder', 'minus', 'remove', 'delete'],
        'heroicons-folder-arrow-down': ['folder', 'download', 'arrow', 'save'],
        'heroicons-document': ['document', 'file', 'page', 'paper'],
        'heroicons-document-text': ['document', 'text', 'file', 'article', 'writing'],
        'heroicons-document-chart-bar': ['document', 'chart', 'report', 'analytics', 'graph'],
        'heroicons-document-check': ['document', 'check', 'approved', 'verified'],
        'heroicons-document-duplicate': ['document', 'duplicate', 'copy', 'clone'],
        'heroicons-document-plus': ['document', 'plus', 'add', 'new', 'create'],
        'heroicons-document-minus': ['document', 'minus', 'remove', 'delete'],
        'heroicons-document-arrow-down': ['document', 'download', 'save'],
        'heroicons-document-arrow-up': ['document', 'upload', 'export'],
        'heroicons-document-magnifying-glass': ['document', 'search', 'find', 'magnifying glass'],
        'heroicons-archive-box': ['archive', 'box', 'storage', 'backup'],
        'heroicons-clipboard': ['clipboard', 'paste', 'copy', 'notes'],
        'heroicons-clipboard-document': ['clipboard', 'document', 'paste', 'copy'],
        'heroicons-clipboard-document-check': ['clipboard', 'check', 'done', 'approved'],
        'heroicons-clipboard-document-list': ['clipboard', 'list', 'checklist', 'tasks'],
        'heroicons-inbox': ['inbox', 'mail', 'email', 'messages'],
        'heroicons-inbox-arrow-down': ['inbox', 'download', 'receive', 'mail'],
        'heroicons-inbox-stack': ['inbox', 'stack', 'mail', 'messages', 'multiple'],
        'heroicons-rectangle-stack': ['stack', 'layers', 'cards', 'collection'],
        'heroicons-circle-stack': ['stack', 'database', 'coins', 'discs', 'layers'],
        'heroicons-square-3-stack-3d': ['stack', '3d', 'layers', 'depth', 'perspective'],
        // Places
        'heroicons-home': ['home', 'house', 'residence', 'main'],
        'heroicons-home-modern': ['home', 'modern', 'house', 'contemporary', 'building'],
        'heroicons-building-office': ['building', 'office', 'workplace', 'business'],
        'heroicons-building-office-2': ['building', 'office', 'corporate', 'skyscraper'],
        'heroicons-building-library': ['library', 'building', 'books', 'education', 'museum'],
        'heroicons-building-storefront': ['store', 'shop', 'retail', 'storefront', 'business'],
        'heroicons-map': ['map', 'geography', 'location', 'navigation'],
        'heroicons-map-pin': ['map', 'pin', 'location', 'place', 'marker'],
        'heroicons-globe-alt': ['globe', 'world', 'earth', 'international'],
        'heroicons-globe-americas': ['globe', 'americas', 'world', 'north america', 'south america'],
        'heroicons-globe-asia-australia': ['globe', 'asia', 'australia', 'world', 'pacific'],
        'heroicons-globe-europe-africa': ['globe', 'europe', 'africa', 'world'],
        'heroicons-academic-cap': ['academic', 'cap', 'graduation', 'education', 'university', 'school'],
        'heroicons-briefcase': ['briefcase', 'business', 'work', 'office', 'job'],
        // People
        'heroicons-users': ['users', 'people', 'group', 'team'],
        'heroicons-user': ['user', 'person', 'profile', 'account'],
        'heroicons-user-circle': ['user', 'circle', 'avatar', 'profile'],
        'heroicons-user-group': ['user', 'group', 'team', 'people', 'community'],
        'heroicons-user-plus': ['user', 'plus', 'add', 'invite', 'register'],
        'heroicons-user-minus': ['user', 'minus', 'remove', 'delete'],
        'heroicons-face-smile': ['face', 'smile', 'happy', 'emoji', 'smiley'],
        'heroicons-face-frown': ['face', 'frown', 'sad', 'unhappy', 'emoji'],
        'heroicons-identification': ['id', 'identification', 'badge', 'card', 'identity'],
        'heroicons-hand-raised': ['hand', 'raised', 'stop', 'halt', 'wave'],
        'heroicons-hand-thumb-up': ['thumbs up', 'like', 'approve', 'good'],
        'heroicons-hand-thumb-down': ['thumbs down', 'dislike', 'disapprove', 'bad'],
        // Messages
        'heroicons-envelope': ['envelope', 'mail', 'email', 'letter', 'message'],
        'heroicons-envelope-open': ['envelope', 'open', 'mail', 'read', 'email'],
        'heroicons-phone': ['phone', 'call', 'telephone', 'mobile'],
        'heroicons-megaphone': ['megaphone', 'announce', 'broadcast', 'marketing'],
        'heroicons-chat-bubble-left': ['chat', 'message', 'bubble', 'comment', 'talk'],
        'heroicons-chat-bubble-bottom-center': ['chat', 'message', 'bubble', 'comment'],
        'heroicons-chat-bubble-left-right': ['chat', 'conversation', 'message', 'discuss'],
        'heroicons-chat-bubble-oval-left': ['chat', 'message', 'bubble', 'comment'],
        'heroicons-chat-bubble-oval-left-ellipsis': ['chat', 'typing', 'message', 'thinking'],
        'heroicons-paper-airplane': ['paper airplane', 'send', 'message', 'email', 'deliver'],
        'heroicons-at-symbol': ['at', 'email', 'mention', 'symbol', 'address'],
        'heroicons-hashtag': ['hashtag', 'tag', 'social', 'number', 'pound'],
        'heroicons-signal': ['signal', 'reception', 'wireless', 'network'],
        'heroicons-signal-slash': ['signal', 'no signal', 'offline', 'disconnected'],
        'heroicons-share': ['share', 'social', 'forward', 'distribute'],
        // Media
        'heroicons-musical-note': ['music', 'note', 'song', 'audio', 'tune'],
        'heroicons-film': ['film', 'movie', 'cinema', 'video', 'reel'],
        'heroicons-camera': ['camera', 'photo', 'picture', 'photography'],
        'heroicons-photo': ['photo', 'image', 'picture', 'gallery'],
        'heroicons-video-camera': ['video', 'camera', 'record', 'film'],
        'heroicons-tv': ['tv', 'television', 'screen', 'monitor', 'watch'],
        'heroicons-radio': ['radio', 'broadcast', 'fm', 'music'],
        'heroicons-play': ['play', 'start', 'video', 'music', 'media'],
        'heroicons-play-circle': ['play', 'circle', 'start', 'video', 'media'],
        'heroicons-pause': ['pause', 'stop', 'break', 'media'],
        'heroicons-pause-circle': ['pause', 'circle', 'stop', 'media'],
        'heroicons-play-pause': ['play', 'pause', 'toggle', 'media'],
        'heroicons-stop': ['stop', 'end', 'halt', 'media'],
        'heroicons-backward': ['backward', 'rewind', 'previous', 'media'],
        'heroicons-forward': ['forward', 'skip', 'next', 'media'],
        'heroicons-speaker-wave': ['speaker', 'volume', 'audio', 'sound', 'loud'],
        'heroicons-speaker-x-mark': ['speaker', 'mute', 'silent', 'no sound'],
        'heroicons-microphone': ['microphone', 'mic', 'record', 'voice', 'audio'],
        'heroicons-gif': ['gif', 'animation', 'image', 'meme', 'animated'],
        // Markers
        'heroicons-star': ['star', 'favorite', 'rating', 'featured'],
        'heroicons-heart': ['heart', 'love', 'like', 'favorite'],
        'heroicons-bookmark': ['bookmark', 'save', 'favorite', 'read later'],
        'heroicons-bookmark-square': ['bookmark', 'square', 'save', 'favorite'],
        'heroicons-bookmark-slash': ['bookmark', 'unsave', 'remove', 'slash'],
        'heroicons-flag': ['flag', 'report', 'mark', 'country'],
        'heroicons-tag': ['tag', 'label', 'category', 'price'],
        'heroicons-sparkles': ['sparkles', 'magic', 'special', 'new', 'ai'],
        'heroicons-trophy': ['trophy', 'winner', 'prize', 'award'],
        'heroicons-gift': ['gift', 'present', 'birthday', 'surprise'],
        'heroicons-ticket': ['ticket', 'event', 'concert', 'pass'],
        'heroicons-cake': ['cake', 'birthday', 'dessert', 'celebration'],
        'heroicons-check-badge': ['badge', 'check', 'verified', 'certified'],
        // Creative
        'heroicons-book-open': ['book', 'open', 'read', 'study'],
        'heroicons-newspaper': ['newspaper', 'news', 'press', 'article'],
        'heroicons-pencil': ['pencil', 'write', 'edit', 'draw'],
        'heroicons-paint-brush': ['paint', 'brush', 'art', 'creative', 'design'],
        'heroicons-scissors': ['scissors', 'cut', 'trim', 'craft'],
        'heroicons-paper-clip': ['paper clip', 'attach', 'attachment', 'file'],
        'heroicons-light-bulb': ['light bulb', 'idea', 'bright', 'innovation', 'creative'],
        'heroicons-puzzle-piece': ['puzzle', 'piece', 'game', 'solve', 'jigsaw'],
        'heroicons-swatch': ['swatch', 'color', 'palette', 'design', 'sample'],
        'heroicons-eye': ['eye', 'view', 'see', 'watch', 'visible'],
        'heroicons-eye-slash': ['eye', 'slash', 'hidden', 'invisible'],
        'heroicons-eye-dropper': ['eye dropper', 'color picker', 'sample', 'design'],
        'heroicons-viewfinder-circle': ['viewfinder', 'camera', 'target', 'focus'],
        'heroicons-italic': ['italic', 'text', 'format', 'style', 'font'],
        'heroicons-underline': ['underline', 'text', 'format', 'style'],
        'heroicons-strikethrough': ['strikethrough', 'text', 'format', 'delete', 'cross out'],
        // Finance
        'heroicons-shopping-cart': ['shopping', 'cart', 'buy', 'store', 'ecommerce'],
        'heroicons-shopping-bag': ['shopping', 'bag', 'buy', 'store', 'retail'],
        'heroicons-wallet': ['wallet', 'money', 'payment', 'finance'],
        'heroicons-banknotes': ['banknotes', 'money', 'cash', 'bills', 'currency', 'dollar'],
        'heroicons-credit-card': ['credit card', 'payment', 'money', 'finance'],
        'heroicons-currency-dollar': ['dollar', 'money', 'currency', 'finance', 'usd'],
        'heroicons-receipt-percent': ['receipt', 'discount', 'sale', 'percent', 'coupon'],
        'heroicons-calculator': ['calculator', 'math', 'compute', 'numbers'],
        'heroicons-chart-bar': ['chart', 'bar', 'graph', 'analytics', 'data', 'statistics'],
        'heroicons-chart-bar-square': ['chart', 'bar', 'square', 'analytics', 'data'],
        'heroicons-chart-pie': ['chart', 'pie', 'graph', 'analytics', 'data', 'statistics'],
        'heroicons-presentation-chart-bar': ['presentation', 'chart', 'slides', 'analytics'],
        'heroicons-presentation-chart-line': ['presentation', 'chart', 'line', 'trends'],
        'heroicons-table-cells': ['table', 'cells', 'spreadsheet', 'grid', 'data'],
        'heroicons-arrow-trending-up': ['trending', 'up', 'growth', 'increase', 'chart'],
        'heroicons-arrow-trending-down': ['trending', 'down', 'decrease', 'decline', 'chart'],
        // Devices
        'heroicons-computer-desktop': ['computer', 'desktop', 'pc', 'monitor', 'screen'],
        'heroicons-device-phone-mobile': ['phone', 'mobile', 'smartphone', 'device', 'cell'],
        'heroicons-device-tablet': ['tablet', 'ipad', 'device', 'screen'],
        'heroicons-printer': ['printer', 'print', 'output', 'document'],
        'heroicons-server': ['server', 'hosting', 'backend', 'cloud'],
        'heroicons-server-stack': ['server', 'stack', 'hosting', 'datacenter', 'cloud'],
        'heroicons-cpu-chip': ['cpu', 'chip', 'processor', 'hardware', 'silicon'],
        'heroicons-wifi': ['wifi', 'wireless', 'internet', 'network'],
        'heroicons-code-bracket': ['code', 'bracket', 'programming', 'developer'],
        'heroicons-command-line': ['command line', 'terminal', 'shell', 'cli'],
        'heroicons-window': ['window', 'browser', 'app', 'interface'],
        'heroicons-battery-100': ['battery', 'full', 'charge', 'power'],
        'heroicons-battery-50': ['battery', 'half', 'charge', 'power'],
        'heroicons-battery-0': ['battery', 'empty', 'dead', 'power'],
        'heroicons-power': ['power', 'on', 'off', 'switch', 'button'],
        // Tools
        'heroicons-cog-6-tooth': ['cog', 'settings', 'gear', 'config'],
        'heroicons-cog-8-tooth': ['cog', 'settings', 'gear', 'config'],
        'heroicons-cog': ['cog', 'settings', 'gear', 'config'],
        'heroicons-wrench': ['wrench', 'tool', 'fix', 'repair'],
        'heroicons-wrench-screwdriver': ['wrench', 'screwdriver', 'tool', 'fix', 'repair'],
        'heroicons-adjustments-horizontal': ['adjustments', 'settings', 'sliders', 'config', 'tune'],
        'heroicons-funnel': ['funnel', 'filter', 'sort', 'refine'],
        'heroicons-bars-3': ['bars', 'menu', 'hamburger', 'lines', 'navigation'],
        'heroicons-bars-2': ['bars', 'menu', 'lines', 'navigation'],
        'heroicons-bars-4': ['bars', 'menu', 'lines', 'navigation'],
        'heroicons-list-bullet': ['list', 'bullet', 'items', 'unordered'],
        'heroicons-numbered-list': ['list', 'numbered', 'ordered', 'items'],
        'heroicons-queue-list': ['queue', 'list', 'playlist', 'items', 'order'],
        'heroicons-magnifying-glass': ['magnifying glass', 'search', 'find', 'zoom'],
        'heroicons-key': ['key', 'lock', 'access', 'security'],
        'heroicons-lock-closed': ['lock', 'closed', 'secure', 'locked'],
        'heroicons-lock-open': ['lock', 'open', 'unlocked', 'accessible'],
        'heroicons-bell': ['bell', 'notification', 'alert', 'alarm'],
        'heroicons-bell-alert': ['bell', 'alert', 'notification', 'urgent'],
        'heroicons-bell-slash': ['bell', 'mute', 'silent', 'no notification'],
        'heroicons-trash': ['trash', 'delete', 'remove', 'garbage'],
        // Security
        'heroicons-finger-print': ['fingerprint', 'biometric', 'identity', 'security', 'auth'],
        'heroicons-shield-check': ['shield', 'check', 'security', 'protected', 'safe'],
        'heroicons-link': ['link', 'chain', 'url', 'connection'],
        'heroicons-qr-code': ['qr', 'code', 'scan', 'barcode'],
        'heroicons-rss': ['rss', 'feed', 'subscribe', 'syndication'],
        'heroicons-no-symbol': ['no', 'symbol', 'prohibited', 'forbidden', 'block'],
        // Weather
        'heroicons-sun': ['sun', 'sunny', 'day', 'weather', 'light'],
        'heroicons-moon': ['moon', 'night', 'dark', 'lunar'],
        'heroicons-cloud': ['cloud', 'weather', 'sky', 'overcast'],
        'heroicons-cloud-arrow-down': ['cloud', 'download', 'save'],
        'heroicons-cloud-arrow-up': ['cloud', 'upload', 'backup'],
        'heroicons-fire': ['fire', 'flame', 'hot', 'trending', 'popular'],
        'heroicons-bolt': ['bolt', 'lightning', 'electric', 'power', 'energy'],
        'heroicons-bolt-slash': ['bolt', 'slash', 'no power', 'offline'],
        // Science
        'heroicons-beaker': ['beaker', 'science', 'lab', 'chemistry', 'experiment'],
        'heroicons-bug-ant': ['bug', 'ant', 'insect', 'debug', 'pest'],
        'heroicons-scale': ['scale', 'balance', 'justice', 'law', 'weigh'],
        'heroicons-lifebuoy': ['lifebuoy', 'help', 'support', 'rescue', 'safety'],
        'heroicons-variable': ['variable', 'math', 'code', 'formula', 'algebra'],
        'heroicons-cube': ['cube', '3d', 'box', 'shape', 'geometry'],
        'heroicons-cube-transparent': ['cube', 'transparent', '3d', 'wireframe'],
        // Objects
        'heroicons-truck': ['truck', 'delivery', 'shipping', 'transport', 'vehicle'],
        'heroicons-rocket-launch': ['rocket', 'launch', 'space', 'startup', 'fast'],
        'heroicons-square-2-stack': ['stack', 'layers', 'duplicate', 'copy'],
        'heroicons-squares-2x2': ['grid', 'squares', 'layout', 'dashboard', 'apps'],
        'heroicons-squares-plus': ['squares', 'plus', 'add', 'apps', 'widget'],
        'heroicons-view-columns': ['columns', 'layout', 'grid', 'view'],
        'heroicons-language': ['language', 'translate', 'international', 'i18n', 'globe'],
        'heroicons-clock': ['clock', 'time', 'hour', 'schedule'],
        'heroicons-calendar': ['calendar', 'date', 'schedule', 'event'],
        'heroicons-calendar-days': ['calendar', 'days', 'schedule', 'planner'],
        'heroicons-calendar-date-range': ['calendar', 'range', 'dates', 'period', 'span'],
        // Arrows
        'heroicons-arrow-path': ['arrow', 'path', 'refresh', 'cycle', 'sync'],
        'heroicons-arrow-down-tray': ['download', 'tray', 'save', 'arrow'],
        'heroicons-arrow-up-tray': ['upload', 'tray', 'export', 'arrow'],
        'heroicons-arrow-up-circle': ['arrow', 'up', 'circle', 'increase'],
        'heroicons-arrow-down-circle': ['arrow', 'down', 'circle', 'decrease'],
        'heroicons-arrows-pointing-out': ['arrows', 'expand', 'fullscreen', 'enlarge'],
        'heroicons-arrows-pointing-in': ['arrows', 'collapse', 'shrink', 'minimize'],
        'heroicons-chevron-up': ['chevron', 'up', 'arrow', 'expand'],
        'heroicons-chevron-down': ['chevron', 'down', 'arrow', 'collapse'],
        'heroicons-chevron-left': ['chevron', 'left', 'arrow', 'back'],
        'heroicons-chevron-right': ['chevron', 'right', 'arrow', 'forward'],
        'heroicons-chevron-double-up': ['chevron', 'double', 'up', 'fast'],
        'heroicons-chevron-double-down': ['chevron', 'double', 'down', 'fast'],
        'heroicons-chevron-double-left': ['chevron', 'double', 'left', 'fast'],
        'heroicons-chevron-double-right': ['chevron', 'double', 'right', 'fast'],
        'heroicons-backspace': ['backspace', 'delete', 'erase', 'keyboard'],
        // Status
        'heroicons-check-circle': ['check', 'circle', 'done', 'success', 'verified'],
        'heroicons-check': ['check', 'done', 'success', 'complete'],
        'heroicons-x-circle': ['x', 'circle', 'close', 'error', 'cancel'],
        'heroicons-x-mark': ['x', 'close', 'cancel', 'delete'],
        'heroicons-plus-circle': ['plus', 'circle', 'add', 'new'],
        'heroicons-plus': ['plus', 'add', 'new', 'create'],
        'heroicons-minus-circle': ['minus', 'circle', 'remove', 'subtract'],
        'heroicons-minus': ['minus', 'remove', 'subtract', 'less'],
        'heroicons-question-mark-circle': ['question', 'help', 'faq', 'info', 'ask'],
        'heroicons-exclamation-circle': ['exclamation', 'warning', 'alert', 'error'],
        'heroicons-exclamation-triangle': ['exclamation', 'triangle', 'warning', 'caution', 'danger'],
        'heroicons-information-circle': ['information', 'info', 'help', 'about', 'details'],
        'heroicons-ellipsis-horizontal': ['ellipsis', 'more', 'menu', 'options', 'dots'],
        'heroicons-ellipsis-vertical': ['ellipsis', 'vertical', 'more', 'menu', 'options'],
        'heroicons-ellipsis-horizontal-circle': ['ellipsis', 'circle', 'more', 'menu'],
        // Cursors
        'heroicons-cursor-arrow-rays': ['cursor', 'arrow', 'click', 'pointer', 'rays'],
        'heroicons-cursor-arrow-ripple': ['cursor', 'arrow', 'click', 'pointer', 'ripple']
    },

    // Search terms for emojis: emoji character -> array of searchable synonyms/keywords
    EMOJI_SEARCH_TERMS: {
        '📁': ['folder', 'directory', 'files'],
        '📂': ['folder', 'open', 'directory'],
        '📚': ['books', 'library', 'reading', 'study', 'literature'],
        '📖': ['book', 'open', 'reading', 'study'],
        '📰': ['newspaper', 'news', 'press', 'media', 'article'],
        '📄': ['document', 'file', 'page', 'paper'],
        '📑': ['bookmarks', 'tabs', 'dividers', 'sections'],
        '📋': ['clipboard', 'paste', 'list', 'checklist'],
        '📝': ['memo', 'write', 'note', 'pencil', 'edit'],
        '✏️': ['pencil', 'write', 'edit', 'draw'],
        '🗂️': ['card dividers', 'organize', 'tabs', 'index'],
        '📎': ['paperclip', 'attach', 'attachment', 'clip'],
        '📌': ['pushpin', 'pin', 'tack', 'location', 'mark'],
        '🗃️': ['card file box', 'archive', 'storage', 'index'],
        '📓': ['notebook', 'journal', 'diary', 'notes'],
        '💻': ['laptop', 'computer', 'device', 'macbook'],
        '📱': ['phone', 'mobile', 'smartphone', 'cell', 'iphone'],
        '📺': ['television', 'tv', 'screen', 'watch', 'monitor'],
        '🎬': ['clapperboard', 'movie', 'film', 'cinema', 'action', 'hollywood'],
        '🎵': ['music', 'note', 'song', 'audio', 'melody'],
        '🎧': ['headphones', 'audio', 'music', 'listen'],
        '🎮': ['game controller', 'gaming', 'console', 'play', 'video game', 'xbox', 'playstation'],
        '📷': ['camera', 'photo', 'picture', 'photography'],
        '📹': ['video camera', 'record', 'film', 'camcorder'],
        '🖨️': ['printer', 'print', 'paper', 'output'],
        '⌨️': ['keyboard', 'typing', 'keys', 'input'],
        '🖥️': ['desktop', 'computer', 'monitor', 'screen', 'pc'],
        '🖱️': ['mouse', 'cursor', 'click', 'computer'],
        '💾': ['floppy disk', 'save', 'retro', 'storage', 'vintage'],
        '📡': ['satellite dish', 'signal', 'broadcast', 'antenna', 'communication'],
        '⭐': ['star', 'favorite', 'rating', 'featured'],
        '🌟': ['glowing star', 'sparkle', 'shine', 'bright'],
        '✨': ['sparkles', 'magic', 'special', 'glitter', 'new'],
        '💫': ['dizzy star', 'shooting star', 'sparkle'],
        '⚡': ['lightning', 'electric', 'power', 'bolt', 'zap', 'energy'],
        '🔥': ['fire', 'flame', 'hot', 'trending', 'popular'],
        '💥': ['explosion', 'boom', 'crash', 'impact', 'bang'],
        '❄️': ['snowflake', 'snow', 'winter', 'cold', 'ice', 'frozen'],
        '🌈': ['rainbow', 'colorful', 'pride', 'spectrum'],
        '🎇': ['sparkler', 'firework', 'celebration', 'sparkle'],
        '🎆': ['fireworks', 'celebration', 'new year', 'festival'],
        '💎': ['gem', 'diamond', 'jewel', 'precious', 'luxury'],
        '🔮': ['crystal ball', 'magic', 'fortune', 'predict', 'mystic'],
        '🪩': ['disco ball', 'party', 'dance', 'club', 'mirror ball'],
        '☄️': ['comet', 'space', 'shooting star', 'meteor'],
        '☀️': ['sun', 'sunny', 'weather', 'day', 'bright', 'solar'],
        '🌙': ['moon', 'crescent', 'night', 'lunar', 'sleep'],
        '☁️': ['cloud', 'weather', 'sky', 'overcast'],
        '🌧️': ['rain', 'rainy', 'weather', 'shower', 'precipitation'],
        '⛈️': ['thunderstorm', 'storm', 'lightning', 'weather'],
        '🌪️': ['tornado', 'storm', 'cyclone', 'weather', 'twister'],
        '🌊': ['wave', 'ocean', 'sea', 'water', 'surf', 'tsunami'],
        '💧': ['droplet', 'water', 'tear', 'rain', 'liquid'],
        '🌤️': ['mostly sunny', 'partly cloudy', 'weather', 'fair'],
        '🌥️': ['mostly cloudy', 'partly sunny', 'weather', 'overcast'],
        '🌦️': ['sun and rain', 'weather', 'shower'],
        '🌬️': ['wind', 'breeze', 'blow', 'weather', 'air'],
        '☔': ['umbrella', 'rain', 'weather', 'wet', 'rainy'],
        '🌫️': ['fog', 'mist', 'haze', 'weather', 'smog'],
        '⛅': ['partly cloudy', 'weather', 'sun', 'cloud'],
        '🌲': ['evergreen', 'tree', 'pine', 'forest', 'nature', 'christmas'],
        '🌳': ['deciduous tree', 'tree', 'oak', 'nature', 'park'],
        '🌴': ['palm tree', 'tropical', 'beach', 'island', 'vacation'],
        '🌻': ['sunflower', 'flower', 'garden', 'yellow', 'nature'],
        '🌺': ['hibiscus', 'flower', 'tropical', 'hawaii', 'nature'],
        '🌸': ['cherry blossom', 'flower', 'spring', 'japan', 'sakura', 'pink'],
        '🌷': ['tulip', 'flower', 'spring', 'garden', 'netherlands'],
        '🌹': ['rose', 'flower', 'love', 'red', 'romance', 'valentine'],
        '🍀': ['four leaf clover', 'luck', 'lucky', 'irish', 'shamrock'],
        '🌿': ['herb', 'plant', 'green', 'nature', 'leaf', 'organic'],
        '💐': ['bouquet', 'flowers', 'gift', 'arrangement', 'floral'],
        '🪻': ['hyacinth', 'flower', 'purple', 'spring', 'garden'],
        '🪷': ['lotus', 'flower', 'zen', 'meditation', 'buddhism', 'peaceful'],
        '🌼': ['blossom', 'flower', 'daisy', 'garden', 'nature'],
        '🏵️': ['rosette', 'flower', 'award', 'decoration'],
        '🍂': ['fallen leaf', 'autumn', 'fall', 'leaves', 'orange'],
        '🍁': ['maple leaf', 'canada', 'autumn', 'fall', 'red'],
        '🌵': ['cactus', 'desert', 'plant', 'succulent', 'arizona'],
        '🌾': ['rice', 'wheat', 'grain', 'farm', 'agriculture', 'harvest'],
        '🌱': ['seedling', 'sprout', 'plant', 'grow', 'nature', 'new'],
        '🪴': ['potted plant', 'houseplant', 'indoor', 'garden', 'decor'],
        '🎋': ['tanabata tree', 'bamboo', 'japanese', 'festival'],
        '🎍': ['pine decoration', 'kadomatsu', 'japanese', 'new year'],
        '🍃': ['leaves', 'wind', 'nature', 'green', 'blowing'],
        '☘️': ['shamrock', 'irish', 'clover', 'luck', 'ireland'],
        '🪹': ['nest', 'bird', 'home', 'eggs'],
        '🪸': ['coral', 'ocean', 'reef', 'marine', 'sea'],
        '🍄': ['mushroom', 'fungus', 'toadstool', 'nature', 'forest'],
        '🪵': ['wood', 'log', 'timber', 'lumber', 'campfire'],
        '🪨': ['rock', 'stone', 'boulder', 'geology', 'nature'],
        '☕': ['coffee', 'cafe', 'espresso', 'drink', 'hot', 'morning', 'caffeine'],
        '🍵': ['tea', 'green tea', 'drink', 'hot', 'cup', 'matcha'],
        '🍺': ['beer', 'drink', 'alcohol', 'pub', 'bar', 'brew', 'pint'],
        '🍷': ['wine', 'drink', 'alcohol', 'red', 'glass', 'vineyard'],
        '🥤': ['cup with straw', 'soda', 'drink', 'beverage', 'soft drink'],
        '🧃': ['juice box', 'juice', 'drink', 'kids', 'beverage'],
        '🍽️': ['place setting', 'dining', 'restaurant', 'eat', 'meal', 'food'],
        '🍴': ['fork and knife', 'eating', 'dining', 'food', 'utensils', 'restaurant'],
        '🥢': ['chopsticks', 'asian', 'eating', 'chinese', 'japanese', 'food'],
        '🧂': ['salt', 'seasoning', 'cooking', 'spice', 'flavor'],
        '🍶': ['sake', 'japanese', 'alcohol', 'rice wine', 'drink'],
        '🥂': ['clinking glasses', 'cheers', 'toast', 'celebration', 'champagne'],
        '🍸': ['cocktail', 'martini', 'drink', 'alcohol', 'bar'],
        '🫖': ['teapot', 'tea', 'brew', 'drink', 'hot'],
        '🥛': ['milk', 'dairy', 'glass', 'drink', 'calcium'],
        '🍕': ['pizza', 'food', 'italian', 'slice', 'pepperoni'],
        '🍔': ['hamburger', 'burger', 'food', 'fast food', 'beef', 'bbq'],
        '🍟': ['french fries', 'fries', 'food', 'fast food', 'potato'],
        '🌮': ['taco', 'mexican', 'food', 'tortilla', 'tex-mex'],
        '🍜': ['noodles', 'ramen', 'soup', 'food', 'asian', 'japanese'],
        '🍣': ['sushi', 'japanese', 'food', 'fish', 'rice', 'seafood'],
        '🍰': ['cake', 'shortcake', 'dessert', 'sweet', 'birthday', 'bakery'],
        '🍩': ['doughnut', 'donut', 'sweet', 'dessert', 'snack', 'breakfast'],
        '🍎': ['apple', 'fruit', 'red', 'food', 'healthy'],
        '🍇': ['grapes', 'fruit', 'wine', 'purple', 'food'],
        '🥑': ['avocado', 'fruit', 'food', 'healthy', 'guacamole', 'green'],
        '🍓': ['strawberry', 'fruit', 'red', 'berry', 'food', 'sweet'],
        '🌽': ['corn', 'maize', 'vegetable', 'food', 'farm'],
        '🧁': ['cupcake', 'cake', 'dessert', 'sweet', 'bakery', 'muffin'],
        '🥐': ['croissant', 'pastry', 'bread', 'french', 'breakfast', 'bakery'],
        '🐶': ['dog', 'puppy', 'pet', 'canine', 'animal', 'woof'],
        '🐱': ['cat', 'kitten', 'pet', 'feline', 'animal', 'meow'],
        '🐦': ['bird', 'tweet', 'flying', 'wing', 'animal'],
        '🐟': ['fish', 'ocean', 'sea', 'aquarium', 'aquatic'],
        '🦋': ['butterfly', 'insect', 'beautiful', 'nature', 'metamorphosis'],
        '🐝': ['bee', 'honey', 'insect', 'buzz', 'pollinate'],
        '🦊': ['fox', 'animal', 'cunning', 'red', 'woodland'],
        '🐼': ['panda', 'bear', 'animal', 'bamboo', 'china', 'cute'],
        '🦁': ['lion', 'king', 'animal', 'pride', 'safari', 'jungle'],
        '🐸': ['frog', 'toad', 'amphibian', 'green', 'ribbit'],
        '🐧': ['penguin', 'bird', 'arctic', 'cold', 'linux', 'tux'],
        '🦜': ['parrot', 'bird', 'colorful', 'tropical', 'talk'],
        '🐙': ['octopus', 'ocean', 'sea', 'tentacles', 'marine'],
        '🐞': ['ladybug', 'beetle', 'insect', 'lucky', 'bug'],
        '🦒': ['giraffe', 'tall', 'animal', 'safari', 'africa'],
        '🦄': ['unicorn', 'horse', 'magic', 'fantasy', 'mythical', 'rainbow'],
        '🐯': ['tiger', 'animal', 'stripes', 'wild', 'jungle', 'cat'],
        '🐻': ['bear', 'animal', 'grizzly', 'teddy', 'woodland'],
        '🐨': ['koala', 'animal', 'australia', 'marsupial', 'cute'],
        '🐰': ['rabbit', 'bunny', 'easter', 'pet', 'animal', 'hare'],
        '🦉': ['owl', 'bird', 'night', 'wise', 'nocturnal'],
        '🦅': ['eagle', 'bird', 'freedom', 'america', 'raptor'],
        '🐢': ['turtle', 'tortoise', 'slow', 'shell', 'reptile'],
        '🐬': ['dolphin', 'ocean', 'sea', 'marine', 'smart', 'swim'],
        '🦈': ['shark', 'ocean', 'sea', 'predator', 'jaws', 'fish'],
        '🐘': ['elephant', 'animal', 'big', 'trunk', 'safari', 'africa'],
        '🦩': ['flamingo', 'bird', 'pink', 'tropical', 'wading'],
        '🐺': ['wolf', 'animal', 'howl', 'wild', 'pack'],
        '🦝': ['raccoon', 'animal', 'trash panda', 'nocturnal', 'masked'],
        '🐳': ['whale', 'ocean', 'sea', 'marine', 'blue whale', 'spout'],
        '🏠': ['house', 'home', 'building', 'residence'],
        '🏢': ['office building', 'business', 'workplace', 'corporate'],
        '🏫': ['school', 'education', 'building', 'academy'],
        '🏥': ['hospital', 'medical', 'health', 'clinic', 'emergency'],
        '🏰': ['castle', 'palace', 'medieval', 'fortress', 'kingdom'],
        '⛪': ['church', 'religion', 'chapel', 'worship'],
        '🕌': ['mosque', 'islam', 'religion', 'worship', 'minaret'],
        '🗼': ['tower', 'tokyo', 'landmark', 'tall'],
        '🏛️': ['classical building', 'government', 'museum', 'columns', 'greek'],
        '🎪': ['circus tent', 'carnival', 'show', 'entertainment'],
        '🏟️': ['stadium', 'arena', 'sports', 'venue', 'concert'],
        '🗽': ['statue of liberty', 'new york', 'america', 'freedom', 'landmark'],
        '⛩️': ['shrine', 'torii', 'japanese', 'shinto', 'gate'],
        '🏗️': ['construction', 'building', 'crane', 'development'],
        '🏘️': ['houses', 'neighborhood', 'suburb', 'residential'],
        '✈️': ['airplane', 'plane', 'flight', 'travel', 'airport', 'fly'],
        '🚗': ['car', 'auto', 'vehicle', 'drive', 'automobile'],
        '🚲': ['bicycle', 'bike', 'cycling', 'ride', 'pedal', 'cyclist', 'exercise'],
        '🚀': ['rocket', 'space', 'launch', 'startup', 'fast'],
        '⛵': ['sailboat', 'boat', 'sail', 'ocean', 'wind'],
        '🚂': ['train', 'locomotive', 'steam', 'railway', 'railroad'],
        '🚁': ['helicopter', 'chopper', 'fly', 'aircraft', 'aviation'],
        '🛸': ['flying saucer', 'ufo', 'alien', 'space', 'extraterrestrial'],
        '🏎️': ['race car', 'formula 1', 'racing', 'speed', 'fast'],
        '🚌': ['bus', 'transit', 'transport', 'public', 'school bus'],
        '🛶': ['canoe', 'kayak', 'paddle', 'boat', 'river'],
        '🚢': ['ship', 'boat', 'cruise', 'ocean', 'vessel'],
        '🛵': ['scooter', 'moped', 'vespa', 'motorcycle', 'ride'],
        '🚃': ['railway car', 'train', 'metro', 'subway', 'transit'],
        '🛩️': ['small airplane', 'plane', 'private jet', 'aviation'],
        '⚽': ['soccer', 'football', 'sport', 'ball', 'kick'],
        '🏀': ['basketball', 'sport', 'ball', 'hoop', 'nba'],
        '🎾': ['tennis', 'sport', 'ball', 'racket', 'court'],
        '🎯': ['bullseye', 'target', 'aim', 'dart', 'goal', 'focus'],
        '🏆': ['trophy', 'winner', 'champion', 'award', 'prize', 'cup'],
        '🎭': ['performing arts', 'theater', 'theatre', 'drama', 'masks', 'comedy', 'tragedy'],
        '🎨': ['art palette', 'paint', 'creative', 'design', 'color', 'artist'],
        '🎸': ['guitar', 'music', 'rock', 'instrument', 'play'],
        '🎹': ['piano', 'music', 'keyboard', 'keys', 'instrument'],
        '🏋️': ['weightlifting', 'gym', 'exercise', 'fitness', 'workout', 'strength'],
        '🏈': ['football', 'american football', 'sport', 'nfl', 'ball'],
        '🎳': ['bowling', 'sport', 'pins', 'lane', 'ball'],
        '🏓': ['ping pong', 'table tennis', 'sport', 'paddle'],
        '🥊': ['boxing', 'sport', 'fight', 'punch', 'glove'],
        '🎺': ['trumpet', 'music', 'brass', 'instrument', 'jazz'],
        '❤️': ['red heart', 'love', 'like', 'romance', 'valentine'],
        '💛': ['yellow heart', 'love', 'friendship', 'sunny'],
        '💚': ['green heart', 'love', 'nature', 'eco', 'healthy'],
        '💙': ['blue heart', 'love', 'trust', 'calm', 'peace'],
        '💜': ['purple heart', 'love', 'royalty', 'luxury'],
        '🧡': ['orange heart', 'love', 'warm', 'friendship'],
        '🖤': ['black heart', 'love', 'dark', 'goth', 'emo'],
        '🤍': ['white heart', 'love', 'pure', 'clean', 'peace'],
        '💖': ['sparkling heart', 'love', 'sparkle', 'adorable'],
        '💝': ['heart with ribbon', 'love', 'gift', 'valentine'],
        '💗': ['growing heart', 'love', 'expanding', 'affection'],
        '💞': ['revolving hearts', 'love', 'spinning', 'couple'],
        '💕': ['two hearts', 'love', 'pair', 'couple', 'romance'],
        '🤎': ['brown heart', 'love', 'earth', 'nature'],
        '❣️': ['heart exclamation', 'love', 'emphasis', 'passion'],
        '✅': ['check mark', 'done', 'complete', 'yes', 'success', 'approved'],
        '❌': ['cross mark', 'no', 'wrong', 'error', 'delete', 'cancel'],
        '⚠️': ['warning', 'alert', 'caution', 'danger', 'attention'],
        'ℹ️': ['info', 'information', 'help', 'about', 'details'],
        '❓': ['question', 'help', 'ask', 'what', 'faq', 'unknown'],
        '🔔': ['bell', 'notification', 'alert', 'alarm', 'ring'],
        '🔒': ['lock', 'security', 'locked', 'private', 'safe'],
        '🔑': ['key', 'lock', 'access', 'password', 'unlock'],
        '💡': ['light bulb', 'idea', 'bright', 'innovation', 'think'],
        '🎁': ['gift', 'present', 'birthday', 'christmas', 'surprise'],
        '🔗': ['link', 'chain', 'url', 'connection', 'hyperlink'],
        '⏰': ['alarm clock', 'time', 'wake up', 'timer', 'schedule'],
        '📢': ['loudspeaker', 'announce', 'broadcast', 'megaphone', 'volume'],
        '🚫': ['prohibited', 'no', 'forbidden', 'banned', 'stop'],
        '✳️': ['sparkle', 'star', 'asterisk', 'special'],
        '💰': ['money bag', 'rich', 'wealth', 'cash', 'finance', 'dollar'],
        '💼': ['briefcase', 'business', 'work', 'office', 'job'],
        '🎓': ['graduation cap', 'education', 'university', 'college', 'degree', 'school'],
        '🏅': ['medal', 'award', 'achievement', 'winner', 'first place'],
        '🛒': ['shopping cart', 'buy', 'store', 'ecommerce', 'retail'],
        '🌍': ['globe europe', 'world', 'earth', 'planet', 'europe', 'africa'],
        '🌎': ['globe americas', 'world', 'earth', 'planet', 'america'],
        '🌏': ['globe asia', 'world', 'earth', 'planet', 'asia', 'australia'],
        '🗺️': ['world map', 'geography', 'travel', 'atlas', 'explore'],
        '🧲': ['magnet', 'attract', 'magnetic', 'pull'],
        '🔭': ['telescope', 'space', 'astronomy', 'stars', 'observe'],
        '🧪': ['test tube', 'science', 'lab', 'chemistry', 'experiment'],
        '💊': ['pill', 'medicine', 'drug', 'health', 'pharmacy', 'medical'],
        '🪙': ['coin', 'money', 'gold', 'currency', 'token'],
        '😀': ['grinning', 'happy', 'smile', 'face', 'joy'],
        '😊': ['smiling', 'happy', 'blush', 'face', 'warm'],
        '🥳': ['party face', 'celebration', 'birthday', 'fun', 'horn'],
        '🤔': ['thinking', 'wonder', 'hmm', 'consider', 'ponder'],
        '😎': ['cool', 'sunglasses', 'awesome', 'confident', 'chill'],
        '🤩': ['star-struck', 'excited', 'amazing', 'wow', 'fan'],
        '🙄': ['eye roll', 'annoyed', 'whatever', 'bored'],
        '😴': ['sleeping', 'tired', 'zzz', 'nap', 'rest', 'exhausted'],
        '🤗': ['hugging', 'hug', 'warm', 'embrace', 'welcome'],
        '🥰': ['love face', 'adore', 'hearts', 'cute', 'affection'],
        '😂': ['laughing', 'tears of joy', 'funny', 'lol', 'hilarious'],
        '🫡': ['salute', 'respect', 'honor', 'military', 'roger'],
        '😇': ['halo', 'angel', 'innocent', 'good', 'blessed'],
        '🤓': ['nerd', 'geek', 'smart', 'glasses', 'studious'],
        '😏': ['smirk', 'sly', 'smug', 'knowing', 'flirty'],
        '👍': ['thumbs up', 'like', 'approve', 'good', 'yes', 'ok'],
        '👎': ['thumbs down', 'dislike', 'disapprove', 'bad', 'no'],
        '👋': ['wave', 'hello', 'hi', 'bye', 'greeting'],
        '✋': ['raised hand', 'stop', 'high five', 'halt'],
        '🤝': ['handshake', 'deal', 'agreement', 'partner', 'business'],
        '🙏': ['pray', 'please', 'thank you', 'hope', 'namaste'],
        '👏': ['clap', 'applause', 'bravo', 'congratulations'],
        '🎉': ['party popper', 'celebration', 'hooray', 'birthday', 'confetti'],
        '🎊': ['confetti', 'celebration', 'party', 'festival'],
        '🔖': ['bookmark', 'save', 'mark', 'read later', 'tag'],
        '✌️': ['peace', 'victory', 'two', 'fingers'],
        '🤞': ['crossed fingers', 'luck', 'hope', 'wish'],
        '👆': ['point up', 'above', 'direction', 'this'],
        '💪': ['flexed bicep', 'strong', 'muscle', 'power', 'fitness', 'gym', 'strength'],
        '🫶': ['heart hands', 'love', 'care', 'support', 'appreciate']
    },

    // Lucide outline icons organized by category
    PRESET_ICON_CATEGORIES: [
        { label: 'Files', icons: ['folder', 'folder-open', 'folder-archive', 'folder-check', 'folder-cog', 'folder-heart', 'folder-minus', 'folder-plus', 'folders', 'file', 'file-text', 'file-badge', 'file-check', 'file-cog', 'file-lock', 'files', 'archive', 'clipboard', 'inbox', 'layers'] },
        { label: 'Places', icons: ['home', 'house', 'building', 'building-2', 'store', 'landmark', 'factory', 'warehouse', 'castle', 'church', 'hospital', 'tent', 'mountain', 'fence', 'school'] },
        { label: 'Favorites', icons: ['star', 'heart', 'heart-handshake', 'bookmark', 'flag', 'tag', 'tags', 'award', 'crown', 'gem', 'diamond', 'sparkles', 'trophy', 'medal'] },
        { label: 'Reading', icons: ['book', 'book-open', 'book-marked', 'library', 'newspaper', 'scroll', 'notebook', 'graduation-cap', 'brain', 'kanban', 'sticker'] },
        { label: 'Audio', icons: ['music', 'headphones', 'headset', 'mic', 'radio', 'podcast', 'disc', 'album', 'boom-box', 'cassette-tape', 'speaker', 'drum', 'bluetooth', 'signal'] },
        { label: 'Visual', icons: ['video', 'video-off', 'film', 'tv', 'monitor', 'camera', 'image', 'images', 'eye', 'eye-off', 'picture-in-picture', 'youtube'] },
        { label: 'Games', icons: ['gamepad-2', 'joystick', 'dice-5', 'puzzle', 'drama', 'wand', 'wand-2', 'origami'] },
        { label: 'Sports', icons: ['volleyball', 'dumbbell', 'target', 'bike', 'trophy', 'medal', 'thumbs-up'] },
        { label: 'Travel', icons: ['plane', 'ship', 'sailboat', 'rocket', 'train', 'bus', 'car', 'tractor', 'cable-car', 'backpack', 'compass', 'navigation', 'map', 'map-pin'] },
        { label: 'Tech', icons: ['code', 'terminal', 'database', 'server', 'cpu', 'hard-drive', 'laptop', 'computer', 'keyboard', 'mouse', 'printer', 'usb', 'wifi', 'globe', 'rss', 'git-merge', 'git-branch', 'webhook', 'scan', 'settings'] },
        { label: 'Nature', icons: ['sun', 'sun-dim', 'sun-snow', 'sunrise', 'sunset', 'moon', 'cloud', 'umbrella', 'tree-pine', 'tree-deciduous', 'flower-2', 'leaf', 'clover', 'droplets', 'snowflake', 'wind', 'haze', 'orbit', 'earth'] },
        { label: 'Animals', icons: ['bird', 'cat', 'dog', 'fish', 'rabbit', 'turtle', 'bug', 'feather', 'egg', 'baby', 'shrimp'] },
        { label: 'Food', icons: ['coffee', 'utensils', 'chef-hat', 'pizza', 'sandwich', 'croissant', 'apple', 'banana', 'cherry', 'citrus', 'grape', 'carrot', 'beef', 'drumstick', 'soup', 'popcorn', 'cake', 'cookie', 'lollipop', 'popsicle', 'ice-cream-cone', 'flame', 'wine', 'martini', 'bottle-wine', 'cup-soda', 'milk'] },
        { label: 'Shopping', icons: ['shopping-cart', 'shopping-bag', 'shopping-basket', 'gift', 'package', 'wallet', 'credit-card', 'coins', 'piggy-bank', 'box', 'briefcase', 'ticket', 'barcode'] },
        { label: 'Home', icons: ['bed', 'bath', 'lamp', 'lamp-ceiling', 'lamp-desk', 'lamp-floor', 'refrigerator', 'washing-machine'] },
        { label: 'Health', icons: ['stethoscope', 'syringe', 'thermometer', 'thermometer-sun', 'test-tube', 'microscope'] },
        { label: 'Fashion', icons: ['shirt', 'glasses', 'watch'] },
        { label: 'Tools', icons: ['hammer', 'wrench', 'scissors', 'ruler', 'highlighter', 'paintbrush', 'palette', 'brush', 'pen', 'pencil-line', 'stamp', 'key', 'lock', 'link', 'magnet', 'plug', 'battery', 'flashlight', 'hourglass', 'timer', 'clock', 'calendar'] },
        { label: 'Social', icons: ['mail', 'mailbox', 'message-square', 'message-circle', 'phone', 'at-sign', 'send', 'users', 'user', 'contact', 'hand', 'handshake', 'megaphone', 'share-2'] },
        { label: 'Status', icons: ['circle-check', 'circle-x', 'repeat', 'undo', 'upload', 'search', 'trash', 'x', 'recycle'] },
        { label: 'Misc', icons: ['anchor', 'axe', 'barrel', 'bell', 'binoculars', 'bone', 'candy', 'cone', 'construction', 'fan', 'fuel', 'hash', 'hop', 'logs', 'milestone', 'pin', 'satellite', 'skull', 'slice', 'sword', 'table', 'telescope', 'traffic-cone', 'vegan', 'weight', 'wheat', 'zap', 'atom', 'dna', 'hexagon', 'triangle', 'circle', 'square', 'octagon', 'lightbulb'] }
    ],

    // Heroicons solid icons organized by category
    FILLED_ICON_CATEGORIES: [
        { label: 'Files', icons: ['folder', 'folder-open', 'folder-plus', 'folder-minus', 'folder-arrow-down', 'document', 'document-text', 'document-chart-bar', 'document-check', 'document-duplicate', 'document-plus', 'document-minus', 'document-arrow-down', 'document-arrow-up', 'document-magnifying-glass', 'archive-box', 'clipboard', 'clipboard-document', 'clipboard-document-check', 'clipboard-document-list', 'inbox', 'inbox-arrow-down', 'inbox-stack', 'rectangle-stack', 'circle-stack', 'square-3-stack-3d'] },
        { label: 'Places', icons: ['home', 'home-modern', 'building-office', 'building-office-2', 'building-library', 'building-storefront', 'map', 'map-pin', 'globe-alt', 'globe-americas', 'globe-asia-australia', 'globe-europe-africa', 'academic-cap', 'briefcase'] },
        { label: 'People', icons: ['users', 'user', 'user-circle', 'user-group', 'user-plus', 'user-minus', 'face-smile', 'face-frown', 'identification', 'hand-raised', 'hand-thumb-up', 'hand-thumb-down'] },
        { label: 'Messages', icons: ['envelope', 'envelope-open', 'phone', 'megaphone', 'chat-bubble-left', 'chat-bubble-bottom-center', 'chat-bubble-left-right', 'chat-bubble-oval-left', 'chat-bubble-oval-left-ellipsis', 'paper-airplane', 'at-symbol', 'hashtag', 'signal', 'signal-slash', 'share'] },
        { label: 'Media', icons: ['musical-note', 'film', 'camera', 'photo', 'video-camera', 'tv', 'radio', 'play', 'play-circle', 'pause', 'pause-circle', 'play-pause', 'stop', 'backward', 'forward', 'speaker-wave', 'speaker-x-mark', 'microphone', 'gif'] },
        { label: 'Markers', icons: ['star', 'heart', 'bookmark', 'bookmark-square', 'bookmark-slash', 'flag', 'tag', 'sparkles', 'trophy', 'gift', 'ticket', 'cake', 'check-badge'] },
        { label: 'Creative', icons: ['book-open', 'newspaper', 'pencil', 'paint-brush', 'scissors', 'paper-clip', 'light-bulb', 'puzzle-piece', 'swatch', 'eye', 'eye-slash', 'eye-dropper', 'viewfinder-circle', 'italic', 'underline', 'strikethrough'] },
        { label: 'Finance', icons: ['shopping-cart', 'shopping-bag', 'wallet', 'banknotes', 'credit-card', 'currency-dollar', 'receipt-percent', 'calculator', 'chart-bar', 'chart-bar-square', 'chart-pie', 'presentation-chart-bar', 'presentation-chart-line', 'table-cells', 'arrow-trending-up', 'arrow-trending-down'] },
        { label: 'Devices', icons: ['computer-desktop', 'device-phone-mobile', 'device-tablet', 'printer', 'server', 'server-stack', 'cpu-chip', 'wifi', 'code-bracket', 'command-line', 'window', 'battery-100', 'battery-50', 'battery-0', 'power'] },
        { label: 'Tools', icons: ['cog-6-tooth', 'cog-8-tooth', 'cog', 'wrench', 'wrench-screwdriver', 'adjustments-horizontal', 'funnel', 'bars-3', 'bars-2', 'bars-4', 'list-bullet', 'numbered-list', 'queue-list', 'magnifying-glass', 'key', 'lock-closed', 'lock-open', 'bell', 'bell-alert', 'bell-slash', 'trash'] },
        { label: 'Security', icons: ['finger-print', 'shield-check', 'link', 'qr-code', 'rss', 'no-symbol'] },
        { label: 'Weather', icons: ['sun', 'moon', 'cloud', 'cloud-arrow-down', 'cloud-arrow-up', 'fire', 'bolt', 'bolt-slash'] },
        { label: 'Science', icons: ['beaker', 'bug-ant', 'scale', 'lifebuoy', 'variable', 'cube', 'cube-transparent'] },
        { label: 'Objects', icons: ['truck', 'rocket-launch', 'square-2-stack', 'squares-2x2', 'squares-plus', 'view-columns', 'language', 'clock', 'calendar', 'calendar-days', 'calendar-date-range'] },
        { label: 'Arrows', icons: ['arrow-path', 'arrow-down-tray', 'arrow-up-tray', 'arrow-up-circle', 'arrow-down-circle', 'arrows-pointing-out', 'arrows-pointing-in', 'chevron-up', 'chevron-down', 'chevron-left', 'chevron-right', 'chevron-double-up', 'chevron-double-down', 'chevron-double-left', 'chevron-double-right', 'backspace'] },
        { label: 'Status', icons: ['check-circle', 'check', 'x-circle', 'x-mark', 'plus-circle', 'plus', 'minus-circle', 'minus', 'question-mark-circle', 'exclamation-circle', 'exclamation-triangle', 'information-circle', 'ellipsis-horizontal', 'ellipsis-vertical', 'ellipsis-horizontal-circle'] },
        { label: 'Cursors', icons: ['cursor-arrow-rays', 'cursor-arrow-ripple'] }
    ],

    // Emojis organized by category
    // Each emoji entry is [emoji, title]
    EMOJI_CATEGORIES: [
        { label: 'Files', emojis: [['📁', 'Folder'], ['📂', 'Open folder'], ['📚', 'Books'], ['📖', 'Open book'], ['📰', 'Newspaper'], ['📄', 'Document'], ['📑', 'Bookmarks'], ['📋', 'Clipboard'], ['📝', 'Memo'], ['✏️', 'Pencil'], ['🗂️', 'Card dividers'], ['📎', 'Paperclip'], ['📌', 'Pushpin'], ['🗃️', 'Card file box'], ['📓', 'Notebook']] },
        { label: 'Tech', emojis: [['💻', 'Laptop'], ['📱', 'Phone'], ['📺', 'Television'], ['🎬', 'Clapperboard'], ['🎵', 'Music'], ['🎧', 'Headphones'], ['🎮', 'Game controller'], ['📷', 'Camera'], ['📹', 'Video camera'], ['🖨️', 'Printer'], ['⌨️', 'Keyboard'], ['🖥️', 'Desktop'], ['🖱️', 'Mouse'], ['💾', 'Floppy disk'], ['📡', 'Satellite dish']] },
        { label: 'Stars', emojis: [['⭐', 'Star'], ['🌟', 'Glowing star'], ['✨', 'Sparkles'], ['💫', 'Dizzy star'], ['⚡', 'Lightning'], ['🔥', 'Fire'], ['💥', 'Explosion'], ['❄️', 'Snowflake'], ['🌈', 'Rainbow'], ['🎇', 'Sparkler'], ['🎆', 'Fireworks'], ['💎', 'Gem'], ['🔮', 'Crystal ball'], ['🪩', 'Disco ball'], ['☄️', 'Comet']] },
        { label: 'Weather', emojis: [['☀️', 'Sun'], ['🌙', 'Crescent moon'], ['☁️', 'Cloud'], ['🌧️', 'Rain'], ['⛈️', 'Thunderstorm'], ['🌪️', 'Tornado'], ['🌊', 'Wave'], ['💧', 'Droplet'], ['🌤️', 'Mostly sunny'], ['🌥️', 'Mostly cloudy'], ['🌦️', 'Sun and rain'], ['🌬️', 'Wind'], ['☔', 'Umbrella'], ['🌫️', 'Fog'], ['⛅', 'Partly cloudy']] },
        { label: 'Nature', emojis: [['🌲', 'Evergreen'], ['🌳', 'Deciduous tree'], ['🌴', 'Palm tree'], ['🌻', 'Sunflower'], ['🌺', 'Hibiscus'], ['🌸', 'Cherry blossom'], ['🌷', 'Tulip'], ['🌹', 'Rose'], ['🍀', 'Four leaf clover'], ['🌿', 'Herb'], ['💐', 'Bouquet'], ['🪻', 'Hyacinth'], ['🪷', 'Lotus'], ['🌼', 'Blossom'], ['🏵️', 'Rosette']] },
        { label: '', emojis: [['🍂', 'Fallen leaf'], ['🍁', 'Maple leaf'], ['🌵', 'Cactus'], ['🌾', 'Sheaf of rice'], ['🌱', 'Seedling'], ['🪴', 'Potted plant'], ['🎋', 'Tanabata tree'], ['🎍', 'Pine decoration'], ['🍃', 'Leaves'], ['☘️', 'Shamrock'], ['🪹', 'Nest'], ['🪸', 'Coral'], ['🍄', 'Mushroom'], ['🪵', 'Wood'], ['🪨', 'Rock']] },
        { label: 'Food', emojis: [['☕', 'Coffee'], ['🍵', 'Tea'], ['🍺', 'Beer'], ['🍷', 'Wine'], ['🥤', 'Cup with straw'], ['🧃', 'Juice box'], ['🍽️', 'Place setting'], ['🍴', 'Fork and knife'], ['🥢', 'Chopsticks'], ['🧂', 'Salt'], ['🍶', 'Sake'], ['🥂', 'Clinking glasses'], ['🍸', 'Cocktail'], ['🫖', 'Teapot'], ['🥛', 'Milk']] },
        { label: '', emojis: [['🍕', 'Pizza'], ['🍔', 'Hamburger'], ['🍟', 'French fries'], ['🌮', 'Taco'], ['🍜', 'Noodles'], ['🍣', 'Sushi'], ['🍰', 'Cake'], ['🍩', 'Doughnut'], ['🍎', 'Apple'], ['🍇', 'Grapes'], ['🥑', 'Avocado'], ['🍓', 'Strawberry'], ['🌽', 'Corn'], ['🧁', 'Cupcake'], ['🥐', 'Croissant']] },
        { label: 'Animals', emojis: [['🐶', 'Dog'], ['🐱', 'Cat'], ['🐦', 'Bird'], ['🐟', 'Fish'], ['🦋', 'Butterfly'], ['🐝', 'Bee'], ['🦊', 'Fox'], ['🐼', 'Panda'], ['🦁', 'Lion'], ['🐸', 'Frog'], ['🐧', 'Penguin'], ['🦜', 'Parrot'], ['🐙', 'Octopus'], ['🐞', 'Ladybug'], ['🦒', 'Giraffe']] },
        { label: '', emojis: [['🦄', 'Unicorn'], ['🐯', 'Tiger'], ['🐻', 'Bear'], ['🐨', 'Koala'], ['🐰', 'Rabbit'], ['🦉', 'Owl'], ['🦅', 'Eagle'], ['🐢', 'Turtle'], ['🐬', 'Dolphin'], ['🦈', 'Shark'], ['🐘', 'Elephant'], ['🦩', 'Flamingo'], ['🐺', 'Wolf'], ['🦝', 'Raccoon'], ['🐳', 'Whale']] },
        { label: 'Places', emojis: [['🏠', 'House'], ['🏢', 'Office building'], ['🏫', 'School'], ['🏥', 'Hospital'], ['🏰', 'Castle'], ['⛪', 'Church'], ['🕌', 'Mosque'], ['🗼', 'Tower'], ['🏛️', 'Classical building'], ['🎪', 'Circus tent'], ['🏟️', 'Stadium'], ['🗽', 'Statue of Liberty'], ['⛩️', 'Shrine'], ['🏗️', 'Construction'], ['🏘️', 'Houses']] },
        { label: 'Transport', emojis: [['✈️', 'Airplane'], ['🚗', 'Car'], ['🚲', 'Bicycle'], ['🚀', 'Rocket'], ['⛵', 'Sailboat'], ['🚂', 'Train'], ['🚁', 'Helicopter'], ['🛸', 'Flying saucer'], ['🏎️', 'Race car'], ['🚌', 'Bus'], ['🛶', 'Canoe'], ['🚢', 'Ship'], ['🛵', 'Scooter'], ['🚃', 'Railway car'], ['🛩️', 'Small airplane']] },
        { label: 'Sports', emojis: [['⚽', 'Soccer'], ['🏀', 'Basketball'], ['🎾', 'Tennis'], ['🎯', 'Bullseye'], ['🏆', 'Trophy'], ['🎭', 'Performing arts'], ['🎨', 'Art palette'], ['🎸', 'Guitar'], ['🎹', 'Piano'], ['🏋️', 'Weightlifting'], ['🏈', 'Football'], ['🎳', 'Bowling'], ['🏓', 'Ping pong'], ['🥊', 'Boxing'], ['🎺', 'Trumpet']] },
        { label: 'Hearts', emojis: [['❤️', 'Red heart'], ['💛', 'Yellow heart'], ['💚', 'Green heart'], ['💙', 'Blue heart'], ['💜', 'Purple heart'], ['🧡', 'Orange heart'], ['🖤', 'Black heart'], ['🤍', 'White heart'], ['💖', 'Sparkling heart'], ['💝', 'Heart with ribbon'], ['💗', 'Growing heart'], ['💞', 'Revolving hearts'], ['💕', 'Two hearts'], ['🤎', 'Brown heart'], ['❣️', 'Heart exclamation']] },
        { label: 'Status', emojis: [['✅', 'Check mark'], ['❌', 'Cross mark'], ['⚠️', 'Warning'], ['ℹ️', 'Info'], ['❓', 'Question'], ['🔔', 'Bell'], ['🔒', 'Lock'], ['🔑', 'Key'], ['💡', 'Light bulb'], ['🎁', 'Gift'], ['🔗', 'Link'], ['⏰', 'Alarm clock'], ['📢', 'Loudspeaker'], ['🚫', 'Prohibited'], ['✳️', 'Sparkle']] },
        { label: 'Objects', emojis: [['💰', 'Money bag'], ['💼', 'Briefcase'], ['🎓', 'Graduation cap'], ['🏅', 'Medal'], ['💎', 'Gem stone'], ['🛒', 'Shopping cart'], ['🌍', 'Globe Europe'], ['🌎', 'Globe Americas'], ['🌏', 'Globe Asia'], ['🗺️', 'World map'], ['🧲', 'Magnet'], ['🔭', 'Telescope'], ['🧪', 'Test tube'], ['💊', 'Pill'], ['🪙', 'Coin']] },
        { label: 'Faces', emojis: [['😀', 'Grinning'], ['😊', 'Smiling'], ['🥳', 'Party face'], ['🤔', 'Thinking'], ['😎', 'Cool'], ['🤩', 'Star-struck'], ['🙄', 'Eye roll'], ['😴', 'Sleeping'], ['🤗', 'Hugging'], ['🥰', 'Love face'], ['😂', 'Laughing'], ['🫡', 'Salute'], ['😇', 'Halo'], ['🤓', 'Nerd'], ['😏', 'Smirk']] },
        { label: 'Gestures', emojis: [['👍', 'Thumbs up'], ['👎', 'Thumbs down'], ['👋', 'Wave'], ['✋', 'Raised hand'], ['🤝', 'Handshake'], ['🙏', 'Pray'], ['👏', 'Clap'], ['🎉', 'Party popper'], ['🎊', 'Confetti'], ['🔖', 'Bookmark'], ['✌️', 'Peace'], ['🤞', 'Crossed fingers'], ['👆', 'Point up'], ['💪', 'Flexed bicep'], ['🫶', 'Heart hands']] }
    ],

    // Color palette organized by columns (each column is one hue, rows go light to dark)
    // 12 columns: Gray, Red, Pink, Purple, Indigo, Blue, Cyan, Teal, Green, Lime, Yellow, Orange
    COLOR_PALETTE: [
        // Row 1: Lightest
        '#f5f5f5', '#ffcdd2', '#f8bbd0', '#e1bee7', '#c5cae9', '#bbdefb', '#b3e5fc', '#b2dfdb', '#c8e6c9', '#dcedc8', '#fff9c4', '#ffe0b2',
        // Row 2: Light
        '#e0e0e0', '#ef9a9a', '#f48fb1', '#ce93d8', '#9fa8da', '#90caf9', '#81d4fa', '#80cbc4', '#a5d6a7', '#c5e1a5', '#fff59d', '#ffcc80',
        // Row 3: Medium-Light
        '#bdbdbd', '#e57373', '#f06292', '#ba68c8', '#7986cb', '#64b5f6', '#4fc3f7', '#4db6ac', '#81c784', '#aed581', '#fff176', '#ffb74d',
        // Row 4: Medium
        '#9e9e9e', '#f44336', '#ec407a', '#ab47bc', '#5c6bc0', '#42a5f5', '#29b6f6', '#26a69a', '#66bb6a', '#9ccc65', '#ffee58', '#ffa726',
        // Row 5: Medium-Dark
        '#757575', '#e53935', '#d81b60', '#8e24aa', '#3f51b5', '#1e88e5', '#039be5', '#00897b', '#43a047', '#7cb342', '#fdd835', '#ff9800',
        // Row 6: Dark
        '#616161', '#c62828', '#ad1457', '#6a1b9a', '#303f9f', '#1565c0', '#0277bd', '#00695c', '#2e7d32', '#558b2f', '#f9a825', '#ef6c00',
        // Row 7: Darkest
        '#424242', '#b71c1c', '#880e4f', '#4a148c', '#1a237e', '#0d47a1', '#01579b', '#004d40', '#1b5e20', '#33691e', '#f57f17', '#e65100'
    ],

    // Build the preset icons (Lucide outline) grid
    make_preset_icons: function () {
        var $container = $.make('div', { className: 'NB-folder-icon-presets-container' });

        _.each(this.PRESET_ICON_CATEGORIES, function (category) {
            var $row = $.make('div', { className: 'NB-folder-icon-preset-row' }, [
                $.make('div', { className: 'NB-folder-icon-preset-label' }, category.label),
                $.make('div', { className: 'NB-folder-icon-preset-items' })
            ]);
            var $items = $row.find('.NB-folder-icon-preset-items');
            _.each(category.icons, function (icon_name) {
                var $icon = $.make('div', { className: 'NB-folder-icon-preset', 'data-icon': icon_name }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/lucide/' + icon_name + '.svg' })
                ]);
                $items.append($icon);
            });
            $container.append($row);
        });

        return $container;
    },

    // Build the filled icons (Heroicons solid) grid
    make_filled_icons: function () {
        var $container = $.make('div', { className: 'NB-folder-icon-filled-container' });

        _.each(this.FILLED_ICON_CATEGORIES, function (category) {
            var $row = $.make('div', { className: 'NB-folder-icon-filled-row' }, [
                $.make('div', { className: 'NB-folder-icon-filled-label' }, category.label),
                $.make('div', { className: 'NB-folder-icon-filled-items' })
            ]);
            var $items = $row.find('.NB-folder-icon-filled-items');
            _.each(category.icons, function (icon_name) {
                var $icon = $.make('div', { className: 'NB-folder-icon-preset NB-folder-icon-filled', 'data-icon': icon_name, 'data-icon-set': 'heroicons-solid' }, [
                    $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/heroicons-solid/' + icon_name + '.svg' })
                ]);
                $items.append($icon);
            });
            $container.append($row);
        });

        return $container;
    },

    // Build the emoji picker grid
    make_emoji_picker: function () {
        var $container = $.make('div', { className: 'NB-folder-icon-emojis-container' });

        _.each(this.EMOJI_CATEGORIES, function (category) {
            var $row = $.make('div', { className: 'NB-folder-icon-emoji-row' }, [
                $.make('div', { className: 'NB-folder-icon-emoji-label' }, category.label),
                $.make('div', { className: 'NB-folder-icon-emoji-items' })
            ]);
            var $items = $row.find('.NB-folder-icon-emoji-items');
            _.each(category.emojis, function (entry) {
                var emoji = entry[0], title = entry[1];
                var $emoji = $.make('div', { className: 'NB-folder-icon-emoji-option', 'data-emoji': emoji, title: title }, emoji);
                $items.append($emoji);
            });
            $container.append($row);
        });

        return $container;
    },

    // Build the color palette grid
    make_color_palette: function () {
        var $colors = $.make('div', { className: 'NB-folder-icon-colors-grid' });
        _.each(this.COLOR_PALETTE, function (color) {
            var $color = $.make('div', {
                className: 'NB-folder-icon-color',
                style: 'background-color: ' + color + (color === '#ffffff' ? '; border: 1px solid #ddd' : ''),
                'data-color': color
            });
            $colors.append($color);
        });

        return $colors;
    },

    // Build the upload section
    make_upload_section: function () {
        return $.make('div', { className: 'NB-folder-icon-section NB-folder-icon-upload-section' }, [
            $.make('div', { className: 'NB-folder-icon-upload-container' }, [
                $.make('input', { type: 'file', className: 'NB-folder-icon-file-input', accept: 'image/*' }),
                $.make('div', { className: 'NB-folder-icon-upload-button' }, [
                    $.make('div', { className: 'NB-folder-icon-upload-icon' }),
                    $.make('div', { className: 'NB-folder-icon-upload-text' }, [
                        $.make('span', { className: 'NB-folder-icon-upload-label' }, 'Upload Custom Image'),
                        $.make('span', { className: 'NB-folder-icon-upload-hint' }, 'PNG, JPG, GIF, SVG, or WebP \u2014 max 5 MB, any size')
                    ]),
                    $.make('div', { className: 'NB-loading' })
                ]),
                $.make('div', { className: 'NB-folder-icon-upload-preview' }),
                $.make('div', { className: 'NB-folder-icon-upload-error' })
            ])
        ]);
    },

    // Build the search input for filtering icons
    // Build the inline search filter (right-justified next to section label)
    make_search_input: function () {
        return $.make('div', { className: 'NB-folder-icon-search' }, [
            $.make('img', { src: NEWSBLUR.Globals.MEDIA_URL + 'img/icons/lucide/search.svg', className: 'NB-folder-icon-search-icon' }),
            $.make('input', {
                type: 'text',
                className: 'NB-folder-icon-search-input',
                placeholder: 'Filter icons...'
            }),
            $.make('div', { className: 'NB-folder-icon-search-clear NB-hidden' }, '\u00d7')
        ]);
    },

    // Filter icons and emojis based on search query.
    // Only hides individual icons/emojis that don't match.
    // Sections, section headers, upload, and color always stay visible.
    filter_icons: function ($editor, query) {
        query = (query || '').toLowerCase().trim();
        var self = this;

        // Toggle clear button
        $('.NB-folder-icon-search-clear', $editor).toggleClass('NB-hidden', !query);

        if (!query) {
            // Show everything
            $('.NB-folder-icon-preset', $editor).show();
            $('.NB-folder-icon-emoji-option', $editor).show();
            $('.NB-folder-icon-preset-row', $editor).show();
            $('.NB-folder-icon-filled-row', $editor).show();
            $('.NB-folder-icon-emoji-row', $editor).show();
            $('.NB-folder-icon-preset-label', $editor).show();
            $('.NB-folder-icon-filled-label', $editor).show();
            $('.NB-folder-icon-emoji-label', $editor).show();
            $('.NB-folder-icon-no-results', $editor).remove();
            return;
        }

        var terms = query.split(/\s+/);
        var has_any_match = false;

        // Reset all rows to visible before filtering so :visible checks work
        $('.NB-folder-icon-preset-row, .NB-folder-icon-filled-row, .NB-folder-icon-emoji-row', $editor).show();

        // Filter Lucide outline icons
        $('.NB-folder-icon-presets-container .NB-folder-icon-preset', $editor).each(function () {
            var $icon = $(this);
            var icon_name = $icon.data('icon');
            var search_terms = self.ICON_SEARCH_TERMS[icon_name] || [icon_name.replace(/-/g, ' ')];
            var match = _.every(terms, function (term) {
                return _.some(search_terms, function (st) {
                    return st.indexOf(term) !== -1;
                });
            });
            $icon.toggle(match);
            if (match) has_any_match = true;
        });

        // Filter Heroicons solid icons
        $('.NB-folder-icon-filled-container .NB-folder-icon-preset', $editor).each(function () {
            var $icon = $(this);
            var icon_name = $icon.data('icon');
            var search_key = 'heroicons-' + icon_name;
            var search_terms = self.ICON_SEARCH_TERMS[search_key] || [icon_name.replace(/-/g, ' ')];
            var match = _.every(terms, function (term) {
                return _.some(search_terms, function (st) {
                    return st.indexOf(term) !== -1;
                });
            });
            $icon.toggle(match);
            if (match) has_any_match = true;
        });

        // Filter emojis
        $('.NB-folder-icon-emoji-option', $editor).each(function () {
            var $emoji = $(this);
            var emoji_char = $emoji.data('emoji');
            var title = ($emoji.attr('title') || '').toLowerCase();
            var search_terms = self.EMOJI_SEARCH_TERMS[emoji_char] || [title];
            var match = _.every(terms, function (term) {
                return _.some(search_terms, function (st) {
                    return st.indexOf(term) !== -1;
                });
            });
            $emoji.toggle(match);
            if (match) has_any_match = true;
        });

        // Hide category labels when searching (filtered results are flat)
        $('.NB-folder-icon-preset-label', $editor).hide();
        $('.NB-folder-icon-filled-label', $editor).hide();
        $('.NB-folder-icon-emoji-label', $editor).hide();

        // Hide rows that have no visible icons
        $('.NB-folder-icon-preset-row, .NB-folder-icon-filled-row, .NB-folder-icon-emoji-row', $editor).each(function () {
            var $row = $(this);
            var has_visible = $row.find('.NB-folder-icon-preset:visible, .NB-folder-icon-emoji-option:visible').length > 0;
            $row.toggle(has_visible);
        });

        // Show/hide no results message
        $('.NB-folder-icon-no-results', $editor).remove();
        if (!has_any_match) {
            $editor.append($.make('div', { className: 'NB-folder-icon-no-results' }, 'No icons match "' + query + '"'));
        }
    },

    // Build the complete icon editor with all sections
    // Options:
    //   include_upload: boolean (default true) - whether to show upload section
    //   include_reset: boolean (default false) - whether to show reset button
    //   reset_label: string (default 'Clear icon') - label for reset button
    make_icon_editor: function (options) {
        options = options || {};
        var include_upload = options.include_upload !== false;
        var include_reset = options.include_reset === true;
        var reset_label = options.reset_label || 'Clear icon';
        var self = this;

        var sections = [];

        if (include_upload) {
            sections.push(this.make_upload_section());
        }

        sections.push(
            $.make('div', { className: 'NB-folder-icon-section' }, [
                $.make('div', { className: 'NB-folder-icon-section-label' }, 'Color'),
                this.make_color_palette()
            ])
        );

        // Outline Icons section with inline search filter on the right
        sections.push(
            $.make('div', { className: 'NB-folder-icon-section' }, [
                $.make('div', { className: 'NB-folder-icon-section-header' }, [
                    $.make('div', { className: 'NB-folder-icon-section-label' }, 'Outline Icons'),
                    this.make_search_input()
                ]),
                this.make_preset_icons()
            ])
        );

        sections.push(
            $.make('div', { className: 'NB-folder-icon-section' }, [
                $.make('div', { className: 'NB-folder-icon-section-label' }, 'Filled Icons'),
                this.make_filled_icons()
            ])
        );

        sections.push(
            $.make('div', { className: 'NB-folder-icon-section' }, [
                $.make('div', { className: 'NB-folder-icon-section-label' }, 'Emoji'),
                this.make_emoji_picker()
            ])
        );

        if (include_reset) {
            sections.push(
                $.make('div', { className: 'NB-folder-icon-section NB-folder-icon-reset-section' }, [
                    $.make('a', { className: 'NB-folder-icon-clear', href: '#' }, reset_label)
                ])
            );
        }

        var $editor = $.make('div', { className: 'NB-folder-icon-editor' }, sections);

        // Bind live search
        var $search_input = $editor.find('.NB-folder-icon-search-input');
        $search_input.on('input', function () {
            self.filter_icons($editor, $(this).val());
        });

        // Bind clear button
        $editor.find('.NB-folder-icon-search-clear').on('click', function () {
            $search_input.val('').trigger('input').focus();
        });

        return $editor;
    },

    // Update icon grid colors using mask-image technique
    update_icon_grid_colors: function ($container, color) {
        var has_color = color && color !== '#000000';

        $('.NB-folder-icon-preset img', $container).each(function () {
            var $img = $(this);
            var icon_url = $img.attr('src');

            if (has_color) {
                // Replace img with colored span using mask-image
                var $colored = $.make('span', { className: 'NB-folder-icon-colored-preview' });
                $colored.css({
                    'display': 'inline-block',
                    'width': '20px',
                    'height': '20px',
                    'background-color': color,
                    '-webkit-mask-image': 'url(' + icon_url + ')',
                    'mask-image': 'url(' + icon_url + ')',
                    '-webkit-mask-size': 'contain',
                    'mask-size': 'contain',
                    '-webkit-mask-repeat': 'no-repeat',
                    'mask-repeat': 'no-repeat',
                    '-webkit-mask-position': 'center',
                    'mask-position': 'center'
                });
                $colored.attr('data-original-src', icon_url);
                $img.replaceWith($colored);
            }
        });

        // Also handle already-colored previews
        $('.NB-folder-icon-preset .NB-folder-icon-colored-preview', $container).each(function () {
            var $preview = $(this);
            if (has_color) {
                $preview.css('background-color', color);
            } else {
                // Restore to original img
                var icon_url = $preview.attr('data-original-src');
                var $img = $.make('img', { src: icon_url });
                $preview.replaceWith($img);
            }
        });
    }
};
