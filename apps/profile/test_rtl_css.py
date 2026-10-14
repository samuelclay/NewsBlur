import os
import re
import tempfile
from types import SimpleNamespace
from unittest.mock import Mock, patch

from django.core.handlers.exception import convert_exception_to_response
from django.template import Context, Template
from django.test import RequestFactory, SimpleTestCase
from pipeline.conf import settings as pipeline_settings

from apps.profile import language
from apps.profile.language import (
    FLIPPED_STYLESHEET_PATTERN,
    LanguageCatalogMiddleware,
    NewsBlurLocaleMiddleware,
    flipped_stylesheet_data,
    flipped_stylesheet_sources,
    language_context,
)
from utils.rtl_css import absolutize_urls, flip_stylesheet


def declarations(css):
    """test_rtl_css.py: {selector: "prop:value;..."} with whitespace removed, for order-free comparisons."""
    css = re.sub(r"\s+", "", css)
    return {selector: body.rstrip(";") for selector, body in re.findall(r"([^{}]+)\{([^{}]*)\}", css)}


class Test_RtlCss(SimpleTestCase):
    def test_shorthands_and_one_sided_properties_swap_sides(self):
        flipped = flip_stylesheet(
            ".a { margin: 1px 2px 3px 4px; padding: 1px 2px; border-width: 0 0 0 1px; inset: 0 auto auto 0; }"
            ".b { margin-left: 4px; padding-right: 6px; border-left: 1px solid red; border-right-color: blue; }"
            ".c { left: 0; right: auto; }"
        )
        self.assertEqual(
            flipped,
            ".a { margin: 1px 4px 3px 2px; padding: 1px 2px; border-width: 0 1px 0 0; inset: 0 0 auto auto; }"
            ".b { margin-right: 4px; padding-left: 6px; border-right: 1px solid red; border-left-color: blue; }"
            ".c { right: 0; left: auto; }",
        )

    def test_one_sided_rules_keep_the_cascade_instead_of_resetting(self):
        # test_rtl_css.py: the override stylesheet reset padding-right to 0 here and wiped the 40px.
        flipped = declarations(
            flip_stylesheet(
                ".NB-story-pane-west .NB-story-title { padding-left: 40px; }"
                ".NB-image-preview-small-right .NB-story-pane-west .NB-story-title.NB-has-image"
                " { padding-right: 90px; }"
            )
        )
        self.assertEqual(flipped[".NB-story-pane-west.NB-story-title"], "padding-right:40px")
        self.assertEqual(
            flipped[".NB-image-preview-small-right.NB-story-pane-west.NB-story-title.NB-has-image"],
            "padding-left:90px",
        )

    def test_keywords_and_cursors_swap(self):
        self.assertEqual(
            flip_stylesheet(
                ".a{float:left;clear:right;text-align:LEFT;cursor:e-resize}.b{float:none;cursor:nwse-resize}"
            ),
            ".a{float:right;clear:left;text-align:right;cursor:w-resize}.b{float:none;cursor:nesw-resize}",
        )

    def test_border_radius_mirrors_corners(self):
        flipped = flip_stylesheet(
            ".a{border-radius:1px 2px 3px 4px / 5px 6px}"
            ".b{border-radius:1px 2px 3px}"
            ".c{border-radius:4px}"
            ".d{border-top-left-radius:3px;-webkit-border-bottom-right-radius:2px;-moz-border-radius-topleft:1px}"
        )
        self.assertEqual(
            flipped,
            ".a{border-radius:2px 1px 4px 3px / 6px 5px}"
            ".b{border-radius:2px 1px 2px 3px}"
            ".c{border-radius:4px}"
            ".d{border-top-right-radius:3px;-webkit-border-bottom-left-radius:2px;-moz-border-radius-topright:1px}",
        )

    def test_background_positions(self):
        flipped = declarations(
            flip_stylesheet(
                ".keywords{background-position:left center, top right}"
                ".percent{background-position:30% 50%, 50% 0}"
                ".offset{background-position:4px 6px}"
                ".offset-keyword{background:transparent url('/a.svg') no-repeat 4px center}"
                ".zero{background:url(/a.svg) no-repeat 0 0;background-size:16px}"
                ".sprite-cell{background-position:-16px 0}"
                ".edge{background-position:right 8px top 2px}"
                ".axis{background-position-x:10px}"
                ".sized{background:url(/a.svg) no-repeat center/16px}"
            )
        )
        self.assertEqual(flipped[".keywords"], "background-position:rightcenter,topleft")
        self.assertEqual(flipped[".percent"], "background-position:70%50%,50%0")
        self.assertEqual(flipped[".offset"], "background-position:right4pxtop6px")
        self.assertEqual(
            flipped[".offset-keyword"], "background:transparenturl('/a.svg')no-repeatright4pxcenter"
        )
        self.assertEqual(flipped[".zero"], "background:url(/a.svg)no-repeat100%0;background-size:16px")
        self.assertEqual(flipped[".sprite-cell"], "background-position:-16px0")
        self.assertEqual(flipped[".edge"], "background-position:left8pxtop2px")
        self.assertEqual(flipped[".axis"], "background-position-x:right10px")
        self.assertEqual(flipped[".sized"], "background:url(/a.svg)no-repeatcenter/16px")

    def test_default_image_positions_mirror_whether_written_or_not(self):
        # test_rtl_css.py: LightningCSS drops "0 0" from minified bundles, so both forms must agree.
        flipped = declarations(
            flip_stylesheet(
                ".written{background:url(/a.svg) no-repeat 0 0}.implicit{background:url(/a.svg) no-repeat}"
                ".color{background:0 0}.gradient{background:linear-gradient(#fff,#000)}"
            )
        )
        self.assertEqual(flipped[".written"], "background:url(/a.svg)no-repeat100%0")
        self.assertEqual(flipped[".implicit"], "background:url(/a.svg)no-repeat100%0")
        self.assertEqual(flipped[".color"], "background:00")
        self.assertEqual(flipped[".gradient"], "background:linear-gradient(#fff,#000)")

    def test_sprite_sheets_keep_their_offsets(self):
        css = ".ui-icon-carat{background-position:0 0}.x{background:url(/img/chosen-sprite.png) no-repeat 4px 2px}"
        self.assertEqual(flip_stylesheet(css), css)

    def test_gradients_and_shadows(self):
        flipped = declarations(
            flip_stylesheet(
                ".fade{background:linear-gradient(to right,#fff 0%,rgba(0,0,0,0) 100%)}"
                ".bar{background:linear-gradient(90deg,#22c55e,#16a34a)}"
                ".diagonal{background:linear-gradient(135deg,#fff,#000)}"
                ".mask{-webkit-mask-image:linear-gradient(to left,black 80%,transparent)}"
                ".shadow{box-shadow:inset 2px 0 3px #000,-1px 1px rgba(0,0,0,.2);text-shadow:0 1px #fff}"
            )
        )
        self.assertEqual(flipped[".fade"], "background:linear-gradient(toleft,#fff0%,rgba(0,0,0,0)100%)")
        self.assertEqual(flipped[".bar"], "background:linear-gradient(270deg,#22c55e,#16a34a)")
        self.assertEqual(flipped[".diagonal"], "background:linear-gradient(135deg,#fff,#000)")
        self.assertEqual(flipped[".mask"], "-webkit-mask-image:linear-gradient(toright,black80%,transparent)")
        self.assertEqual(
            flipped[".shadow"], "box-shadow:inset-2px03px#000,1px1pxrgba(0,0,0,.2);text-shadow:01px#fff"
        )

    def test_media_queries_are_flipped_and_other_at_rules_are_untouched(self):
        css = (
            '@charset "utf-8";@import url(/a.css);'
            "@media (max-width: 10px){@supports (display:grid){.a{left:0;float:right}}}"
            "@font-face{font-family:x;src:url(/f.woff) format('woff');unicode-range:U+0-7F}"
            "@keyframes slide{from{left:0;margin-left:4px}to{left:10px}}"
            "@page{margin-left:1in}"
        )
        self.assertEqual(
            flip_stylesheet(css),
            '@charset "utf-8";@import url(/a.css);'
            "@media (max-width: 10px){@supports (display:grid){.a{right:0;float:left}}}"
            "@font-face{font-family:x;src:url(/f.woff) format('woff');unicode-range:U+0-7F}"
            "@keyframes slide{from{left:0;margin-left:4px}to{left:10px}}"
            "@page{margin-left:1in}",
        )

    def test_javascript_positioned_elements_keep_their_offsets(self):
        flipped = flip_stylesheet(
            "#story_pane .NB-text-view{left:200%;margin-left:4px}"
            ".NB-popover{left:0;text-align:left}"
            ".centered{left:50%;transform:translateX(-50%);margin-left:2px}"
        )
        self.assertEqual(
            flipped,
            "#story_pane .NB-text-view{left:200%;margin-right:4px}"
            ".NB-popover{left:0;text-align:right}"
            ".centered{left:50%;transform:translateX(-50%);margin-right:2px}",
        )

    def test_story_content_and_chosen_stay_ltr(self):
        flipped = flip_stylesheet(
            ".NB-feed-story blockquote, .NB-feed-story-content img, .NB-sideoption blockquote{border-left:2px solid}"
            ".chzn-container .chzn-single div{right:0}.chzn-rtl .chzn-single div{left:3px;right:auto}"
        )
        self.assertEqual(
            flipped,
            ".NB-feed-story blockquote,.NB-feed-story-content img{border-left:2px solid}"
            ".NB-sideoption blockquote{border-right:2px solid}"
            ".chzn-container .chzn-single div{right:0}.chzn-rtl .chzn-single div{left:3px;right:auto}",
        )

    def test_minified_input_with_strings_urls_and_important(self):
        css = (
            '.a{content:"{;}";margin-left:0!important;background:url(data:image/svg+xml;base64,e30=) 0 50%}'
            ".b{padding:0 1px 0 2px !important}/* margin-left:9px */.c{right:1px}"
        )
        self.assertEqual(
            flip_stylesheet(css),
            '.a{content:"{;}";margin-right:0!important;background:url(data:image/svg+xml;base64,e30=) 100% 50%}'
            ".b{padding:0 2px 0 1px !important}.c{left:1px}",
        )

    def test_flipping_twice_restores_the_stylesheet(self):
        css = (
            ".a{margin:1px 2px 3px 4px;padding-left:5px!important;float:left;text-align:right;left:0}"
            "@media (min-width:1px){.b{border-radius:1px 2px 3px 4px;border-right:1px solid red;right:auto}}"
            ".c{background-position:30% 0,left top;box-shadow:inset 2px 1px #000;cursor:ne-resize}"
            ".d{background:linear-gradient(to right,#fff,#000);clear:left}"
            "@keyframes k{from{left:0}}"
        )
        self.assertEqual(flip_stylesheet(flip_stylesheet(css)), css)
        # test_rtl_css.py: a length offset comes back in its equivalent edge-offset form.
        self.assertEqual(
            flip_stylesheet(flip_stylesheet(".e{background-position:4px 6px}")),
            ".e{background-position:left 4px top 6px}",
        )

    def test_relative_urls_resolve_against_the_source_stylesheet(self):
        css = "a{background:url(img/x.png)}b{background:url('../y.png')}c{background:url(/z.png)}@import \"p.css\";"
        self.assertEqual(
            absolutize_urls(css, "/media/css/reader/reader.css"),
            "a{background:url(/media/css/reader/img/x.png)}b{background:url('/media/css/y.png')}"
            'c{background:url(/z.png)}@import "/media/css/reader/p.css";',
        )


class Test_RtlStylesheetView(SimpleTestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.source = os.path.join(self.directory.name, "common.css")
        with open(self.source, "w") as stylesheet:
            stylesheet.write(".a{margin-left:4px;background:url(img/a.png) no-repeat 0 0}")
        sources = patch(
            "apps.profile.language.flipped_stylesheet_sources",
            side_effect=lambda bundle: ((self.source, "/media/css/reader/common.css"),),
        )
        sources.start()
        self.addCleanup(sources.stop)
        language._flipped_stylesheet_build.cache_clear()
        self.addCleanup(language._flipped_stylesheet_build.cache_clear)

    def rtl_request(self):
        request = self.factory.get("/", HTTP_ACCEPT_LANGUAGE="ar")
        request.user = SimpleNamespace(is_authenticated=False)
        NewsBlurLocaleMiddleware(lambda request: None).process_request(request)
        return request

    def test_rtl_pages_link_a_versioned_immutable_flipped_stylesheet(self):
        url = language_context(self.rtl_request())["ui_flipped_stylesheets"]["common"]
        self.assertRegex(url[1:], FLIPPED_STYLESHEET_PATTERN)
        downstream = Mock()
        response = LanguageCatalogMiddleware(downstream)(
            self.factory.get(url, HTTP_COOKIE="newsblur_sessionid=x")
        )
        downstream.assert_not_called()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Content-Type"], "text/css; charset=utf-8")
        self.assertEqual(response["Cache-Control"], "public, max-age=31536000, immutable")
        self.assertFalse(response.cookies)
        self.assertEqual(
            response.content,
            b".a{margin-right:4px;background:url(/media/css/reader/img/a.png) no-repeat 100% 0}",
        )
        conditional = self.factory.get(url, HTTP_IF_NONE_MATCH="W/" + response["ETag"])
        self.assertEqual(LanguageCatalogMiddleware(downstream)(conditional).status_code, 304)

    def test_an_older_version_is_served_without_caching(self):
        response = LanguageCatalogMiddleware(Mock())(self.factory.get("/rtl/common/0123456789abcdef.css"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Cache-Control"], "no-store")

    def test_only_flippable_bundles_are_served(self):
        # test_rtl_css.py: Django wraps each middleware so the Http404 it raises becomes a 404 response.
        middleware = convert_exception_to_response(LanguageCatalogMiddleware(Mock()))
        response = middleware(self.factory.get("/rtl/bookmarklet/0123456789abcdef.css"))
        self.assertEqual(response.status_code, 404)

    def test_editing_a_source_file_changes_the_version(self):
        _, before = flipped_stylesheet_data("common")
        with open(self.source, "w") as stylesheet:
            stylesheet.write(".a{margin-left:8px}")
        _, after = flipped_stylesheet_data("common")
        self.assertNotEqual(before, after)

    def test_ltr_pages_never_build_a_flip(self):
        request = self.factory.get("/", HTTP_ACCEPT_LANGUAGE="en")
        request.user = SimpleNamespace(is_authenticated=False)
        NewsBlurLocaleMiddleware(lambda request: None).process_request(request)
        with patch("apps.profile.language.flipped_stylesheet_data") as data:
            context = language_context(request)
            self.assertEqual(context["ui_flipped_stylesheets"], {})
        data.assert_not_called()

    def test_stylesheet_tag_links_the_flip_only_on_rtl_pages(self):
        template = Template('{% load utils_tags %}{% include_stylesheets "common" %}')
        rtl_html = template.render(Context(language_context(self.rtl_request())))
        self.assertRegex(rtl_html, r'^<link href="/rtl/common/[a-f0-9]{16}\.css" rel="stylesheet"')
        ltr_html = template.render(Context({"ui_flipped_stylesheets": {}}))
        self.assertIn("/css/reader/reader.css", ltr_html)
        self.assertNotIn("/rtl/", ltr_html)

    def test_production_reads_the_compiled_bundle(self):
        storage = Mock()
        storage.stored_name.return_value = "css/common.0123456789ab.css"
        storage.path.return_value = "/srv/newsblur/static/css/common.0123456789ab.css"
        with patch.dict(pipeline_settings.settings, {"PIPELINE_ENABLED": True}), patch(
            "apps.profile.language.staticfiles_storage", storage
        ):
            # test_rtl_css.py: setUp patches the module attribute, so this calls the imported original.
            sources = flipped_stylesheet_sources("common")
        storage.stored_name.assert_called_once_with("css/common.css")
        self.assertEqual(
            sources,
            (("/srv/newsblur/static/css/common.0123456789ab.css", "/static/css/common.0123456789ab.css"),),
        )
