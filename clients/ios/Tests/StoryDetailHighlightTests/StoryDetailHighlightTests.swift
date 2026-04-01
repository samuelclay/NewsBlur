import JavaScriptCore
import XCTest

final class StoryDetailHighlightTests: XCTestCase {
    func test_applyClassifierHighlights_appends_score_icons_for_async_marks() throws {
        let context = try makeContext()
        let scriptURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("static/storyDetailView.js")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        context.evaluateScript(script)
        XCTAssertNil(context.exception)

        let iconCount = context.evaluateScript(
            """
            resetMocks();
            applyClassifierHighlights({
                texts: { "Claude Code": 1 },
                text_regex: {}
            });
            flushTimeouts();
            flushPendingMarks();
            iconCount();
            """
        )

        XCTAssertNil(context.exception)
        XCTAssertEqual(iconCount?.toInt32(), 1)
    }

    private func makeContext() throws -> JSContext {
        let context = try XCTUnwrap(JSContext())
        let exceptionExpectation = XCTestExpectation(description: "JavaScript exception")
        exceptionExpectation.isInverted = true

        context.exceptionHandler = { _, exception in
            if let exception {
                XCTFail("JavaScript exception: \(exception)")
                exceptionExpectation.fulfill()
            }
        }

        context.evaluateScript(
            #"""
            var timeoutQueue = [];
            var pendingMarks = [];

            function setTimeout(fn) {
                timeoutQueue.push(fn);
                return timeoutQueue.length;
            }

            function flushTimeouts() {
                while (timeoutQueue.length) {
                    timeoutQueue.shift()();
                }
            }

            function flushPendingMarks() {
                while (pendingMarks.length) {
                    pendingMarks.shift()();
                }
            }

            function MockElement(className) {
                this.className = className || "";
                this.html = "";
                var self = this;
                this.classList = {
                    contains: function(name) {
                        return self.className.split(/\s+/).indexOf(name) !== -1;
                    }
                };
            }

            MockElement.prototype.querySelector = function(selector) {
                if (selector.indexOf("NB-score-icon") !== -1 && this.html.indexOf("NB-score-icon") !== -1) {
                    return {};
                }
                return null;
            };

            MockElement.prototype.insertAdjacentHTML = function(position, html) {
                this.html += html;
            };

            var container = {
                marks: [],
                querySelectorAll: function(selector) {
                    if (selector === "mark[data-markjs]") {
                        return this.marks;
                    }
                    return [];
                }
            };

            function resetMocks() {
                timeoutQueue = [];
                pendingMarks = [];
                container.marks = [];
            }

            function iconCount() {
                var count = 0;
                for (var i = 0; i < container.marks.length; i++) {
                    if (container.marks[i].html.indexOf("NB-score-icon") !== -1) {
                        count++;
                    }
                }
                return count;
            }

            var document = {
                getElementById: function(id) {
                    if (id === "NB-story") {
                        return container;
                    }
                    return null;
                },
                getElementsByClassName: function() {
                    return [];
                },
                elementFromPoint: function() {
                    return null;
                }
            };

            var window = {
                sampleText: true,
                location: "",
                pageYOffset: 0,
                console: { log: function() {} }
            };
            var console = window.console;

            function NoClickDelay() {}

            function JQueryStub() {}
            JQueryStub.prototype.live = function() { return this; };
            JQueryStub.prototype.each = function() { return this; };
            JQueryStub.prototype.bind = function() { return this; };
            JQueryStub.prototype.fitVids = function() { return this; };
            JQueryStub.prototype.closest = function() { return { length: 0 }; };
            JQueryStub.prototype.offset = function() { return { left: 0, top: 0, width: 0, height: 0 }; };
            JQueryStub.prototype.attr = function() { return ""; };
            JQueryStub.prototype.width = function() { return 0; };
            JQueryStub.prototype.height = function() { return 0; };
            JQueryStub.prototype.prop = function() { return ""; };
            JQueryStub.prototype.parent = function() { return this; };
            JQueryStub.prototype.addClass = function() { return this; };
            JQueryStub.prototype.removeClass = function() { return this; };
            JQueryStub.prototype.hasClass = function() { return false; };
            JQueryStub.prototype.contents = function() { return { unwrap: function() {} }; };

            function $(selector) {
                return new JQueryStub(selector);
            }
            $.scroll = function() {};

            function Zepto(callback) {
                if (callback) {
                    callback($);
                }
            }

            function Mark(ctx) {
                this.ctx = ctx;
            }

            Mark.prototype.unmark = function(opt) {
                if (opt && opt.done) {
                    opt.done();
                }
                return this;
            };

            Mark.prototype.mark = function(text, opt) {
                var ctx = this.ctx;
                pendingMarks.push(function() {
                    var el = new MockElement(opt.className);
                    ctx.marks.push(el);
                    if (opt.each) {
                        opt.each(el);
                    }
                });
                return this;
            };

            Mark.prototype.markRegExp = function(regex, opt) {
                var ctx = this.ctx;
                pendingMarks.push(function() {
                    var el = new MockElement(opt.className);
                    ctx.marks.push(el);
                    if (opt.each) {
                        opt.each(el);
                    }
                });
                return this;
            };
            """#
        )

        XCTAssertNil(context.exception)
        wait(for: [exceptionExpectation], timeout: 0.01)

        return context
    }
}
