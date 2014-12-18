from rdflib.Namespace import Namespace


# The RDF Namespace
# http://ilrt.org/discovery/2001/07/rdf-syntax-grammar/#section-Namespace
RDFNS = Namespace("http://www.w3.org/1999/02/22-rdf-syntax-ns#")

# Syntax names
RDF = RDFNS["RDF"]
DESCRIPTION = RDFNS["Description"]
ID = RDFNS["ID"]
ABOUT = RDFNS["about"]
PARSE_TYPE = RDFNS["parseType"]
RESOURCE = RDFNS["resource"]
LI = RDFNS["li"]
NODE_ID = RDFNS["nodeID"]
DATATYPE = RDFNS["datatype"]

# RDF Classes
SEQ = RDFNS["Seq"]
BAG = RDFNS["Bag"]
ALT = RDFNS["Alt"]
STATEMENT = RDFNS["Statement"]
PROPERTY = RDFNS["Property"]
XMLLiteral = RDFNS["XMLLiteral"]
LIST = RDFNS["List"]

# RDF Properties
SUBJECT = RDFNS["subject"]
PREDICATE = RDFNS["predicate"]
OBJECT = RDFNS["object"]
TYPE = RDFNS["type"]
VALUE = RDFNS["value"]
FIRST = RDFNS["first"]
REST = RDFNS["rest"]
# and _n where n is a non-negative integer

# RDF Resources
NIL = RDFNS["nil"]


# http://www.w3.org/TR/rdf-syntax-grammar/#eventterm-attribute-URI
# A mapping from unqualified terms to there qualified version.
UNQUALIFIED = {"about" : ABOUT, "ID" : ID, 
               "type" : TYPE, "resource": RESOURCE, "parseType": PARSE_TYPE}

# http://www.w3.org/TR/rdf-syntax-grammar/#coreSyntaxTerms
CORE_SYNTAX_TERMS = [RDF, ID, ABOUT, PARSE_TYPE, RESOURCE, NODE_ID, DATATYPE]

# http://www.w3.org/TR/rdf-syntax-grammar/#syntaxTerms
SYNTAX_TERMS = CORE_SYNTAX_TERMS + [DESCRIPTION, LI]

# http://www.w3.org/TR/rdf-syntax-grammar/#oldTerms
OLD_TERMS = [RDFNS["aboutEach"], RDFNS["aboutEachPrefix"], RDFNS["bagID"]]


# SCHEMA
RDFSNS = Namespace("http://www.w3.org/2000/01/rdf-schema#")

RDFS_CLASS = RDFSNS["Class"]
RDFS_RESOURCE = RDFSNS["Resource"]
RDFS_SUBCLASSOF = RDFSNS["subClassOf"]
RDFS_SUBPROPERTYOF = RDFSNS["subPropertyOf"]
RDFS_ISDEFINEDBY = RDFSNS["isDefinedBy"]
RDFS_LABEL = RDFSNS["label"]
RDFS_COMMENT = RDFSNS["comment"]
RDFS_RANGE = RDFSNS["range"]
RDFS_DOMAIN = RDFSNS["domain"]
RDFS_LITERAL = RDFSNS["Literal"]
RDFS_CONTAINER = RDFSNS["Container"]
RDFS_SEEALSO = RDFSNS["seeAlso"]
