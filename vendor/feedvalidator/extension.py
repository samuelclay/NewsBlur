"""$Id: extension.py 750 2007-04-06 18:40:28Z rubys $"""

__author__ = "Sam Ruby <http://intertwingly.net>, Mark Pilgrim <http://diveintomark.org/> and Phil Ringnalda <http://philringnalda.com>"
__version__ = "$Revision: 750 $"
__date__ = "$Date: 2007-04-06 18:40:28 +0000 (Fri, 06 Apr 2007) $"
__copyright__ = "Copyright (c) 2002 Sam Ruby, Mark Pilgrim and Phil Ringnalda"
            
from validators import *
from logging import *

########################################################################
#                 Extensions that are valid everywhere                 #
########################################################################

class extension_everywhere:
  def do_dc_title(self):
    return text(), noduplicates()

  def do_dc_description(self):
    return text(), noduplicates()

  def do_dc_publisher(self):
    if "webMaster" in self.children:
      self.log(DuplicateSemantics({"core":"webMaster", "ext":"dc:publisher"}))
    return text() # duplicates allowed

  def do_dc_contributor(self):
    return text() # duplicates allowed

  def do_dc_type(self):
    return text(), noduplicates()
  
  def do_dc_format(self):
    return text(), noduplicates()

  def do_dc_identifier(self):
    return text()

  def do_dc_source(self):
    if "source" in self.children:
      self.log(DuplicateItemSemantics({"core":"source", "ext":"dc:source"}))
    return text(), noduplicates()

  def do_dc_language(self):
    if "language" in self.children:
      self.log(DuplicateSemantics({"core":"language", "ext":"dc:language"}))
    return iso639(), noduplicates()

  def do_dc_relation(self):
    return text(), # duplicates allowed

  def do_dc_coverage(self):
    return text(), # duplicates allowed

  def do_dc_rights(self):
    if "copyright" in self.children:
      self.log(DuplicateSemantics({"core":"copyright", "ext":"dc:rights"}))
    return nonhtml(), noduplicates()

  def do_dcterms_alternative(self):
    return text() #duplicates allowed

  def do_dcterms_abstract(self):
    return text(), noduplicates()

  def do_dcterms_tableOfContents(self):
    return rdfResourceURI(), noduplicates()

  def do_dcterms_created(self):
    return w3cdtf(), noduplicates()
  
  def do_dcterms_valid(self):
    return eater()
  
  def do_dcterms_available(self):
    return eater()

  def do_dcterms_issued(self):
    return w3cdtf(), noduplicates()

  def do_dcterms_modified(self):
    if "lastBuildDate" in self.children:
      self.log(DuplicateSemantics({"core":"lastBuildDate", "ext":"dcterms:modified"}))
    return w3cdtf(), noduplicates()

  def do_dcterms_dateAccepted(self):
    return text(), noduplicates()

  def do_dcterms_dateCopyrighted(self):
    return text(), noduplicates()

  def do_dcterms_dateSubmitted(self):
    return text(), noduplicates()

  def do_dcterms_extent(self):
    return positiveInteger(), nonblank(), noduplicates()

#  def do_dcterms_medium(self):
#    spec defines it as something that should never be used
#    undefined element'll do for now 

  def do_dcterms_isVersionOf(self):
    return rdfResourceURI() # duplicates allowed
  
  def do_dcterms_hasVersion(self):
    return rdfResourceURI() # duplicates allowed

  def do_dcterms_isReplacedBy(self):
    return rdfResourceURI() # duplicates allowed

  def do_dcterms_replaces(self):
    return rdfResourceURI() # duplicates allowed

  def do_dcterms_isRequiredBy(self):
    return rdfResourceURI() # duplicates allowed

  def do_dcterms_requires(self):
    return rdfResourceURI() # duplicates allowed

  def do_dcterms_isPartOf(self):
    return rdfResourceURI() # duplicates allowed

  def do_dcterms_hasPart(self):
    return rdfResourceURI() # duplicates allowed

  def do_dcterms_isReferencedBy(self):
    return rdfResourceURI() # duplicates allowed

  def do_dcterms_references(self):
    return rdfResourceURI() # duplicates allowed

  def do_dcterms_isFormatOf(self):
    return rdfResourceURI() # duplicates allowed

  def do_dcterms_hasFormat(self):
    return rdfResourceURI() # duplicates allowed

  def do_dcterms_conformsTo(self):
    return rdfResourceURI() # duplicates allowed

  def do_dcterms_spatial(self):
    return eater()  

  def do_dcterms_temporal(self):
    return eater()

  def do_dcterms_audience(self):
    return text()

  def do_dcterms_mediator(self):
    return text(), noduplicates()

  # added to DMCI, but no XML mapping has been defined
  def do_dcterms_accessRights(self):
    return eater()

  def do_dcterms_accrualMethod(self):
    return eater()

  def do_dcterms_accrualPeriodicity(self):
    return eater()

  def do_dcterms_accrualPolicy(self):
    return eater()

  def do_dcterms_bibliographicCitation(self):
    return eater()

  def do_dcterms_educationLevel(self):
    return eater()

  def do_dcterms_instructionalMethod(self):
    return eater()

  def do_dcterms_license(self):
    return eater()

  def do_dcterms_provenance(self):
    return eater()

  def do_dcterms_rightsHolder(self):
    return eater()

  def do_rdfs_seeAlso(self):
    return rdfResourceURI() # duplicates allowed

  def do_geo_Point(self):
    return geo_point()

  def do_geo_lat(self):
    return latitude()

  def do_geo_long(self):
    return longitude()

  def do_geo_alt(self):
    return decimal()

  def do_geourl_latitude(self):
    return latitude()

  def do_geourl_longitude(self):
    return longitude()

  def do_icbm_latitude(self):
    return latitude()

  def do_icbm_longitude(self):
    return longitude()

########################################################################
#    Extensions that are valid at either the channel or item levels    #
########################################################################

from media import media_elements, media_content, media_group
class extension_channel_item(extension_everywhere, media_elements):
  def do_taxo_topics(self):
    return eater()

  def do_l_link(self):
    return l_link()


########################################################################
#         Extensions that are valid at only at the item level          #
########################################################################

class extension_item(extension_channel_item):
  def do_annotate_reference(self):
    return rdfResourceURI(), noduplicates()
    
  def do_ag_source(self):
    return text(), noduplicates()

  def do_ag_sourceURL(self):
    return rfc2396_full(), noduplicates()

  def do_ag_timestamp(self):
    return iso8601(), noduplicates()

  def do_ev_startdate(self):
    return iso8601(), noduplicates()

  def do_ev_enddate(self):
    return iso8601(), noduplicates()

  def do_ev_location(self):
    return eater()

  def do_ev_organizer(self):
    return eater()

  def do_ev_type(self):
    return text(), noduplicates()

  def do_foaf_maker(self):
    return eater()

  def do_foaf_primaryTopic(self):
    return eater()

  def do_slash_comments(self):
    return nonNegativeInteger()

  def do_slash_section(self):
    return text()

  def do_slash_department(self):
    return text()

  def do_slash_hit_parade(self):
    return commaSeparatedIntegers(), noduplicates()

  def do_thr_children(self):
    return eater()

  def do_thr_in_reply_to(self):
    return in_reply_to()

  def do_wfw_comment(self):
    return rfc2396_full(), noduplicates()

  def do_wfw_commentRss(self):
    return rfc2396_full(), noduplicates()

  def do_wfw_commentRSS(self):
    self.log(CommentRSS({"parent":self.parent.name, "element":self.name}))
    return rfc2396_full(), noduplicates()

  def do_wiki_diff(self):
     return text()

  def do_wiki_history(self):
     return text()

  def do_wiki_importance(self):
     return text()

  def do_wiki_status(self):
     return text()

  def do_wiki_version(self):
     return text()

  def do_g_actor(self):
    return nonhtml(), noduplicates()

  def do_g_age(self):
    return nonNegativeInteger(), noduplicates()

  def do_g_agent(self):
    return nonhtml(), noduplicates()

  def do_g_area(self):
    return nonhtml(), noduplicates() # intUnit

  def do_g_apparel_type(self):
    return nonhtml(), noduplicates()

  def do_g_artist(self):
    return nonhtml(), noduplicates()

  def do_g_author(self):
    return nonhtml(), noduplicates()

  def do_g_bathrooms(self):
    return nonNegativeInteger(), noduplicates()

  def do_g_bedrooms(self):
    return nonNegativeInteger(), noduplicates()

  def do_g_brand(self):
    return nonhtml(), noduplicates()

  def do_g_calories(self):
    return g_float(), noduplicates()

  def do_g_cholesterol(self):
    return g_float(), noduplicates()

  def do_g_color(self):
    return nonhtml(), noduplicates()

  def do_g_cooking_time(self):
    return g_float(), noduplicates()

  def do_g_condition(self):
    return nonhtml(), noduplicates()

  def do_g_course(self):
    return nonhtml(), noduplicates()

  def do_g_course_date_range(self):
    return g_dateTimeRange(), noduplicates()

  def do_g_course_number(self):
    return nonhtml(), noduplicates()

  def do_g_course_times(self):
    return nonhtml(), noduplicates()

  def do_g_cuisine(self):
    return nonhtml(), noduplicates()

  def do_g_currency(self):
    return iso4217(), noduplicates()

  def do_g_delivery_notes(self):
    return nonhtml(), noduplicates()

  def do_g_delivery_radius(self):
    return floatUnit(), noduplicates()

  def do_g_education(self):
    return nonhtml(), noduplicates()

  def do_g_employer(self):
    return nonhtml(), noduplicates()

  def do_g_ethnicity(self):
    return nonhtml(), noduplicates()

  def do_g_event_date_range(self):
    return g_dateTimeRange(), noduplicates()

  def do_g_expiration_date(self):
    return iso8601_date(), noduplicates()

  def do_g_expiration_date_time(self):
    return iso8601(), noduplicates()

  def do_g_fiber(self):
    return g_float(), noduplicates()

  def do_g_from_location(self):
    return g_locationType(), noduplicates()

  def do_g_gender(self):
    return g_genderEnumeration(), noduplicates()

  def do_g_hoa_dues(self):
    return g_float(), noduplicates()

  def do_g_format(self):
    return nonhtml(), noduplicates()

  def do_g_id(self):
    return nonhtml(), noduplicates()

  def do_g_image_link(self):
    return rfc2396_full(), maxten()

  def do_g_immigration_status(self):
    return nonhtml(), noduplicates()

  def do_g_interested_in(self):
    return nonhtml(), noduplicates()

  def do_g_isbn(self):
    return nonhtml(), noduplicates()

  def do_g_job_function(self):
    return nonhtml(), noduplicates()

  def do_g_job_industry(self):
    return nonhtml(), noduplicates()

  def do_g_job_type(self):
    return nonhtml(), noduplicates()

  def do_g_label(self):
    return g_labelType(), maxten()

  def do_g_listing_type(self):
    return truefalse(), noduplicates()

  def do_g_location(self):
    return g_full_locationType(), noduplicates()

  def do_g_main_ingredient(self):
    return nonhtml(), noduplicates()

  def do_g_make(self):
    return nonhtml(), noduplicates()

  def do_g_manufacturer(self):
    return nonhtml(), noduplicates()

  def do_g_manufacturer_id(self):
    return nonhtml(), noduplicates()

  def do_g_marital_status(self):
    return g_maritalStatusEnumeration(), noduplicates()

  def do_g_meal_type(self):
    return nonhtml(), noduplicates()

  def do_g_megapixels(self):
    return floatUnit(), noduplicates()

  def do_g_memory(self):
    return floatUnit(), noduplicates()

  def do_g_mileage(self):
    return g_intUnit(), noduplicates()

  def do_g_model(self):
    return nonhtml(), noduplicates()

  def do_g_model_number(self):
    return nonhtml(), noduplicates()

  def do_g_name_of_item_being_reviewed(self):
    return nonhtml(), noduplicates()

  def do_g_news_source(self):
    return nonhtml(), noduplicates()

  def do_g_occupation(self):
    return nonhtml(), noduplicates()

  def do_g_payment_notes(self):
    return nonhtml(), noduplicates()

  def do_g_pages(self):
    return positiveInteger(), nonblank(), noduplicates()

  def do_g_payment_accepted(self):
    return g_paymentMethodEnumeration()

  def do_g_pickup(self):
    return truefalse(), noduplicates()

  def do_g_preparation_time(self):
    return floatUnit(), noduplicates()

  def do_g_price(self):
    return floatUnit(), noduplicates()

  def do_g_price_type(self):
    return g_priceTypeEnumeration(), noduplicates()

  def do_g_processor_speed(self):
    return floatUnit(), noduplicates()

  def do_g_product_type(self):
    return nonhtml(), noduplicates()

  def do_g_property_type(self):
    return nonhtml(), noduplicates()

  def do_g_protein(self):
    return floatUnit(), noduplicates()

  def do_g_publication_name(self):
    return nonhtml(), noduplicates()

  def do_g_publication_volume(self):
    return nonhtml(), noduplicates()

  def do_g_publish_date(self):
    return iso8601_date(), noduplicates()

  def do_g_quantity(self):
    return nonNegativeInteger(), nonblank(), noduplicates()

  def do_g_rating(self):
    return g_ratingTypeEnumeration(), noduplicates()

  def do_g_review_type(self):
    return nonhtml(), noduplicates()

  def do_g_reviewer_type(self):
    return g_reviewerTypeEnumeration(), noduplicates()

  def do_g_salary(self):
    return g_float(), noduplicates()

  def do_g_salary_type(self):
    return g_salaryTypeEnumeration(), noduplicates()

  def do_g_saturated_fat(self):
    return g_float(), noduplicates()

  def do_g_school_district(self):
    return nonhtml(), noduplicates()

  def do_g_service_type(self):
    return nonhtml(), noduplicates()

  def do_g_servings(self):
    return g_float(), noduplicates()

  def do_g_sexual_orientation(self):
    return nonhtml(), noduplicates()

  def do_g_size(self):
    return nonhtml(), noduplicates() # TODO: expressed in either two or three dimensions.

  def do_g_shipping(self):
    return g_shipping(), noduplicates()

  def do_g_sodium(self):
    return g_float(), noduplicates()

  def do_g_subject(self):
    return nonhtml(), noduplicates()

  def do_g_subject_area(self):
    return nonhtml(), noduplicates()

  def do_g_tax_percent(self):
    return percentType(), noduplicates()

  def do_g_tax_region(self):
    return nonhtml(), noduplicates()

  def do_g_to_location(self):
    return g_locationType(), noduplicates()

  def do_g_total_carbs(self):
    return g_float(), noduplicates()

  def do_g_total_fat(self):
    return g_float(), noduplicates()

  def do_g_travel_date_range(self):
    return g_dateTimeRange(), noduplicates()

  def do_g_university(self):
    return nonhtml(), noduplicates()

  def do_g_upc(self):
    return nonhtml(), noduplicates()

  def do_g_url_of_item_being_reviewed(self):
    return rfc2396_full(), noduplicates()

  def do_g_vehicle_type(self):
    return nonhtml(), noduplicates()

  def do_g_vin(self):
    return nonhtml(), noduplicates()

  def do_g_weight(self):
    return floatUnit(), noduplicates()

  def do_g_year(self):
    return g_year(), noduplicates()

  def do_media_group(self):
    return media_group()

  def do_media_content(self):
    return media_content()

  def do_georss_where(self):
    return georss_where()

  def do_georss_point(self):
    return gml_pos()

  def do_georss_line(self):
    return gml_posList()

  def do_georss_polygon(self):
    return gml_posList()

  def do_georss_featuretypetag(self):
    return text()

  def do_georss_relationshiptag(self):
    return text()

  def do_georss_featurename(self):
    return text()

  def do_georss_elev(self):
    return decimal()

  def do_georss_floor(self):
    return Integer()

  def do_georss_radius(self):
    return Float()

class georss_where(validatorBase):
  def do_gml_Point(self):
    return gml_point()
  def do_gml_LineString(self):
    return gml_line()
  def do_gml_Polygon(self):
    return gml_polygon()
  def do_gml_Envelope(self):
    return gml_envelope()

class geo_srsName(validatorBase):
  def getExpectedAttrNames(self):
    return [(None, u'srsName')]

class gml_point(geo_srsName):
  def do_gml_pos(self):
    return gml_pos()

class geo_point(validatorBase):
  def do_geo_lat(self):
    return latitude()

  def do_geo_long(self):
    return longitude()

  def validate(self):
    if "geo_lat" not in self.children:
      self.log(MissingElement({"parent":self.name.replace('_',':'), "element":"geo:lat"}))
    if "geo_long" not in self.children:
      self.log(MissingElement({"parent":self.name.replace('_',':'), "element":"geo:long"}))


class gml_pos(text):
  def validate(self):
    if not re.match('^[-+]?\d+\.?\d*[ ,][-+]?\d+\.?\d*$', self.value):
      return self.log(InvalidCoord({'value':self.value}))
    if self.value.find(',')>=0:
      self.log(CoordComma({'value':self.value}))

class gml_line(geo_srsName):
  def do_gml_posList(self):
    return gml_posList()

class gml_posList(text):
  def validate(self):
    if self.value.find(',')>=0:
      # ensure that commas are only used to separate lat and long 
      if not re.match('^[-+.0-9]+[, ][-+.0-9]( [-+.0-9]+[, ][-+.0-9])+$',
        value.strip()):
        return self.log(InvalidCoordList({'value':self.value}))
      self.log(CoordComma({'value':self.value}))
      self.value=self.value.replace(',',' ')
    values = self.value.strip().split()
    if len(values)<3 or len(values)%2 == 1:
      return self.log(InvalidCoordList({'value':self.value}))
    for value in values:
      if not re.match('^[-+]?\d+\.?\d*$', value):
        return self.log(InvalidCoordList({'value':value}))

class gml_polygon(geo_srsName):
  def do_gml_exterior(self):
    return gml_exterior()

class gml_exterior(validatorBase):
  def do_gml_LinearRing(self):
    return gml_linearRing()

class gml_linearRing(geo_srsName):
  def do_gml_posList(self):
    return gml_posList()

class gml_envelope(geo_srsName):
  def do_gml_lowerCorner(self):
    return gml_pos()
  def do_gml_upperCorner(self):
    return gml_pos()

class access_restriction(enumeration):
  error = InvalidAccessRestrictionRel
  valuelist =  ["allow", "deny"]

  def getExpectedAttrNames(self):
    return [(None, u'relationship')]

  def prevalidate(self):
    self.children.append(True) # force warnings about "mixed" content

    if not self.attrs.has_key((None,"relationship")):
      self.log(MissingAttribute({"parent":self.parent.name, "element":self.name, "attr":"relationship"}))
    else:
      self.value=self.attrs.getValue((None,"relationship"))

########################################################################
#     Extensions that are valid at only at the RSS 2.0 item level      #
########################################################################

class extension_rss20_item(extension_item):
  def do_trackback_ping(self):
    return rfc2396_full(), noduplicates()

  def do_trackback_about(self):
    return rfc2396_full()

  def do_dcterms_accessRights(self):
    return eater()

  def do_dcterms_accrualMethod(self):
    return eater()

  def do_dcterms_accrualPeriodicity(self):
    return eater()

  def do_dcterms_accrualPolicy(self):
    return eater()

  def do_dcterms_bibliographicCitation(self):
    return eater()

  def do_dcterms_educationLevel(self):
    return eater()

  def do_dcterms_instructionalMethod(self):
    return eater()

  def do_dcterms_license(self):
    return eater()

  def do_dcterms_provenance(self):
    return eater()

  def do_dcterms_rightsHolder(self):
    return eater()

########################################################################
#     Extensions that are valid at only at the RSS 1.0 item level      #
########################################################################

class extension_rss10_item(extension_item):
  def do_trackback_ping(self):
    return rdfResourceURI(), noduplicates()

  def do_trackback_about(self):
    return rdfResourceURI()

  def do_l_permalink(self):
    return l_permalink()

class l_permalink(rdfResourceURI, MimeType):
  lNS = u'http://purl.org/rss/1.0/modules/link/'
  def getExpectedAttrNames(self):
    return rdfResourceURI.getExpectedAttrNames(self) + [(self.lNS, u'type')]
  def validate(self):
    if (self.lNS, 'type') in self.attrs.getNames():
      self.value=self.attrs.getValue((self.lNS, 'type'))
      MimeType.validate(self)
    return rdfResourceURI.validate(self) 

class l_link(rdfResourceURI, MimeType):
  lNS = u'http://purl.org/rss/1.0/modules/link/'
  def getExpectedAttrNames(self):
    return rdfResourceURI.getExpectedAttrNames(self) + [
      (self.lNS, u'lang'), (self.lNS, u'rel'),
      (self.lNS, u'type'), (self.lNS, u'title')
    ]
  def prevalidate(self):
    self.validate_optional_attribute((self.lNS,'lang'), iso639)
    self.validate_required_attribute((self.lNS,'rel'), rfc2396_full)
    self.validate_optional_attribute((self.lNS,'title'), nonhtml)

    if self.attrs.has_key((self.lNS, "type")):
      if self.attrs.getValue((self.lNS, "type")).find(':') < 0:
        self.validate_optional_attribute((self.lNS,'type'), MimeType)
      else:
        self.validate_optional_attribute((self.lNS,'type'), rfc2396_full)



########################################################################
#      Extensions that are valid at only at the Atom entry level       #
########################################################################

class extension_entry(extension_item):
  def do_dc_creator(self): # atom:creator
    return text() # duplicates allowed
  def do_dc_subject(self): # atom:category
    return text() # duplicates allowed
  def do_dc_date(self): # atom:published
    return w3cdtf(), noduplicates()
  def do_creativeCommons_license(self):
    return rfc2396_full()

  def do_trackback_ping(self):
    return rfc2396_full(), noduplicates()

  # XXX This should have duplicate semantics with link[@rel='related']
  def do_trackback_about(self):
    return rfc2396_full()

########################################################################
#        Extensions that are valid at only at the channel level        #
########################################################################

class extension_channel(extension_channel_item):
  def do_admin_generatorAgent(self):
    if "generator" in self.children:
      self.log(DuplicateSemantics({"core":"generator", "ext":"admin:generatorAgent"}))
    return admin_generatorAgent(), noduplicates()

  def do_admin_errorReportsTo(self):
    return admin_errorReportsTo(), noduplicates()

  def do_blogChannel_blogRoll(self):
    return rfc2396_full(), noduplicates()

  def do_blogChannel_mySubscriptions(self):
    return rfc2396_full(), noduplicates()

  def do_blogChannel_blink(self):
    return rfc2396_full(), noduplicates()

  def do_blogChannel_changes(self):
    return rfc2396_full(), noduplicates()

  def do_sy_updatePeriod(self):
    return sy_updatePeriod(), noduplicates()

  def do_sy_updateFrequency(self):
    return positiveInteger(), nonblank(), noduplicates()

  def do_sy_updateBase(self):
    return w3cdtf(), noduplicates()

  def do_foaf_maker(self):
    return eater()

  def do_cp_server(self):
    return rdfResourceURI()

  def do_wiki_interwiki(self):
     return text()

  def do_thr_in_reply_to(self):
    return in_reply_to()

  def do_cf_listinfo(self):
    from cf import listinfo
    return listinfo()

  def do_cf_treatAs(self):
    from cf import treatAs
    return treatAs()

  def do_opensearch_totalResults(self):
    return nonNegativeInteger(), noduplicates()

  def do_opensearch_startIndex(self):
    return Integer(), noduplicates()

  def do_opensearch_itemsPerPage(self):
    return nonNegativeInteger(), noduplicates()

  def do_opensearch_Query(self):
    from opensearch import Query
    return Query()

  def do_xhtml_div(self):
    return eater()

  def do_xhtml_meta(self):
    return xhtml_meta()

class xhtml_meta(validatorBase):
  def getExpectedAttrNames(self):
    return [ (None, u'name'), (None, u'content') ]
  def prevalidate(self):
    self.validate_required_attribute((None,'name'), xhtmlMetaEnumeration)
    self.validate_required_attribute((None,'content'), robotsEnumeration)

class xhtmlMetaEnumeration(caseinsensitive_enumeration):
  error = InvalidMetaName
  valuelist =  ["robots"]

class robotsEnumeration(caseinsensitive_enumeration):
  error = InvalidMetaContent
  valuelist =  [
    "all", "none",
    "index", "index,follow", "index,nofollow",
    "noindex", "noindex,follow", "noindex,nofollow",
    "follow", "follow,index", "follow,noindex",
    "nofollow", "nofollow,index", "nofollow,noindex"]

########################################################################
#       Extensions that are valid at only at the Atom feed level       #
########################################################################

class extension_feed(extension_channel):
  def do_dc_creator(self): # atom:creator
    return text() # duplicates allowed
  def do_dc_subject(self): # atom:category
    return text() # duplicates allowed
  def do_dc_date(self): # atom:updated
    return w3cdtf(), noduplicates()
  def do_creativeCommons_license(self):
    return rfc2396_full()
  def do_access_restriction(self):
    return access_restriction()

########################################################################
#                              Validators                              #
########################################################################

class admin_generatorAgent(rdfResourceURI): pass
class admin_errorReportsTo(rdfResourceURI): pass

class sy_updatePeriod(text):
  def validate(self):
    if self.value not in ('hourly', 'daily', 'weekly', 'monthly', 'yearly'):
      self.log(InvalidUpdatePeriod({"parent":self.parent.name, "element":self.name, "value":self.value}))
    else:
      self.log(ValidUpdatePeriod({"parent":self.parent.name, "element":self.name, "value":self.value}))

class g_complex_type(validatorBase):
  def getExpectedAttrNames(self):
    if self.getFeedType() == TYPE_RSS1:
      return [(u'http://www.w3.org/1999/02/22-rdf-syntax-ns#', u'parseType')]
    else:
      return []

class g_shipping(g_complex_type):
  def do_g_service(self):
    return g_serviceTypeEnumeration(), noduplicates()
  def do_g_country(self):
    return iso3166(), noduplicates()
  def do_g_price(self):
    return floatUnit(), noduplicates()

class g_dateTimeRange(g_complex_type):
  def do_g_start(self):
    return iso8601(), noduplicates()
  def do_g_end(self):
    return iso8601(), noduplicates()

class g_labelType(text):
  def validate(self):
    if self.value.find(',')>=0:
      self.log(InvalidLabel({"parent":self.parent.name, "element":self.name,
        "attr": ':'.join(self.name.split('_',1)), "value":self.value}))

class g_locationType(text):
  def validate(self):
    if len(self.value.split(',')) not in [2,3]: 
      self.log(InvalidLocation({"parent":self.parent.name, "element":self.name,
        "attr": ':'.join(self.name.split('_',1)), "value":self.value}))

class g_full_locationType(text):
  def validate(self):
    fields = self.value.split(',')
    if len(fields) != 5 or 0 in [len(f.strip()) for f in fields]: 
      self.log(InvalidFullLocation({"parent":self.parent.name, "element":self.name,
        "attr": ':'.join(self.name.split('_',1)), "value":self.value}))

class g_genderEnumeration(enumeration):
  error = InvalidGender
  valuelist =  ["Male", "M", "Female", "F"]

class g_maritalStatusEnumeration(enumeration):
  error = InvalidMaritalStatus
  valuelist =  ["single", "divorced", "separated", "widowed", "married", "in relationship"]

class g_paymentMethodEnumeration(enumeration):
  error = InvalidPaymentMethod
  valuelist =  ["Cash", "Check", "Visa", "MasterCard",
   "AmericanExpress", "Discover", "WireTransfer"]

class g_priceTypeEnumeration(enumeration):
  error = InvalidPriceType
  valuelist =  ["negotiable", "starting"]

class g_ratingTypeEnumeration(enumeration):
  error = InvalidRatingType
  valuelist =  ["1", "2", "3", "4", "5"]

class g_reviewerTypeEnumeration(enumeration):
  error = InvalidReviewerType
  valuelist =  ["editorial", "user"]

class g_salaryTypeEnumeration(enumeration):
  error = InvalidSalaryType
  valuelist =  ["starting", "negotiable"]

class g_serviceTypeEnumeration(enumeration):
  error = InvalidServiceType
  valuelist =  ['FedEx', 'UPS', 'DHL', 'Mail', 'Other', 'Overnight', 'Standard']

class g_float(text):
  def validate(self):
    import re
    if not re.match('\d+\.?\d*\s*\w*', self.value):
      self.log(InvalidFloat({"parent":self.parent.name, "element":self.name,
        "attr": ':'.join(self.name.split('_',1)), "value":self.value}))

class floatUnit(text):
  def validate(self):
    import re
    if not re.match('\d+\.?\d*\s*\w*$', self.value):
      self.log(InvalidFloatUnit({"parent":self.parent.name, "element":self.name,
        "attr": ':'.join(self.name.split('_',1)), "value":self.value}))

class decimal(text):
  def validate(self):
    import re
    if not re.match('[-+]?\d+\.?\d*\s*$', self.value):
      self.log(InvalidFloatUnit({"parent":self.parent.name, "element":self.name,
        "attr": ':'.join(self.name.split('_',1)), "value":self.value}))

class g_year(text):
  def validate(self):
    import time
    try:
      year = int(self.value)
      if year < 1900 or year > time.localtime()[0]+4: raise InvalidYear
    except:
      self.log(InvalidYear({"parent":self.parent.name, "element":self.name,
        "attr": ':'.join(self.name.split('_',1)), "value":self.value}))

class g_intUnit(text):
  def validate(self):
    try:
      if int(self.value.split(' ')[0].replace(',','')) < 0: raise InvalidIntUnit
    except:
      self.log(InvalidIntUnit({"parent":self.parent.name, "element":self.name,
        "attr": ':'.join(self.name.split('_',1)), "value":self.value}))

class maxten(validatorBase):
  def textOK(self):
    pass

  def prevalidate(self):
    if 10 == len([1 for child in self.parent.children if self.name==child]):
      self.log(TooMany({"parent":self.parent.name, "element":self.name}))

class in_reply_to(canonicaluri, xmlbase):
  def getExpectedAttrNames(self):
    return [(None, u'href'), (None, u'ref'), (None, u'source'), (None, u'type')]

  def validate(self):
    if self.attrs.has_key((None, "href")):
      self.value = self.attrs.getValue((None, "href"))
      self.name = "href"
      xmlbase.validate(self)

    if self.attrs.has_key((None, "ref")):
      self.value = self.attrs.getValue((None, "ref"))
      self.name = "ref"
      canonicaluri.validate(self)

    if self.attrs.has_key((None, "source")):
      self.value = self.attrs.getValue((None, "source"))
      self.name = "source"
      xmlbase.validate(self)

    if self.attrs.has_key((None, "type")):
      self.value = self.attrs.getValue((None, "type"))
      if not mime_re.match(self.value):
        self.log(InvalidMIMEType({"parent":self.parent.name, "element":self.name, "attr":"type", "value":self.value}))
      else:
        self.log(ValidMIMEAttribute({"parent":self.parent.name, "element":self.name, "attr":"type", "value":self.value}))
