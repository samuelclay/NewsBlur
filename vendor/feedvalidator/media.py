from validators import *

class media_elements:
  def do_media_adult(self):
    self.log(DeprecatedMediaAdult({"parent":self.name, "element":"media:adult"}))
    return truefalse(), noduplicates()
  def do_media_category(self):
    return media_category()
  def do_media_copyright(self):
    return media_copyright(), noduplicates()
  def do_media_credit(self):
    return media_credit()
  def do_media_description(self):
    return media_title(), noduplicates()
  def do_media_keywords(self):
    return text()
  def do_media_hash(self):
    return media_hash()
  def do_media_player(self):
    return media_player()
  def do_media_rating(self):
    return media_rating()
  def do_media_restriction(self):
    return media_restriction()
  def do_media_text(self):
    return media_text()
  def do_media_title(self):
    return media_title(), noduplicates()
  def do_media_thumbnail(self):
    return media_thumbnail()

class media_category(nonhtml,rfc2396_full):
  def getExpectedAttrNames(self):
      return [(None,u'label'),(None, u'scheme')]
  def prevalidate(self):
    self.name = "label"
    self.value = self.attrs.get((None,u'label'))
    if self.value: nonhtml.validate(self)

    self.name = "scheme"
    self.value = self.attrs.get((None,u'scheme'))
    if self.value: rfc2396_full.validate(self)

    self.name = "media_category"
    self.value = ""

class media_copyright(nonhtml,rfc2396_full):
  def getExpectedAttrNames(self):
      return [(None,u'url')]
  def prevalidate(self):
    self.name = "url"
    self.value = self.attrs.get((None,u'url'))
    if self.value: rfc2396_full.validate(self)

    self.name = "media_copyright"
    self.value = ""

class media_credit(text,rfc2396_full):
  EBU = [
    "actor", "adaptor", "anchor person", "animal trainer", "animator",
    "announcer", "armourer", "art director", "artist/performer",
    "assistant camera", "assistant chief lighting technician",
    "assistant director", "assistant producer", "assistant visual editor",
    "author", "broadcast assistant", "broadcast journalist", "camera operator",
    "carpenter", "casting", "causeur", "chief lighting technician", "choir",
    "choreographer", "clapper loader", "commentary or commentator",
    "commissioning broadcaster", "composer", "computer programmer",
    "conductor", "consultant", "continuity checker", "correspondent",
    "costume designer", "dancer", "dialogue coach", "director",
    "director of photography", "distribution company", "draughtsman",
    "dresser", "dubber", "editor/producer", "editor", "editor", "ensemble",
    "executive producer", "expert", "fight director", "floor manager",
    "focus puller", "foley artist", "foley editor", "foley mixer",
    "graphic assistant", "graphic designer", "greensman", "grip",
    "hairdresser", "illustrator", "interviewed guest", "interviewer",
    "key character", "key grip", "key talents", "leadman", "librettist",
    "lighting director", "lighting technician", "location manager",
    "lyricist", "make up artist", "manufacturer", "matte artist",
    "music arranger", "music group", "musician", "news reader", "orchestra",
    "participant", "photographer", "post", "producer", "production assistant",
    "production company", "production department", "production manager",
    "production secretary", "programme production researcher",
    "property manager", "publishing company", "puppeteer", "pyrotechnician",
    "reporter", "rigger", "runner", "scenario", "scenic operative",
    "script supervisor", "second assistant camera",
    "second assistant director", "second unit director", "set designer",
    "set dresser", "sign language", "singer", "sound designer", "sound mixer",
    "sound recordist", "special effects", "stunts", "subtitles",
    "technical director", "term", "translation", "transportation manager",
    "treatment/programme proposal", "vision mixer", "visual editor",
    "visual effects", "wardrobe", "witness",

    # awaiting confirmation
    "artist", "performer", "editor", "producer", "treatment",
    "treatment proposal", "programme proposal",
  ]

  def getExpectedAttrNames(self):
    return [(None, u'role'),(None,u'scheme')]
  def prevalidate(self):
    scheme = self.attrs.get((None, 'scheme')) or 'urn:ebu'
    role = self.attrs.get((None, 'role'))

    if role:
      if scheme=='urn:ebu' and role not in self.EBU:
        self.log(InvalidCreditRole({"parent":self.parent.name, "element":self.name, "attr":"role", "value":role}))
      elif role != role.lower():
        self.log(InvalidCreditRole({"parent":self.parent.name, "element":self.name, "attr":"role", "value":role}))

    self.value = scheme
    self.name = "scheme"
    if scheme != 'urn:ebu': rfc2396_full.validate(self)

    self.name = "media_credit"
    self.value = ""

class media_hash(text):
  def getExpectedAttrNames(self):
    return [(None,u'algo')]
  def prevalidate(self):
    self.algo = self.attrs.get((None, 'algo'))
    if self.algo and self.algo not in ['md5', 'sha-1']:
      self.log(InvalidMediaHash({"parent":self.parent.name, "element":self.name, "attr":"algo", "value":self.algo}))
  def validate(self):
    self.value = self.value.strip()
    if not re.match("^[0-9A-Za-z]+$",self.value):
      self.log(InvalidMediaHash({"parent":self.parent.name, "element":self.name, "value":self.value}))
    else:
      if self.algo == 'sha-1':
        if len(self.value) != 40:
          self.log(InvalidMediaHash({"parent":self.parent.name, "element":self.name, "algo":self.algo, "value":self.value}))
      else:
        if len(self.value) != 32:
          self.log(InvalidMediaHash({"parent":self.parent.name, "element":self.name, "algo":self.algo, "value":self.value}))

class media_rating(rfc2396_full):
  def getExpectedAttrNames(self):
    return [(None, u'scheme')]
  def validate(self):
    scheme = self.attrs.get((None, 'scheme')) or 'urn:simple'
    if scheme == 'urn:simple':
      if self.value not in ['adult', 'nonadult']:
        self.log(InvalidMediaRating({"parent":self.parent.name, "element":self.name, "scheme":scheme, "value":self.value}))
    elif scheme == 'urn:mpaa':
      if self.value not in ['g', 'm', 'nc-17', 'pg', 'pg-13', 'r', 'x']:
        self.log(InvalidMediaRating({"parent":self.parent.name, "element":self.name, "scheme":scheme, "value":self.value}))
    elif scheme == 'urn:v-chip':
      if self.value not in ['14+', '18+', 'c', 'c8', 'g', 'pg',
        'tv-14', 'tv-g', 'tv-ma', 'tv-pg', 'tv-y', 'tv-y7', 'tv-y7-fv']:
        self.log(InvalidMediaRating({"parent":self.parent.name, "element":self.name, "scheme":scheme, "value":self.value}))
    elif scheme == 'urn:icra':
      code = '([nsvlocx]z [01]|(n[a-c]|s[a-f]|v[a-j]|l[a-c]|o[a-h]|c[a-b]|x[a-e]) 1)'
      if not re.match(r"^r \(%s( %s)*\)$" %(code,code),self.value):
        self.log(InvalidMediaRating({"parent":self.parent.name, "element":self.name, "scheme":scheme, "value":self.value}))
      pass
    else:
      self.value = scheme
      self.name = 'scheme'
      rfc2396_full.validate(self)

class media_restriction(text,rfc2396_full,iso3166):
  def getExpectedAttrNames(self):
    return [(None, u'relationship'),(None,u'type')]
  def validate(self):
    relationship = self.attrs.get((None, 'relationship'))
    if not relationship:
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"relationship"}))
    elif relationship not in ['allow','disallow']:
      self.log(InvalidMediaRestrictionRel({"parent":self.parent.name, "element":self.name, "attr":"relationship", "value":relationship}))

    type = self.attrs.get((None, 'type'))
    if not type:
      if self.value and self.value not in ['all','none']:
        self.log(InvalidMediaRestriction({"parent":self.parent.name, "element":self.name, "value":self.value}))
    elif type == 'country':
      self.name = 'country'
      countries = self.value.upper().split(' ')
      for self.value in countries:
        iso3166.validate(self)
    elif type == 'uri':
      rfc2396_full.validate(self)
    else:
      self.log(InvalidMediaRestrictionType({"parent":self.parent.name, "element":self.name, "attr":"type", "value":type}))

class media_player(validatorBase,positiveInteger,rfc2396_full):
  def getExpectedAttrNames(self):
    return [(None,u'height'),(None,u'url'),(None, u'width')]
  def validate(self):
    self.value = self.attrs.get((None, 'url'))
    if self.value:
      self.name = "url"
      rfc2396_full.validate(self)
    else:
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"url"}))

    self.value = self.attrs.get((None, 'height'))
    self.name = "height"
    if self.value: positiveInteger.validate(self)

    self.value = self.attrs.get((None, 'width'))
    self.name = "width"
    if self.value: positiveInteger.validate(self)

class media_text(nonhtml):
  def getExpectedAttrNames(self):
    return [(None,u'end'),(None,u'lang'),(None,u'start'),(None, u'type')]
  def prevalidate(self):
    self.type = self.attrs.get((None, 'type'))
    if self.type and self.type not in ['plain', 'html']:
      self.log(InvalidMediaTextType({"parent":self.parent.name, "element":self.name, "attr":"type", "value":self.type}))

    start = self.attrs.get((None, 'start'))
    if start and not media_thumbnail.npt_re.match(start):
      self.log(InvalidNPTTime({"parent":self.parent.name, "element":self.name, "attr":"start", "value":start}))
    else:
      self.log(ValidNPTTime({"parent":self.parent.name, "element":self.name, "attr":"start", "value":start}))

    end = self.attrs.get((None, 'end'))
    if end and not media_thumbnail.npt_re.match(end):
      self.log(InvalidNPTTime({"parent":self.parent.name, "element":self.name, "attr":"end", "value":end}))
    else:
      self.log(ValidNPTTime({"parent":self.parent.name, "element":self.name, "attr":"end", "value":end}))

    lang = self.attrs.get((None, 'lang'))
    if lang: iso639_validate(self.log,lang,'lang',self.parent)

  def validate(self):
    if self.type == 'html':
      self.validateSafe(self.value)
    else:
      nonhtml.validate(self, ContainsUndeclaredHTML)

class media_title(nonhtml):
  def getExpectedAttrNames(self):
    return [(None, u'type')]
  def prevalidate(self):
    self.type = self.attrs.get((None, 'type'))
    if self.type and self.type not in ['plain', 'html']:
      self.log(InvalidMediaTextType({"parent":self.parent.name, "element":self.name, "attr":"type", "value":self.type}))
  def validate(self):
    if self.type == 'html':
      self.validateSafe(self.value)
    else:
      nonhtml.validate(self, ContainsUndeclaredHTML)

class media_thumbnail(validatorBase,positiveInteger,rfc2396_full):
  npt_re = re.compile("^(now)|(\d+(\.\d+)?)|(\d+:\d\d:\d\d(\.\d+)?)$")
  def getExpectedAttrNames(self):
    return [(None,u'height'),(None,u'time'),(None,u'url'),(None, u'width')]
  def validate(self):
    time = self.attrs.get((None, 'time'))
    if time and not media_thumbnail.npt_re.match(time):
      self.log(InvalidNPTTime({"parent":self.parent.name, "element":self.name, "attr":"time", "value":time}))
    else:
      self.log(ValidNPTTime({"parent":self.parent.name, "element":self.name, "attr":"time", "value":time}))

    self.value = self.attrs.get((None, 'url'))
    if self.value:
      self.name = "url"
      rfc2396_full.validate(self)
    else:
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"url"}))

    self.value = self.attrs.get((None, 'height'))
    self.name = "height"
    if self.value: positiveInteger.validate(self)

    self.value = self.attrs.get((None, 'width'))
    self.name = "width"
    if self.value: positiveInteger.validate(self)

from extension import extension_everywhere
class media_content(validatorBase, media_elements, extension_everywhere,
    positiveInteger, rfc2396_full, truefalse, nonNegativeInteger):
  def getExpectedAttrNames(self):
    return [
        (None,u'bitrate'),
        (None,u'channels'),
        (None,u'duration'),
        (None,u'expression'),
        (None,u'fileSize'),
        (None,u'framerate'),
        (None,u'height'),
        (None,u'isDefault'),
        (None,u'lang'),
        (None,u'medium'),
        (None,u'samplingrate'),
        (None,u'type'),
        (None,u'url'),
        (None,u'width')
      ]
  def validate(self):
    self.value = self.attrs.get((None,u'bitrate'))
    if self.value and not re.match('\d+\.?\d*', self.value):
      self.log(InvalidFloat({"parent":self.parent.name, "element":self.name,
        "attr": 'bitrate', "value":self.value}))

    self.value = self.attrs.get((None, 'channels'))
    self.name = "channels"
    if self.value: nonNegativeInteger.validate(self)

    self.value = self.attrs.get((None,u'duration'))
    if self.value and not re.match('\d+\.?\d*', self.value):
      self.log(InvalidFloat({"parent":self.parent.name, "element":self.name,
        "attr": 'duration', "value":self.value}))

    self.value = self.attrs.get((None,u'expression'))
    if self.value and self.value not in ['sample', 'full', 'nonstop']:
      self.log(InvalidMediaExpression({"parent":self.parent.name, "element":self.name, "value": self.value}))

    self.value = self.attrs.get((None, 'fileSize'))
    self.name = "fileSize"
    if self.value: positiveInteger.validate(self)

    self.value = self.attrs.get((None,u'framerate'))
    if self.value and not re.match('\d+\.?\d*', self.value):
      self.log(InvalidFloat({"parent":self.parent.name, "element":self.name,
        "attr": 'framerate', "value":self.value}))

    self.value = self.attrs.get((None, 'height'))
    self.name = "height"
    if self.value: positiveInteger.validate(self)

    self.value = self.attrs.get((None, 'isDefault'))
    if self.value: truefalse.validate(self)

    self.value = self.attrs.get((None, 'lang'))
    if self.value: iso639_validate(self.log,self.value,'lang',self.parent)

    self.value = self.attrs.get((None,u'medium'))
    if self.value and self.value not in ['image', 'audio', 'video', 'document', 'executable']:
      self.log(InvalidMediaMedium({"parent":self.parent.name, "element":self.name, "value": self.value}))

    self.value = self.attrs.get((None,u'samplingrate'))
    if self.value and not re.match('\d+\.?\d*', self.value):
      self.log(InvalidFloat({"parent":self.parent.name, "element":self.name,
        "attr": 'samplingrate', "value":self.value}))

    self.value = self.attrs.get((None,u'type'))
    if self.value and not mime_re.match(self.value):
      self.log(InvalidMIMEAttribute({"parent":self.parent.name, "element":self.name, "attr":'type'}))

    self.name = "url"
    self.value = self.attrs.get((None,u'url'))
    if self.value: rfc2396_full.validate(self)

    self.value = self.attrs.get((None, 'width'))
    self.name = "width"
    if self.value: positiveInteger.validate(self)

class media_group(validatorBase, media_elements):
  def do_media_content(self):
    return media_content()
