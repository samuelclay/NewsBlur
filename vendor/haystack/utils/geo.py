from django.contrib.gis.geos import Point
from django.contrib.gis.measure import Distance, D
from haystack.constants import WGS_84_SRID
from haystack.exceptions import SpatialError


def ensure_geometry(geom):
    """
    Makes sure the parameter passed in looks like a GEOS ``GEOSGeometry``.
    """
    if not hasattr(geom, 'geom_type'):
        raise SpatialError("Point '%s' doesn't appear to be a GEOS geometry." % geom)

    return geom


def ensure_point(geom):
    """
    Makes sure the parameter passed in looks like a GEOS ``Point``.
    """
    ensure_geometry(geom)

    if geom.geom_type != 'Point':
        raise SpatialError("Provided geometry '%s' is not a 'Point'." % geom)

    return geom


def ensure_wgs84(point):
    """
    Ensures the point passed in is a GEOS ``Point`` & returns that point's
    data is in the WGS-84 spatial reference.
    """
    ensure_point(point)
    # Clone it so we don't alter the original, in case they're using it for
    # something else.
    new_point = point.clone()

    if not new_point.srid:
        # It has no spatial reference id. Assume WGS-84.
        new_point.set_srid(WGS_84_SRID)
    elif new_point.srid != WGS_84_SRID:
        # Transform it to get to the right system.
        new_point.transform(WGS_84_SRID)

    return new_point


def ensure_distance(dist):
    """
    Makes sure the parameter passed in is a 'Distance' object.
    """
    try:
        # Since we mostly only care about the ``.km`` attribute, make sure
        # it's there.
        km = dist.km
    except AttributeError:
        raise SpatialError("'%s' does not appear to be a 'Distance' object." % dist)

    return dist


def generate_bounding_box(point_1, point_2):
    """
    Takes two opposite corners of a bounding box (in any order) & generates
    a two-tuple of the correct coordinates for the bounding box.

    The two-tuple is in the form ``((min_lat, min_lng), (max_lat, max_lng))``.
    """
    lng_1, lat_1 = point_1.get_coords()
    lng_2, lat_2 = point_2.get_coords()
    min_lat, max_lat = min(lat_1, lat_2), max(lat_1, lat_2)
    min_lng, max_lng = min(lng_1, lng_2), max(lng_1, lng_2)
    return ((min_lat, min_lng), (max_lat, max_lng))
